#include "v3_chunk_transfer.h"

#include <QCryptographicHash>
#include <QJsonArray>
#include <QUuid>

// ── Utilitaire de hash ───────────────────────────────────────────────────────

QString V3ChunkHash::of(const QByteArray &bytes)
{
    const QByteArray digest = QCryptographicHash::hash(bytes, QCryptographicHash::Sha256);
    return QStringLiteral("sha256:") + QString::fromLatin1(digest.toHex());
}

// ── V3ChunkDataFrame ─────────────────────────────────────────────────────────

QJsonObject V3ChunkDataFrame::toJson() const
{
    QJsonObject obj;
    obj.insert(QStringLiteral("transferId"), transferId);
    obj.insert(QStringLiteral("chunkIndex"), chunkIndex);
    obj.insert(QStringLiteral("chunkCount"), chunkCount);
    obj.insert(QStringLiteral("fullHash"), fullHash);
    obj.insert(QStringLiteral("chunkHash"), chunkHash);
    // Base64 : survit au transport texte JSON (comme l'ancien OpChunk).
    obj.insert(QStringLiteral("fragment"),
               QString::fromLatin1(fragment.toBase64()));
    return obj;
}

bool V3ChunkDataFrame::fromJson(const QJsonObject &obj, V3ChunkDataFrame &out)
{
    const QJsonValue vId    = obj.value(QStringLiteral("transferId"));
    const QJsonValue vIndex = obj.value(QStringLiteral("chunkIndex"));
    const QJsonValue vCount = obj.value(QStringLiteral("chunkCount"));
    const QJsonValue vFull  = obj.value(QStringLiteral("fullHash"));
    const QJsonValue vChunk = obj.value(QStringLiteral("chunkHash"));
    const QJsonValue vFrag  = obj.value(QStringLiteral("fragment"));

    if (!vId.isString() || !vIndex.isDouble() || !vCount.isDouble()
        || !vFull.isString() || !vChunk.isString() || !vFrag.isString()) {
        return false;
    }

    out.transferId = vId.toString();
    out.chunkIndex = vIndex.toInt(-1);
    out.chunkCount = vCount.toInt(0);
    out.fullHash   = vFull.toString();
    out.chunkHash  = vChunk.toString();
    out.fragment   = QByteArray::fromBase64(vFrag.toString().toLatin1());
    return true;
}

bool V3ChunkDataFrame::isStructurallyValid() const
{
    return !transferId.isEmpty()
           && chunkCount > 0
           && chunkIndex >= 0
           && chunkIndex < chunkCount
           && !fullHash.isEmpty()
           && !chunkHash.isEmpty();
}

// ── V3ChunkRequestFrame ──────────────────────────────────────────────────────

QJsonObject V3ChunkRequestFrame::toJson() const
{
    QJsonArray arr;
    for (int i : missing) arr.append(i);
    QJsonObject obj;
    obj.insert(QStringLiteral("transferId"), transferId);
    obj.insert(QStringLiteral("missing"), arr);
    return obj;
}

bool V3ChunkRequestFrame::fromJson(const QJsonObject &obj, V3ChunkRequestFrame &out)
{
    const QJsonValue vId = obj.value(QStringLiteral("transferId"));
    const QJsonValue vMissing = obj.value(QStringLiteral("missing"));
    if (!vId.isString() || !vMissing.isArray()) return false;
    out.transferId = vId.toString();
    out.missing.clear();
    const QJsonArray arr = vMissing.toArray();
    for (const QJsonValue &v : arr) {
        if (!v.isDouble()) return false;
        out.missing.append(v.toInt());
    }
    return true;
}

// ── V3ChunkSender ────────────────────────────────────────────────────────────

QString V3ChunkSender::begin(const QByteArray &payload, int capacityBytes, qint64 nowMs)
{
    if (payload.isEmpty() || capacityBytes <= 0) return QString();

    const QString transferId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString fullHash = V3ChunkHash::of(payload);
    const int count = (payload.size() + capacityBytes - 1) / capacityBytes;

    SendState st;
    st.lastActivityMs = nowMs;
    st.frames.reserve(count);
    for (int i = 0; i < count; ++i) {
        V3ChunkDataFrame f;
        f.transferId = transferId;
        f.chunkIndex = i;
        f.chunkCount = count;
        f.fullHash   = fullHash;
        f.fragment   = payload.mid(i * capacityBytes, capacityBytes);
        f.chunkHash  = V3ChunkHash::of(f.fragment);
        st.frames.append(f);
    }
    m_transfers.insert(transferId, st);
    return transferId;
}

QList<V3ChunkDataFrame> V3ChunkSender::allFrames(const QString &transferId) const
{
    auto it = m_transfers.constFind(transferId);
    if (it == m_transfers.constEnd()) return {};
    return it->frames;
}

QList<V3ChunkDataFrame> V3ChunkSender::framesFor(const QString &transferId,
                                                 const QList<int> &indices, qint64 nowMs)
{
    auto it = m_transfers.find(transferId);
    if (it == m_transfers.end()) return {};
    it->lastActivityMs = nowMs;

    QList<V3ChunkDataFrame> out;
    const int count = it->frames.size();
    for (int idx : indices) {
        if (idx >= 0 && idx < count) out.append(it->frames.at(idx));
    }
    return out;
}

QList<V3ChunkDataFrame> V3ChunkSender::serveRequest(const V3ChunkRequestFrame &req, qint64 nowMs)
{
    return framesFor(req.transferId, req.missing, nowMs);
}

