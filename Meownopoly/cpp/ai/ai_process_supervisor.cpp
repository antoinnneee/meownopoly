#include "ai_process_supervisor.h"

#include "gateway/ai_gateway_server.h"

#include <QCoreApplication>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTimer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>
#include <QStandardPaths>
#include <QUuid>
#include <QUrl>
#include <QDebug>

#include <string>
#include <utility>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

// ============================================================================
// Constantes de politique (doc 14 §4 — questions ouvertes tranchées par un
// défaut raisonnable et paramétrable ici). Toutes en un point unique pour être
// ré-arbitrées facilement.
// ============================================================================

// Fenêtre par défaut avant de considérer un démarrage comme échoué.
#ifndef MEOW_AI_STARTUP_TIMEOUT_MS
#  define MEOW_AI_STARTUP_TIMEOUT_MS 30000
#endif
// Borne d'exécution par défaut d'une invocation one-shot (0 = désactivée).
#ifndef MEOW_AI_INVOCATION_TIMEOUT_MS
#  define MEOW_AI_INVOCATION_TIMEOUT_MS 0
#endif
// Nombre de redémarrages automatiques avant Failed définitif (crash involontaire).
#ifndef MEOW_AI_MAX_RESTARTS
#  define MEOW_AI_MAX_RESTARTS 2
#endif
// Backoff de base entre redémarrages (multiplié par le rang de tentative).
#ifndef MEOW_AI_RESTART_BACKOFF_MS
#  define MEOW_AI_RESTART_BACKOFF_MS 1500
#endif
// Délai laissé à un arrêt gracieux (terminate) avant le kill dur.
#ifndef MEOW_AI_GRACEFUL_KILL_MS
#  define MEOW_AI_GRACEFUL_KILL_MS 3000
#endif
// Plafond de la capture stdout/stderr par agent (anneau : on garde la fin).
#ifndef MEOW_AI_OUTPUT_BUFFER_BYTES
#  define MEOW_AI_OUTPUT_BUFFER_BYTES (64 * 1024)
#endif

// — Handshake arbitre (C6, D24/D31) —
// Version de protocole du canal attendue. Co-versionnée AVEC le manifeste
// (channel_manifest.json → protocolVersion, aujourd'hui 1.0.0) et le contrat
// machine généré (D17) : à régénérer/re-synchroniser en M12/T5-2. Recopie
// manuelle assumée au MVP, comme la table ToolDef de la passerelle.
#ifndef MEOW_AI_PROTOCOL_VERSION
#  define MEOW_AI_PROTOCOL_VERSION "1.0.0"
#endif
// Capacité (tool) que l'arbitre DOIT voir pour prouver son rôle (challenge D24).
#ifndef MEOW_AI_ARBITER_CAPABILITY
#  define MEOW_AI_ARBITER_CAPABILITY "arbiter_verdict"
#endif
// Borne d'un challenge de handshake (l'agent doit répondre vite). En deçà, on
// considère l'arbitre indisponible (Erreur), pas un plantage à redémarrer.
#ifndef MEOW_AI_HANDSHAKE_TIMEOUT_MS
#  define MEOW_AI_HANDSHAKE_TIMEOUT_MS 25000
#endif

namespace {

// Wrapper de QProcess::ExitStatus / ProcessError en int pour découplage header.
constexpr int kCrashExit = 1; // QProcess::CrashExit

QString roleName(AiProcessSupervisor::Role r)
{
    return r == AiProcessSupervisor::Arbiter ? QStringLiteral("arbiter")
                                             : QStringLiteral("proposer");
}

// Marqueur machine que l'agent arbitre émet sur stdout au terme du challenge.
// Format : `MEOW_ARBITER_HANDSHAKE:{"role":"arbiter","protocolVersion":"1.0.0",
//           "capabilities":["arbiter_verdict", ...]}`.
constexpr const char *kHandshakeMarker = "MEOW_ARBITER_HANDSHAKE:";

void appendUniquePath(QStringList *paths, const QString &path)
{
    if (!paths || path.trimmed().isEmpty())
        return;

    QString normalizedPath = path.trimmed();
    if (normalizedPath.size() >= 2
        && ((normalizedPath.front() == u'\"' && normalizedPath.back() == u'\"')
            || (normalizedPath.front() == u'\'' && normalizedPath.back() == u'\''))) {
        normalizedPath = normalizedPath.mid(1, normalizedPath.size() - 2);
    }
    const QString cleanPath = QDir::cleanPath(normalizedPath);
#ifdef Q_OS_WIN
    for (const QString &existing : std::as_const(*paths)) {
        if (existing.compare(cleanPath, Qt::CaseInsensitive) == 0)
            return;
    }
#else
    if (paths->contains(cleanPath))
        return;
#endif
    paths->append(cleanPath);
}

QString tomlString(const QString &value)
{
    QString escaped = value;
    escaped.replace(u'\\', QStringLiteral("\\\\"));
    escaped.replace(u'\"', QStringLiteral("\\\""));
    escaped.replace(u'\n', QStringLiteral("\\n"));
    escaped.replace(u'\r', QStringLiteral("\\r"));
    return u'\"' + escaped + u'\"';
}

void appendPathList(QStringList *paths, const QString &pathList)
{
    for (const QString &path : pathList.split(QDir::listSeparator(), Qt::SkipEmptyParts))
        appendUniquePath(paths, path);
}

#ifdef Q_OS_WIN
QString expandWindowsEnvironment(const QString &value)
{
    const DWORD required = ExpandEnvironmentStringsW(
        reinterpret_cast<LPCWSTR>(value.utf16()), nullptr, 0);
    if (required == 0)
        return value;

    std::wstring expanded(required, L'\0');
    if (ExpandEnvironmentStringsW(reinterpret_cast<LPCWSTR>(value.utf16()),
                                  expanded.data(), required) == 0) {
        return value;
    }
    if (!expanded.empty() && expanded.back() == L'\0')
        expanded.pop_back();
    return QString::fromStdWString(expanded);
}
#endif

QStringList executableSearchPaths()
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QStringList paths;

    // Le PATH du process reste prioritaire. Il couvre notamment les installs
    // système et les gestionnaires de versions actifs au lancement de l'app.
    appendPathList(&paths, env.value(QStringLiteral("PATH")));
    appendUniquePath(&paths, QCoreApplication::applicationDirPath());

    const auto appendEnvPath = [&env, &paths](const char *name,
                                              const QString &suffix = QString()) {
        const QString base = env.value(QString::fromLatin1(name));
        if (!base.isEmpty())
            appendUniquePath(&paths, suffix.isEmpty() ? base : QDir(base).filePath(suffix));
    };

#ifdef Q_OS_WIN
    // Une application ouverte depuis Explorer peut garder un PATH antérieur à
    // l'installation du CLI. Relire les deux PATH persistés évite d'imposer une
    // déconnexion/reconnexion ou un lancement depuis un terminal.
    QSettings userEnvironment(QStringLiteral("HKEY_CURRENT_USER\\Environment"),
                              QSettings::NativeFormat);
    QSettings machineEnvironment(
        QStringLiteral("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"),
        QSettings::NativeFormat);
    appendPathList(&paths, expandWindowsEnvironment(
                               userEnvironment.value(QStringLiteral("Path")).toString()));
    appendPathList(&paths, expandWindowsEnvironment(
                               machineEnvironment.value(QStringLiteral("Path")).toString()));

