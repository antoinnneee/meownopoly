#include "bench_job.h"

#include "ai/bench/bench_constants.h"

#include <QFile>
#include <QJsonDocument>

namespace {

// jobId : reporté dans le verdict même quand le reste du job est invalide
// (permet au superviseur de corréler le fail à la bonne proposition).
BenchJobParseResult fail(const QString &details, const QString &jobId = {})
{
    BenchJobParseResult r;
    r.ok = false;
    r.details = details;
    r.job.jobId = jobId;
    return r;
}

} // namespace

BenchJobParseResult parseBenchJobFile(const QString &path)
{
    if (path.isEmpty())
        return fail(QStringLiteral("aucun fichier de job fourni en argument "
                                   "(usage : meow_testbench <job.json>)"));

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return fail(QStringLiteral("fichier de job illisible '%1' : %2")
                        .arg(path, file.errorString()));

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError)
        return fail(QStringLiteral("JSON du job invalide : %1 (offset %2)")
                        .arg(parseError.errorString())
                        .arg(parseError.offset));
    if (!doc.isObject())
        return fail(QStringLiteral("le job doit être un objet JSON"));

    const QJsonObject root = doc.object();
    BenchJobParseResult result;
    BenchJob &job = result.job;

    // --- jobId ---
    job.jobId = root.value(QStringLiteral("jobId")).toString();
    if (job.jobId.isEmpty())
        return fail(QStringLiteral("champ 'jobId' manquant ou vide"));

    // --- benchVersion ---
    if (!root.value(QStringLiteral("benchVersion")).isDouble())
        return fail(QStringLiteral("champ 'benchVersion' manquant"), job.jobId);
    job.benchVersion = root.value(QStringLiteral("benchVersion")).toInt();
    if (job.benchVersion != MEOW_BENCH_VERSION)
        return fail(QStringLiteral("benchVersion %1 non supportée (banc en "
                                   "version %2)")
                        .arg(job.benchVersion)
                        .arg(MEOW_BENCH_VERSION),
                    job.jobId);

    // --- snapshot ---
    const QJsonValue snapshotVal = root.value(QStringLiteral("snapshot"));
    if (!snapshotVal.isObject())
        return fail(QStringLiteral("champ 'snapshot' manquant ou non-objet"),
                    job.jobId);
    const QJsonObject snapshot = snapshotVal.toObject();
    const QJsonValue mapVal = snapshot.value(QStringLiteral("map"));
    if (!mapVal.isObject())
        return fail(QStringLiteral("champ 'snapshot.map' manquant ou non-objet"),
                    job.jobId);
    job.snapshotMap = mapVal.toObject();
    // memory/modules : réservés (doc 05 / D41), tolérés absents au squelette.
    job.snapshotMemory = snapshot.value(QStringLiteral("memory")).toObject();
    job.snapshotModules = snapshot.value(QStringLiteral("modules")).toObject();

    // --- artifact : validé présent, non instancié au squelette (P2 stub) ---
    const QJsonValue artifactVal = root.value(QStringLiteral("artifact"));
    if (!artifactVal.isObject())
        return fail(QStringLiteral("champ 'artifact' manquant ou non-objet"),
                    job.jobId);
    job.artifact = artifactVal.toObject();
    if (!job.artifact.value(QStringLiteral("source")).isString())
        return fail(QStringLiteral("champ 'artifact.source' manquant"),
                    job.jobId);
    if (!job.artifact.value(QStringLiteral("contentHash")).isString())
        return fail(QStringLiteral("champ 'artifact.contentHash' manquant"),
                    job.jobId);

    // --- budgets / stimuli / seed : optionnels au squelette ---
    job.budgets = root.value(QStringLiteral("budgets")).toObject();
    job.stimuli = root.value(QStringLiteral("stimuli")).toArray();
    job.seed = quint32(root.value(QStringLiteral("seed")).toDouble(0));

    result.ok = true;
    return result;
}
