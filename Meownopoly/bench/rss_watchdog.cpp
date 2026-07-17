#include "rss_watchdog.h"

#include "ai/bench/bench_constants.h"
#include "bench_verdict.h"

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <thread>

#ifdef Q_OS_WIN
// clang-format off
#include <windows.h>
#include <psapi.h>
// clang-format on
#endif

namespace {

std::atomic<const char *> g_phase{"job"};
std::atomic<quint64> g_peakRss{0};
QString g_jobId; // écrit une fois avant le start du thread, lu ensuite

quint64 readRssBytes()
{
#ifdef Q_OS_WIN
    PROCESS_MEMORY_COUNTERS pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc)))
        return quint64(pmc.WorkingSetSize);
    return 0;
#else
    // TODO(M13) : lire /proc/self/statm sur Linux. Stub : pas de
    // surveillance — le plafond OS post-MVP (cgroups) prendra le relais.
    return 0;
#endif
}

void watchdogLoop()
{
    constexpr quint64 limitBytes =
        quint64(MEOW_BENCH_MAX_RSS_MB) * 1024ull * 1024ull;
    for (;;) {
        std::this_thread::sleep_for(
            std::chrono::milliseconds(MEOW_BENCH_RSS_POLL_MS));
        const quint64 rss = readRssBytes();
        if (rss > g_peakRss.load(std::memory_order_relaxed))
            g_peakRss.store(rss, std::memory_order_relaxed);
        if (rss > limitBytes) {
            // Dépassement : verdict runaway_alloc flushé, puis mort immédiate
            // du process (exit 0 : un verdict a été rendu, doc 12 §2.2).
            BenchFailure failure;
            failure.code = QStringLiteral("runaway_alloc");
            failure.phase =
                QString::fromLatin1(g_phase.load(std::memory_order_relaxed));
            failure.details =
                QStringLiteral("RSS %1 Mo > plafond %2 Mo — auto-kill")
                    .arg(rss / (1024 * 1024))
                    .arg(MEOW_BENCH_MAX_RSS_MB);
            failure.retryable = false;

            QJsonObject metrics;
            metrics.insert(QStringLiteral("peakMemMB"),
                           double(rss) / (1024.0 * 1024.0));
            printBenchVerdict(g_jobId, false, {failure}, metrics, 0);
            std::_Exit(0);
        }
    }
}

} // namespace

void RssWatchdog::start(const QString &jobId)
{
    g_jobId = jobId;
    g_peakRss.store(readRssBytes(), std::memory_order_relaxed);
    std::thread(watchdogLoop).detach();
}

void RssWatchdog::setPhase(const char *phase)
{
    g_phase.store(phase, std::memory_order_relaxed);
}

quint64 RssWatchdog::peakRssBytes()
{
    const quint64 now = readRssBytes();
    const quint64 peak = g_peakRss.load(std::memory_order_relaxed);
    return now > peak ? now : peak;
}

quint64 RssWatchdog::currentRssBytes()
{
    return readRssBytes();
}
