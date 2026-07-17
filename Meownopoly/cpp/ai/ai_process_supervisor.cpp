#include "ai_process_supervisor.h"

#include <QCoreApplication>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTimer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>
#include <QUrl>
#include <QDebug>

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

namespace {

// Wrapper de QProcess::ExitStatus / ProcessError en int pour découplage header.
constexpr int kCrashExit = 1; // QProcess::CrashExit

QString roleName(AiProcessSupervisor::Role r)
{
    return r == AiProcessSupervisor::Arbiter ? QStringLiteral("arbiter")
                                             : QStringLiteral("proposer");
}

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
    switch (static_cast<State>(stateOf(role))) {
    case Stopped:    return Absent;
    case Starting:   return Testing;
    case Restarting: return Testing;
    case Ready:      return Prete;
    case Failed:     return Erreur;
    }
    return Absent;
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
    if (role == Proposer)
        emit proposerStateChanged();
    else
        emit arbiterStateChanged();
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
    QString program = opts.value(QStringLiteral("program")).toString();
    if (program.isEmpty())
        program = defaultProgram(adapter);

    a->oneShot = opts.value(QStringLiteral("oneShot"), false).toBool();
    a->reachedReady = false;
    a->invocationTimeoutMs =
        opts.value(QStringLiteral("invocationTimeoutMs"),
                   MEOW_AI_INVOCATION_TIMEOUT_MS).toInt();

    // Secret (token) → fichier MCP à permissions restreintes. JAMAIS l'argv.
    cleanupMcpFileOnly(a);
    a->mcpConfigPath = writeMcpConfigFile(a->role, opts);

    QStringList args = (adapter == Codex) ? codexArgs(opts, a->mcpConfigPath)
                                          : claudeArgs(opts, a->mcpConfigPath);

    QProcess *p = new QProcess(this);
    a->process = p;

    // Environnement : hérite du système, complété (jamais le token en clair sur
    // l'argv). On expose l'URL de la passerelle et le chemin de config MCP par
    // env pour les adaptateurs qui préfèrent l'env au flag.
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("MEOW_AI_GATEWAY_URL"), gatewayUrlFromOpts(opts));
    if (!a->mcpConfigPath.isEmpty())
        env.insert(QStringLiteral("MEOW_AI_MCP_CONFIG"), a->mcpConfigPath);
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

    p->start(program, args);

    // Instantané synchrone : si le binaire est introuvable, errorOccurred
    // (FailedToStart) arrive de façon asynchrone — géré dans onErrorOccurred.
    emit logMessage(QStringLiteral("[AiSupervisor] lancement %1 : %2 (%3 arg)")
                        .arg(roleName(a->role), program)
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
    const QString output = QString::fromUtf8(a->outputBuf);

    // Détache le QProcess du runtime avant toute décision de redémarrage.
    QProcess *p = a->process;
    a->process = nullptr;
    if (p) {
        p->disconnect(this);
        p->deleteLater();
    }
    cleanupMcpFileOnly(a);

    if (a->oneShot && !crashed && exitCode == 0) {
        // Invocation terminée normalement.
        emit invocationCompleted(a->role, exitCode, output);
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
        a->process = nullptr;
        if (p) {
            p->disconnect(this);
            p->deleteLater();
        }
        cleanupMcpFileOnly(a);
        a->lastError = QStringLiteral("binaire introuvable ou non lançable");
        emit logMessage(QStringLiteral("[AiSupervisor] %1 échec de lancement")
                            .arg(roleName(a->role)));
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
    if (!mcpConfigPath.isEmpty())
        args << QStringLiteral("--mcp-config") << mcpConfigPath;
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
    // Codex en mode non interactif (`codex exec`). Même principe : la config MCP
    // (avec le token) passe par fichier, pas par l'argv.
    QStringList args;
    args << QStringLiteral("exec");
    if (!mcpConfigPath.isEmpty())
        args << QStringLiteral("--config") << mcpConfigPath;
    const QString model = opts.value(QStringLiteral("model")).toString();
    if (!model.isEmpty())
        args << QStringLiteral("--model") << model;
    args << opts.value(QStringLiteral("extraArgs")).toStringList();
    return args;
}

// ============================================================================
// Injection MCP (fichier à permissions restreintes) — SEUL vecteur du secret
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
