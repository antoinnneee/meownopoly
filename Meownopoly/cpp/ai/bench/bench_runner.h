#ifndef MEOW_BENCH_RUNNER_H
#define MEOW_BENCH_RUNNER_H

// ============================================================================
// bench_runner — pipeline P1→P5 du banc d'essai hors-process (D26, tâche A5)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md §3 (phases), §4 (verdict/metrics),
//                 §5 (auto-surveillance RSS), §9 (constantes).
//
// Exécuté DANS le process jetable `meow_testbench` (meow_testbench_main.cpp),
// jamais dans le jeu — le superviseur (bench_supervisor, A3) ne voit que la
// ligne `MEOWBENCH:` sur stdout. Ce fichier est volontairement EXCLU du GLOB
// de l'exécutable principal (cf. CMakeLists) : le jeu n'exécute jamais de
// code candidat in-process.
//
// Phases :
//   P1 Reconstruction  : Map::loadMap(snapshot.map) + moteur Pattounx v2 à
//                        vide + warm-up des modules QML de l'allow-list D34
//                        (pour que le coût de chargement des plugins QtQuick
//                        n'émarge pas au budget mémoire de l'artefact).
//   P2 Instanciation   : RestrictedContext + façade Meow.GameApi (code
//                        partagé banc/jeu, cpp/ai/sandbox/), création de
//                        l'artefact ; boucle au chargement → watchdog thread
//                        → verdict `load_timeout` flushé puis sortie.
//   P3 Simulation      : N ticks à vide accélérés (physique + event loop +
//                        handlers `tick`), mesures p50/p95/max par tick.
//   P4 Stimulation     : stimuli du job + scénarios génériques dérivés des
//                        abonnements observés (injection directe des
//                        événements — reco doc 12 §11, pas de physique réelle),
//                        budgets handler/flood/quotas/write-set.
//   P5 Teardown        : destruction, vérification racine morte + zéro
//                        activité façade résiduelle (leak).
//
// Sécurité du banc lui-même (doc 12 §5) : thread de surveillance qui
//   - poll le RSS toutes les 100 ms et auto-tue au-delà de
//     MEOW_BENCH_MAX_RSS_MB avec verdict `runaway_alloc` flushé avant sortie ;
//   - sert de watchdog de phase (P2 create / P4 dispatch synchrones et
//     ininterruptibles in-process : seul un _exit rend la main).
// ============================================================================

#include "bench_protocol.h"

class QQmlEngine;

// ─── Constantes §9 (pattern D22). Le job peut les surcharger via `budgets`. ──
#ifndef MEOW_BENCH_LOAD_TIMEOUT_MS
#define MEOW_BENCH_LOAD_TIMEOUT_MS 5000
#endif
#ifndef MEOW_BENCH_IDLE_TICKS
#define MEOW_BENCH_IDLE_TICKS 600
#endif
#ifndef MEOW_BENCH_MAX_RSS_MB
#define MEOW_BENCH_MAX_RSS_MB 512
#endif
// Budgets artefact (valeurs D34, sérialisées dans le job en temps normal)
#ifndef MEOW_BENCH_TICK_BUDGET_US
#define MEOW_BENCH_TICK_BUDGET_US 500            // ≤ 0,5 ms/tick soutenu
#endif
#ifndef MEOW_BENCH_HANDLER_BUDGET_US
#define MEOW_BENCH_HANDLER_BUDGET_US 2000        // ≤ 2 ms/événement
#endif
#ifndef MEOW_BENCH_EMIT_MAX_PER_SEC
#define MEOW_BENCH_EMIT_MAX_PER_SEC 30           // ≤ 30 émissions/s
#endif
#ifndef MEOW_BENCH_OBJECT_MAX
#define MEOW_BENCH_OBJECT_MAX 200                // ≤ 200 objets
#endif
#ifndef MEOW_BENCH_ARTIFACT_MEM_MB
#define MEOW_BENCH_ARTIFACT_MEM_MB 8             // ≤ 8 Mo (delta RSS depuis P1)
#endif
#ifndef MEOW_BENCH_MEMORY_VALUE_MAX_BYTES
#define MEOW_BENCH_MEMORY_VALUE_MAX_BYTES 1024   // D35 : 1 KB/valeur
#endif
// Mécanique interne du banc
#ifndef MEOW_BENCH_BASELINE_TICKS
#define MEOW_BENCH_BASELINE_TICKS 60             // étalonnage pré-artefact (P1)
#endif
#ifndef MEOW_BENCH_POST_TEARDOWN_TICKS
#define MEOW_BENCH_POST_TEARDOWN_TICKS 30        // fenêtre d'observation leak (P5)
#endif
#ifndef MEOW_BENCH_P3_HARD_TIMEOUT_MS
#define MEOW_BENCH_P3_HARD_TIMEOUT_MS 10000      // garde-fou hang P3 (watchdog)
#endif
#ifndef MEOW_BENCH_P4_HANG_TIMEOUT_MS
#define MEOW_BENCH_P4_HANG_TIMEOUT_MS 5000       // garde-fou hang par dispatch P4
#endif
#ifndef MEOW_BENCH_FLOOD_WINDOW_MS
#define MEOW_BENCH_FLOOD_WINDOW_MS 500           // fenêtre temps réel event_flood
#endif

namespace meow::bench {

// Exécute le pipeline P1→P5 sur un job déjà validé (parseJobFile ok=true).
// Rend TOUJOURS un verdict (pass ou fail) — sauf comportement pathologique
// (boucle, allocation massive) où le watchdog flushe lui-même un verdict
// synthétique sur stdout puis termine le process (exit 0 : verdict rendu).
// `durationMs` est laissé à 0 — renseigné par l'appelant (mur global du main).
BenchVerdict runBenchJob(QQmlEngine &engine, const BenchJob &job);

} // namespace meow::bench

#endif // MEOW_BENCH_RUNNER_H