    // Emplacements standards des installateurs utilisateur qui ne mettent pas
    // toujours à jour le PATH du processus déjà ouvert.
    const QString home = QDir::homePath();
    const QString appData = env.value(QStringLiteral("APPDATA"),
                                      QDir(home).filePath(QStringLiteral("AppData/Roaming")));
    const QString localAppData = env.value(
        QStringLiteral("LOCALAPPDATA"),
        QDir(home).filePath(QStringLiteral("AppData/Local")));
    appendUniquePath(&paths, QDir(appData).filePath(QStringLiteral("npm")));
    appendUniquePath(&paths,
                     QDir(localAppData).filePath(QStringLiteral("Microsoft/WinGet/Links")));
    appendUniquePath(&paths, QDir(home).filePath(QStringLiteral(".local/bin")));

    appendEnvPath("PNPM_HOME");
    appendEnvPath("NVM_SYMLINK");
    appendEnvPath("VOLTA_HOME", QStringLiteral("bin"));
    appendEnvPath("BUN_INSTALL", QStringLiteral("bin"));
#else
    const QString home = QDir::homePath();
    appendUniquePath(&paths, QDir(home).filePath(QStringLiteral(".local/bin")));
    appendUniquePath(&paths, QDir(home).filePath(QStringLiteral(".npm-global/bin")));
    appendUniquePath(&paths, QDir(home).filePath(QStringLiteral(".cargo/bin")));
    appendUniquePath(&paths, QStringLiteral("/opt/homebrew/bin"));
    appendUniquePath(&paths, QStringLiteral("/usr/local/bin"));
    appendUniquePath(&paths, QStringLiteral("/opt/local/bin"));

    appendEnvPath("PNPM_HOME");
    appendEnvPath("VOLTA_HOME", QStringLiteral("bin"));
    appendEnvPath("BUN_INSTALL", QStringLiteral("bin"));
    appendEnvPath("NPM_CONFIG_PREFIX", QStringLiteral("bin"));
#endif
    return paths;
}

QString resolveProgram(const QString &requestedProgram, const QStringList &searchPaths)
{
    QString requested = requestedProgram.trimmed();
    // Accepte un chemin copié/collé depuis un terminal avec ses guillemets.
    if (requested.size() >= 2
        && ((requested.front() == u'\"' && requested.back() == u'\"')
            || (requested.front() == u'\'' && requested.back() == u'\''))) {
        requested = requested.mid(1, requested.size() - 2);
    }
    if (requested.isEmpty())
        return QString();

#ifdef Q_OS_WIN
    // CreateProcess ne sait lancer que les exécutables natifs. Chercher les
    // extensions dans cet ordre évite de sélectionner le shim POSIX sans
    // extension que npm pose à côté de codex.cmd.
    if (QFileInfo(requested).suffix().isEmpty()) {
        static const QStringList suffixes = {
            QStringLiteral(".exe"), QStringLiteral(".com"),
            QStringLiteral(".cmd"), QStringLiteral(".bat"),
            QStringLiteral(".ps1")
        };
        for (const QString &suffix : suffixes) {
            const QString found = QStandardPaths::findExecutable(requested + suffix,
                                                                 searchPaths);
            if (!found.isEmpty())
                return QDir::toNativeSeparators(found);
        }
    }
#endif

    const QString found = QStandardPaths::findExecutable(requested, searchPaths);
    return found.isEmpty() ? QString() : QDir::toNativeSeparators(found);
}

#ifdef Q_OS_WIN
QString quoteWindowsCommandArgument(const QString &argument)
{
    // Quoting compatible CommandLineToArgvW pour la commande placée derrière
    // cmd.exe /C. Les arguments usuels des CLIs (chemins inclus) restent ainsi
    // des tokens distincts ; le prompt, potentiellement arbitraire, passe par
    // stdin et ne touche jamais cette ligne de commande.
    QString quoted = QStringLiteral("\"");
    int backslashes = 0;
    for (const QChar ch : argument) {
        if (ch == u'\\') {
            ++backslashes;
            continue;
        }
        if (ch == u'\"') {
            quoted += QString(backslashes * 2 + 1, u'\\');
            quoted += ch;
            backslashes = 0;
            continue;
        }
        quoted += QString(backslashes, u'\\');
        backslashes = 0;
        quoted += ch;
    }
    quoted += QString(backslashes * 2, u'\\');
    quoted += u'\"';
    return quoted;
}

QString cmdNativeArguments(const QString &script, const QStringList &arguments)
{
    QString command = quoteWindowsCommandArgument(script);
    for (const QString &argument : arguments) {
        command += u' ';
        command += quoteWindowsCommandArgument(argument);
    }

    // /D neutralise les AutoRun utilisateur ; /S impose les règles stables de
    // retrait des guillemets externes de /C. Le guillemetage doublé est celui
    // requis par cmd.exe pour une commande dont le premier token est quoté.
    return QStringLiteral("/D /S /C \"") + command + u'\"';
}
#endif

} // namespace

AiProcessSupervisor *AiProcessSupervisor::m_instance = nullptr;

AiProcessSupervisor::AiProcessSupervisor(QObject *parent) : QObject(parent)
{
    // Garantie anti-orphelin : à la fermeture propre de l'application, tous les
    // enfants sont arrêtés gracieusement. Le destructeur (et, sous Windows, le
    // Job Object KILL_ON_JOB_CLOSE) couvrent en plus les fermetures brutales.
    if (qApp)
        connect(qApp, &QCoreApplication::aboutToQuit, this,
                &AiProcessSupervisor::stopAll);
}

AiProcessSupervisor::~AiProcessSupervisor()
{
    // Aucun orphelin : on tue durement ce qui vit encore, synchronement.
    const auto agents = m_agents.values();
    for (Agent *a : agents) {
        if (a->process) {
            a->intentionalStop = true;
            forceKill(a);
        }
        cleanupProcess(a);
        delete a;
    }
    m_agents.clear();

#ifdef Q_OS_WIN
    if (m_jobHandle) {
        // La fermeture du handle déclenche KILL_ON_JOB_CLOSE → tout l'arbre de
        // process rattaché meurt, y compris les petits-enfants (Node du CLI).
        CloseHandle(reinterpret_cast<HANDLE>(m_jobHandle));
        m_jobHandle = nullptr;
    }
#endif

    if (m_instance == this)
        m_instance = nullptr;
}

