#ifndef BENCH_PHASES_H
#define BENCH_PHASES_H

// ============================================================================
// Phases de test P1→P5 du banc (doc/v3/12_BANC_ESSAI_R1.md §3).
//
// Squelette M9.1 : P1 (reconstruction du snapshot + démarrage du moteur
// physique) est réelle ; P2→P5 sont des stubs qui passent, structurés une
// fonction par phase pour être remplis par la tâche A5 du plan (doc 15).
// ============================================================================

#include "bench_job.h"

#include "game/physics/pattounx_engine_v2.h"

#include <QJsonObject>
#include <QRandomGenerator>

class Map;

struct PhaseResult
{
    bool ok = true;
    QString failureCode; // vide si ok
    QString details;
    bool retryable = false;

    static PhaseResult pass() { return {}; }
    static PhaseResult fail(const QString &code,
                            const QString &details,
                            bool retryable = false)
    {
        return {false, code, details, retryable};
    }
};

class BenchPhases
{
public:
    explicit BenchPhases(const BenchJob &job);
    ~BenchPhases();

    // P1 — Reconstruction : recharge le snapshot map (chemin de sérialisation
    // existant, même format que le full-sync collab) + démarre le moteur
    // physique à vide (quelques ticks). Échec → snapshot_invalid.
    PhaseResult runP1Reconstruction();

    // P2 — Instanciation de l'artefact dans le contexte restreint.
    // STUB : l'artefact n'est pas instancié au squelette (dépend de A6,
    // contexte restreint + façade Meow.GameApi). Codes cibles : load_failed,
    // load_timeout (> MEOW_BENCH_LOAD_TIMEOUT_MS).
    PhaseResult runP2Instantiation();

    // P3 — Simulation à vide : MEOW_BENCH_IDLE_TICKS ticks accélérés.
    // STUB : quelques ticks réels sont déjà faits en P1 ; la mesure
    // tick_budget/runaway_alloc par tick viendra avec A5.
    PhaseResult runP3IdleSimulation();

    // P4 — Stimulation : rejoue job.stimuli (event_budget, event_flood,
    // memory_quota, writeset_violation). STUB au squelette.
    PhaseResult runP4Stimulation();

    // P5 — Teardown : détruit l'artefact et vérifie la libération (leak).
    // Au squelette : libère la carte reconstruite en P1.
    PhaseResult runP5Teardown();

    // Métriques collectées (doc 12 §4) — partiel au squelette : loadMs,
    // tileCount, idleTicks.
    QJsonObject metrics() const { return m_metrics; }

private:
    const BenchJob &m_job;
    Map *m_map = nullptr;
    pattounx::PattounX_engine m_engine;
    QRandomGenerator m_rng; // seedée par job.seed — toute source d'aléa du
                            // banc doit passer par elle (reproductibilité R1)
    QJsonObject m_metrics;
};

#endif // BENCH_PHASES_H
