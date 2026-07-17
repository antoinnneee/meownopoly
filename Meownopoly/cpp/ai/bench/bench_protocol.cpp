// ============================================================================
// bench_protocol — implémentation du contrat job / verdict (doc 12 §2 / §4)
// ============================================================================

#include "bench_protocol.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QStringList>

namespace meow::bench {

namespace {
// Convertit un code failure::k* (const char[]) en QString sans dépendre du
// cast implicite from-ASCII (potentiellement désactivé).
inline QString code(const char *c) { return QString::fromLatin1(c); }
} // namespace

// ─── Job ────────────────────────────────────────────────────────────────────
BenchJob parseJobFile(const QString &path)
{
    BenchJob job;

    if (path.isEmpty()) {
        job.errorCode = code(failure::kJobReadError);
        job.errorDetails = QStringLiteral("aucun chemin de fichier de job fourni en argument");
        return job;
    }

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        job.errorCode = code(failure::kJobReadError);
        job.errorDetails = QStringLiteral("ouverture impossible de « %1 » : %2")
                               .arg(path, f.errorString());
        return job;
    }
    const QByteArray data = f.readAll();
    f.close();

    QJsonParseError perr{};
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError) {
        job.errorCode = code(failure::kJobParseError);
        job.errorDetails = QStringLiteral("JSON invalide (offset %1) : %2")
                               .arg(perr.offset)
                               .arg(perr.errorString());
        return job;
    }
    if (!doc.isObject()) {
        job.errorCode = code(failure::kJobParseError);
        job.errorDetails = QStringLiteral("le job racine n'est pas un objet JSON");
        return job;
    }

    const QJsonObject root = doc.object();
    job.jobId        = root.value(QStringLiteral("jobId")).toString();
    job.benchVersion = root.value(QStringLiteral("benchVersion")).toInt();
    job.snapshot     = root.value(QStringLiteral("snapshot")).toObject();
    job.artifact     = root.value(QStringLiteral("artifact")).toObject();
    job.budgets      = root.value(QStringLiteral("budgets")).toObject();
    job.stimuli      = root.value(QStringLiteral("stimuli")).toArray();
    job.seed         = static_cast<qint64>(root.value(QStringLiteral("seed")).toDouble());

    // Validation minimale de structure (doc 12 §2.3). Le contenu profond
    // (map reconstructible, budgets exploitables) est vérifié par les phases.
    QStringList missing;
    if (job.jobId.isEmpty())                                    missing << QStringLiteral("jobId");
    if (!root.contains(QStringLiteral("snapshot")))             missing << QStringLiteral("snapshot");
    if (!root.contains(QStringLiteral("artifact")))             missing << QStringLiteral("artifact");
    if (job.artifact.value(QStringLiteral("source")).toString().isEmpty())
        missing << QStringLiteral("artifact.source");
    if (!missing.isEmpty()) {
        job.errorCode = code(failure::kJobInvalid);
        job.errorDetails = QStringLiteral("champs obligatoires manquants ou vides : %1")
                               .arg(missing.join(QStringLiteral(", ")));
        return job;
    }

    if (job.benchVersion != kBenchVersion) {
        job.errorCode = code(failure::kJobInvalid);
        job.errorDetails = QStringLiteral("benchVersion %1 incompatible avec le banc (%2)")
                               .arg(job.benchVersion)
                               .arg(kBenchVersion);
        return job;
    }

    job.ok = true;
    return job;
}

// ─── Verdict ────────────────────────────────────────────────────────────────
QJsonObject BenchFailure::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("code"), code);
    if (!phase.isEmpty())
        o.insert(QStringLiteral("phase"), phase);
    o.insert(QStringLiteral("details"), details);
    o.insert(QStringLiteral("retryable"), retryable);
    for (auto it = extra.constBegin(); it != extra.constEnd(); ++it)
        o.insert(it.key(), it.value());
    return o;
}

QJsonObject BenchVerdict::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("jobId"), jobId);
    o.insert(QStringLiteral("benchVersion"), benchVersion);
    o.insert(QStringLiteral("verdict"), pass ? QStringLiteral("pass") : QStringLiteral("fail"));
    QJsonArray fs;
    for (const BenchFailure &f : failures)
        fs.append(f.toJson());
    o.insert(QStringLiteral("failures"), fs);
    o.insert(QStringLiteral("metrics"), metrics);
    o.insert(QStringLiteral("durationMs"), durationMs);
    return o;
}

BenchVerdict BenchVerdict::fail(const QString &jobId, const BenchFailure &f)
{
    BenchVerdict v;
    v.jobId = jobId;
    v.pass = false;
    v.failures.append(f);
    return v;
}

QByteArray formatVerdictLine(const QJsonObject &verdict)
{
    return QByteArray(kVerdictPrefix)
           + QJsonDocument(verdict).toJson(QJsonDocument::Compact);
}

QJsonObject extractVerdict(const QByteArray &stdoutData)
{
    const QByteArray prefix(kVerdictPrefix);
    const QList<QByteArray> lines = stdoutData.split('\n');
    // Dernière ligne préfixée valide : un verdict tardif l'emporte sur un
    // éventuel verdict de substitution émis plus tôt.
    for (int i = lines.size() - 1; i >= 0; --i) {
        const QByteArray line = lines.at(i).trimmed();
        if (!line.startsWith(prefix))
            continue;
        const QByteArray payload = line.mid(prefix.size());
        QJsonParseError perr{};
        const QJsonDocument doc = QJsonDocument::fromJson(payload, &perr);
        if (perr.error == QJsonParseError::NoError && doc.isObject())
            return doc.object();
    }
    return {};
}

QJsonObject makeTimeoutVerdict(const QString &jobId, int timeoutMs)
{
    BenchFailure f;
    f.code = code(failure::kBenchTimeout);
    f.details = QStringLiteral("le banc n'a pas rendu de verdict en %1 ms (process tué)")
                    .arg(timeoutMs);
    f.retryable = true;
    return BenchVerdict::fail(jobId, f).toJson();
}

QJsonObject makeCrashVerdict(const QString &jobId, int exitCode, const QString &details)
{
    BenchFailure f;
    f.code = code(failure::kCrash);
    f.details = details.isEmpty()
                    ? QStringLiteral("le banc s'est terminé sans verdict (exitCode %1)").arg(exitCode)
                    : details;
    f.retryable = true;
    f.extra.insert(QStringLiteral("exitCode"), exitCode);
    return BenchVerdict::fail(jobId, f).toJson();
}

} // namespace meow::bench