bool V3ChunkSender::has(const QString &transferId) const
{
    return m_transfers.contains(transferId);
}

int V3ChunkSender::chunkCount(const QString &transferId) const
{
    auto it = m_transfers.constFind(transferId);
    if (it == m_transfers.constEnd()) return 0;
    return it->frames.size();
}

bool V3ChunkSender::complete(const QString &transferId)
{
    return m_transfers.remove(transferId) > 0;
}

QStringList V3ChunkSender::staleTransfers(qint64 nowMs, qint64 timeoutMs) const
{
    QStringList out;
    for (auto it = m_transfers.constBegin(); it != m_transfers.constEnd(); ++it) {
        if (nowMs - it->lastActivityMs > timeoutMs) out.append(it.key());
    }
    return out;
}

// ── V3ChunkReceiver ──────────────────────────────────────────────────────────

V3ChunkAccept V3ChunkReceiver::accept(const V3ChunkDataFrame &frame, qint64 nowMs,
                                      QByteArray &outPayload)
{
    if (!frame.isStructurallyValid()) return V3ChunkAccept::Invalid;

    // Intégrité locale du fragment : une corruption qui a survécu au décodage
    // JSON est attrapée ici → le fragment reste « manquant » et sera re-demandé.
    if (V3ChunkHash::of(frame.fragment) != frame.chunkHash) {
        // On garde/instaure quand même l'entrée pour que missing() reste correct,
        // mais on ne marque PAS ce fragment reçu.
        RecvState &stCorrupt = m_transfers[frame.transferId];
        if (stCorrupt.chunkCount == 0) {
            stCorrupt.chunkCount = frame.chunkCount;
            stCorrupt.fullHash   = frame.fullHash;
            stCorrupt.received   = QBitArray(frame.chunkCount, false);
            stCorrupt.fragments.resize(frame.chunkCount);
        }
        stCorrupt.lastActivityMs = nowMs;
        return V3ChunkAccept::Corrupt;
    }

    RecvState &st = m_transfers[frame.transferId];
    if (st.chunkCount == 0) {
        // Premier fragment de ce transfert : initialise le bitmap.
        st.chunkCount = frame.chunkCount;
        st.fullHash   = frame.fullHash;
        st.received   = QBitArray(frame.chunkCount, false);
        st.fragments.resize(frame.chunkCount);
    } else if (st.chunkCount != frame.chunkCount || st.fullHash != frame.fullHash) {
        // Frame appartenant à une AUTRE version du contenu (métadonnées
        // incohérentes) : refusé sans polluer le réassemblage en cours.
        return V3ChunkAccept::Invalid;
    }

    st.lastActivityMs = nowMs;

    if (st.received.testBit(frame.chunkIndex)) {
        return V3ChunkAccept::Duplicate;
    }

    st.received.setBit(frame.chunkIndex);
    st.fragments[frame.chunkIndex] = frame.fragment;
    ++st.haveCount;

    if (st.haveCount < st.chunkCount) {
        return V3ChunkAccept::InProgress;
    }

    // Tous les fragments présents : reconstitution + checksum final.
    QByteArray full;
    for (const QByteArray &frag : st.fragments) full.append(frag);

    if (V3ChunkHash::of(full) != st.fullHash) {
        // Corruption non attrapée au grain fragment (collision improbable, ou
        // fullHash lui-même corrompu) : on purge le bitmap pour re-demander le
        // transfert entier plutôt que de livrer un payload faux.
        st.received.fill(false);
        st.fragments = QList<QByteArray>(st.chunkCount);
        st.haveCount = 0;
        return V3ChunkAccept::ChecksumMismatch;
    }

    outPayload = full;
    m_transfers.remove(frame.transferId);
    return V3ChunkAccept::Complete;
}

QList<int> V3ChunkReceiver::missing(const QString &transferId) const
{
    auto it = m_transfers.constFind(transferId);
    if (it == m_transfers.constEnd()) return {};
    QList<int> out;
    for (int i = 0; i < it->chunkCount; ++i) {
        if (!it->received.testBit(i)) out.append(i);
    }
    return out;
}

V3ChunkRequestFrame V3ChunkReceiver::buildRequest(const QString &transferId,
                                                  bool &requested) const
{
    V3ChunkRequestFrame req;
    req.transferId = transferId;
    req.missing = missing(transferId);
    requested = !req.missing.isEmpty();
    return req;
}

bool V3ChunkReceiver::has(const QString &transferId) const
{
    return m_transfers.contains(transferId);
}

int V3ChunkReceiver::receivedCount(const QString &transferId) const
{
    auto it = m_transfers.constFind(transferId);
    return it == m_transfers.constEnd() ? 0 : it->haveCount;
}

int V3ChunkReceiver::expectedCount(const QString &transferId) const
{
    auto it = m_transfers.constFind(transferId);
    return it == m_transfers.constEnd() ? 0 : it->chunkCount;
}

bool V3ChunkReceiver::drop(const QString &transferId)
{
    return m_transfers.remove(transferId) > 0;
}

QStringList V3ChunkReceiver::staleTransfers(qint64 nowMs, qint64 timeoutMs) const
{
    QStringList out;
    for (auto it = m_transfers.constBegin(); it != m_transfers.constEnd(); ++it) {
        if (nowMs - it->lastActivityMs > timeoutMs) out.append(it.key());
    }
    return out;
}