AiProcessSupervisor *AiProcessSupervisor::instance()
{
    if (!m_instance)
        m_instance = new AiProcessSupervisor();
    return m_instance;
}

QObject *AiProcessSupervisor::qmlInstance(QQmlEngine *, QJSEngine *)
{
    return instance();
}

void AiProcessSupervisor::registerQml()
{
    qmlRegisterSingletonType<AiProcessSupervisor>(
        "AiSupervisor", 1, 0, "AiProcessSupervisor",
        &AiProcessSupervisor::qmlInstance);
}

// ============================================================================
// Accès aux agents
// ============================================================================

AiProcessSupervisor::Agent *AiProcessSupervisor::agentFor(int role, bool create)
{
    auto it = m_agents.find(role);
    if (it != m_agents.end())
        return it.value();
    if (!create)
        return nullptr;
    Agent *a = new Agent();
    a->role = static_cast<Role>(role);
    m_agents.insert(role, a);
    return a;
}

const AiProcessSupervisor::Agent *AiProcessSupervisor::agentFor(int role) const
{
    auto it = m_agents.constFind(role);
    return it == m_agents.constEnd() ? nullptr : it.value();
}

// ============================================================================
// Getters d'état
// ============================================================================

int AiProcessSupervisor::stateOf(int role) const
{
    const Agent *a = agentFor(role);
    return a ? static_cast<int>(a->state) : static_cast<int>(Stopped);
}

int AiProcessSupervisor::lobbyState(int role) const
{
    // Le résultat du handshake prime sur l'état brut du process : un arbitre
    // challengé avec succès reste `Prêt` même une fois son process one-shot
    // terminé (Stopped) ; un échec latche `Erreur` jusqu'au prochain test (D31).
    const Agent *a = agentFor(role);
    if (a) {
        switch (a->handshakePhase) {
        case HsInProgress: return Testing;
        case HsPassed:     return Prete;
        case HsFailed:     return Erreur;
        default:           break; // HsNone → projection de l'état process
        }
    }
    switch (static_cast<State>(stateOf(role))) {
    case Stopped:    return Absent;
    case Starting:   return Testing;
    case Restarting: return Testing;
    case Ready:      return Prete;
    case Failed:     return Erreur;
    }
    return Absent;
}

bool AiProcessSupervisor::arbiterReady() const
{
    const Agent *a = agentFor(Arbiter);
    return a && a->handshakePhase == HsPassed;
}

QString AiProcessSupervisor::arbiterHandshakeReason() const
{
    const Agent *a = agentFor(Arbiter);
    return a ? a->handshakeReason : QString();
}

QString AiProcessSupervisor::protocolVersion() const
{
    return QStringLiteral(MEOW_AI_PROTOCOL_VERSION);
}

// — Diagnostic passerelle IA (lecture seule) ————————————————————————————————

bool AiProcessSupervisor::gatewayPresent() const
{
    return AiGatewayServer::instance() != nullptr;
}

bool AiProcessSupervisor::gatewayListening() const
{
    const AiGatewayServer *g = AiGatewayServer::instance();
    return g && g->isListening();
}

int AiProcessSupervisor::gatewayPort() const
{
    const AiGatewayServer *g = AiGatewayServer::instance();
    return g ? int(g->port()) : 0;
}

bool AiProcessSupervisor::gatewayHttpAvailable() const
{
    return AiGatewayServer::httpServerAvailable();
}

QString AiProcessSupervisor::gatewayProposerToken() const
{
    const AiGatewayServer *g = AiGatewayServer::instance();
    return g ? g->proposerToken() : QString();
}

QString AiProcessSupervisor::gatewayArbiterToken() const
{
    const AiGatewayServer *g = AiGatewayServer::instance();
    return g ? g->arbiterToken() : QString();
}

bool AiProcessSupervisor::isRunning(int role) const
{
    const Agent *a = agentFor(role);
    return a && a->process; // process non nul = vivant (nettoyé sur finished)
}

QString AiProcessSupervisor::lastError(int role) const
{
    const Agent *a = agentFor(role);
    return a ? a->lastError : QString();
}

QString AiProcessSupervisor::recentOutput(int role) const
{
    const Agent *a = agentFor(role);
    return a ? QString::fromUtf8(a->outputBuf) : QString();
}

// ============================================================================
// Machine à états
// ============================================================================

void AiProcessSupervisor::setState(Agent *a, State s, const QString &reason)
{
    if (!reason.isEmpty())
        a->lastError = reason;
    if (a->state == s)
        return;
    a->state = s;

    emit stateChanged(a->role, static_cast<int>(s));
    emitStateFor(a->role);
    emit logMessage(QStringLiteral("[AiSupervisor] %1 → %2%3")
                        .arg(roleName(a->role))
                        .arg(static_cast<int>(s))
                        .arg(reason.isEmpty() ? QString()
                                              : QStringLiteral(" (") + reason + ')'));

    if (s == Ready)
        emit agentReady(a->role);
    else if (s == Failed)
        emit agentFailed(a->role, a->lastError);
}

void AiProcessSupervisor::emitStateFor(Role role)
{
    if (role == Proposer) {
        emit proposerStateChanged();
    } else {
        emit arbiterStateChanged();
        // La projection lobby de l'arbitre dépend de l'état process quand aucun
        // handshake n'est en jeu (HsNone) : la garder synchrone.
        emit arbiterLobbyStateChanged();
    }
}

// ============================================================================
// Démarrage
// ============================================================================

bool AiProcessSupervisor::startAgent(int role, const QVariantMap &opts)
{
    if (role != Proposer && role != Arbiter) {
        emit logMessage(QStringLiteral("[AiSupervisor] Rôle inconnu: %1").arg(role));
        return false;
    }
    Agent *a = agentFor(role, /*create*/ true);
    if (a->process) {
        emit logMessage(QStringLiteral("[AiSupervisor] %1 déjà en cours — utiliser restart")
                            .arg(roleName(a->role)));
        return false;
    }
    a->restartCount = 0;
    a->intentionalStop = false;
    a->lastOpts = opts;
    return launch(a, opts);
}

