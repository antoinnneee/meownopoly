#include "proposal_session.h"

#include "communication/catway.h"
#include "communication/player_network.h"
#include "net/v3/v3_envelope.h"
#include "net/v3/v3_protocol.h"
#include "net/v3/v3_message_type.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonDocument>
#include <QUuid>

ProposalSession *ProposalSession::m_pThis = nullptr;

// ── Singleton ───────────────────────────────────────────────────────────────

ProposalSession::ProposalSession(QObject *parent) : QObject(parent) {}

ProposalSession *ProposalSession::instance()
{
    if (!m_pThis)
        m_pThis = new ProposalSession();
    return m_pThis;
}

QObject *ProposalSession::qmlInstance(QQmlEngine * /*engine*/, QJSEngine * /*scriptEngine*/)
{
    return instance();
}

void ProposalSession::registerQml()
{
    qmlRegisterSingletonType<ProposalSession>("ProposalSession", 1, 0, "ProposalSession",
                                              &ProposalSession::qmlInstance);
}

// ── Helpers locaux ──────────────────────────────────────────────────────────

namespace {
// États terminaux (doc 13 §2 / proposal_types) : à leur réception, l'hôte
// libère la garde de flux unique. Chaînes stables (voir proposalStateName).
bool isTerminalStateName(const QString &s)
{
    return s == QLatin1String("applied")
        || s == QLatin1String("rejected_mechanical")
        || s == QLatin1String("rejected_arbiter")
        || s == QLatin1String("rejected_bench")
        || s == QLatin1String("failed");
}

// Lit un proposalId dans une enveloppe JSON ; en génère un frais si absent
// (l'auteur peut l'omettre — l'hôte fait foi sur l'identité).
QString readOrMakeProposalId(QJsonObject &envelope)
{
    QString pid = envelope.value(QStringLiteral("proposalId")).toString();
    if (pid.isEmpty()) {
        pid = QUuid::createUuid().toString(QUuid::WithoutBraces);
        envelope.insert(QStringLiteral("proposalId"), pid);
    }
    return pid;
}
} // namespace

// ── Cycle de vie ────────────────────────────────────────────────────────────

bool ProposalSession::startAsHost(const QString &localPlayerId, const QString &sessionId)
{
    // Aucune règle d'exclusivité : la plage V3 0x60+ est disjointe de
    // Game/Editor/Physics, ProposalSession coexiste avec elles (D40).
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = QString{};
    m_sessionId     = sessionId.isEmpty()
                          ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                          : sessionId;
    m_isHost        = true;
    m_active        = true;

    connectToCatway();

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit sessionIdChanged();
    emit isHostChanged();
    emit activeChanged();

    qDebug() << "[ProposalSession] Started as HOST, playerId =" << localPlayerId
             << "session =" << m_sessionId;
    return true;
}

bool ProposalSession::startAsClient(const QString &localPlayerId,
                                    const QString &hostPlayerId,
                                    const QString &sessionId)
{
    if (hostPlayerId.isEmpty()) {
        qWarning() << "[ProposalSession] startAsClient: hostPlayerId vide.";
        return false;
    }
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = hostPlayerId;
    m_sessionId     = sessionId;
    m_isHost        = false;
    m_active        = true;

    connectToCatway();

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit sessionIdChanged();
    emit isHostChanged();
    emit activeChanged();

    qDebug() << "[ProposalSession] Started as CLIENT, playerId =" << localPlayerId
             << "host =" << hostPlayerId << "session =" << sessionId;
    return true;
}

void ProposalSession::stop()
{
    disconnectFromCatway();

    m_active  = false;
    m_isHost  = false;
    m_localPlayerId.clear();
    m_hostPlayerId.clear();
    m_sessionId.clear();
    m_outSeq  = 0;

    m_inflight.clear();
    m_authorByProposal.clear();
    m_seenProposals.clear();
    m_transferProposal.clear();

    const bool hadPending = !m_inbound.isEmpty();
    m_inbound.clear();
    if (m_processing) {
        m_processing = false;
        m_currentProposalId.clear();
        emit busyChanged();
    }
    if (hadPending) emit pendingCountChanged();

    emit activeChanged();
    emit isHostChanged();
    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit sessionIdChanged();

    qDebug() << "[ProposalSession] Stopped.";
}

