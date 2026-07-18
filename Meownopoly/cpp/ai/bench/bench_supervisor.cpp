// ============================================================================
// BenchSupervisor — implémentation (doc 12 §2.2 / §5, tâche A3)
// ============================================================================

#include "bench_supervisor.h"
#include "bench_protocol.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLibraryInfo>
#include <QTemporaryFile>
#include <QTextStream>
#include <QTimer>
#include <QDebug>

namespace mb = meow::bench;

namespace {
// ---------------------------------------------------------------------------
// Journal de diagnostic du pipeline banc : chaque étape (résolution du chemin,
// spawn, sortie du process, verdict) est tracée dans un fichier append-only
// pour diagnostiquer les échecs environnementaux (exe introuvable, crash au
// démarrage, DLLs manquantes) sans dépendre de la console de l'IDE.
QString benchLogPath()
{
    return QDir::temp().absoluteFilePath(QStringLiteral("meow_bench_debug.log"));
}

void benchLog(const QString &line)
{
    qInfo().noquote() << "[BenchSupervisor]" << line;
    QFile f(benchLogPath());
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream ts(&f);
        ts << QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz"))
           << QStringLiteral("  ") << line << QChar(u'\n');
    }
}

// Tronque une sortie de process pour le journal (dernières lignes utiles).
QString tailForLog(const QByteArray &raw, int maxChars = 600)
{
    QString s = QString::fromUtf8(raw).trimmed();
    if (s.size() > maxChars)
        s = QStringLiteral("…") + s.right(maxChars);
    return s.isEmpty() ? QStringLiteral("(vide)") : s;
}
} // namespace

BenchSupervisor::BenchSupervisor(QObject *parent)
    : QObject(parent)
{
    m_benchExe = resolveDefaultBenchPath();
}

BenchSupervisor::~BenchSupervisor()
{
    cleanup();
}

void BenchSupervisor::setBenchExecutablePath(const QString &path)
{
    m_benchExe = path;
}

void BenchSupervisor::setTimeoutMs(int ms)
{
    if (ms > 0)
        m_timeoutMs = ms;
}

bool BenchSupervisor::busy() const
{
    return m_process != nullptr;
}

QString BenchSupervisor::resolveDefaultBenchPath()
{
#if defined(Q_OS_WIN)
    const QString exeName = QStringLiteral("meow_testbench.exe");
#else
    const QString exeName = QStringLiteral("meow_testbench");
#endif

    // Override explicite par l'environnement (debug / déploiement atypique).
    const QString envExe = QString::fromUtf8(qgetenv("MEOW_BENCH_EXE"));
    if (!envExe.isEmpty()) {
        benchLog(QStringLiteral("résolution : MEOW_BENCH_EXE = %1 (exists=%2)")
                     .arg(envExe).arg(QFileInfo::exists(envExe)));
        return envExe;
    }

    // Le banc est bâti dans le même arbre de build que le jeu, mais le dossier
    // exact varie : à côté de l'exe (Qt Creator single-config, exe racine
    // déployé), ou dans un sous-dossier de configuration (Ninja Multi-Config :
    // build/Release, build/Debug…). On sonde les candidats dans l'ordre.
    const QDir appDir(QCoreApplication::applicationDirPath());
    QStringList candidates;
    candidates << appDir.absoluteFilePath(exeName);
    for (const QString &config : { QStringLiteral("Release"), QStringLiteral("Debug"),
                                   QStringLiteral("RelWithDebInfo"), QStringLiteral("MinSizeRel") }) {
        candidates << appDir.absoluteFilePath(config + QLatin1Char('/') + exeName);
        candidates << appDir.absoluteFilePath(QStringLiteral("../") + config + QLatin1Char('/') + exeName);
    }

    for (const QString &c : candidates) {
        if (QFileInfo::exists(c)) {
            benchLog(QStringLiteral("résolution : banc trouvé → %1").arg(QDir::cleanPath(c)));
            return QDir::cleanPath(c);
        }
    }

    benchLog(QStringLiteral("résolution : banc INTROUVABLE. Candidats sondés :\n  - %1")
                 .arg(candidates.join(QStringLiteral("\n  - "))));
    // On retourne quand même le candidat « à côté du jeu » : le message
    // d'erreur du verdict citera ce chemin attendu.
    return candidates.first();
}