bool AiProcessSupervisor::launch(Agent *a, const QVariantMap &opts)
{
    const Adapter adapter =
        static_cast<Adapter>(opts.value(QStringLiteral("adapter"), int(ClaudeCli)).toInt());
    QString requestedProgram = opts.value(QStringLiteral("program")).toString().trimmed();
    if (requestedProgram.isEmpty())
        requestedProgram = defaultProgram(adapter);

    const QStringList searchPaths = executableSearchPaths();
    QString program = resolveProgram(requestedProgram, searchPaths);
    if (program.isEmpty())
        program = requestedProgram; // laisse QProcess produire son diagnostic natif

    a->oneShot = opts.value(QStringLiteral("oneShot"), false).toBool();
    a->reachedReady = false;
    a->invocationTimeoutMs =
        opts.value(QStringLiteral("invocationTimeoutMs"),
                   MEOW_AI_INVOCATION_TIMEOUT_MS).toInt();
    // Chaque lancement repart d'un tampon de sortie vierge : un marqueur de
    // handshake (ou toute sortie) résiduel d'un run précédent ne doit jamais
    // être attribué au nouveau process (faux « Prêt » au challenge C6,
    // invocationCompleted pollué par les runs passés).
    a->outputBuf.clear();
    a->stdoutBuf.clear();

    // Claude reçoit un fichier MCP temporaire à permissions restreintes.
    // Codex reçoit l'URL via overrides TOML et lit le secret depuis une variable
    // d'environnement dédiée (son CLI n'accepte pas un fichier JSON ici).
    // Dans les deux cas le token ne touche jamais l'argv.
    cleanupMcpFileOnly(a);
    a->mcpConfigPath = adapter == ClaudeCli
                           ? writeMcpConfigFile(a->role, opts)
                           : QString();

    emit logMessage(
        QStringLiteral("[AiSupervisor] configuration %1 : adaptateur=%2, "
                       "passerelle=%3, token=%4, configMcp=%5, skill=%6")
            .arg(roleName(a->role),
                 adapter == Codex ? QStringLiteral("codex") : QStringLiteral("claude"),
                 gatewayUrlFromOpts(opts).isEmpty() ? QStringLiteral("absente")
                                                    : QStringLiteral("configurée"),
                 opts.value(QStringLiteral("token")).toString().isEmpty()
                     ? QStringLiteral("absent") : QStringLiteral("présent"),
                 a->mcpConfigPath.isEmpty() ? QStringLiteral("absente")
                                            : QStringLiteral("créée"),
                 opts.value(QStringLiteral("skillPath")).toString().isEmpty()
                     ? QStringLiteral("absente") : QStringLiteral("présente")));

    QStringList args = (adapter == Codex) ? codexArgs(opts, a->mcpConfigPath)
                                          : claudeArgs(opts, a->mcpConfigPath);

    QProcess *p = new QProcess(this);
    a->process = p;

    // Environnement : hérite du système, complété (jamais le token en clair sur
    // l'argv). On expose l'URL de la passerelle et le chemin de config MCP par
    // env pour les adaptateurs qui préfèrent l'env au flag.
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    // Utiliser le même PATH enrichi que la résolution. C'est nécessaire pour
    // les shims npm (.cmd), qui relancent généralement `node` par son nom.
    env.insert(QStringLiteral("PATH"), searchPaths.join(QDir::listSeparator()));
    env.insert(QStringLiteral("MEOW_AI_GATEWAY_URL"), gatewayUrlFromOpts(opts));
    if (!a->mcpConfigPath.isEmpty())
        env.insert(QStringLiteral("MEOW_AI_MCP_CONFIG"), a->mcpConfigPath);
    if (adapter == Codex) {
        const QString token = opts.value(QStringLiteral("token")).toString();
        if (!token.isEmpty())
            env.insert(QStringLiteral("MEOW_AI_MCP_BEARER_TOKEN"), token);
    }
    const QString skillPath = opts.value(QStringLiteral("skillPath")).toString();
    if (!skillPath.isEmpty())
        env.insert(QStringLiteral("MEOW_AI_SKILL_PATH"), skillPath);
    env.insert(QStringLiteral("MEOW_AI_ROLE"), roleName(a->role));
    p->setProcessEnvironment(env);

    const QString workingDir = opts.value(QStringLiteral("workingDir")).toString();
    if (!workingDir.isEmpty())
        p->setWorkingDirectory(workingDir);

    // stdout et stderr séparés pour distinguer diagnostic vs contenu.
    p->setProcessChannelMode(QProcess::SeparateChannels);

    const Role role = a->role;
    connect(p, &QProcess::started, this, [this, role]() {
        if (Agent *ag = agentFor(role, false)) onStarted(ag);
    });
    connect(p, &QProcess::finished, this,
            [this, role](int code, QProcess::ExitStatus st) {
                if (Agent *ag = agentFor(role, false))
                    onFinished(ag, code, static_cast<int>(st));
            });
    connect(p, &QProcess::errorOccurred, this, [this, role](QProcess::ProcessError e) {
        if (Agent *ag = agentFor(role, false)) onErrorOccurred(ag, static_cast<int>(e));
    });
    connect(p, &QProcess::readyReadStandardOutput, this, [this, role]() {
        if (Agent *ag = agentFor(role, false)) onReadyReadOut(ag);
    });
    connect(p, &QProcess::readyReadStandardError, this, [this, role]() {
        if (Agent *ag = agentFor(role, false)) onReadyReadErr(ag);
    });

    setState(a, Starting);

    // Timer de timeout de démarrage : si l'agent n'atteint pas Ready à temps,
    // on considère l'échec (kill + politique de redémarrage).
    const int startupMs =
        opts.value(QStringLiteral("startupTimeoutMs"), MEOW_AI_STARTUP_TIMEOUT_MS).toInt();
    if (startupMs > 0) {
        if (!a->startupTimer) {
            a->startupTimer = new QTimer(this);
            a->startupTimer->setSingleShot(true);
            connect(a->startupTimer, &QTimer::timeout, this, [this, role]() {
                Agent *ag = agentFor(role, false);
                if (!ag || ag->reachedReady) return;
                ag->lastError = QStringLiteral("timeout de démarrage");
                emit logMessage(QStringLiteral("[AiSupervisor] %1 timeout démarrage")
                                    .arg(roleName(ag->role)));
                // Traite comme un crash involontaire → politique de redémarrage.
                forceKill(ag); // onFinished enchaînera scheduleRestart / Failed
            });
        }
        a->startupTimer->start(startupMs);
    }

#ifdef Q_OS_WIN
    const QString suffix = QFileInfo(program).suffix().toLower();
    if (suffix == QStringLiteral("cmd") || suffix == QStringLiteral("bat")) {
        QString commandInterpreter = env.value(QStringLiteral("COMSPEC"));
        if (commandInterpreter.isEmpty())
            commandInterpreter = resolveProgram(QStringLiteral("cmd.exe"), searchPaths);
        p->setProgram(commandInterpreter.isEmpty() ? QStringLiteral("cmd.exe")
                                                    : commandInterpreter);
        p->setNativeArguments(cmdNativeArguments(program, args));
        p->start();
    } else if (suffix == QStringLiteral("ps1")) {
        QString powershell = resolveProgram(QStringLiteral("powershell.exe"), searchPaths);
        if (powershell.isEmpty())
            powershell = QStringLiteral("powershell.exe");
        QStringList powershellArgs{
            QStringLiteral("-NoLogo"), QStringLiteral("-NoProfile"),
            QStringLiteral("-NonInteractive"), QStringLiteral("-File"), program
        };
        powershellArgs += args;
        p->start(powershell, powershellArgs);
    } else {
        p->start(program, args);
    }
#else
    p->start(program, args);
#endif

    // Instantané synchrone : si le binaire est introuvable, errorOccurred
    // (FailedToStart) arrive de façon asynchrone — géré dans onErrorOccurred.
    emit logMessage(QStringLiteral("[AiSupervisor] lancement %1 : %2 → %3 (%4 arg)")
                        .arg(roleName(a->role), requestedProgram, program)
                        .arg(args.size()));

    // Le prompt initial (opts["prompt"]) est poussé sur stdin dans onStarted(),
    // une fois le canal d'entrée ouvert.
    return true;
}

