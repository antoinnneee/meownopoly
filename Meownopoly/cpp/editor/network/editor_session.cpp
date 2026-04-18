#include "editor_session.h"
#include "editor_protocol.h"
#include "editor_message_type.h"

#include "communication/catway.h"
#include "communication/player_network.h"
#include "game/network/game_session.h"

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
        // Met à jour la map de présence (QVariantMap playerId → [uuid,...])
        // avant de ré-émettre, pour que les consumers QML via binding sur
        // `remoteSelections` voient la nouvelle valeur au moment du signal.
        QStringList uuids;
        const QJsonArray arr = payload.value("uuids").toArray();
        uuids.reserve(arr.size());
        for (const QJsonValue &v : arr) uuids.append(v.toString());
        if (uuids.isEmpty()) {
            m_remoteSelections.remove(senderId);
        } else {
            m_remoteSelections.insert(senderId, QVariant::fromValue(uuids));
        }
        emit remoteSelectionsChanged();

        emit selectionReceived(senderId, payload);
        if (m_isHost) {
            relayReliableToOthers(senderId, EditorProtocol::pack(type, payload));
        }
        break;
    }

    case EditorMessageType::OpReject:
        emit opRejected(payload);
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

    // senderId vient de Catway ; on ignore parts[0] (redondant avec senderId).
    emit cursorReceived(senderId, x, y);
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

// bascule du rôle client → hôte en préservant l'état local.
bool EditorSession::promoteToHost()
{
    if (!m_active) {
        qWarning() << "[EditorSession] promoteToHost: session inactive";
        return false;
    }
    if (m_isHost) return true;
    const QString me = m_localPlayerId;
    qDebug() << "[EditorSession] promotion hôte — pair local =" << me;
    // On garde les tuiles locales (pas touché par stop/startAsHost).
    stop();
    const bool ok = startAsHost(me);
    if (ok) emit promotedToHost();
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
