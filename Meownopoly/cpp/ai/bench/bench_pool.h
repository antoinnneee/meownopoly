#ifndef MEOW_BENCH_POOL_H
#define MEOW_BENCH_POOL_H

// ============================================================================
// BenchPool — file de validation + pool de process + cache (doc 12 §6-7, A8)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md §6 (coût de spawn et pool) et §7
//                 (cache de verdicts).
//
// Point d'entrée unique côté jeu pour valider un artefact. Empile trois
// mécaniques au-dessus de `BenchSupervisor` (A3) :
//
//   1. CACHE (BenchVerdictCache, §7) — clé `contentHash+benchVersion+
//      hash(budgets)`. Un artefact déjà validé n'est PAS re-testé : le verdict
//      est rendu immédiatement, sans spawner de process (revalidation à coût
//      nul au chargement, doc 04 §3.5). Le snapshot ne fait pas partie de la clé.
//
//   2. POOL de process (§6) — `MEOW_BENCH_POOL` process (défaut 1). Au MVP la
//      file transactionnelle D12 sérialise déjà les propositions : un seul
//      process suffit ; le pool > 1 ne sert que le collab futur. Les jobs qui
//      n'ont pas de hit cache sont mis en file et distribués aux slots libres.
//
//   3. RECYCLAGE (§6) — un slot est recyclé (process discard + neuf) après
//      chaque verdict `fail`/`timeout` (hygiène : pas de réutilisation d'un
//      moteur qui vient de subir un artefact hostile) ET tous les
//      `MEOW_BENCH_JOBS_PER_PROCESS` jobs (défaut 10) même en `pass`.
//
// NOTE d'implémentation (MVP) : `BenchSupervisor` spawn un process À FROID par
// job (le banc actuel lit un job puis sort — meow_testbench_main.cpp). Le slot
// est donc un `BenchSupervisor` réutilisable, et « recycler » = le détruire puis
// le recréer (reset des compteurs, largage d'un éventuel état résiduel). La
// persistance d'un process CHAUD lisant les jobs sur stdin (le vrai gain de
// coût du §6) est une évolution ultérieure, conditionnée par la mesure du
// démarrage froid (jalon R1) : la politique de recyclage codée ici est le point
// d'accroche exact de cette évolution, sans changer l'API publique.
//
// 100 % ASYNCHRONE : `submit()` rend la main aussitôt, le verdict arrive par le
// signal `verdictReady`. Aucun blocage du GUI (invariant doc 12 §1, hérité de
// BenchSupervisor). Ne dépend que de Qt6::Core — aucun réseau.
// ============================================================================

#include <QObject>
#include <QJsonObject>
#include <QString>
#include <QQueue>
#include <QVector>

#include "bench_verdict_cache.h"

class BenchSupervisor;

// Nombre de process chauds (doc 12 §9). Défaut 1 ; surchargeable par le #define
// (D22), par l'environnement `MEOW_BENCH_POOL`, ou par setPoolSize().
#ifndef MEOW_BENCH_POOL
#define MEOW_BENCH_POOL 1
#endif

// Recyclage d'un slot même en pass, tous les N jobs (doc 12 §9).
#ifndef MEOW_BENCH_JOBS_PER_PROCESS
#define MEOW_BENCH_JOBS_PER_PROCESS 10
#endif

namespace meow::bench {

class BenchPool : public QObject
{
    Q_OBJECT

public:
    explicit BenchPool(QObject *parent = nullptr);
    ~BenchPool() override;

    // Chemin de l'exécutable du banc (propagé aux slots). Défaut : résolu par
    // BenchSupervisor à côté de l'application.
    void setBenchExecutablePath(const QString &path);

    // Taille du pool (>= 1). Redimensionne les slots. Défaut : env
    // `MEOW_BENCH_POOL` sinon MEOW_BENCH_POOL.
    void setPoolSize(int n);
    int poolSize() const { return m_slots.size(); }

    // Nombre de jobs par process avant recyclage (>= 1). Défaut
    // MEOW_BENCH_JOBS_PER_PROCESS.
    void setJobsPerProcess(int n);
    int jobsPerProcess() const { return m_jobsPerProcess; }

    // Soumet un job (doc 12 §2.3). Hit cache ⇒ `verdictReady` (asynchrone) sans
    // spawn. Sinon mise en file + distribution à un slot libre. Le `jobId` du
    // job corrèle le verdict.
    void submit(const QJsonObject &job);

    // File d'attente en cours (jobs pas encore distribués à un slot).
    int pending() const { return m_queue.size(); }

    // Accès au cache (stats/purge). Purge nécessaire sur bump de benchVersion
    // au runtime (rare) ou changement de politique.
    BenchVerdictCache &cache() { return m_cache; }
    void clearCache() { m_cache.clear(); }

signals:
    // Verdict d'un job soumis (réel, synthétique, ou servi par le cache). Sur
    // hit cache, `verdict.metrics.fromCache == true`. Toujours bien formé.
    void verdictReady(const QString &jobId, const QJsonObject &verdict);

private:
    // Un slot = un process réutilisable + sa comptabilité de recyclage.
    struct Slot {
        BenchSupervisor *sup = nullptr;
        int   jobsSinceSpawn = 0;
        bool  busy = false;
        QString jobId;       // job en cours (corrélation)
        QString cacheKey;    // clé de cache du job en cours (put à la fin)
    };

    static int defaultPoolSize();
    static QString cacheKeyForJob(const QJsonObject &job);

    void ensureSlot(int i);          // (re)crée le BenchSupervisor du slot i
    void recycleSlot(int i);         // détruit + recrée (hygiène / seuil)
    void dispatch();                 // distribue la file aux slots libres
    void onSlotVerdict(int i, const QJsonObject &verdict);
    void emitDeferred(const QString &jobId, const QJsonObject &verdict);

    BenchVerdictCache m_cache;
    QVector<Slot>     m_slots;
    QQueue<QJsonObject> m_queue;
    QString m_benchExe;              // vide → défaut du superviseur
    int     m_jobsPerProcess = MEOW_BENCH_JOBS_PER_PROCESS;
};

} // namespace meow::bench

#endif // MEOW_BENCH_POOL_H
