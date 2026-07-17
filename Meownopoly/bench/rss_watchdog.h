#ifndef RSS_WATCHDOG_H
#define RSS_WATCHDOG_H

// ============================================================================
// Auto-surveillance mémoire du banc (doc/v3/12_BANC_ESSAI_R1.md §5).
// Thread dédié qui poll la RSS du process toutes les MEOW_BENCH_RSS_POLL_MS ms
// et auto-tue au-delà de MEOW_BENCH_MAX_RSS_MB avec un verdict `runaway_alloc`
// flushé avant l'arrêt (exit 0 : verdict rendu).
//
// Windows : GetProcessMemoryInfo (psapi). Linux : stub à compléter en M13
// (lecture de /proc/self/statm).
// ============================================================================

#include <QString>

class RssWatchdog
{
public:
    // Démarre le thread de surveillance (détaché — le process meurt avec).
    // jobId/phase servent au verdict synthétique en cas de dépassement.
    static void start(const QString &jobId);

    // Phase courante, reportée dans le verdict runaway_alloc. Le pointeur
    // doit rester valide (littéraux "P1".."P5" attendus).
    static void setPhase(const char *phase);

    // Pic RSS observé depuis start(), en octets (0 si plateforme non gérée).
    static quint64 peakRssBytes();

    // RSS courante du process, en octets (0 si plateforme non gérée).
    static quint64 currentRssBytes();
};

#endif // RSS_WATCHDOG_H
