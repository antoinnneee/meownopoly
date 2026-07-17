#ifndef DEADLINE_WATCHDOG_H
#define DEADLINE_WATCHDOG_H

// ============================================================================
// Watchdog d'échéance du banc (pattern rss_watchdog, doc 12 §3 P2/P4).
//
// Problème : une boucle JS infinie (Component.onCompleted, handler
// d'événement) bloque le THREAD PRINCIPAL du banc — aucun timer Qt ne peut
// la mesurer. Réponse en deux crans :
//   1. à l'échéance, le thread watchdog appelle QJSEngine::setInterrupted(true)
//      (thread-safe) : le moteur JS avorte l'exécution en cours, le thread
//      principal reprend la main et rend lui-même le verdict (metrics
//      complètes) ;
//   2. filet ultime : si le thread principal n'a pas désarmé après le délai
//      de grâce (bloqué hors JS pur), le watchdog flushe lui-même le verdict
//      et _Exit(0) — le superviseur (30 s) n'est jamais atteint sur ce chemin.
//
// Un seul armement à la fois (le banc est séquentiel).
// ============================================================================

#include <QString>

class QJSEngine;

class DeadlineWatchdog
{
public:
    // À appeler une fois avant tout arm() (jobId du verdict synthétique).
    static void init(const QString &jobId);

    // Arme une échéance : au bout de timeoutMs, interrompt le moteur ; après
    // graceMs supplémentaires sans disarm(), verdict `code` + _Exit(0).
    // `phase`/`code` : littéraux statiques ("P2", "load_timeout"…).
    static void arm(const char *phase,
                    const char *code,
                    const QString &details,
                    int timeoutMs,
                    QJSEngine *engine,
                    int graceMs);

    // Désarme. Retourne true si l'échéance avait déjà interrompu le moteur
    // (l'appelant rend alors le verdict correspondant au code armé).
    static bool disarm();
};

#endif // DEADLINE_WATCHDOG_H
