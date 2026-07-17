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

// ----------------------------------------------------------------------------
// Budgets runtime d'un artefact (D34, doc 04 §3.4, doc 08). Défauts compilés ;
// le job du banc peut les surcharger via son champ `budgets` (doc 12 §2.3 :
// le jeu est la source de vérité, le banc applique ce qu'on lui donne).
// ----------------------------------------------------------------------------

// Budget CPU par handler d'événement (P4, event_budget si p95 au-delà).
#ifndef MEOW_SANDBOX_MAX_HANDLER_MS
#define MEOW_SANDBOX_MAX_HANDLER_MS 2
#endif

// Budget CPU par tick de simulation (P3, tick_budget si p95 soutenu au-delà).
// En millisecondes, fractionnaire.
#ifndef MEOW_SANDBOX_MAX_TICK_MS
#define MEOW_SANDBOX_MAX_TICK_MS 0.5
#endif

// Plafond mémoire par artefact (D34). NON APPLIQUÉ au banc MVP : la RSS d'un
// process Qt/QML ne permet pas d'isoler la part de l'artefact (charger le
// module QtQuick coûte à lui seul des dizaines de Mo). Le filet effectif est
// MEOW_BENCH_MAX_RSS_MB (512, runaway_alloc). TODO(D13) : mesure par heap JS
// au confinement in-process.
#ifndef MEOW_SANDBOX_MAX_MEM_MB
#define MEOW_SANDBOX_MAX_MEM_MB 8
#endif

// Nombre max d'objets QML instanciés par un artefact (object_quota).
#ifndef MEOW_SANDBOX_MAX_OBJECTS
#define MEOW_SANDBOX_MAX_OBJECTS 200
#endif

// Plafond d'émissions events.emit par seconde (event_flood).
#ifndef MEOW_SANDBOX_MAX_EMIT_PER_S
#define MEOW_SANDBOX_MAX_EMIT_PER_S 30
#endif

// Taille max (KB) d'une valeur écrite via memory.set (memory_quota, D15).
#ifndef MEOW_SANDBOX_MEM_VALUE_KB
#define MEOW_SANDBOX_MEM_VALUE_KB 1
#endif

// Plafond DUR par appel de handler avant interruption du moteur JS (P4).
// Distinct du budget MEOW_SANDBOX_MAX_HANDLER_MS (2 ms, verdict p95) : c'est
// le filet anti-gel — un handler encore vivant après ce délai est interrompu
// (QJSEngine::setInterrupted) et le verdict event_budget est rendu.
#ifndef MEOW_BENCH_HANDLER_HARD_CAP_MS
#define MEOW_BENCH_HANDLER_HARD_CAP_MS 1000
#endif

// Délai de grâce du watchdog d'échéance : après setInterrupted(true), si le
// thread principal n'a toujours pas repris la main (code bloqué hors JS pur),
// le verdict est flushé depuis le watchdog et le process _Exit(0).
#ifndef MEOW_BENCH_INTERRUPT_GRACE_MS
#define MEOW_BENCH_INTERRUPT_GRACE_MS 2000
#endif

#endif // BENCH_CONSTANTS_H
