#ifndef MEOW_BENCH_VERDICT_CACHE_H
#define MEOW_BENCH_VERDICT_CACHE_H

// ============================================================================
// BenchVerdictCache — cache de verdicts du banc d'essai (doc 12 §7, tâche A8)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md §7.
//
// « Un artefact déjà validé (même source, même banc, mêmes budgets) n'est pas
// re-testé. » C'est le mécanisme de revalidation à coût nul au chargement
// (doc 04 §3.5) et chez les pairs (D16).
//
// CLÉ : `contentHash(artifact) + benchVersion + hash(budgets)`.
//   - `contentHash` : empreinte de la SOURCE de l'artefact (fournie par
//     l'enveloppe de proposition, doc 13) ;
//   - `benchVersion` : un bump invalide tout le cache (évolution des règles) ;
//   - `hash(budgets)` : les budgets D34 font partie de l'identité du verdict
//     (mêmes règles de mesure).
// Le **snapshot ne fait PAS partie de la clé** (doc 12 §7) : le verdict porte
// sur le comportement intrinsèque de l'artefact (chargement, budgets, fuites),
// pas sur une carte précise — l'adéquation à la partie est jugée par l'arbitre.
//
// MVP : cache mémoire par process (QHash), plafonné, éviction FIFO. La
// persistance disque (revalidation inter-sessions) est une évolution ultérieure
// non requise par R1. Ne dépend que de Qt6::Core — aucun réseau.
// ============================================================================

#include <QString>
#include <QJsonObject>
#include <QHash>
#include <QQueue>

// Plafond d'entrées en mémoire (pattern D22). Au-delà : éviction FIFO.
#ifndef MEOW_BENCH_CACHE_MAX
#define MEOW_BENCH_CACHE_MAX 512
#endif

namespace meow::bench {

class BenchVerdictCache
{
public:
    BenchVerdictCache() = default;

    // Construit la clé de cache (doc 12 §7). `contentHash` vide ⇒ QString vide
    // renvoyée : un artefact sans empreinte n'est jamais mis en cache (l'appelant
    // teste `key.isEmpty()`).
    static QString makeKey(const QString &contentHash, int benchVersion,
                           const QJsonObject &budgets);

    // Empreinte canonique et stable des budgets (clés triées par QJsonObject,
    // JSON compact) — deux jeux de budgets équivalents produisent la même clé.
    static QString hashBudgets(const QJsonObject &budgets);

    // Cherche un verdict en cache. Retourne true et renseigne `verdict` sur hit.
    bool tryGet(const QString &key, QJsonObject &verdict) const;

    // Insère/rafraîchit un verdict. No-op si `key` est vide. Évince en FIFO
    // au-delà de MEOW_BENCH_CACHE_MAX.
    void put(const QString &key, const QJsonObject &verdict);

    // Politique de mise en cache (doc 12 §7 + §6 hygiène) : on ne cache QUE les
    // verdicts DÉTERMINISTES — un `pass`, ou un `fail` dont AUCUN échec n'est
    // `retryable`. Les verdicts synthétiques d'environnement (`bench_timeout`,
    // `crash`, warm-up impossible…) sont marqués retryable et ne doivent jamais
    // figer un artefact.
    static bool isCacheable(const QJsonObject &verdict);

    void clear();
    int size() const { return m_entries.size(); }

private:
    QHash<QString, QJsonObject> m_entries;
    QQueue<QString>             m_fifo;   // ordre d'insertion pour l'éviction
};

} // namespace meow::bench

#endif // MEOW_BENCH_VERDICT_CACHE_H