// ── Connexion Catway ────────────────────────────────────────────────────────

void ProposalSession::connectToCatway()
{
    Catway *catway = Catway::instance();
    m_reliableConn = connect(catway, &Catway::reliableMessageReceived,
                             this,   &ProposalSession::onReliableReceived);
    m_ackConn      = connect(catway, &Catway::v3MessageAcked,
                             this,   &ProposalSession::onV3MessageAcked);
    m_failConn     = connect(catway, &Catway::v3MessageFailed,
                             this,   &ProposalSession::onV3MessageFailed);
    m_timeoutConn  = connect(catway, &Catway::playerTimedOut,
                             this,   &ProposalSession::onPlayerTimedOut);
}

void ProposalSession::disconnectFromCatway()
{
    disconnect(m_reliableConn);
    disconnect(m_ackConn);
    disconnect(m_failConn);
    disconnect(m_timeoutConn);
}

// ── Envoi V3 point-à-point ──────────────────────────────────────────────────

void ProposalSession::sendEnvelopeTo(const QString &playerId, const QString &kind,
                                     const QJsonObject &payload, const QString &proposalId,
                                     const QString &correlationId)
{
    if (playerId.isEmpty()) {
        qWarning() << "[ProposalSession] sendEnvelopeTo: playerId vide, kind =" << kind;
        return;
    }
    const V3Envelope env = V3Envelope::create(m_sessionId, m_localPlayerId, kind,
                                              ++m_outSeq, payload, correlationId);
    const QByteArray packet = V3Protocol::pack(env);

    m_inflight.insert(env.messageId, { proposalId, kind });
    Catway::instance()->sendV3Reliable(playerId, packet, env.messageId);
}

// ── Auteur → hôte ───────────────────────────────────────────────────────────

QString ProposalSession::submitProposal(const QVariantMap &envelopeJson)
{
    if (!m_active) {
        qWarning() << "[ProposalSession] submitProposal: session inactive.";
        return {};
    }
    QJsonObject envelope = QJsonObject::fromVariantMap(envelopeJson);
    const QString proposalId = readOrMakeProposalId(envelope);

    if (m_isHost) {
        // Auto-soumission : la proposition entre directement dans le pipeline
        // local (l'hôte est aussi auteur). Pas de trajet réseau (D16 : jamais
        // de diffusion pair-à-pair d'une proposition).
        enqueueInbound(m_localPlayerId, proposalId, envelope);
        return proposalId;
    }

    sendSubmitToHost(proposalId, envelope);
    return proposalId;
}

void ProposalSession::sendSubmitToHost(const QString &proposalId, const QJsonObject &envelope)
{
    const QByteArray full = QJsonDocument(envelope).toJson(QJsonDocument::Compact);

    // Cas nominal : l'enveloppe tient dans un paquet → un seul `proposal.submit`.
    if (full.size() <= k_chunkThresholdBytes) {
        sendEnvelopeTo(m_hostPlayerId, QLatin1String(k_kindSubmit), envelope, proposalId);
        return;
    }

    // Enveloppe volumineuse (artefacts) → chunking réparable B4. Chaque fragment
    // voyage dans sa propre enveloppe V3 fiable (ACK/retry M3 par fragment) ; le
    // récepteur détecte et re-demande les manquants.
    const qint64 nowMs    = QDateTime::currentMSecsSinceEpoch();
    const int    capacity = k_chunkThresholdBytes - V3ChunkSender::kFrameOverheadBytes;
    const QString transferId = m_chunkSender.begin(full, capacity, nowMs);
    if (transferId.isEmpty()) {
        qWarning() << "[ProposalSession] chunking: begin() a échoué pour" << proposalId;
        emit proposalSendFailed(proposalId, QStringLiteral("chunk_begin_failed"));
        return;
    }
    m_transferProposal.insert(transferId, proposalId);

    const QList<V3ChunkDataFrame> frames = m_chunkSender.allFrames(transferId);
    qDebug().noquote() << "[ProposalSession] chunking proposal" << proposalId
                       << "size=" << full.size() << "→" << frames.size() << "fragments";
    for (const V3ChunkDataFrame &f : frames) {
        QJsonObject payload = f.toJson();
        payload.insert(QStringLiteral("origKind"), QLatin1String(k_kindSubmit));
        payload.insert(QStringLiteral("proposalId"), proposalId);
        sendEnvelopeTo(m_hostPlayerId, QLatin1String(k_kindChunkData), payload, proposalId);
    }
}