// ============================================================================
// Handlers QProcess
// ============================================================================

void AiProcessSupervisor::onStarted(Agent *a)
{
    // Process en vie. On considère l'agent opérationnel (Ready) ; C6 pourra
    // conditionner cet état au handshake via notifyHandshake().
    a->reachedReady = true;
    if (a->startupTimer) a->startupTimer->stop();

    // Anti-orphelin : rattache l'enfant (et son arbre) au Job Object dès qu'il a
    // un PID, avant qu'il ne crée ses propres petits-enfants (Node du CLI).
    assignToJob(a->process);

    setState(a, Ready);

    emit logMessage(QStringLiteral(
                        "[AiSupervisor] %1 démarré : pid=%2, oneShot=%3, timeout=%4 ms")
                        .arg(roleName(a->role))
                        .arg(a->process ? a->process->processId() : 0)
                        .arg(a->oneShot ? QStringLiteral("oui") : QStringLiteral("non"))
                        .arg(a->invocationTimeoutMs));

    // Prompt initial différé jusqu'ici (canal stdin ouvert).
    const QString prompt = a->lastOpts.value(QStringLiteral("prompt")).toString();
    if (!prompt.isEmpty() && a->process) {
        a->process->write(prompt.toUtf8());
        a->process->write("\n");
        if (a->oneShot)
            a->process->closeWriteChannel(); // signale la fin d'entrée au CLI
    }

    // Borne d'exécution d'une invocation (facultative).
    if (a->invocationTimeoutMs > 0) {
        if (!a->invocationTimer) {
            a->invocationTimer = new QTimer(this);
            a->invocationTimer->setSingleShot(true);
            const Role role = a->role;
            connect(a->invocationTimer, &QTimer::timeout, this, [this, role]() {
                Agent *ag = agentFor(role, false);
                if (!ag || !ag->process) return;
                ag->lastError = QStringLiteral("timeout d'invocation");
                emit logMessage(QStringLiteral("[AiSupervisor] %1 timeout invocation")
                                    .arg(roleName(ag->role)));
                ag->intentionalStop = true; // dépassement borné → pas de restart
                forceKill(ag);
            });
        }
        a->invocationTimer->start(a->invocationTimeoutMs);
    }
}

void AiProcessSupervisor::onFinished(Agent *a, int exitCode, int exitStatus)
{
    if (a->startupTimer) a->startupTimer->stop();
    if (a->invocationTimer) a->invocationTimer->stop();

    const bool crashed = (exitStatus == kCrashExit);
    const QString responseOutput = QString::fromUtf8(a->stdoutBuf);

    emit logMessage(QStringLiteral(
                        "[AiSupervisor] %1 terminé : code=%2, statut=%3, sortie=%4 octets")
                        .arg(roleName(a->role))
                        .arg(exitCode)
                        .arg(crashed ? QStringLiteral("crash") : QStringLiteral("normal"))
                        .arg(a->outputBuf.size()));

    // Détache le QProcess du runtime avant toute décision de redémarrage.
    QProcess *p = a->process;
    a->process = nullptr;
    if (p) {
        p->disconnect(this);
        p->deleteLater();
    }
    cleanupMcpFileOnly(a);

    // C6 — un challenge d'arbitre en cours court-circuite la politique normale
    // (invocation/restart) : le résultat est décidé par la sortie du one-shot.
    if (a->handshakePhase == HsInProgress) {
        finishArbiterHandshake(a, responseOutput, crashed);
        return;
    }

    if (a->oneShot && !crashed && exitCode == 0) {
        // Invocation terminée normalement.
        emit invocationCompleted(a->role, exitCode, responseOutput);
        a->intentionalStop = false;
        setState(a, Stopped);
        return;
    }

    if (a->intentionalStop) {
        // Arrêt volontaire (stop/kill/timeout borné) : pas de redémarrage.
        a->intentionalStop = false;
        setState(a, Stopped);
        return;
    }

    // Sortie anormale involontaire (crash ou exit != 0) → politique de restart.
    a->lastError = crashed
                       ? QStringLiteral("crash du process")
                       : QStringLiteral("sortie anormale (code %1)").arg(exitCode);
    emit logMessage(QStringLiteral("[AiSupervisor] %1 %2")
                        .arg(roleName(a->role), a->lastError));

    if (a->restartCount < MEOW_AI_MAX_RESTARTS) {
        scheduleRestart(a);
    } else {
        setState(a, Failed, QStringLiteral("échec définitif après %1 redémarrage(s)")
                                 .arg(a->restartCount));
    }
}

void AiProcessSupervisor::onErrorOccurred(Agent *a, int processError)
{
    // QProcess::FailedToStart == 0. Les autres erreurs (Crashed, Timedout…)
    // remontent aussi ici mais le pilotage principal se fait via finished().
    if (processError == 0 /* FailedToStart */) {
        if (a->startupTimer) a->startupTimer->stop();
        QProcess *p = a->process;
        const QString nativeError = p ? p->errorString() : QString();
        a->process = nullptr;
        if (p) {
            p->disconnect(this);
            p->deleteLater();
        }
        cleanupMcpFileOnly(a);
        a->lastError = nativeError.isEmpty()
                           ? QStringLiteral("binaire introuvable ou non lançable")
                           : QStringLiteral("binaire introuvable ou non lançable : %1")
                                 .arg(nativeError);
        emit logMessage(QStringLiteral("[AiSupervisor] %1 échec de lancement : %2")
                            .arg(roleName(a->role), a->lastError));
        // Un challenge d'arbitre qui n'a même pas pu démarrer = Erreur latchée.
        if (a->handshakePhase == HsInProgress) {
            finishArbiterHandshake(a, QString(), /*crashed*/ false);
            return;
        }
        // Échec de lancement = pas de redémarrage en boucle : Failed direct.
        setState(a, Failed, a->lastError);
    }
}

void AiProcessSupervisor::onReadyReadOut(Agent *a)
{
    if (a->process)
        appendOutput(a, a->process->readAllStandardOutput(), /*isError*/ false);
}

void AiProcessSupervisor::onReadyReadErr(Agent *a)
{
    if (a->process)
        appendOutput(a, a->process->readAllStandardError(), /*isError*/ true);
}

