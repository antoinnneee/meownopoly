#include "editor_session.h"
#include "editor_protocol.h"
#include "editor_message_type.h"

#include "communication/catway.h"
#include "communication/player_network.h"
#include "game/network/game_session.h"

#include <QDebug>
#include <QStringList>

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
}

void EditorSession::disconnectFromCatway()
{
    disconnect(m_reliableConn);
    disconnect(m_udpConn);
}

// ── Envoi ──────────────────────────────────────────────────────────────────────

void EditorSession::sendEvent(int type, const QJsonObject &payload)
{
    if (!m_active) return;
    const auto msgType = static_cast<EditorMessageType::Value>(type);
    const QByteArray packet = EditorProtocol::pack(msgType, payload);
    Catway *catway = Catway::instance();

    if (m_isHost) {
        catway->broadcastReliable(packet);
    } else {
        PlayerNetwork *host = catway->playerById(m_hostPlayerId);
        if (host) {
            catway->sendReliableToPlayer(host, packet);
        } else {
            qWarning() << "[EditorSession] sendEvent: host player not found:" << m_hostPlayerId;
        }
    }
}

void EditorSession::broadcastEvent(int type, const QJsonObject &payload)
{
    if (!m_active || !m_isHost) {
        qWarning() << "[EditorSession] broadcastEvent called by non-host — ignoring.";
        return;
    }
    const QByteArray packet = EditorProtocol::pack(
        static_cast<EditorMessageType::Value>(type), payload);
    Catway::instance()->broadcastReliable(packet);
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
    case EditorMessageType::Op:
        emit opReceived(senderId, payload);
        // Hôte : rebroadcast aux autres clients (l'auteur reçoit via son propre
        // chemin local ; voir note dans le plan sur le design apply-on-rebroadcast).
        if (m_isHost) {
            relayReliableToOthers(senderId, EditorProtocol::pack(type, payload));
        }
        break;

    case EditorMessageType::SelectionUpdate:
        emit selectionReceived(senderId, payload);
        if (m_isHost) {
            relayReliableToOthers(senderId, EditorProtocol::pack(type, payload));
        }
        break;

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
