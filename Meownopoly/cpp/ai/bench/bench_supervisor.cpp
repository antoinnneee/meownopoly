#include "bench_supervisor.h"
#include "bench_constants.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>
#include <QUuid>

BenchSupervisor::BenchSupervisor(QObject *parent)
    : QObject(parent)
{
    m_timeoutTimer.setSingleShot(true);
    m_timeoutTimer.setInterval(MEOW_BENCH_TIMEOUT_MS);
    connect(&m_timeoutTimer, &QTimer::timeout, this, &BenchSupervisor::onTimeout);
}

BenchSupervisor::~BenchSupervisor()
{
    // Aucun orphelin à la fermeture : si un banc tourne encore, on le tue.
    if (m_process) {
        m_process->kill();
        m_process->waitForFinished(1000);
    }
    if (!m_jobFilePath.isEmpty())
        QFile::remove(m_jobFilePath);
}

QString BenchSupervisor::benchExecutablePath() const
{
    if (!m_benchExecutablePath.isEmpty())
        return m_benchExecutablePath;
    QString name = QStringLiteral(MEOW_BENCH_EXE_NAME);
#ifdef Q_OS_WIN
    name += QStringLiteral(".exe");
#endif
    return QCoreApplication::applicationDirPath() + QLatin1Char('/') + name;
}

void BenchSupervisor::setBenchExecutablePath(const QString &path)
{
    m_benchExecutablePath = path;
}

bool BenchSupervisor::runJob(const QJsonObject &job)
{
    if (m_process) {
        qWarning() << "BenchSupervisor::runJob : un job est déjà en cours — refusé"
                   << "(une seule validation à la fois au MVP, doc 12 §6)";
        return false;
    }

    m_verdictEmitted = false;
    m_killedByTimeout = false;
    m_jobId = job.value(QStringLiteral("jobId")).toString();

    // --- Écriture du job dans un fichier temporaire ---
    const QString tempDir =
        QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_jobFilePath = tempDir + QStringLiteral("/meow_bench_job_")
                    + QUuid::createUuid().toString(QUuid::WithoutBraces)
                    + QStringLiteral(".json");
    QFile jobFile(m_jobFilePath);
    if (!jobFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        const QJsonObject verdict = syntheticVerdict(
            QStringLiteral("job_invalid"),
            QStringLiteral("impossible d'écrire le fichier de job : %1")
                .arg(jobFile.errorString()));
        m_jobFilePath.clear();
        emitVerdictOnce(verdict);
        return false;
    }
    jobFile.write(QJsonDocument(job).toJson(QJsonDocument::Compact));
    jobFile.close();

    // --- Lancement du banc, headless ---
    m_process = new QProcess(this);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);
    connect(m_process,
            qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, &BenchSupervisor::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred,
            this, &BenchSupervisor::onProcessError);

    const QStringList args{QStringLiteral("-platform"),
                           QStringLiteral("offscreen"),
                           m_jobFilePath};
    m_process->start(benchExecutablePath(), args);
    m_timeoutTimer.start();
    return true;
}

void BenchSupervisor::onTimeout()
{
    if (!m_process)
        return;
    // Timeout dur : kill, verdict synthétique. onProcessFinished sera appelé
    // par le kill mais n'émettra rien (garde m_verdictEmitted).
    m_killedByTimeout = true;
    m_process->kill();
    emitVerdictOnce(syntheticVerdict(
        QStringLiteral("bench_timeout"),
        QStringLiteral("le banc n'a pas rendu de verdict en %1 ms — kill")
            .arg(MEOW_BENCH_TIMEOUT_MS)));
}

void BenchSupervisor::onProcessError(QProcess::ProcessError error)
{
    // FailedToStart n'émet jamais finished() → verdict crash ici. Les autres
    // erreurs (Crashed…) sont suivies d'un finished() qui fait le travail.
    if (error != QProcess::FailedToStart)
        return;
    m_timeoutTimer.stop();
    emitVerdictOnce(syntheticVerdict(
        QStringLiteral("crash"),
        QStringLiteral("le banc n'a pas pu démarrer : %1")
            .arg(m_process ? m_process->errorString()
                           : QStringLiteral("processus inconnu"))));
    cleanupProcess();
}

void BenchSupervisor::onProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    m_timeoutTimer.stop();

    if (m_verdictEmitted) {
        // Timeout déjà verdicté (ou FailedToStart) — juste nettoyer.
        cleanupProcess();
        return;
    }

    // --- Recherche de la ligne MEOWBENCH: sur stdout ---
    const QString out = QString::fromUtf8(m_process->readAllStandardOutput());
    QJsonObject verdict;
    bool found = false;
    const QStringList lines = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &rawLine : lines) {
        const QString line = rawLine.trimmed();
        if (!line.startsWith(QStringLiteral(MEOW_BENCH_VERDICT_PREFIX)))
            continue;
        const QByteArray payload =
            line.mid(int(qstrlen(MEOW_BENCH_VERDICT_PREFIX))).toUtf8();
        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(payload, &parseError);
        if (parseError.error == QJsonParseError::NoError && doc.isObject()) {
            verdict = doc.object();
            found = true; // on garde la DERNIÈRE ligne valide
        }
    }

    if (found) {
        emitVerdictOnce(verdict);
    } else {
        // Exit sans verdict = crash du banc lui-même (doc 12 §2.2), que le
        // code de sortie soit != 0 (crash franc) ou 0 (stdout inexploitable).
        QJsonObject extra;
        extra.insert(QStringLiteral("exitCode"), exitCode);
        const QString detail =
            (status == QProcess::CrashExit)
                ? QStringLiteral("le banc a crashé sans rendre de verdict")
                : QStringLiteral(
                      "le banc s'est terminé (exit %1) sans ligne MEOWBENCH:")
                      .arg(exitCode);
        emitVerdictOnce(
            syntheticVerdict(QStringLiteral("crash"), detail, extra));
    }
    cleanupProcess();
}

QJsonObject BenchSupervisor::syntheticVerdict(const QString &code,
                                              const QString &details,
                                              const QJsonObject &extra) const
{
    QJsonObject failure;
    failure.insert(QStringLiteral("code"), code);
    failure.insert(QStringLiteral("phase"), QStringLiteral("supervisor"));
    failure.insert(QStringLiteral("details"), details);
    // bench_timeout/crash peuvent être des aléas d'environnement : rejouables.
    failure.insert(QStringLiteral("retryable"),
                   code != QStringLiteral("job_invalid"));
    for (auto it = extra.begin(); it != extra.end(); ++it)
        failure.insert(it.key(), it.value());

    QJsonObject verdict;
    verdict.insert(QStringLiteral("jobId"), m_jobId);
    verdict.insert(QStringLiteral("benchVersion"), MEOW_BENCH_VERSION);
    verdict.insert(QStringLiteral("verdict"), QStringLiteral("fail"));
    verdict.insert(QStringLiteral("failures"), QJsonArray{failure});
    verdict.insert(QStringLiteral("metrics"), QJsonObject{});
    verdict.insert(QStringLiteral("durationMs"), 0);
    return verdict;
}

void BenchSupervisor::emitVerdictOnce(const QJsonObject &verdict)
{
    if (m_verdictEmitted)
        return;
    m_verdictEmitted = true;
    emit verdictReady(verdict);
}

void BenchSupervisor::cleanupProcess()
{
    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }
    if (!m_jobFilePath.isEmpty()) {
        QFile::remove(m_jobFilePath);
        m_jobFilePath.clear();
    }
}