void AiProcessSupervisor::appendOutput(Agent *a, const QByteArray &data, bool isError)
{
    if (data.isEmpty())
        return;
    a->outputBuf.append(data);
    // Anneau : on ne conserve que la fin (les derniers octets).
    if (a->outputBuf.size() > MEOW_AI_OUTPUT_BUFFER_BYTES)
        a->outputBuf = a->outputBuf.right(MEOW_AI_OUTPUT_BUFFER_BYTES);
    if (!isError) {
        a->stdoutBuf.append(data);
        if (a->stdoutBuf.size() > MEOW_AI_OUTPUT_BUFFER_BYTES)
            a->stdoutBuf = a->stdoutBuf.right(MEOW_AI_OUTPUT_BUFFER_BYTES);
    }
    emit outputReceived(a->role, QString::fromUtf8(data), isError);
}

// ============================================================================
// Arrêt / kill / redémarrage
// ============================================================================

void AiProcessSupervisor::stopAgent(int role)
{
    Agent *a = agentFor(role, false);
    if (!a) return;
    // Annule tout redémarrage programmé.
    a->restartCount = MEOW_AI_MAX_RESTARTS;
    if (!a->process) {
        setState(a, Stopped);
        return;
    }
    a->intentionalStop = true;
    gracefulStop(a);
}

void AiProcessSupervisor::gracefulStop(Agent *a)
{
    if (!a->process) return;
    QProcess *p = a->process;
    // Demande d'arrêt propre puis kill dur après un délai de grâce.
    p->terminate();
    const Role role = a->role;
    QTimer::singleShot(MEOW_AI_GRACEFUL_KILL_MS, this, [this, role]() {
        Agent *ag = agentFor(role, false);
        if (ag && ag->process &&
            ag->process->state() != QProcess::NotRunning) {
            emit logMessage(QStringLiteral("[AiSupervisor] %1 kill après grâce")
                                .arg(roleName(ag->role)));
            ag->process->kill();
        }
    });
}

void AiProcessSupervisor::killAgent(int role)
{
    Agent *a = agentFor(role, false);
    if (!a) return;
    a->restartCount = MEOW_AI_MAX_RESTARTS; // pas de redémarrage
    if (!a->process) {
        setState(a, Stopped);
        return;
    }
    a->intentionalStop = true;
    forceKill(a);
}

void AiProcessSupervisor::forceKill(Agent *a)
{
    if (a->process && a->process->state() != QProcess::NotRunning) {
        a->process->kill();
        // Attente bornée pour garantir la libération synchrone (destructeur,
        // aboutToQuit) sans figer indéfiniment le GUI.
        a->process->waitForFinished(MEOW_AI_GRACEFUL_KILL_MS);
    }
}

void AiProcessSupervisor::scheduleRestart(Agent *a)
{
    a->restartCount += 1;
    const int backoff = MEOW_AI_RESTART_BACKOFF_MS * a->restartCount;
    setState(a, Restarting,
             QStringLiteral("tentative %1/%2 dans %3 ms")
                 .arg(a->restartCount).arg(MEOW_AI_MAX_RESTARTS).arg(backoff));
    const Role role = a->role;
    QTimer::singleShot(backoff, this, [this, role]() {
        Agent *ag = agentFor(role, false);
        if (!ag || ag->process) return;          // annulé ou déjà relancé
        if (ag->state != Restarting) return;      // annulé entre-temps (stop)
        launch(ag, ag->lastOpts);
    });
}

void AiProcessSupervisor::restartAgent(int role)
{
    Agent *a = agentFor(role, false);
    if (!a) return;
    if (a->process) {
        // Redémarrage manuel : arrêt volontaire courant, puis relance à la fin.
        a->intentionalStop = true;
        const QVariantMap opts = a->lastOpts;
        const Role r = a->role;
        connect(a->process, &QProcess::finished, this,
                [this, r, opts](int, QProcess::ExitStatus) {
                    Agent *ag = agentFor(r, false);
                    if (ag && !ag->process) {
                        ag->restartCount = 0;
                        ag->intentionalStop = false;
                        launch(ag, opts);
                    }
                }, Qt::SingleShotConnection);
        gracefulStop(a);
    } else {
        a->restartCount = 0;
        a->intentionalStop = false;
        launch(a, a->lastOpts);
    }
}

void AiProcessSupervisor::stopAll()
{
    const auto agents = m_agents.values();
    for (Agent *a : agents) {
        a->restartCount = MEOW_AI_MAX_RESTARTS;
        if (a->process) {
            a->intentionalStop = true;
            gracefulStop(a);
        }
    }
}

void AiProcessSupervisor::sendInput(int role, const QString &text)
{
    Agent *a = agentFor(role, false);
    if (!a || !a->process ||
        a->process->state() != QProcess::Running) {
        emit logMessage(QStringLiteral("[AiSupervisor] sendInput ignoré (%1 non lancé)")
                            .arg(roleName(static_cast<Role>(role))));
        return;
    }
    a->process->write(text.toUtf8());
    if (!text.endsWith('\n'))
        a->process->write("\n");
}

void AiProcessSupervisor::notifyHandshake(int role, bool ok, const QString &reason)
{
    Agent *a = agentFor(role, false);
    if (!a || !a->process) return;
    if (ok) {
        if (a->state != Ready)
            setState(a, Ready);
    } else {
        a->intentionalStop = true; // handshake refusé → pas de redémarrage
        a->lastError = reason.isEmpty()
                           ? QStringLiteral("handshake refusé")
                           : reason;
        forceKill(a);
        setState(a, Failed, a->lastError);
    }
}

// ============================================================================
// Handshake + challenge arbitre (C6, D24/D31)
// ============================================================================

QString AiProcessSupervisor::defaultChallengePrompt()
{
    // Prompt de challenge : demande à l'agent de se connecter au canal MCP, de
    // vérifier qu'il voit le tool de verdict (challenge de capacité) et de
    // renvoyer une ligne machine attestant rôle + version + capacités. L'agent
    // ne peut renseigner honnêtement ces champs qu'après connexion au canal.
    return QStringLiteral(
        "Handshake d'arbitre (challenge). Connecte-toi au serveur MCP fourni "
        "(mcpServers.meownopoly), liste les tools disponibles, puis réponds par "
        "UNE SEULE ligne, sans autre texte, au format exact :\n"
        "%1{\"role\":\"arbiter\",\"protocolVersion\":\"%2\","
        "\"capabilities\":[<noms des tools que tu vois>]}\n"
        "La valeur %2 est la version du canal Meownopoly (et non la version "
        "du transport MCP). N'invente aucun nom de tool : recopie seulement "
        "ceux que le serveur MCP expose.")
        .arg(QString::fromLatin1(kHandshakeMarker),
             QStringLiteral(MEOW_AI_PROTOCOL_VERSION));
}