// ── Hôte → auteur ───────────────────────────────────────────────────────────

void ProposalSession::notifyState(const QString &proposalId, const QString &state,
                                  const QString &reason, const QString &code)
{
    if (!m_active || !m_isHost) return;

    QJsonObject payload{
        { QStringLiteral("proposalId"), proposalId },
        { QStringLiteral("state"),      state },
        { QStringLiteral("reason"),     reason },
        { QStringLiteral("code"),       code },
    };

    const QString author = m_authorByProposal.value(proposalId);
    if (author.isEmpty() || author == m_localPlayerId) {
        // Auteur = l'hôte lui-même (auto-soumission) : livraison locale directe.
        emit stateReceived(proposalId, state, reason, code);
    } else {
        sendEnvelopeTo(author, QLatin1String(k_kindState), payload, proposalId);
    }

    // Un état terminal libère la garde de flux unique et fait avancer la file.
    if (isTerminalStateName(state))
        endProcessing(proposalId);
}

void ProposalSession::notifyVerdict(const QString &proposalId, const QVariantMap &verdictJson)
{
    if (!m_active || !m_isHost) return;

    const QJsonObject verdict = QJsonObject::fromVariantMap(verdictJson);
    QJsonObject payload{
        { QStringLiteral("proposalId"), proposalId },
        { QStringLiteral("verdict"),    verdict },
    };

    const QString author = m_authorByProposal.value(proposalId);
    if (author.isEmpty() || author == m_localPlayerId) {
        emit verdictReceived(proposalId, verdict.toVariantMap());
    } else {
        sendEnvelopeTo(author, QLatin1String(k_kindVerdict), payload, proposalId);
    }
}

void ProposalSession::endProcessing(const QString &proposalId)
{
    if (!m_isHost) return;
    if (proposalId != m_currentProposalId) return; // idempotent / hors garde

    m_processing = false;
    m_currentProposalId.clear();
    emit busyChanged();
    pumpInbound();
}

// ── Garde de flux unique (hôte) ─────────────────────────────────────────────

void ProposalSession::enqueueInbound(const QString &authorId, const QString &proposalId,
                                     const QJsonObject &envelope)
{
    // Dédup grossière : ignore une proposition déjà vue (retransmission d'un
    // submit dont le messageId a changé mais le proposalId non, ou re-soumission
    // accidentelle). Une amendement légitime porte un nouveau proposalId.
    if (m_seenProposals.contains(proposalId)
        || proposalId == m_currentProposalId) {
        return;
    }
    for (const Inbound &in : m_inbound)
        if (in.proposalId == proposalId) return;

    m_authorByProposal.insert(proposalId, authorId);
    m_inbound.append({ authorId, proposalId, envelope });
    emit pendingCountChanged();
    pumpInbound();
}

void ProposalSession::pumpInbound()
{
    // Garde de flux unique : « une proposition en benching/applying à la fois ».
    if (m_processing || m_inbound.isEmpty()) return;

    const Inbound in = m_inbound.takeFirst();
    emit pendingCountChanged();

    m_processing = true;
    m_currentProposalId = in.proposalId;

    // Mémorise le proposalId comme vu (éviction FIFO bornée).
    m_seenProposals.append(in.proposalId);
    while (m_seenProposals.size() > k_seenMemory)
        m_seenProposals.removeFirst();

    emit busyChanged();
    emit proposalReceived(in.authorId, in.proposalId, in.envelope.toVariantMap());
}

// ── Réception ───────────────────────────────────────────────────────────────

