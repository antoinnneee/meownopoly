#include "deadline_watchdog.h"

#include "bench_verdict.h"

#include <QJSEngine>

#include <condition_variable>
#include <cstdlib>
#include <mutex>
#include <thread>

namespace {

struct WatchdogState
{
    std::mutex mutex;
    std::condition_variable cv;
    bool threadStarted = false;

    quint64 generation = 0; // incrémentée à chaque arm/disarm
    bool armed = false;
    bool fired = false; // le moteur a été interrompu pour la génération armée

    const char *phase = "job";
    const char *code = "bench_timeout";
    QString details;
    int timeoutMs = 0;
    int graceMs = 0;
    QJSEngine *engine = nullptr;
    QString jobId;
};

WatchdogState *state()
{
    static WatchdogState s;
    return &s;
}

void watchdogLoop()
{
    WatchdogState *s = state();
    std::unique_lock<std::mutex> lock(s->mutex);
    for (;;) {
        s->cv.wait(lock, [s] { return s->armed; });
        const quint64 gen = s->generation;

        // --- Cran 1 : attendre l'échéance ou un disarm ---
        const auto deadline = std::chrono::steady_clock::now()
                              + std::chrono::milliseconds(s->timeoutMs);
        if (s->cv.wait_until(lock, deadline,
                             [s, gen] { return s->generation != gen; }))
            continue; // désarmé (ou ré-armé) à temps

        // Échéance atteinte : interrompre le moteur JS.
        s->fired = true;
        if (s->engine)
            s->engine->setInterrupted(true);

        // --- Cran 2 : délai de grâce puis verdict + _Exit ---
        const auto graceDeadline = std::chrono::steady_clock::now()
                                   + std::chrono::milliseconds(s->graceMs);
        if (s->cv.wait_until(lock, graceDeadline,
                             [s, gen] { return s->generation != gen; }))
            continue; // le thread principal a repris la main et désarmé

        BenchFailure failure;
        failure.code = QString::fromLatin1(s->code);
        failure.phase = QString::fromLatin1(s->phase);
        failure.details = s->details
                          + QStringLiteral(" (verdict flushé par le watchdog "
                                           "d'échéance, thread principal "
                                           "toujours bloqué)");
        failure.retryable = false;
        printBenchVerdict(s->jobId, false, {failure}, QJsonObject{}, 0);
        std::_Exit(0); // verdict rendu → exit 0 (doc 12 §2.2)
    }
}

} // namespace

void DeadlineWatchdog::init(const QString &jobId)
{
    WatchdogState *s = state();
    std::lock_guard<std::mutex> lock(s->mutex);
    s->jobId = jobId;
    if (!s->threadStarted) {
        s->threadStarted = true;
        std::thread(watchdogLoop).detach();
    }
}

void DeadlineWatchdog::arm(const char *phase,
                           const char *code,
                           const QString &details,
                           int timeoutMs,
                           QJSEngine *engine,
                           int graceMs)
{
    WatchdogState *s = state();
    {
        std::lock_guard<std::mutex> lock(s->mutex);
        ++s->generation;
        s->armed = true;
        s->fired = false;
        s->phase = phase;
        s->code = code;
        s->details = details;
        s->timeoutMs = timeoutMs;
        s->graceMs = graceMs;
        s->engine = engine;
    }
    s->cv.notify_all();
}

bool DeadlineWatchdog::disarm()
{
    WatchdogState *s = state();
    bool fired = false;
    {
        std::lock_guard<std::mutex> lock(s->mutex);
        ++s->generation;
        s->armed = false;
        fired = s->fired;
        s->fired = false;
        s->engine = nullptr;
    }
    s->cv.notify_all();
    return fired;
}
