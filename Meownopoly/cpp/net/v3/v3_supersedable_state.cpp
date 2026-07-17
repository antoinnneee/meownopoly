#include "v3_supersedable_state.h"

#include <algorithm>

V3SupersedeVerdict V3SupersedableState::evaluate(const QString &key, quint64 seq) const
{
    const quint64 last = m_keySeq.value(key, 0);
    if (seq > last)
        return V3SupersedeVerdict::Applied;
    if (seq == last)
        return V3SupersedeVerdict::Duplicate;
    return V3SupersedeVerdict::Stale;
}

V3SupersedeVerdict V3SupersedableState::offer(const QString &key, quint64 seq)
{
    const V3SupersedeVerdict verdict = evaluate(key, seq);
    if (verdict == V3SupersedeVerdict::Applied)
        m_keySeq.insert(key, seq);
    return verdict;
}

quint64 V3SupersedableState::lastSeq(const QString &key) const
{
    return m_keySeq.value(key, 0);
}

bool V3SupersedableState::hasKey(const QString &key) const
{
    return m_keySeq.contains(key);
}

quint64 V3SupersedableState::nextSeq(const QString &key)
{
    // Monotonie stricte : on repart de la dernière séquence connue de la clé
    // (qui a pu être relevée par un snapshot de réparation) et on incrémente.
    const quint64 next = m_keySeq.value(key, 0) + 1;
    m_keySeq.insert(key, next);
    return next;
}

bool V3SupersedableState::applySnapshot(const V3StateSnapshot &snapshot)
{
    // Ordonnancement des snapshots : un snapshot rejoué ou obsolète (séquence
    // non strictement supérieure au dernier appliqué) est ignoré.
    if (snapshot.snapshotSeq <= m_snapshotSeq)
        return false;

    // Fusion par maximum : le snapshot comble les deltas perdus sans jamais
    // régresser une clé pour laquelle un delta plus récent est déjà arrivé.
    for (auto it = snapshot.keySeqs.constBegin(); it != snapshot.keySeqs.constEnd(); ++it) {
        quint64 &cur = m_keySeq[it.key()];
        cur = std::max(cur, it.value());
    }

    m_snapshotSeq = snapshot.snapshotSeq;
    return true;
}

V3StateSnapshot V3SupersedableState::captureSnapshot(quint64 snapshotSeq) const
{
    V3StateSnapshot snap;
    snap.snapshotSeq = snapshotSeq;
    snap.keySeqs = m_keySeq;
    return snap;
}

bool V3SupersedableState::dropKey(const QString &key)
{
    return m_keySeq.remove(key) > 0;
}

int V3SupersedableState::dropKeysWithPrefix(const QString &prefix)
{
    int removed = 0;
    for (auto it = m_keySeq.begin(); it != m_keySeq.end();) {
        if (it.key().startsWith(prefix)) {
            it = m_keySeq.erase(it);
            ++removed;
        } else {
            ++it;
        }
    }
    return removed;
}

void V3SupersedableState::clear()
{
    m_keySeq.clear();
    m_snapshotSeq = 0;
}

QStringList V3SupersedableState::keys() const
{
    return m_keySeq.keys();
}
