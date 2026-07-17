// ============================================================================
// BenchVerdictCache — implémentation (doc 12 §7, tâche A8)
// ============================================================================

#include "bench_verdict_cache.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonArray>

namespace meow::bench {

QString BenchVerdictCache::hashBudgets(const QJsonObject &budgets)
{
    // QJsonObject sérialise ses clés triées → forme canonique stable. On hache
    // la même métrique que le transport (JSON compact UTF-8).
    const QByteArray canonical =
        QJsonDocument(budgets).toJson(QJsonDocument::Compact);
    return QString::fromLatin1(
        QCryptographicHash::hash(canonical, QCryptographicHash::Sha256).toHex());
}

QString BenchVerdictCache::makeKey(const QString &contentHash, int benchVersion,
                                   const QJsonObject &budgets)
{
    if (contentHash.isEmpty())
        return QString(); // pas d'empreinte → non cachable

    // contentHash + benchVersion + hash(budgets), re-condensé pour une clé de
    // taille fixe (doc 12 §7). Les séparateurs '|' évitent toute collision par
    // concaténation ambiguë.
    const QByteArray composed = contentHash.toUtf8()
                                + '|' + QByteArray::number(benchVersion)
                                + '|' + hashBudgets(budgets).toUtf8();
    return QString::fromLatin1(
        QCryptographicHash::hash(composed, QCryptographicHash::Sha256).toHex());
}

bool BenchVerdictCache::isCacheable(const QJsonObject &verdict)
{
    if (verdict.isEmpty())
        return false;
    // Un pass est toujours déterministe.
    if (verdict.value(QStringLiteral("verdict")).toString() == QLatin1String("pass"))
        return true;
    // Un fail n'est cachable que si AUCUN de ses échecs n'est retryable
    // (environnemental : timeout, crash, warm-up impossible…).
    const QJsonArray failures = verdict.value(QStringLiteral("failures")).toArray();
    for (const QJsonValue &fv : failures) {
        if (fv.toObject().value(QStringLiteral("retryable")).toBool(false))
            return false;
    }
    return true;
}

bool BenchVerdictCache::tryGet(const QString &key, QJsonObject &verdict) const
{
    if (key.isEmpty())
        return false;
    const auto it = m_entries.constFind(key);
    if (it == m_entries.constEnd())
        return false;
    verdict = it.value();
    return true;
}

void BenchVerdictCache::put(const QString &key, const QJsonObject &verdict)
{
    if (key.isEmpty())
        return;
    if (!m_entries.contains(key))
        m_fifo.enqueue(key);
    m_entries.insert(key, verdict);

    // Éviction FIFO au-delà du plafond.
    while (m_entries.size() > MEOW_BENCH_CACHE_MAX && !m_fifo.isEmpty()) {
        const QString oldest = m_fifo.dequeue();
        // Une clé ré-insérée entre-temps peut apparaître deux fois dans la file :
        // on ne supprime que si elle n'a pas été ré-enfilée plus récemment.
        if (!m_fifo.contains(oldest))
            m_entries.remove(oldest);
    }
}

void BenchVerdictCache::clear()
{
    m_entries.clear();
    m_fifo.clear();
}

} // namespace meow::bench
