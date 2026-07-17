#ifndef BENCH_CONSTANTS_H
#define BENCH_CONSTANTS_H

// ============================================================================
// Constantes du banc d'essai hors-process (doc/v3/12_BANC_ESSAI_R1.md §9).
// Pattern D22 : toutes derrière #define. Header partagé entre le superviseur
// côté jeu (cpp/ai/bench/bench_supervisor.*) et l'exécutable meow_testbench
// (Meownopoly/bench/).
// ============================================================================

// Version du protocole job/verdict. Bump à chaque évolution des règles du
// banc (invalide le cache de verdicts, doc 12 §7).
#define MEOW_BENCH_VERSION 1

// Préfixe de la ligne de verdict sur stdout — survit aux logs parasites.
#define MEOW_BENCH_VERDICT_PREFIX "MEOWBENCH:"

// Timeout dur global côté superviseur (kill + verdict bench_timeout).
#define MEOW_BENCH_TIMEOUT_MS 30000

// Plafond de la phase P2 (instanciation de l'artefact, D34).
#define MEOW_BENCH_LOAD_TIMEOUT_MS 5000

// Ticks simulés en P3 (simulation à vide).
#define MEOW_BENCH_IDLE_TICKS 600

// Auto-kill mémoire du banc (RSS), verdict runaway_alloc (doc 12 §5).
#define MEOW_BENCH_MAX_RSS_MB 512

// Période du poll RSS d'auto-surveillance.
#define MEOW_BENCH_RSS_POLL_MS 100

// Process chauds pré-lancés (mode pool, §6) — non implémenté au squelette.
#define MEOW_BENCH_POOL 1

// Recyclage d'un process de pool même en pass (§6) — non implémenté.
#define MEOW_BENCH_JOBS_PER_PROCESS 10

// Dry-runs artifact_dryrun par invocation d'IA (D42) — non implémenté.
#define MEOW_BENCH_DRYRUN_QUOTA 10

// Nom de base de l'exécutable du banc (sans extension plateforme).
#define MEOW_BENCH_EXE_NAME "meow_testbench"

#endif // BENCH_CONSTANTS_H
