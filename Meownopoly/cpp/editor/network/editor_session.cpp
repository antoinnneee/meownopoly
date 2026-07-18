#include "editor_session.h"
#include "editor_protocol.h"
#include "editor_message_type.h"

#include "communication/catway.h"
#include "communication/player_network.h"
#include "game/network/game_session.h"

// V3 T4-3 (D37) — checkpoint de migration + coordination des sessions V3.
#include "ai/ai_process_supervisor.h"
#include "ai/network/proposal_session.h"
#include "artifacts/artifact_registry.h"
#include "game/events/gameplay_event_bus.h"
#include "game/memory/state_bus.h"
#include "game/physics/physics_session.h"
#include "game/rules/rules_engine.h"

#include <QDebug>
#include <QStringList>
#include <QJsonArray>
#include <QJsonDocument>
#include <QUuid>

EditorSession *EditorSession::m_pThis = nullptr;

// ── Singleton ─────────────────────────────────────────────────────────────────

EditorSession::EditorSession(QObject *parent) : QObject(parent) {}

EditorSession *EditorSession::instance()
{
    if (!m_pThis)
        m_pThis = new EditorSession();
    return m_pThis;
}

QObject *EditorSession::qmlInstance(QQmlEngine * /*engine*/, QJSEngine * /*scriptEngine*/)
{
    return instance();
}

void EditorSession::registerQml()
{
    qmlRegisterSingletonType<EditorSession>("EditorSession", 1, 0, "EditorSession",
                                           &EditorSession::qmlInstance);
    qmlRegisterUncreatableMetaObject(EditorMessageType::staticMetaObject,
                                     "EditorSession", 1, 0,
                                     "EditorMessageType",
                                     "Error: only enums");
}

// ── Initialisation ─────────────────────────────────────────────────────────────

bool EditorSession::startAsHost(const QString &localPlayerId, const QString &sessionId)
{
    if (GameSession::instance()->active()) {
        qWarning() << "[EditorSession] Refus: GameSession active — exclusivité.";
        return false;
    }
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = QString{};
    m_sessionId     = sessionId;
    m_isHost        = true;
    m_active        = true;

    connectToCatway();

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit sessionIdChanged();
    emit isHostChanged();
    emit activeChanged();

    qDebug() << "[EditorSession] Started as HOST, playerId =" << localPlayerId
             << "session =" << sessionId;
    return true;
}