void ProposalSession::onReliableReceived(const QString &senderId, const QByteArray &data)
{
    if (!m_active) return;
    if (!V3Protocol::isV3Packet(data)) return; // pas un paquet V3 → ignoré

    V3MessageType::Value type;
    V3Envelope env;
    if (!V3Protocol::unpack(data, type, env)) return; // forme invalide → ignoré

    // Cette session ne consomme QUE la famille "proposal.*" ; les autres
    // familles V3 (state.*, tx.*, session.*) partagent l'octet 0x60 mais un
    // autre `kind` et sont ignorées ici (démux par préfixe de kind).
    if (!env.kind.startsWith(QLatin1String("proposal.")))
        return;

    // Intégrité : le payloadHash doit correspondre (la couche transport garantit
    // la forme, pas la cohérence — cf. V3Protocol::unpack). Rejet silencieux d'un
    // payload corrompu (le chunking B4 gère la réparation pour les gros envois).
    if (!env.verifyPayloadHash()) {
        qWarning() << "[ProposalSession] payloadHash incohérent, kind =" << env.kind;
        return;
    }

    const QJsonObject &payload = env.payload;

    if (env.kind == QLatin1String(k_kindSubmit)) {
        if (!m_isHost) return; // D16 : seul l'hôte reçoit des propositions
        QJsonObject envelope = payload;
        const QString proposalId = readOrMakeProposalId(envelope);
        enqueueInbound(senderId, proposalId, envelope);
        return;
    }

    if (env.kind == QLatin1String(k_kindChunkData)) {
        if (!m_isHost) return;
        handleChunkData(senderId, payload);
        return;
    }

    if (env.kind == QLatin1String(k_kindChunkReq)) {
        handleChunkRequest(senderId, payload);
        return;
    }

    if (env.kind == QLatin1String(k_kindState)) {
        if (m_isHost) return; // l'état ne remonte que vers l'auteur
        emit stateReceived(payload.value(QStringLiteral("proposalId")).toString(),
                           payload.value(QStringLiteral("state")).toString(),
                           payload.value(QStringLiteral("reason")).toString(),
                           payload.value(QStringLiteral("code")).toString());
        return;
    }

    if (env.kind == QLatin1String(k_kindVerdict)) {
        if (m_isHost) return;
        emit verdictReceived(payload.value(QStringLiteral("proposalId")).toString(),
                             payload.value(QStringLiteral("verdict")).toObject().toVariantMap());
        return;
    }
}

void ProposalSession::handleChunkData(const QString &senderId, const QJsonObject &payload)
{
    V3ChunkDataFrame frame;
    if (!V3ChunkDataFrame::fromJson(payload, frame)) return;

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    QByteArray reassembled;
    const V3ChunkAccept result = m_chunkReceiver.accept(frame, nowMs, reassembled);

    switch (result) {
    case V3ChunkAccept::Complete: {
        // Payload complet reconstitué → dispatch comme un submit standard.
        const QJsonDocument doc = QJsonDocument::fromJson(reassembled);
        if (!doc.isObject()) {
            qWarning() << "[ProposalSession] transfert complet mais JSON invalide.";
            return;
        }
        if (m_isHost) {
            QJsonObject envelope = doc.object();
            const QString proposalId = readOrMakeProposalId(envelope);
            enqueueInbound(senderId, proposalId, envelope);
        }
        break;
    }
    case V3ChunkAccept::InProgress: {
        // Déclencheur de réparation : à la réception du DERNIER fragment alors
        // qu'il en manque encore, demander explicitement les manquants (B4).
        if (frame.chunkIndex == frame.chunkCount - 1) {
            bool requested = false;
            const V3ChunkRequestFrame req =
                m_chunkReceiver.buildRequest(frame.transferId, requested);
            if (requested) {
                QJsonObject reqPayload = req.toJson();
                reqPayload.insert(QStringLiteral("proposalId"),
                                  payload.value(QStringLiteral("proposalId")).toString());
                sendEnvelopeTo(senderId, QLatin1String(k_kindChunkReq), reqPayload,
                               payload.value(QStringLiteral("proposalId")).toString());
            }
        }
        break;
    }
    case V3ChunkAccept::ChecksumMismatch: {
        // Tous reçus mais checksum final faux : le transfert est rouvert côté
        // récepteur, re-demande complète.
        bool requested = false;
        const V3ChunkRequestFrame req =
            m_chunkReceiver.buildRequest(frame.transferId, requested);
        if (requested) {
            QJsonObject reqPayload = req.toJson();
            reqPayload.insert(QStringLiteral("proposalId"),
                              payload.value(QStringLiteral("proposalId")).toString());
            sendEnvelopeTo(senderId, QLatin1String(k_kindChunkReq), reqPayload,
                           payload.value(QStringLiteral("proposalId")).toString());
        }
        break;
    }
    case V3ChunkAccept::Duplicate:
    case V3ChunkAccept::Corrupt:
    case V3ChunkAccept::Invalid:
        // Corrupt/Invalid : le fragment reste « manquant », la réparation viendra
        // au prochain déclencheur. Duplicate : rien à faire.
        break;
    }
}

