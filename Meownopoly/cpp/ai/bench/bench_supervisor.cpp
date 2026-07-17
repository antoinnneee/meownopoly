// ============================================================================
// BenchSupervisor — implémentation (doc 12 §2.2 / §5, tâche A3)
// ============================================================================

#include "bench_supervisor.h"
#include "bench_protocol.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLibraryInfo>
#include <QTemporaryFile>
#include <QTimer>
#include <QDebug>

namespace mb = meow::bench;

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
    // L'exécutable du banc est bâti à côté du jeu (même dossier de sortie).
    QDir dir(QCoreApplication::applicationDirPath());
#if defined(Q_OS_WIN)
    return dir.absoluteFilePath(QStringLiteral("meow_testbench.exe"));
#else
    return dir.absoluteFilePath(QStringLiteral("meow_testbench"));
#endif
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
    const QJsonObject verdict = mb::extractVerdict(out);

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

    cleanup();
    emit verdictReady(verdict);
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