bool AiProcessSupervisor::testArbiter(const QVariantMap &opts)
{
    Agent *a = agentFor(Arbiter, /*create*/ true);
    if (a->process) {
        emit logMessage(QStringLiteral(
            "[AiSupervisor] handshake arbitre ignoré — un process est déjà en cours"));
        return false;
    }

    QVariantMap o = opts;
    o.insert(QStringLiteral("oneShot"), true); // un challenge = une invocation
    if (o.value(QStringLiteral("prompt")).toString().isEmpty())
        o.insert(QStringLiteral("prompt"), defaultChallengePrompt());
    // Borne dédiée : un arbitre qui ne répond pas au challenge est indisponible.
    if (!o.contains(QStringLiteral("invocationTimeoutMs")))
        o.insert(QStringLiteral("invocationTimeoutMs"), MEOW_AI_HANDSHAKE_TIMEOUT_MS);

    // Entre en phase de test AVANT le lancement : l'indicateur passe à
    // « Test en cours » (D31) et le résultat éventuel précédent est effacé.
    a->handshakePhase = HsInProgress;
    a->handshakeReason.clear();
    a->lastError.clear(); // repart propre : finishArbiterHandshake lit lastError
    emit handshakeStarted(Arbiter);
    emit arbiterLobbyStateChanged();
    emit logMessage(QStringLiteral("[AiSupervisor] handshake arbitre : challenge lancé"));

    if (!startAgent(Arbiter, o)) {
        // Lancement refusé (ex. rôle déjà en cours après coup) → Erreur latchée.
        a->handshakePhase = HsFailed;
        a->handshakeReason = QStringLiteral("impossible de lancer l'agent arbitre");
        a->lastError = a->handshakeReason;
        emit handshakeCompleted(Arbiter, false, a->handshakeReason);
        emit arbiterLobbyStateChanged();
        return false;
    }
    return true;
}