void ProposalSession::handleChunkRequest(const QString &senderId, const QJsonObject &payload)
{
    V3ChunkRequestFrame req;
    if (!V3ChunkRequestFrame::fromJson(payload, req)) return;

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const QList<V3ChunkDataFrame> frames = m_chunkSender.serveRequest(req, nowMs);
    const QString proposalId = payload.value(QStringLiteral("proposalId")).toString();
    for (const V3ChunkDataFrame &f : frames) {
        QJsonObject dataPayload = f.toJson();
        dataPayload.insert(QStringLiteral("origKind"), QLatin1String(k_kindSubmit));
        dataPayload.insert(QStringLiteral("proposalId"), proposalId);
        sendEnvelopeTo(senderId, QLatin1String(k_kindChunkData), dataPayload, proposalId);
    }
}

// ── Issues du transport fiable M3 ───────────────────────────────────────────

void ProposalSession::onV3MessageAcked(const QString & /*playerId*/, const QString &messageId)
{
    const auto it = m_inflight.constFind(messageId);
    if (it == m_inflight.constEnd()) return;
    const Inflight info = it.value();
    m_inflight.erase(it);

    // On confirme la LIVRAISON à l'auteur sur l'ACK d'un `proposal.submit` (envoi
    // en un paquet). Pour un transfert chunké, la complétion réelle est signalée
    // par l'hôte (stateReceived) — un ACK par fragment ne prouve pas le tout.
    if (info.kind == QLatin1String(k_kindSubmit))
        emit proposalDelivered(info.proposalId);
}

void ProposalSession::onV3MessageFailed(const QString & /*playerId*/, const QString &messageId,
                                        const QString &reason)
{
    const auto it = m_inflight.constFind(messageId);
    if (it == m_inflight.constEnd()) return;
    const Inflight info = it.value();
    m_inflight.erase(it);

    // Échec définitif d'un segment (submit OU fragment de chunk) : l'acheminement
    // de la proposition est rompu, le métier décide de re-soumettre. On ne
    // remonte l'échec que pour les segments qui portent une proposition sortante
    // (côté auteur) — pas pour les notifications hôte→auteur.
    if (info.kind == QLatin1String(k_kindSubmit)
        || info.kind == QLatin1String(k_kindChunkData)) {
        if (!m_isHost)
            emit proposalSendFailed(info.proposalId, reason);
    }
}

void ProposalSession::onPlayerTimedOut(const QString &playerId)
{
    if (!m_active) return;

    if (!m_isHost && playerId == m_hostPlayerId) {
        // L'hôte (destinataire unique des propositions) est tombé : tout envoi en
        // vol est perdu. La migration coordonnée (T4-3) rebranchera la session ;
        // ici on remonte l'échec des propositions sortantes non confirmées.
        QList<QString> failed;
        for (auto it = m_inflight.constBegin(); it != m_inflight.constEnd(); ++it) {
            const Inflight &info = it.value();
            if (info.kind == QLatin1String(k_kindSubmit)
                || info.kind == QLatin1String(k_kindChunkData)) {
                if (!failed.contains(info.proposalId))
                    failed.append(info.proposalId);
            }
        }
        m_inflight.clear();
        for (const QString &pid : failed)
            emit proposalSendFailed(pid, QStringLiteral("host_timed_out"));
        return;
    }

    if (m_isHost) {
        // Un auteur est tombé : purge des propositions en file qui lui
        // appartiennent (celle en cours reste pilotée par l'hôte jusqu'à son
        // état terminal — le pipeline local n'a pas besoin du pair).
        bool changed = false;
        for (int i = m_inbound.size() - 1; i >= 0; --i) {
            if (m_inbound.at(i).authorId == playerId) {
                m_authorByProposal.remove(m_inbound.at(i).proposalId);
                m_inbound.removeAt(i);
                changed = true;
            }
        }
        if (changed) emit pendingCountChanged();
    }
}
