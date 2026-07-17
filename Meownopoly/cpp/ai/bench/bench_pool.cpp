// ============================================================================
// BenchPool — implémentation (doc 12 §6-7, tâche A8)
// ============================================================================

#include "bench_pool.h"
#include "bench_supervisor.h"
#include "bench_protocol.h"

#include <QMetaObject>

namespace meow::bench {

BenchPool::BenchPool(QObject *parent)
    : QObject(parent)
{
    setPoolSize(defaultPoolSize());
}

BenchPool::~BenchPool() = default;

int BenchPool::defaultPoolSize()
{
    // Priorité à l'environnement (`MEOW_BENCH_POOL`), sinon le #define (D22).
    bool ok = false;
    const int env = qEnvironmentVariableIntValue("MEOW_BENCH_POOL", &ok);
    if (ok && env >= 1)
        return env;
    return MEOW_BENCH_POOL;
}

void BenchPool::setBenchExecutablePath(const QString &path)
{
    m_benchExe = path;
    for (Slot &s : m_slots) {
        if (s.sup && !path.isEmpty())
            s.sup->setBenchExecutablePath(path);
    }
}

void BenchPool::setPoolSize(int n)
{
    n = qMax(1, n);
    // Rétrécissement : ne supprime que des slots LIBRES (un slot occupé finira
    // son job puis ne sera plus réalimenté — mais au MVP on ne rétrécit pas à
    // chaud, la file étant sérialisée). On (re)dimensionne simplement.
    const int old = m_slots.size();
    if (n < old) {
        for (int i = old - 1; i >= n; --i) {
            if (m_slots[i].sup)
                m_slots[i].sup->deleteLater();
        }
        m_slots.resize(n);
    } else {
        m_slots.resize(n);
        for (int i = old; i < n; ++i) {
            m_slots[i] = Slot{};
            ensureSlot(i);
        }
    }
    dispatch();
}

void BenchPool::setJobsPerProcess(int n)
{
    m_jobsPerProcess = qMax(1, n);
}

void BenchPool::ensureSlot(int i)
{
    Slot &s = m_slots[i];
    if (s.sup)
        return;
    s.sup = new BenchSupervisor(this);
    if (!m_benchExe.isEmpty())
        s.sup->setBenchExecutablePath(m_benchExe);
    s.jobsSinceSpawn = 0;
    s.busy = false;
    // Le superviseur n'émet pas le jobId — on le corrèle via le slot.
    QObject::connect(s.sup, &BenchSupervisor::verdictReady, this,
                     [this, i](const QJsonObject &verdict) { onSlotVerdict(i, verdict); });
}

void BenchPool::recycleSlot(int i)
{
    Slot &s = m_slots[i];
    if (s.sup) {
        s.sup->disconnect(this);
        s.sup->deleteLater();
        s.sup = nullptr;
    }
    s = Slot{};
    ensureSlot(i);
}

QString BenchPool::cacheKeyForJob(const QJsonObject &job)
{
    const QJsonObject artifact = job.value(QStringLiteral("artifact")).toObject();
    const QString contentHash = artifact.value(QStringLiteral("contentHash")).toString();
    int benchVersion = job.value(QStringLiteral("benchVersion")).toInt(kBenchVersion);
    if (benchVersion <= 0)
        benchVersion = kBenchVersion;
    const QJsonObject budgets = job.value(QStringLiteral("budgets")).toObject();
    return BenchVerdictCache::makeKey(contentHash, benchVersion, budgets);
}

void BenchPool::submit(const QJsonObject &job)
{
    const QString jobId = job.value(QStringLiteral("jobId")).toString();
    const QString key = cacheKeyForJob(job);

    // 1) Cache (doc 12 §7) : un artefact déjà validé n'est pas re-testé.
    if (!key.isEmpty()) {
        QJsonObject cached;
        if (m_cache.tryGet(key, cached)) {
            // Re-corréler le verdict au job courant + marqueur de provenance.
            cached.insert(QStringLiteral("jobId"), jobId);
            QJsonObject metrics = cached.value(QStringLiteral("metrics")).toObject();
            metrics.insert(QStringLiteral("fromCache"), true);
            cached.insert(QStringLiteral("metrics"), metrics);
            emitDeferred(jobId, cached);
            return;
        }
    }

    // 2) File d'attente + distribution.
    m_queue.enqueue(job);
    dispatch();
}

void BenchPool::dispatch()
{
    for (int i = 0; i < m_slots.size() && !m_queue.isEmpty(); ++i) {
        Slot &s = m_slots[i];
        if (s.busy || !s.sup || s.sup->busy())
            continue;
        const QJsonObject job = m_queue.dequeue();
        s.busy = true;
        s.jobId = job.value(QStringLiteral("jobId")).toString();
        s.cacheKey = cacheKeyForJob(job);
        s.sup->runJob(job);
    }
}

void BenchPool::onSlotVerdict(int i, const QJsonObject &verdict)
{
    if (i < 0 || i >= m_slots.size())
        return;
    Slot &s = m_slots[i];

    const QString jobId = s.jobId;
    const QString key = s.cacheKey;

    // 1) Cache : ne fige QUE les verdicts déterministes (pass / fail non
    //    retryable) — jamais un timeout/crash environnemental (doc 12 §6-7).
    if (!key.isEmpty() && BenchVerdictCache::isCacheable(verdict))
        m_cache.put(key, verdict);

    // 2) Comptabilité de recyclage (doc 12 §6).
    s.jobsSinceSpawn += 1;
    const bool passed = (verdict.value(QStringLiteral("verdict")).toString()
                         == QLatin1String("pass"));
    const bool recycleForHygiene = !passed;                       // fail/timeout
    const bool recycleForQuota = (s.jobsSinceSpawn >= m_jobsPerProcess);

    // 3) Publier le verdict (avant recyclage : le slot peut être recréé).
    s.busy = false;
    s.jobId.clear();
    s.cacheKey.clear();
    emit verdictReady(jobId, verdict);

    if (recycleForHygiene || recycleForQuota)
        recycleSlot(i);

    // 4) Servir la file d'attente.
    dispatch();
}

void BenchPool::emitDeferred(const QString &jobId, const QJsonObject &verdict)
{
    // Préserve le contrat asynchrone même sur hit cache : l'appelant reçoit
    // toujours le verdict après le retour de submit(), jamais réentrant.
    QMetaObject::invokeMethod(
        this,
        [this, jobId, verdict]() { emit verdictReady(jobId, verdict); },
        Qt::QueuedConnection);
}

} // namespace meow::bench