bool AiProcessSupervisor::evaluateHandshakeOutput(const QString &output, QString *reason)
{
    const auto fail = [reason](const QString &r) {
        if (reason) *reason = r;
        return false;
    };

    const int markerAt = output.lastIndexOf(QString::fromLatin1(kHandshakeMarker));
    if (markerAt < 0)
        return fail(QStringLiteral(
            "l'arbitre n'a pas répondu au handshake (marqueur absent)"));

    // Isole la charge JSON après le marqueur, jusqu'à la fin de ligne.
    int start = markerAt + static_cast<int>(qstrlen(kHandshakeMarker));
    int end = output.indexOf('\n', start);
    if (end < 0) end = output.size();
    const QString jsonText = output.mid(start, end - start).trimmed();

    QJsonParseError perr {};
    const QJsonDocument doc = QJsonDocument::fromJson(jsonText.toUtf8(), &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return fail(QStringLiteral("réponse de handshake illisible (JSON invalide)"));

    const QJsonObject obj = doc.object();

    // 1) Handshake de rôle : l'agent doit revendiquer `arbiter`.
    if (obj.value(QStringLiteral("role")).toString() != QStringLiteral("arbiter"))
        return fail(QStringLiteral("l'agent n'a pas revendiqué le rôle d'arbitre"));

    // 2) Version de protocole : doit correspondre au manifeste (D17).
    const QString proto = obj.value(QStringLiteral("protocolVersion")).toString();
    if (proto != QStringLiteral(MEOW_AI_PROTOCOL_VERSION))
        return fail(QStringLiteral("version de protocole incompatible (arbitre %1, jeu %2)")
                        .arg(proto.isEmpty() ? QStringLiteral("?") : proto,
                             QStringLiteral(MEOW_AI_PROTOCOL_VERSION)));

    // 3) Challenge de capacité : le tool de verdict doit être visible (le
    //    token/rôle ne l'expose qu'à un vrai arbitre, D20/C2).
    const QJsonArray caps = obj.value(QStringLiteral("capabilities")).toArray();
    bool hasVerdict = false;
    for (const QJsonValue &c : caps) {
        if (c.toString() == QStringLiteral(MEOW_AI_ARBITER_CAPABILITY)) {
            hasVerdict = true;
            break;
        }
    }
    if (!hasVerdict)
        return fail(QStringLiteral("l'arbitre n'accède pas au tool de verdict (%1)")
                        .arg(QStringLiteral(MEOW_AI_ARBITER_CAPABILITY)));

    if (reason) reason->clear();
    return true;
}

void AiProcessSupervisor::finishArbiterHandshake(Agent *a, const QString &output,
                                                 bool crashed)
{
    QString reason;
    bool ok = false;
    if (!a->lastError.isEmpty() && a->lastError.contains(QStringLiteral("timeout"))) {
        // Timeout (démarrage/invocation) posé par le socle, qui kill le process :
        // prime sur le CrashExit induit — l'arbitre n'a simplement pas répondu.
        reason = QStringLiteral("l'arbitre n'a pas répondu au challenge (timeout)");
    } else if (crashed) {
        reason = QStringLiteral("l'agent arbitre a planté pendant le handshake");
    } else if (output.isEmpty() && !a->lastError.isEmpty()) {
        // Échec de lancement (binaire introuvable…) remonté par onErrorOccurred.
        reason = a->lastError;
    } else {
        ok = evaluateHandshakeOutput(output, &reason);
    }

    a->handshakePhase = ok ? HsPassed : HsFailed;
    a->handshakeReason = ok ? QString() : reason;
    if (!ok)
        a->lastError = reason;
    a->intentionalStop = false; // le one-shot est fini normalement de notre POV
    a->restartCount = 0;

    // Le process one-shot est déjà terminé → état process Stopped ; la
    // projection lobby lit handshakePhase et affiche Prêt/Erreur (latché).
    setState(a, Stopped, ok ? QString() : reason);

    emit logMessage(QStringLiteral("[AiSupervisor] handshake arbitre : %1%2")
                        .arg(ok ? QStringLiteral("PRÊT") : QStringLiteral("ÉCHEC"),
                             ok ? QString() : QStringLiteral(" — ") + reason));
    emit handshakeCompleted(Arbiter, ok, reason);
    emit arbiterLobbyStateChanged();
}

// ============================================================================
// Nettoyage
// ============================================================================

void AiProcessSupervisor::cleanupMcpFileOnly(Agent *a)
{
    if (!a->mcpConfigPath.isEmpty()) {
        QFile::remove(a->mcpConfigPath);
        a->mcpConfigPath.clear();
    }
}

void AiProcessSupervisor::cleanupProcess(Agent *a)
{
    if (a->startupTimer) { a->startupTimer->stop(); a->startupTimer->deleteLater(); a->startupTimer = nullptr; }
    if (a->invocationTimer) { a->invocationTimer->stop(); a->invocationTimer->deleteLater(); a->invocationTimer = nullptr; }
    if (a->process) {
        a->process->disconnect(this);
        a->process->deleteLater();
        a->process = nullptr;
    }
    cleanupMcpFileOnly(a);
}

// ============================================================================
// Adaptateurs CLI (séparés) — argv sans secret
// ============================================================================

QString AiProcessSupervisor::defaultProgram(Adapter adapter)
{
    return adapter == Codex ? QStringLiteral("codex") : QStringLiteral("claude");
}

QStringList AiProcessSupervisor::claudeArgs(const QVariantMap &opts,
                                            const QString &mcpConfigPath)
{
    // `claude -p` : mode non interactif (print). Le pré-prompt (SKILL.md, D17)
    // et le tour utilisateur arrivent par stdin (voir onStarted). La config MCP
    // — qui porte l'en-tête Authorization (token, D20) — est référencée par
    // FICHIER, jamais inline : le secret ne touche pas l'argv journalisable.
    QStringList args;
    args << QStringLiteral("-p");
    if (!mcpConfigPath.isEmpty()) {
        args << QStringLiteral("--mcp-config") << mcpConfigPath
             << QStringLiteral("--strict-mcp-config")
             << QStringLiteral("--permission-mode") << QStringLiteral("dontAsk")
             << QStringLiteral("--allowedTools")
             << QStringLiteral("mcp__meownopoly__*");
    }
    const QString model = opts.value(QStringLiteral("model")).toString();
    if (!model.isEmpty())
        args << QStringLiteral("--model") << model;
    // Arguments additionnels configurables (jamais codés en dur dans l'UI).
    args << opts.value(QStringLiteral("extraArgs")).toStringList();
    return args;
}

QStringList AiProcessSupervisor::codexArgs(const QVariantMap &opts,
                                           const QString &mcpConfigPath)
{
    Q_UNUSED(mcpConfigPath)
    // `codex exec --config` attend des overrides TOML `clé=valeur`, pas un
    // chemin JSON. L'URL loopback n'est pas secrète ; le jeton est lu par Codex
    // depuis MEOW_AI_MCP_BEARER_TOKEN dans l'environnement du seul enfant.
    QStringList args;
    args << QStringLiteral("exec")
         << QStringLiteral("--ephemeral")
         << QStringLiteral("--sandbox") << QStringLiteral("read-only")
         << QStringLiteral("--skip-git-repo-check")
         << QStringLiteral("--ignore-user-config");
    const QString gatewayUrl = gatewayUrlFromOpts(opts);
    if (!gatewayUrl.isEmpty()) {
        args << QStringLiteral("-c")
             << (QStringLiteral("mcp_servers.meownopoly.url=")
                 + tomlString(gatewayUrl))
             << QStringLiteral("-c")
             << QStringLiteral("mcp_servers.meownopoly.bearer_token_env_var=\"MEOW_AI_MCP_BEARER_TOKEN\"");
    }
    const QString model = opts.value(QStringLiteral("model")).toString();
    if (!model.isEmpty())
        args << QStringLiteral("--model") << model;
    args << opts.value(QStringLiteral("extraArgs")).toStringList();
    return args;
}

// ============================================================================
// Injection MCP Claude (fichier à permissions restreintes)
// ============================================================================

QString AiProcessSupervisor::gatewayUrlFromOpts(const QVariantMap &opts)
{
    QString url = opts.value(QStringLiteral("gatewayUrl")).toString();
    if (!url.isEmpty())
        return url;
    // Défaut : dérivé du port de la passerelle MCP (même convention que C1).
    QByteArray portEnv = qgetenv("MEOW_AI_GATEWAY_PORT");
    const int port = portEnv.isEmpty() ? 0 : portEnv.toInt();
    if (port > 0)
        return QStringLiteral("http://127.0.0.1:%1/mcp").arg(port);
    return QString();
}

QString AiProcessSupervisor::writeMcpConfigFile(Role role, const QVariantMap &opts)
{
    const QString token = opts.value(QStringLiteral("token")).toString();
    const QString url = gatewayUrlFromOpts(opts);
    if (token.isEmpty() || url.isEmpty())
        return QString(); // rien à injecter (mode test sans passerelle)

    // Config MCP au format attendu par les CLIs (mcpServers → transport http +
    // en-tête d'autorisation portant le token de rôle). Le token N'EST écrit
    // que dans ce fichier, jamais dans l'argv ni les logs.
    QJsonObject server;
    server.insert(QStringLiteral("type"), QStringLiteral("http"));
    server.insert(QStringLiteral("url"), url);
    QJsonObject headers;
    headers.insert(QStringLiteral("Authorization"),
                   QStringLiteral("Bearer ") + token);
    server.insert(QStringLiteral("headers"), headers);
    QJsonObject servers;
    servers.insert(QStringLiteral("meownopoly"), server);
    QJsonObject root;
    root.insert(QStringLiteral("mcpServers"), servers);

    const QString dir = QDir::tempPath();
    const QString path = QDir(dir).filePath(
        QStringLiteral("meow_mcp_%1_%2.json")
            .arg(roleName(role), QUuid::createUuid().toString(QUuid::Id128)));

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        emit logMessage(QStringLiteral("[AiSupervisor] échec écriture config MCP"));
        return QString();
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    f.close();
    // Permissions restreintes au propriétaire (le secret ne fuit pas via le FS).
    f.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
    return path;
}

// ============================================================================
// Anti-orphelin — Windows Job Object (KILL_ON_JOB_CLOSE)
// ============================================================================

void AiProcessSupervisor::ensureJobObject()
{
#ifdef Q_OS_WIN
    if (m_jobHandle)
        return;
    HANDLE job = CreateJobObject(nullptr, nullptr);
    if (!job) {
        emit logMessage(QStringLiteral("[AiSupervisor] CreateJobObject a échoué"));
        return;
    }
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION info;
    ZeroMemory(&info, sizeof(info));
    // Quand le dernier handle du job se ferme (fin/crash du jeu), tout l'arbre
    // de process rattaché est tué → aucun orphelin (critère M2).
    info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation,
                                 &info, sizeof(info))) {
        emit logMessage(QStringLiteral("[AiSupervisor] SetInformationJobObject a échoué"));
        CloseHandle(job);
        return;
    }
    m_jobHandle = reinterpret_cast<void *>(job);
#endif
}

void AiProcessSupervisor::assignToJob(QProcess *p)
{
#ifdef Q_OS_WIN
    if (!p)
        return;
    ensureJobObject();
    if (!m_jobHandle)
        return;
    const qint64 pid = p->processId();
    if (pid == 0)
        return;
    HANDLE hProc = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, FALSE,
                               static_cast<DWORD>(pid));
    if (!hProc) {
        emit logMessage(QStringLiteral("[AiSupervisor] OpenProcess a échoué (job)"));
        return;
    }
    if (!AssignProcessToJobObject(reinterpret_cast<HANDLE>(m_jobHandle), hProc))
        emit logMessage(QStringLiteral("[AiSupervisor] AssignProcessToJobObject a échoué"));
    CloseHandle(hProc);
#else
    Q_UNUSED(p);
#endif
}