QProcessEnvironment BenchSupervisor::benchEnvironment()
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();

    // Le banc n'est pas déployé avec ses plugins plateforme : on rend le
    // plugin `offscreen` découvrable via le dossier plugins de la build Qt
    // courante. `-platform offscreen` est passé en argument par ailleurs.
    const QString pluginsPath = QLibraryInfo::path(QLibraryInfo::PluginsPath);
    if (!pluginsPath.isEmpty()) {
        const QString existing = env.value(QStringLiteral("QT_PLUGIN_PATH"));
        env.insert(QStringLiteral("QT_PLUGIN_PATH"),
                   existing.isEmpty()
                       ? pluginsPath
                       : pluginsPath + QDir::listSeparator() + existing);
    }
    // Ceinture et bretelles : impose aussi la plateforme par l'environnement.
    env.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("offscreen"));
    return env;
}

void BenchSupervisor::runJob(const QJsonObject &job)
{
    if (busy()) {
        qWarning() << "[BenchSupervisor] runJob ignoré : une validation est déjà en cours";
        return;
    }

    m_finished = false;
    m_jobId = job.value(QStringLiteral("jobId")).toString();
    benchLog(QStringLiteral("runJob %1 : exe=%2 (exists=%3), timeout=%4 ms")
                 .arg(m_jobId, m_benchExe)
                 .arg(QFileInfo::exists(m_benchExe))
                 .arg(m_timeoutMs));

    // 1) Sérialiser le job dans un fichier temporaire (entrée = fichier, §2.2).
    QTemporaryFile jobFile(QDir::tempPath() + QStringLiteral("/meowbench_job_XXXXXX.json"));
    jobFile.setAutoRemove(false); // on gère la suppression dans cleanup()
    if (!jobFile.open()) {
        finishWith(mb::makeCrashVerdict(
            m_jobId, -1,
            QStringLiteral("impossible d'écrire le fichier de job : %1").arg(jobFile.errorString())));
        return;
    }
    m_jobFilePath = jobFile.fileName();
    jobFile.write(QJsonDocument(job).toJson(QJsonDocument::Compact));
    jobFile.close();

    // 2) Vérifier la présence du banc avant de spawner.
    if (!QFileInfo::exists(m_benchExe)) {
        finishWith(mb::makeCrashVerdict(
            m_jobId, -1,
            QStringLiteral("exécutable du banc introuvable : %1").arg(m_benchExe)));
        return;
    }

    // 3) Spawn asynchrone du banc, headless.
    m_process = new QProcess(this);
    m_process->setProcessEnvironment(benchEnvironment());
    m_process->setProgram(m_benchExe);
    m_process->setArguments(QStringList{
        QStringLiteral("-platform"), QStringLiteral("offscreen"),
        m_jobFilePath,
    });

    connect(m_process, &QProcess::finished, this, &BenchSupervisor::onFinished);
    connect(m_process, &QProcess::errorOccurred, this, &BenchSupervisor::onErrorOccurred);

    // 4) Timeout dur global (§2.2). Single-shot ; armé avant le start.
    m_timer = new QTimer(this);
    m_timer->setSingleShot(true);
    m_timer->setInterval(m_timeoutMs);
    connect(m_timer, &QTimer::timeout, this, &BenchSupervisor::onTimeout);
    m_timer->start();

    m_process->start();
}

