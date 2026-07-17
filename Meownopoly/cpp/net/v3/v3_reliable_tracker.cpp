#include "v3_reliable_tracker.h"

#include <algorithm>

qint64 V3ReliableTracker::retryDelayMs(double rttMs, int sendCount)
{
    // Base adaptative : 2×RTT + marge de traitement. RTT nul/aberrant → borne
    // basse (démarrage de session, avant la première mesure).
    qint64 base = kRetryMinMs;
    if (rttMs > 0.0)
        base = static_cast<qint64>(rttMs * 2.0 + 50.0);
    base = std::clamp(base, kRetryMinMs, kRetryMaxMs);

    // Backoff exponentiel par tentative, borné (sendCount 1 → ×1, 2 → ×2…).
    const int shift = std::clamp(sendCount - 1, 0, 4); // ×16 max avant la borne
    return std::min(base << shift, kRetryMaxMs);
}

bool V3ReliableTracker::trackSend(const QString &playerId, const QString &messageId,
                                  const QByteArray &packet, quint16 seq,
                                  qint64 nowMs, double rttMs)
{
    PlayerState &state = m_players[playerId];
    if (state.pending.size() >= kMaxPendingPerPlayer)
        return false; // file pleine — échec immédiat remonté par l'appelant
    if (state.pending.contains(messageId))
        return false; // double soumission du même messageId

    V3PendingSend entry;
    entry.playerId    = playerId;
    entry.messageId   = messageId;
    entry.packet      = packet;
    entry.seq         = seq;
    entry.sendCount   = 1;
    entry.firstSentMs = nowMs;
    entry.nextRetryMs = nowMs + retryDelayMs(rttMs, 1);

    state.pending.insert(messageId, entry);
    state.seqToMessage.insert(seq, messageId);
    return true;
}

QStringList V3ReliableTracker::confirmAcks(const QString &playerId,
                                           const quint16 *acks, int numAcks)
{
    QStringList confirmed;
    auto it = m_players.find(playerId);
    if (it == m_players.end() || !acks || numAcks <= 0)
        return confirmed;

    PlayerState &state = it.value();
    for (int i = 0; i < numAcks; ++i) {
        const QString messageId = state.seqToMessage.take(acks[i]);
        if (messageId.isEmpty())
            continue; // séquence non suivie (keepalive, trafic V2, seq obsolète)
        if (state.pending.remove(messageId) > 0)
            confirmed.append(messageId);
    }
    return confirmed;
}

QList<V3PendingSend *> V3ReliableTracker::collectDue(const QString &playerId, qint64 nowMs,
                                                     QList<V3PendingSend> &outFailed)
{
    QList<V3PendingSend *> due;
    auto it = m_players.find(playerId);
    if (it == m_players.end())
        return due;

    PlayerState &state = it.value();

    // 1er passage : repérer les épuisés (mutation interdite pendant l'itération).
    QStringList exhausted;
    for (auto pit = state.pending.begin(); pit != state.pending.end(); ++pit) {
        V3PendingSend &entry = pit.value();
        if (nowMs < entry.nextRetryMs)
            continue;
        if (entry.sendCount >= kMaxSendAttempts)
            exhausted.append(entry.messageId);
        else
            due.append(&entry);
    }
    // 2e passage : extraire les épuisés (les pointeurs de `due` restent valides,
    // QHash ne réalloue pas ses nœuds sur remove).
    for (const QString &messageId : exhausted) {
        const V3PendingSend failed = state.pending.take(messageId);
        state.seqToMessage.remove(failed.seq);
        outFailed.append(failed);
    }
    return due;
}

void V3ReliableTracker::markResent(V3PendingSend *entry, quint16 newSeq,
                                   qint64 nowMs, double rttMs)
{
    if (!entry)
        return;
    auto it = m_players.find(entry->playerId);
    if (it != m_players.end()) {
        PlayerState &state = it.value();
        // Désindexer l'ancienne séquence : un ACK tardif de l'envoi précédent
        // ne doit plus pointer vers ce message (la nouvelle séquence prend le
        // relais ; si l'ancien paquet arrive quand même, le récepteur dédup).
        if (state.seqToMessage.value(entry->seq) == entry->messageId)
            state.seqToMessage.remove(entry->seq);
        state.seqToMessage.insert(newSeq, entry->messageId);
    }
    entry->seq = newSeq;
    entry->sendCount += 1;
    entry->nextRetryMs = nowMs + retryDelayMs(rttMs, entry->sendCount);
}

bool V3ReliableTracker::removePending(const QString &playerId, const QString &messageId)
{
    auto it = m_players.find(playerId);
    if (it == m_players.end())
        return false;
    PlayerState &state = it.value();
    const V3PendingSend removed = state.pending.take(messageId);
    if (removed.messageId.isEmpty())
        return false;
    if (state.seqToMessage.value(removed.seq) == messageId)
        state.seqToMessage.remove(removed.seq);
    return true;
}

bool V3ReliableTracker::registerIncoming(const QString &playerId, const QString &messageId)
{
    if (messageId.isEmpty())
        return true; // pas de clé → pas de dédup possible, livrer
    PlayerState &state = m_players[playerId];
    if (state.seenIncoming.contains(messageId))
        return false; // doublon (retransmission déjà livrée)

    state.seenIncoming.insert(messageId);
    state.seenOrder.append(messageId);
    while (state.seenOrder.size() > kDedupMemoryPerPlayer)
        state.seenIncoming.remove(state.seenOrder.takeFirst());
    return true;
}

QList<V3PendingSend> V3ReliableTracker::dropPlayer(const QString &playerId)
{
    QList<V3PendingSend> orphans;
    auto it = m_players.find(playerId);
    if (it == m_players.end())
        return orphans;
    orphans = it.value().pending.values();
    m_players.erase(it);
    return orphans;
}

QStringList V3ReliableTracker::playersWithPending() const
{
    QStringList ids;
    for (auto it = m_players.constBegin(); it != m_players.constEnd(); ++it) {
        if (!it.value().pending.isEmpty())
            ids.append(it.key());
    }
    return ids;
}

int V3ReliableTracker::pendingCount(const QString &playerId) const
{
    auto it = m_players.constFind(playerId);
    return it == m_players.constEnd() ? 0 : it.value().pending.size();
}