bool EditorSession::startAsClient(const QString &localPlayerId,
                                  const QString &hostPlayerId,
                                  const QString &sessionId)
{
    if (GameSession::instance()->active()) {
        qWarning() << "[EditorSession] Refus: GameSession active — exclusivité.";
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

    qDebug() << "[EditorSession] Started as CLIENT, playerId =" << localPlayerId
             << "host =" << hostPlayerId << "session =" << sessionId;
    return true;
}

void EditorSession::stop()
{
    disconnectFromCatway();
    m_active = false;
    m_isHost = false;
    m_localPlayerId.clear();
    m_hostPlayerId.clear();
    m_sessionId.clear();
    if (!m_remoteSelections.isEmpty()) {
        m_remoteSelections.clear();
        emit remoteSelectionsChanged();
    }
    if (!m_knownRoster.isEmpty()) {
        m_knownRoster.clear();
        emit knownRosterChanged();
    }

    emit activeChanged();
    emit isHostChanged();
    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit sessionIdChanged();

    qDebug() << "[EditorSession] Stopped.";
}

// ── Connexion Catway ──────────────────────────────────────────────────────────

void EditorSession::connectToCatway()
{
    Catway *catway = Catway::instance();
    m_reliableConn = connect(catway, &Catway::reliableMessageReceived,
                             this,   &EditorSession::onReliableReceived);
    m_udpConn      = connect(catway, &Catway::udpMessageReceived,
                             this,   &EditorSession::onUdpReceived);
    // détection de perte de pair.
    m_timeoutConn  = connect(catway, &Catway::playerTimedOut,
                             this,   &EditorSession::onPlayerTimedOut);
    if (!m_rateClock.isValid()) m_rateClock.start();
}

void EditorSession::disconnectFromCatway()
{
    disconnect(m_reliableConn);
    disconnect(m_udpConn);
    disconnect(m_timeoutConn);
    m_opBuckets.clear();
    m_chunkBuffers.clear();
    m_serverSeq = 0;
}

// ── Envoi ──────────────────────────────────────────────────────────────────────

void EditorSession::sendEvent(int type, const QJsonObject &payload)
{
    if (!m_active) return;
    const auto msgType = static_cast<EditorMessageType::Value>(type);
    if (m_isHost) {
        sendReliableOrChunked(QString{}, msgType, payload, /*broadcast=*/true);
    } else {
        sendReliableOrChunked(m_hostPlayerId, msgType, payload, /*broadcast=*/false);
    }
}

void EditorSession::broadcastEvent(int type, const QJsonObject &payload)
{
    if (!m_active || !m_isHost) {
        qWarning() << "[EditorSession] broadcastEvent called by non-host — ignoring.";
        return;
    }
    sendReliableOrChunked(QString{},
                          static_cast<EditorMessageType::Value>(type),
                          payload, /*broadcast=*/true);
}

void EditorSession::sendEventTo(const QString &playerId, int type, const QJsonObject &payload)
{
    if (!m_active) return;
    if (playerId.isEmpty()) {
        qWarning() << "[EditorSession] sendEventTo: empty playerId";
        return;
    }
    sendReliableOrChunked(playerId,
                          static_cast<EditorMessageType::Value>(type),
                          payload, /*broadcast=*/false);
}

// envoi reliable avec fallback chunké OpChunk si le paquet dépasse
// k_chunkThresholdBytes. Le chunking ne s'applique qu'aux messages d'éditeur
// dont la perte de framing peut être contournée (on n'entoure pas Hello).
void EditorSession::sendReliableOrChunked(const QString &playerId,
                                          EditorMessageType::Value type,
                                          const QJsonObject &payload,
                                          bool broadcast)
{
    Catway *catway = Catway::instance();
    const QByteArray packet = EditorProtocol::pack(type, payload);

    auto dispatch = [&](const QByteArray &bytes) {
        if (broadcast) {
            catway->broadcastReliable(bytes);
        } else {
            PlayerNetwork *p = catway->playerById(playerId);
            if (p) catway->sendReliableToPlayer(p, bytes);
            else   qWarning() << "[EditorSession] dispatch: player not found:" << playerId;
        }
    };

    if (packet.size() <= k_chunkThresholdBytes) {
        dispatch(packet);
        return;
    }

    // Chunking : on sérialise le payload original en JSON compact, on
    // fragmente en base64 pour survivre au transport texte, puis on envoie
    // N paquets OpChunk { opId, chunkIndex, chunkCount, origType, payloadB64 }.
    const QByteArray full = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    const QByteArray b64  = full.toBase64();
    const int capacity    = k_chunkThresholdBytes - 512; // marge header
    const int count       = (b64.size() + capacity - 1) / capacity;
    const QString opId    = QUuid::createUuid().toString(QUuid::WithoutBraces);

    qDebug().noquote() << "[EditorSession] chunking type" << Qt::hex << int(type)
                       << Qt::dec << "size=" << packet.size()
                       << "→" << count << "chunks (opId=" << opId << ")";

    for (int i = 0; i < count; ++i) {
        const QByteArray frag = b64.mid(i * capacity, capacity);
        QJsonObject chunkPayload{
            { "opId",       opId },
            { "chunkIndex", i },
            { "chunkCount", count },
            { "origType",   int(type) },
            { "payloadB64", QString::fromLatin1(frag) },
        };
        const QByteArray chunkPacket =
            EditorProtocol::pack(EditorMessageType::OpChunk, chunkPayload);
        dispatch(chunkPacket);
    }
}

// retourne true si l'op est autorisée, false si rate-limitée.
bool EditorSession::consumeOpToken(const QString &senderId)
{
    const qint64 nowMs = m_rateClock.isValid() ? m_rateClock.elapsed() : 0;
    TokenBucket &b = m_opBuckets[senderId];
    if (b.lastRefillMs == 0) {
        b.tokens = k_opBurst;
        b.lastRefillMs = nowMs;
    } else {
        const double dt = (nowMs - b.lastRefillMs) / 1000.0;
        b.tokens = qMin(k_opBurst, b.tokens + dt * k_opRatePerSec);
        b.lastRefillMs = nowMs;
    }
    if (b.tokens >= 1.0) {
        b.tokens -= 1.0;
        return true;
    }
    return false;
}

void EditorSession::sendOp(const QJsonObject &op)
{
    sendEvent(EditorMessageType::Op, op);
}

void EditorSession::broadcastOp(const QJsonObject &op)
{
    broadcastEvent(EditorMessageType::Op, op);
}

void EditorSession::sendCursor(qreal x, qreal y)
{
    if (!m_active) return;
    const QString msg = QStringLiteral("%1%2;%3;%4")
                            .arg(QLatin1String(k_cursorPrefix))
                            .arg(m_localPlayerId)
                            .arg(x, 0, 'f', 1)
                            .arg(y, 0, 'f', 1);
    Catway::instance()->broadcastRaw(msg);
}

// ── Relay host ────────────────────────────────────────────────────────────────

void EditorSession::relayReliableToOthers(const QString &senderId, const QByteArray &packet)
{
    if (!m_isHost) return;
    Catway *catway = Catway::instance();
    const int count = catway->playersCount();
    for (int i = 0; i < count; ++i) {
        PlayerNetwork *p = catway->playerAt(i);
        if (p && p->playerId() != senderId && p->isP2pConnected())
            catway->sendReliableToPlayer(p, packet);
    }
}

// ── Réception ─────────────────────────────────────────────────────────────────

void EditorSession::onReliableReceived(const QString &senderId, const QByteArray &data)
{
    EditorMessageType::Value type;
    QJsonObject payload;

    // Ne traiter que les paquets destinés à l'éditeur ; tout le reste
    // (GameSession, chat de test, etc.) est ignoré silencieusement.
    if (!EditorProtocol::unpack(data, type, payload))
        return;

    switch (type) {
    case EditorMessageType::Op: {
        QJsonObject opPayload = payload;
        // côté hôte, rate-limit par expéditeur et tag d'un _seq monotone
        // avant rebroadcast — les clients loggent le _seq pour corrélation.
        if (m_isHost) {
            if (!consumeOpToken(senderId)) {
                qWarning() << "[EditorSession] op rate-limited from" << senderId;
                emit opRateLimited(senderId, 1);
                QJsonObject rej{
                    { "reason", "rate_limited" },
                    { "op",     opPayload.value("op").toInt() },
                };
                sendEventTo(senderId, EditorMessageType::OpReject, rej);
                break;
            }
            opPayload.insert("_seq", double(++m_serverSeq));
            opPayload.insert("_by",  senderId);
        }
        qDebug().noquote() << "[EditorOps] recv seq="
                           << opPayload.value("_seq").toDouble(0)
                           << "from=" << senderId
                           << "type=" << opPayload.value("op").toInt();
        emit opReceived(senderId, opPayload);
        // Hôte : rebroadcast aux autres clients (l'auteur reçoit via son propre
        // chemin local ; voir note dans le plan sur le design apply-on-rebroadcast).
        if (m_isHost) {
            relayReliableToOthers(senderId, EditorProtocol::pack(type, opPayload));
        }
        break;
    }

    case EditorMessageType::OpChunk:
        handleOpChunk(senderId, payload);
        break;

    case EditorMessageType::Hello:
        // l'hôte agrège le roster à la volée. Le premier Hello
        // d'un client l'ajoute ; on rediffuse à tous pour que chacun puisse
        // élire un successeur déterministe en cas de perte de l'hôte.
        if (m_isHost && !senderId.isEmpty() && !m_knownRoster.contains(senderId)) {
            m_knownRoster.append(senderId);
            emit knownRosterChanged();
            broadcastRoster();
        }
        // V3 T4-3 (D37) : un survivant qui reconnecte APRÈS la reprise a raté
        // le broadcast MigrationCheckpointAck — le lui rejouer en point-à-point
        // pour qu'il lève sa suspension locale.
        if (m_isHost && m_wasMigrated && !m_proposalsSuspended && !senderId.isEmpty()) {
            sendEventTo(senderId, EditorMessageType::MigrationCheckpointAck,
                        QJsonObject{{ "sessionId", m_sessionId }});
        }
        emit editorEventReceived(static_cast<int>(type), senderId, payload);
        break;

    case EditorMessageType::PlayerRoster: {
        // côté client, cacher la nouvelle snapshot du roster.
        if (!m_isHost) {
            QStringList newRoster;
            const QJsonArray arr = payload.value("players").toArray();
            newRoster.reserve(arr.size());
            for (const QJsonValue &v : arr) newRoster.append(v.toString());
            if (newRoster != m_knownRoster) {
                m_knownRoster = newRoster;
                emit knownRosterChanged();
                qDebug() << "[EditorSession] roster mis à jour :" << m_knownRoster;
            }
        }
        emit editorEventReceived(static_cast<int>(type), senderId, payload);
        break;
    }

    case EditorMessageType::SelectionUpdate: {
        // L'auteur réel doit être préservé lors du relay hôte : le paquet
        // rebroadcastée arrive chez les autres clients avec senderId = hôte,
        // donc on tague `_by` côté hôte (autoritaire). Côté client qui reçoit
        // du relay, on lit `_by` pour la clé de m_remoteSelections.
        QJsonObject selPayload = payload;
        if (m_isHost) {
            selPayload.insert("_by", senderId);
        }
        const QString author = selPayload.value("_by").toString(senderId);

        QStringList uuids;
        const QJsonArray arr = selPayload.value("uuids").toArray();
        uuids.reserve(arr.size());
        for (const QJsonValue &v : arr) uuids.append(v.toString());
        if (uuids.isEmpty()) {
            m_remoteSelections.remove(author);
        } else {
            m_remoteSelections.insert(author, QVariant::fromValue(uuids));
        }
        emit remoteSelectionsChanged();

        emit selectionReceived(author, selPayload);
        if (m_isHost) {
            relayReliableToOthers(senderId, EditorProtocol::pack(type, selPayload));
        }
        break;
    }

    case EditorMessageType::OpReject:
        emit opRejected(payload);
        break;

    case EditorMessageType::MigrationCheckpointAck:
        // V3 T4-3 (D37) : le nouvel hôte a appliqué le checkpoint ET son
        // arbitre a passé le handshake D24 → fin de la suspension locale.
        // Idempotent (un ACK redondant sur un pair non suspendu ne fait rien).
        if (!m_isHost && senderId == m_hostPlayerId && m_proposalsSuspended) {
            qDebug() << "[EditorSession] MigrationCheckpointAck reçu de"
                     << senderId << "— reprise des propositions";
            m_proposalsSuspended  = false;
            m_migrationInProgress = false;
            emit migrationStateChanged();
            emit proposalsResumed();
        }
        break;

    case EditorMessageType::HostLeaving:
        // l'hôte annonce son départ volontaire → élection immédiate.
        // Même flow que onPlayerTimedOut sur l'hôte, sans attendre les ~10 s.
        if (!m_isHost && senderId == m_hostPlayerId) {
            // V3 T4-3 (D37) : checkpoint embarqué + suspension des propositions
            // + coordination 0x2A/0x46 (arrêt ordonné physique/proposal/state).
            enterMigrationMode(payload.value("checkpoint").toObject());
            // Remplace le roster local par celui embarqué dans le message
            // (source de vérité autoritaire), pour que tous les clients
            // élisent le même successeur même si le dernier broadcastRoster
            // n'était pas parvenu à tout le monde.
            const QJsonArray arr = payload.value("roster").toArray();
            if (!arr.isEmpty()) {
                QStringList newRoster;
                newRoster.reserve(arr.size());
                for (const QJsonValue &v : arr) newRoster.append(v.toString());
                if (newRoster != m_knownRoster) {
                    m_knownRoster = newRoster;
                    emit knownRosterChanged();
                    qDebug() << "[EditorSession] roster remplacé depuis HostLeaving :"
                             << m_knownRoster;
                }
            }
            // Purge le PlayerNetwork de l'ancien hôte pour libérer socket/
                // endpoint et éviter les paquets fantômes ("Paquet UDP spoofé"
                // avec provenance vide — socket fermé côté pair). Sans ça, le
                // nouvel hôte élu pollue son journal tant que le timeout Catway
                // n'a pas purgé l'ancien pair (~10 s).
            Catway *catway = Catway::instance();
            if (PlayerNetwork *oldHost = catway->playerById(senderId)) {
                qDebug() << "[EditorSession] purge ancien hôte PlayerNetwork :"
                         << senderId;
                catway->removePlayer(oldHost);
            }
            const QString elected = electNewHost();
            qWarning() << "[EditorSession] hôte quitte — élection →" << elected;
            emit hostLost(elected);
        }
        break;

    default:
        emit editorEventReceived(static_cast<int>(type), senderId, payload);
        // Hello / Welcome / FullSync / PlayerRoster / OpAck : pas de relay par défaut.
        break;
    }
}

void EditorSession::onUdpReceived(const QString &senderId, const QString &message)
{
    if (!message.startsWith(QLatin1String(k_cursorPrefix))) return;

    const QString body = message.mid(static_cast<int>(qstrlen(k_cursorPrefix)));
    const QStringList parts = body.split(QLatin1Char(';'));
    if (parts.size() != 3) return;

    bool okX, okY;
    const qreal x = parts[1].toDouble(&okX);
    const qreal y = parts[2].toDouble(&okY);
    if (!okX || !okY) return;

    // En P2P, les clients ne sont connectés qu'à l'hôte : le client B ne
    // recevra jamais directement le datagramme UDP du client A. On utilise
    // donc parts[0] (l'auteur embarqué par sendCursor) comme véritable id.
    const QString author = parts[0].isEmpty() ? senderId : parts[0];
    emit cursorReceived(author, x, y);

    // Relay hôte : forward le datagramme brut aux autres pairs P2P, pour que
    // les clients voient les curseurs des autres clients. senderId = id Catway
    // du pair direct (l'auteur si reçu par l'hôte, l'hôte si reçu par un
    // client d'un relay — dans ce second cas on n'entre pas ici, m_isHost=false).
    if (m_isHost && !senderId.isEmpty()) {
        Catway *catway = Catway::instance();
        const int count = catway->playersCount();
        for (int i = 0; i < count; ++i) {
            PlayerNetwork *p = catway->playerAt(i);
            if (!p || !p->isP2pConnected()) continue;
            if (p->playerId() == senderId) continue;   // pas à l'auteur
            catway->sendUdpMessageToPlayer(p, message);
        }
    }
}

// réassemblage des ops chunkées. Une fois tous les fragments reçus,
// on reconstruit le paquet original et on le ré-injecte dans onReliableReceived
// pour suivre le même chemin que les ops non-chunkées (rate-limit, seq, etc.).
void EditorSession::handleOpChunk(const QString &senderId, const QJsonObject &payload)
{
    const QString opId = payload.value("opId").toString();
    const int idx      = payload.value("chunkIndex").toInt(-1);
    const int count    = payload.value("chunkCount").toInt(0);
    const int origType = payload.value("origType").toInt(0);
    const QByteArray frag = payload.value("payloadB64").toString().toLatin1();
    if (opId.isEmpty() || idx < 0 || count <= 0) {
        qWarning() << "[EditorSession] OpChunk payload invalide";
        return;
    }
    const QString key = senderId + QLatin1Char('/') + opId;
    ChunkBuffer &buf = m_chunkBuffers[key];
    if (buf.chunkCount == 0) {
        buf.chunkCount = count;
        buf.origType   = origType;
    }
    buf.chunks.insert(idx, frag);
    if (buf.chunks.size() < buf.chunkCount) return;

    // Tous reçus : concaténer dans l'ordre + décoder.
    QByteArray b64;
    for (int i = 0; i < buf.chunkCount; ++i) b64.append(buf.chunks.value(i));
    const QByteArray full = QByteArray::fromBase64(b64);
    m_chunkBuffers.remove(key);

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(full, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[EditorSession] OpChunk reassembly JSON error:" << err.errorString();
        return;
    }
    // Ré-injection via le chemin normal : on reconstruit le paquet du type d'origine.
    const QByteArray rebuilt = EditorProtocol::pack(
        static_cast<EditorMessageType::Value>(origType), doc.object());
    qDebug() << "[EditorSession] OpChunk reassembled — replaying type"
             << Qt::hex << origType << Qt::dec << "from" << senderId
             << "(" << rebuilt.size() << "bytes)";
    onReliableReceived(senderId, rebuilt);
}

// diffuse le roster courant à tous les clients.
void EditorSession::broadcastRoster()
{
    if (!m_isHost) return;
    QJsonArray arr;
    for (const QString &p : m_knownRoster) arr.append(p);
    broadcastEvent(EditorMessageType::PlayerRoster,
                   QJsonObject{{ "players", arr }});
}

// élection déterministe. Candidats = roster cache ∪ {self} privé
// de l'ancien hôte. Gagnant = plus petit id lexicographique.
QString EditorSession::electNewHost() const
{
    QStringList candidates = m_knownRoster;
    if (!m_localPlayerId.isEmpty() && !candidates.contains(m_localPlayerId))
        candidates.append(m_localPlayerId);
    candidates.removeAll(m_hostPlayerId);
    if (candidates.isEmpty()) return QString{};
    std::sort(candidates.begin(), candidates.end());
    return candidates.first();
}

// annonce volontaire : l'hôte quitte. Broadcast reliable à tous les clients
// pour qu'ils déclenchent l'élection tout de suite (pas d'attente timeout).
// Le roster autoritaire est embarqué dans le payload pour que tous les clients
// élisent à partir de la même source de vérité (évite un split-brain si un
// client vient juste de rejoindre et n'a pas encore reçu le dernier PlayerRoster).
void EditorSession::announceHostLeaving()
{
    if (!m_active || !m_isHost) return;
    QJsonArray arr;
    for (const QString &pid : m_knownRoster) arr.append(pid);
    QJsonObject payload;
    payload["roster"] = arr;

    // V3 T4-3 (D37) : embarquer le checkpoint de migration dans l'annonce.
    // Le transport chunké (OpChunk) de sendReliableOrChunked absorbe un
    // checkpoint volumineux (règlement + journal).
    const QJsonObject checkpoint = buildCheckpointJson();
    payload["checkpoint"] = checkpoint;
    m_migrationCheckpoint = checkpoint.toVariantMap();
    m_migrationInProgress = true;
    m_proposalsSuspended  = true;
    emit migrationStateChanged();

    qDebug() << "[EditorSession] host leaving — broadcast HostLeaving (0x2A"
             << "+ checkpoint D37), roster =" << m_knownRoster;
    broadcastEvent(EditorMessageType::HostLeaving, payload);

    // Coordination des deux HostLeaving (T4-3) : l'annonce éditeur 0x2A part
    // AVANT le 0x46 physique. PhysicsSession::stop() (hôte) broadcast son
    // propre HostLeaving 0x46 — reçu APRÈS le 0x2A, les survivants sont déjà
    // en mode migration et le repli en sim locale du client physique est un
    // état transitoire, pas une seconde autorité (le pair élu re-promeut la
    // physique à la reprise).
    PhysicsSession *phys = PhysicsSession::instance();
    if (phys->active() && phys->isHost()) {
        qDebug() << "[EditorSession] coordination 0x2A→0x46 : arrêt PhysicsSession hôte";
        phys->stop();
    }
    // Sessions V3 hôte : arrêt ordonné. ProposalSession (D40) cesse d'accepter
    // des propositions (suspension côté transport) ; StateBus s'arrête en
    // conservant son miroir (source du volet 3 chez les survivants).
    ProposalSession *prop = ProposalSession::instance();
    if (prop->active()) prop->stop();
    StateBus *bus = StateBus::instance();
    if (bus->active()) bus->stop();
}

// ── V3 T4-3 · Migration d'hôte (checkpoint D37) ──────────────────────────────

// Assemble le checkpoint D37 côté hôte sortant, par priorité :
//  1) règlement versionné (D12)                      — bloquant ;
//  2) hashes des artefacts actifs (mécanique D16)    — bloquant ;
//  3) hash + volume du bus d'état + repère de séquence — bloquant. L'état
//     lui-même est déjà répliqué en continu chez les pairs (deltas/snapshots
//     D35, miroir conservé par StateBus::stop()) : le checkpoint transporte le
//     hash de divergence D39 pour VÉRIFIER le miroir de l'élu, pas les données ;
//  4) contexte d'arbitre (journal D19 borné)          — best-effort.
QJsonObject EditorSession::buildCheckpointJson() const
{
    QJsonObject checkpoint;
    checkpoint["checkpointVersion"] = 1;
    checkpoint["sessionId"]         = m_sessionId;
    checkpoint["hostPlayerId"]      = m_localPlayerId;

    // 1) Règlement versionné (bloquant).
    checkpoint["rulebook"] = RulesEngine::instance()->toJson();

    // 2) Hashes des artefacts actifs (bloquant). Le nouvel hôte vérifie leur
    // disponibilité locale ; les sources manquantes se re-téléchargent auprès
    // des pairs (mécanique D16 — transport de rattrapage hors périmètre T4-3).
    QJsonArray artifacts;
    ArtifactRegistry *reg = ArtifactRegistry::instance();
    const QStringList hashes = reg->knownHashes();
    // Seuls les artefacts encore référencés (refcount > 0) sont « actifs ».
    // Si AUCUN refcount n'est chaud (store rechargé après relance : compteurs
    // en mémoire froids), embarquer tout le store — sur-approximation sûre
    // (le GC au save D36 fait foi, jamais le checkpoint).
    bool anyRef = false;
    for (const QString &h : hashes) {
        if (reg->refCount(h) > 0) { anyRef = true; break; }
    }
    for (const QString &h : hashes) {
        if (!anyRef || reg->refCount(h) > 0)
            artifacts.append(h);
    }
    checkpoint["artifacts"] = artifacts;

    // 3) Snapshot `state` : hash de divergence D39 + repère de volume.
    StateBus *bus = StateBus::instance();
    QJsonObject state;
    state["hash"]           = bus->localStateHash();
    state["namespaceCount"] = bus->namespaces().size();
    checkpoint["state"] = state;

    // 4) Contexte d'arbitre (best-effort) : journal métier D19 borné (verdicts
    // inclus — événements durables du noyau d'audit), à injecter en pré-prompt
    // du nouvel arbitre.
    QJsonObject arbiterContext;
    arbiterContext["journal"] =
        QJsonArray::fromVariantList(GameplayEventBus::instance()->auditLog(0, 128));
    checkpoint["arbiterContext"] = arbiterContext;

    return checkpoint;
}

// Entrée en mode migration côté survivant : stocke le checkpoint (éventuellement
// vide sur le chemin timeout), suspend les propositions (D37) et arrête les
// sessions V3 dépendantes dans l'ordre. Idempotent.
void EditorSession::enterMigrationMode(const QJsonObject &checkpoint)
{
    if (!checkpoint.isEmpty())
        m_migrationCheckpoint = checkpoint.toVariantMap();
    if (!m_migrationInProgress || !m_proposalsSuspended) {
        m_migrationInProgress = true;
        m_proposalsSuspended  = true;
        emit migrationStateChanged();
    }
    m_checkpointApplied = false;

    // Coordination 0x2A/0x46 côté survivant : couper la physique client TOUT DE
    // SUITE (sans attendre le 0x46 de l'ancien hôte, qui peut ne jamais arriver
    // sur le chemin timeout). PhysicsSession::stop() côté client repasse en sim
    // locale — état transitoire assumé pendant la fenêtre de migration, PAS une
    // autorité réseau (aucun snapshot broadcast tant qu'aucun startAsHost).
    PhysicsSession *phys = PhysicsSession::instance();
    if (phys->active() && !phys->isHost()) {
        qDebug() << "[EditorSession] migration : arrêt PhysicsSession client (pré-0x46)";
        phys->stop();
    }
    // ProposalSession : suspension au niveau transport (rien ne part vers un
    // hôte mort) ; StateBus : stop() CONSERVE le miroir répliqué — c'est la
    // source du volet 3 pour le pair élu.
    ProposalSession *prop = ProposalSession::instance();
    if (prop->active()) prop->stop();
    StateBus *bus = StateBus::instance();
    if (bus->active()) bus->stop();
}

void EditorSession::beginHostHandover()
{
    if (!m_active) return;
    if (m_isHost) {
        announceHostLeaving();
    } else {
        // Client qui quitte : pas d'annonce, mais arrêt ordonné de ses sessions
        // V3 dépendantes (sans marquer de migration — il s'en va, c'est tout).
        ProposalSession *prop = ProposalSession::instance();
        if (prop->active()) prop->stop();
        StateBus *bus = StateBus::instance();
        if (bus->active()) bus->stop();
        PhysicsSession *phys = PhysicsSession::instance();
        if (phys->active() && !phys->isHost()) phys->stop();
    }
    stop();
}

bool EditorSession::applyMigrationCheckpoint()
{
    const QJsonObject checkpoint = QJsonObject::fromVariantMap(m_migrationCheckpoint);

    // 1) Règlement versionné — BLOQUANT. Sans checkpoint (départ brutal), le
    // règlement local répliqué fait foi (copie passive du client, doc 06).
    if (checkpoint.contains(QStringLiteral("rulebook"))) {
        QString error;
        if (!RulesEngine::instance()->loadJson(
                checkpoint.value(QStringLiteral("rulebook")).toObject(), &error)) {
            qWarning() << "[EditorSession] checkpoint D37 : règlement inapplicable —"
                       << error << "→ propositions maintenues suspendues";
            m_checkpointApplied = false;
            return false;
        }
        qDebug() << "[EditorSession] checkpoint D37 : règlement appliqué, version ="
                 << RulesEngine::instance()->version();
    } else {
        qWarning() << "[EditorSession] checkpoint D37 absent (départ brutal ?) — "
                      "reprise sur le règlement répliqué local, version ="
                   << RulesEngine::instance()->version();
    }

    // 2) Hashes d'artefacts actifs — BLOQUANT : tout hash indisponible
    // localement doit être re-téléchargé (mécanique D16) avant reprise.
    QStringList missing;
    const QJsonArray artifacts = checkpoint.value(QStringLiteral("artifacts")).toArray();
    for (const QJsonValue &v : artifacts) {
        const QString hash = v.toString();
        if (!hash.isEmpty() && !ArtifactRegistry::instance()->isAvailable(hash))
            missing.append(hash);
    }
    if (!missing.isEmpty()) {
        qWarning() << "[EditorSession] checkpoint D37 :" << missing.size()
                   << "artefact(s) indisponible(s) localement :" << missing
                   << "— éléments à désactiver avec diagnostic (D16), "
                      "propositions maintenues suspendues";
        m_checkpointApplied = false;
        return false;
    }

    // 3) Snapshot `state` : vérification du miroir répliqué local (D39). Le
    // miroir survit à StateBus::stop() — c'est « le snapshot le plus récent »
    // au sens D37 (répliqué en continu par D35). Une divergence est signalée
    // mais n'invalide pas la promotion : le miroir local est la meilleure
    // source survivante, et les pairs se réalignent sur le premier snapshot de
    // réparation du nouvel hôte.
    const QJsonObject state = checkpoint.value(QStringLiteral("state")).toObject();
    const QString expectedHash = state.value(QStringLiteral("hash")).toString();
    if (!expectedHash.isEmpty()) {
        const QString localHash = StateBus::instance()->localStateHash();
        if (localHash != expectedHash) {
            qWarning() << "[EditorSession] checkpoint D37 : divergence d'état —"
                       << "attendu" << expectedHash << "local" << localHash
                       << "(miroir local conservé, réparation au premier snapshot)";
        }
    }

    m_checkpointApplied = true;
    return true;
}

QVariantMap EditorSession::migrationArbiterContext() const
{
    return m_migrationCheckpoint.value(QStringLiteral("arbiterContext")).toMap();
}

// Reprise D37 : checkpoint appliqué + handshake D24. Si l'arbitre est déjà
// « Prêt » (résultat latché du challenge D31), reprise immédiate ; sinon on
// s'abonne à handshakeCompleted et on reprend au premier succès.
void EditorSession::armProposalResume()
{
    if (!m_proposalsSuspended) return;
    AiProcessSupervisor *sup = AiProcessSupervisor::instance();
    if (m_checkpointApplied && sup->arbiterReady()) {
        resumeProposals();
        return;
    }
    if (m_arbiterHsConn) disconnect(m_arbiterHsConn);
    m_arbiterHsConn = connect(
        sup, &AiProcessSupervisor::handshakeCompleted, this,
        [this](int role, bool ok, const QString &reason) {
            if (role != AiProcessSupervisor::Arbiter) return;
            if (!ok) {
                qWarning() << "[EditorSession] handshake arbitre D24 échoué —"
                           << reason << "→ propositions toujours suspendues";
                return;
            }
            if (m_checkpointApplied && m_proposalsSuspended)
                resumeProposals();
        });
    qDebug() << "[EditorSession] reprise D37 armée — en attente du handshake "
                "arbitre (checkpointApplied =" << m_checkpointApplied << ")";
}

void EditorSession::resumeProposals()
{
    if (m_arbiterHsConn) {
        disconnect(m_arbiterHsConn);
        m_arbiterHsConn = {};
    }
    const bool wasSuspended = m_proposalsSuspended;
    m_proposalsSuspended  = false;
    m_migrationInProgress = false;
    emit migrationStateChanged();
    if (wasSuspended) emit proposalsResumed();

    // Le nouvel hôte notifie les survivants : checkpoint ACKé + arbitre prêt
    // → chacun lève sa suspension locale (D37). Les pairs qui reconnectent
    // APRÈS ce broadcast reçoivent l'ACK en point-à-point sur leur Hello.
    if (m_active && m_isHost && m_wasMigrated) {
        qDebug() << "[EditorSession] broadcast MigrationCheckpointAck (0x2B)";
        broadcastEvent(EditorMessageType::MigrationCheckpointAck,
                       QJsonObject{{ "sessionId", m_sessionId },
                                   { "rulebookVersion",
                                     double(RulesEngine::instance()->version()) }});
    }
}

void EditorSession::clearMigrationState()
{
    if (m_arbiterHsConn) {
        disconnect(m_arbiterHsConn);
        m_arbiterHsConn = {};
    }
    const bool changed = m_migrationInProgress || m_proposalsSuspended
                         || !m_migrationCheckpoint.isEmpty();
    m_migrationInProgress = false;
    m_proposalsSuspended  = false;
    m_migrationCheckpoint.clear();
    m_checkpointApplied = false;
    m_wasMigrated       = false;
    if (changed) emit migrationStateChanged();
}

// bascule du rôle client → hôte en préservant l'état local.
bool EditorSession::promoteToHost()
{
    if (!m_active) {
        qWarning() << "[EditorSession] promoteToHost: session inactive";
        return false;
    }
    if (m_isHost) return true;
    const QString me = m_localPlayerId;
    const QString sid = m_sessionId;
    qDebug() << "[EditorSession] promotion hôte — pair local =" << me;

    // V3 T4-3 (D37) : appliquer les volets bloquants du checkpoint AVANT la
    // bascule de rôle (le règlement/artefacts doivent être en place quand les
    // survivants reconnectent). L'échec d'un volet bloquant n'empêche pas la
    // promotion (l'éditeur doit continuer de vivre) mais maintient la
    // suspension des propositions (armProposalResume ne reprendra pas).
    const bool checkpointOk = applyMigrationCheckpoint();
    if (!checkpointOk)
        qWarning() << "[EditorSession] promotion avec checkpoint D37 incomplet — "
                      "propositions maintenues suspendues";

    // On garde les tuiles locales (pas touché par stop/startAsHost).
    stop();
    const bool ok = startAsHost(me, sid);
    if (ok) {
        m_wasMigrated = true;
        // Autorité D33 : le nouvel hôte exécute les règles.
        RulesEngine::instance()->setHostAuthority(true);
        // Bus d'état : repartir en autorité depuis le miroir répliqué conservé
        // (StateBus::stop() ne purge pas les valeurs — volet 3 du checkpoint).
        StateBus *bus = StateBus::instance();
        if (!bus->active()) bus->startAsHost(sid, me);
        // Reprise D37 : handshake arbitre D24 + checkpoint ACKé.
        armProposalResume();
        emit promotedToHost();
    }
    return ok;
}

// perte d'un pair détectée par Catway. Côté client, si c'est l'hôte
// qui tombe → on arrête la session (le QML reprend en mode monoposte avec son
// snapshot local). Côté hôte, on purge la présence et notifie les clients.
void EditorSession::onPlayerTimedOut(const QString &playerId)
{
    if (!m_active) return;
    if (!m_isHost && playerId == m_hostPlayerId) {
        // élection déterministe sur la base du dernier roster cache
        // reçu de l'ancien hôte. Tous les survivants qui partagent le même
        // roster élisent le même gagnant → pas de négociation nécessaire.
        //
        // IMPORTANT : on N'APPELLE PAS `stop()` ici. Le signal est émis
        // synchroniquement, et le handler QML décide : soit `promoteToHost()`
        // (qui fait stop+startAsHost atomiquement), soit `stop()`. Si on
        // enchaînait `stop()` ici, il annulerait la promotion juste faite par
        // le handler → le client perdrait le rôle d'hôte.
        // V3 T4-3 (D37) : départ BRUTAL — pas de checkpoint reçu. Le mode
        // migration est déclenché quand même (suspension + arrêt ordonné des
        // sessions V3) ; les volets bloquants seront reconstruits best-effort
        // depuis l'état répliqué local (règlement passif, miroir StateBus,
        // journal D19 répliqué) par applyMigrationCheckpoint().
        enterMigrationMode(QJsonObject{});
        const QString elected = electNewHost();
        qWarning() << "[EditorSession] hôte perdu (timeout) — élection →" << elected;
        emit hostLost(elected);
        return;
    }
    if (m_isHost) {
        qWarning() << "[EditorSession] pair perdu:" << playerId;
        bool purged = false;
        if (m_remoteSelections.contains(playerId)) {
            m_remoteSelections.remove(playerId);
            purged = true;
        }
        m_opBuckets.remove(playerId);
        // Supprimer les chunks en cours de ce sender.
        QStringList toDrop;
        for (auto it = m_chunkBuffers.begin(); it != m_chunkBuffers.end(); ++it) {
            if (it.key().startsWith(playerId + QLatin1Char('/')))
                toDrop.append(it.key());
        }
        for (const QString &k : toDrop) m_chunkBuffers.remove(k);

        // retirer du roster + rediffuser la nouvelle liste.
        if (m_knownRoster.removeAll(playerId) > 0) {
            emit knownRosterChanged();
            broadcastRoster();
        }

        if (purged) emit remoteSelectionsChanged();
        emit peerLeft(playerId);
    }
}