void BenchSupervisor::onFinished(int exitCode, QProcess::ExitStatus status)
{
    if (m_finished)
        return;

    const QByteArray out = m_process ? m_process->readAllStandardOutput() : QByteArray();
    const QByteArray err = m_process ? m_process->readAllStandardError() : QByteArray();
    const QJsonObject verdict = mb::extractVerdict(out);

    benchLog(QStringLiteral("onFinished %1 : exitCode=%2 status=%3 (0=NormalExit)\n"
                            "  stdout: %4\n  stderr: %5")
                 .arg(m_jobId).arg(exitCode).arg(int(status))
                 .arg(tailForLog(out), tailForLog(err)));

    if (status == QProcess::CrashExit) {
        // Crash dur du process : pas de verdict fiable, on synthétise.
        finishWith(mb::makeCrashVerdict(m_jobId, exitCode,
            QStringLiteral("le banc a crashé (signal), exitCode %1").arg(exitCode)));
        return;
    }

    if (verdict.isEmpty()) {
        // Sortie normale mais aucun verdict `MEOWBENCH:` → banc défaillant.
        finishWith(mb::makeCrashVerdict(m_jobId, exitCode));
        return;
    }

    finishWith(verdict);
}

void BenchSupervisor::onErrorOccurred(QProcess::ProcessError error)
{
    if (m_finished)
        return;

    benchLog(QStringLiteral("onErrorOccurred %1 : error=%2 (%3)")
                 .arg(m_jobId).arg(int(error))
                 .arg(m_process ? m_process->errorString() : QStringLiteral("?")));

    // `finished` couvre les cas post-démarrage ; ici on ne synthétise que les
    // échecs de démarrage (les autres erreurs seront suivies d'un `finished`).
    if (error == QProcess::FailedToStart) {
        finishWith(mb::makeCrashVerdict(
            m_jobId, -1,
            QStringLiteral("impossible de démarrer le banc : %1")
                .arg(m_process ? m_process->errorString() : QStringLiteral("erreur inconnue"))));
    }
}

void BenchSupervisor::onTimeout()
{
    if (m_finished)
        return;

    benchLog(QStringLiteral("onTimeout %1 : %2 ms dépassés, kill du banc")
                 .arg(m_jobId).arg(m_timeoutMs));

    // Timeout dur : tuer le process (le `finished` qui suivra est ignoré par
    // le garde `m_finished`) et rendre le verdict synthétique.
    if (m_process && m_process->state() != QProcess::NotRunning)
        m_process->kill();

    finishWith(mb::makeTimeoutVerdict(m_jobId, m_timeoutMs));
}

void BenchSupervisor::finishWith(const QJsonObject &verdict)
{
    if (m_finished)
        return;
    m_finished = true;

    if (m_timer)
        m_timer->stop();

    benchLog(QStringLiteral("verdict %1 : %2")
                 .arg(m_jobId,
                      QString::fromUtf8(QJsonDocument(verdict).toJson(QJsonDocument::Compact))));

    cleanup();
    // Émission TOUJOURS différée : les échecs pré-spawn (exe du banc absent,
    // fichier de job illisible) arrivent ici synchrones depuis runJob(), donc
    // à l'intérieur de BenchPool::submit → le verdict partirait AVANT que
    // l'appelant (ex. SliceScenarioRunner::validateArtifact) n'ait retourné le
    // jobId au QML, qui corrèle par jobId et perdrait le verdict (bouton
    // « Validation… » bloqué à jamais). Le slot du pool reste `busy` jusqu'à la
    // livraison → pas de re-dispatch intermédiaire, la corrélation tient.
    QMetaObject::invokeMethod(
        this, [this, verdict]() { emit verdictReady(verdict); },
        Qt::QueuedConnection);
}

void BenchSupervisor::cleanup()
{
    if (m_timer) {
        m_timer->stop();
        m_timer->deleteLater();
        m_timer = nullptr;
    }

    if (m_process) {
        m_process->disconnect(this);
        if (m_process->state() != QProcess::NotRunning) {
            m_process->kill();
            m_process->waitForFinished(200); // best-effort, non bloquant durablement
        }
        m_process->deleteLater();
        m_process = nullptr;
    }

    if (!m_jobFilePath.isEmpty()) {
        QFile::remove(m_jobFilePath);
        m_jobFilePath.clear();
    }
}
