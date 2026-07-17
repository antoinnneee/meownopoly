// ============================================================================
// meow_testbench — banc d'essai hors-process (doc/v3/12_BANC_ESSAI_R1.md).
//
// Un run = une validation : le process reçoit un job JSON (chemin en
// argument), déroule les phases P1→P5, écrit une seule ligne de verdict
// `MEOWBENCH:{...}` sur stdout et meurt. Exit code 0 dès qu'un verdict est
// rendu (quel qu'il soit) ; tout autre code = crash du banc lui-même.
//
// Lancé par BenchSupervisor (cpp/ai/bench/) avec `-platform offscreen` —
// rejouable à la main : meow_testbench -platform offscreen job.json
// ============================================================================

#include "bench_job.h"
#include "bench_phases.h"
#include "bench_verdict.h"
#include "rss_watchdog.h"

#include <QElapsedTimer>
#include <QGuiApplication>

namespace {

int emitFailure(const QString &jobId,
                const QString &code,
                const QString &phase,
                const QString &details,
                bool retryable,
                const QJsonObject &metrics,
                qint64 durationMs)
{
    BenchFailure failure;
    failure.code = code;
    failure.phase = phase;
    failure.details = details;
    failure.retryable = retryable;
    printBenchVerdict(jobId, false, {failure}, metrics, durationMs);
    return 0; // verdict rendu → exit 0 (doc 12 §2.2)
}

} // namespace

int main(int argc, char *argv[])
{
    // QGuiApplication (pas QCoreApplication) : consomme `-platform offscreen`
    // et fournira la plateforme QPA au moteur QML des phases P2+ (A5/A6).
    // Aucun exec() : le banc est purement séquentiel, pas de boucle
    // d'événements principale.
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("meow_testbench"));

    QElapsedTimer totalTimer;
    totalTimer.start();

    // --- Argument : chemin du fichier de job (premier positionnel restant,
    // QGuiApplication ayant déjà retiré -platform/offscreen d'arguments()) ---
    QString jobPath;
    const QStringList args = QCoreApplication::arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (!args.at(i).startsWith(QLatin1Char('-'))) {
            jobPath = args.at(i);
            break;
        }
    }

    // --- Parsing/validation du job → job_invalid ---
    const BenchJobParseResult parsed = parseBenchJobFile(jobPath);
    if (!parsed.ok) {
        return emitFailure(parsed.job.jobId, QStringLiteral("job_invalid"),
                           QStringLiteral("job"), parsed.details,
                           /*retryable*/ false, QJsonObject{},
                           totalTimer.elapsed());
    }
    const BenchJob &job = parsed.job;

    // --- Auto-surveillance RSS (doc 12 §5) : auto-kill > 512 Mo avec
    // verdict runaway_alloc flushé avant l'arrêt ---
    RssWatchdog::start(job.jobId);

    // --- Phases P1→P5 ---
    BenchPhases phases(job);
    struct PhaseStep
    {
        const char *name;
        PhaseResult (BenchPhases::*run)();
    };
    const PhaseStep steps[] = {
        {"P1", &BenchPhases::runP1Reconstruction},
        {"P2", &BenchPhases::runP2Instantiation},
        {"P3", &BenchPhases::runP3IdleSimulation},
        {"P4", &BenchPhases::runP4Stimulation},
        {"P5", &BenchPhases::runP5Teardown},
    };

    for (const PhaseStep &step : steps) {
        RssWatchdog::setPhase(step.name);
        const PhaseResult result = (phases.*step.run)();
        if (!result.ok) {
            return emitFailure(job.jobId, result.failureCode,
                               QString::fromLatin1(step.name), result.details,
                               result.retryable, phases.metrics(),
                               totalTimer.elapsed());
        }
    }

    // --- Verdict pass ---
    QJsonObject metrics = phases.metrics();
    metrics.insert(QStringLiteral("peakMemMB"),
                   double(RssWatchdog::peakRssBytes()) / (1024.0 * 1024.0));
    printBenchVerdict(job.jobId, true, {}, metrics, totalTimer.elapsed());
    return 0;
}
