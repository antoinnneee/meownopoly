#ifndef BENCH_PHASES_H
#define BENCH_PHASES_H

// ============================================================================
// Phases de test P1→P5 du banc (doc/v3/12_BANC_ESSAI_R1.md §3).
//
// P1 : reconstruction du snapshot + démarrage du moteur physique.
// P2 : instanciation de l'artefact dans le contexte restreint (A6) —
//      load_failed / load_timeout (watchdog d'échéance + setInterrupted).
// P3 : MEOW_BENCH_IDLE_TICKS ticks accélérés — tick_budget / object_quota
//      (runaway_alloc est porté par le watchdog RSS, toutes phases).
// P4 : stimuli génériques sur les hooks réellement abonnés en P2 —
//      event_budget / event_flood / memory_quota / writeset_violation.
// P5 : teardown — timers actifs et objets survivants → leak.
// ============================================================================

#include "bench_job.h"

#include "game/physics/pattounx_engine_v2.h"

#include "ai/sandbox/meow_game_api.h"

#include <QJsonObject>
#include <QRandomGenerator>
#include <QVector>

class Map;
class QObject;
class QQmlComponent;
class RestrictedContext;

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

    PhaseResult runP1Reconstruction();
    PhaseResult runP2Instantiation();
    PhaseResult runP3IdleSimulation();
    PhaseResult runP4Stimulation();
    PhaseResult runP5Teardown();

    // Métriques collectées (doc 12 §4) : loadMs, tickUsP50/P95/Max,
    // handlerUsP95 (par hook), objectCount, writeSet, emitRate, …
    QJsonObject metrics() const { return m_metrics; }

private:
    // Budgets effectifs : job.budgets (source de vérité côté jeu, doc 12
    // §2.3) avec repli sur les #define D34 de bench_constants.h.
    struct Budgets
    {
        double maxHandlerMs;
        double maxTickMs;
        double maxMemMB; // non appliqué au MVP (cf. bench_constants.h)
        int maxObjects;
        int maxEmitPerS;
        int memValueKb;
        int loadTimeoutMs;
        int idleTicks;
    };

    Budgets effectiveBudgets() const;
    int liveObjectCount() const; // racine + descendants QObject (poll)
    qint64 runOneTick();         // step physique + processEvents borné, en ns
    void recordHandlerCalls(const QVector<MeowHandlerCall> &calls);

    const BenchJob &m_job;
    Map *m_map = nullptr;
    pattounx::PattounX_engine m_engine;
    QRandomGenerator m_rng; // seedée par job.seed — toute source d'aléa du
                            // banc doit passer par elle (reproductibilité R1)
    QJsonObject m_metrics;

    Budgets m_budgets{};
    RestrictedContext *m_ctx = nullptr;
    QQmlComponent *m_component = nullptr;
    QObject *m_root = nullptr;

    // ns par appel de handler, agrégés par nom ("on(zoneEntered)", …).
    QHash<QString, QVector<qint64>> m_handlerNs;
    QStringList m_handlerErrors;
};

#endif // BENCH_PHASES_H
