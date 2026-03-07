#include "game_session.h"
#include "game_protocol.h"
#include "game_message_type.h"

#include "communication/catway.h"

#include <QDebug>

GameSession *GameSession::m_pThis = nullptr;

// ── Singleton ─────────────────────────────────────────────────────────────────

GameSession::GameSession(QObject *parent) : QObject(parent) {}

GameSession *GameSession::instance()
{
    if (!m_pThis)
        m_pThis = new GameSession();
    return m_pThis;
}

QObject *GameSession::qmlInstance(QQmlEngine * /*engine*/, QJSEngine * /*scriptEngine*/)
{
    return instance();
}

void GameSession::registerQml()
{
    qmlRegisterSingletonType<GameSession>("GameSession", 1, 0, "GameSession",
                                         &GameSession::qmlInstance);
    qmlRegisterUncreatableMetaObject(GameMessageType::staticMetaObject,
                                     "GameSession", 1, 0,
                                     "GameMessageType",
                                     "Error: only enums");
}

// ── Initialisation ─────────────────────────────────────────────────────────────

void GameSession::startAsHost(const QString &localPlayerId)
{
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = QString{};
    m_isHost        = true;
    m_active        = true;

    connectToCatway();

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit isHostChanged();
    emit activeChanged();

    qDebug() << "[GameSession] Started as HOST, playerId =" << localPlayerId;
}

void GameSession::startAsClient(const QString &localPlayerId, const QString &hostPlayerId)
{
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = hostPlayerId;
    m_isHost        = false;
    m_active        = true;

    connectToCatway();

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit isHostChanged();
    emit activeChanged();

    qDebug() << "[GameSession] Started as CLIENT, playerId =" << localPlayerId
             << "host =" << hostPlayerId;
}

void GameSession::stop()
{
    disconnectFromCatway();
    m_active = false;
    m_isHost = false;
    m_localPlayerId.clear();
    m_hostPlayerId.clear();

    emit activeChanged();
    emit isHostChanged();
    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();

    qDebug() << "[GameSession] Stopped.";
}

// ── Connexion Catway ──────────────────────────────────────────────────────────

void GameSession::connectToCatway()
{
    Catway *catway = Catway::instance();
    m_reliableConn = connect(catway, &Catway::reliableMessageReceived,
                             this,   &GameSession::onReliableReceived);
    m_udpConn      = connect(catway, &Catway::udpMessageReceived,
                             this,   &GameSession::onUdpReceived);
}

void GameSession::disconnectFromCatway()
{
    disconnect(m_reliableConn);
    disconnect(m_udpConn);
}

// ── Envoi ──────────────────────────────────────────────────────────────────────

void GameSession::sendEvent(int type, const QJsonObject &payload)
{
    const auto msgType = static_cast<GameMessageType::Value>(type);
    const QByteArray packet = GameProtocol::pack(msgType, payload);
    Catway *catway = Catway::instance();

    if (m_isHost) {
        // Hôte : broadcast direct à tous
        catway->broadcastReliable(packet);
    } else {
        // Client : envoie uniquement à l'hôte
        PlayerNetwork *host = catway->playerById(m_hostPlayerId);
        if (host) {
            catway->sendReliableToPlayer(host, packet);
        } else {
            qWarning() << "[GameSession] sendEvent: host player not found:" << m_hostPlayerId;
        }
    }
}

void GameSession::broadcastEvent(int type, const QJsonObject &payload)
{
    if (!m_isHost) {
        qWarning() << "[GameSession] broadcastEvent called by non-host — ignoring.";
        return;
    }
    const QByteArray packet = GameProtocol::pack(
        static_cast<GameMessageType::Value>(type), payload);
    Catway::instance()->broadcastReliable(packet);
}

void GameSession::sendMapSync(const QJsonObject &mapJson)
{
    const QByteArray packet = GameProtocol::pack(GameMessageType::MapSync,
                                                 {{ "map", mapJson }});
    Catway *catway = Catway::instance();

    if (m_isHost) {
        catway->broadcastReliable(packet);
    } else {
        PlayerNetwork *host = catway->playerById(m_hostPlayerId);
        if (host) catway->sendReliableToPlayer(host, packet);
    }
}

void GameSession::sendMinigameInput(qreal x, qreal y, qreal vx, qreal vy)
{
    const QString msg = GameProtocol::packMinigameInput(x, y, vx, vy);
    Catway::instance()->broadcastRaw(msg);
}

void GameSession::broadcastMinigameSnapshot(const QJsonObject &snapshot)
{
    if (!m_isHost) {
        qWarning() << "[GameSession] broadcastMinigameSnapshot called by non-host — ignoring.";
        return;
    }
    const QByteArray packet = GameProtocol::pack(GameMessageType::MinigameSnapshot, snapshot);
    Catway::instance()->broadcastReliable(packet);
}

// ── Réception ─────────────────────────────────────────────────────────────────

void GameSession::onReliableReceived(const QString &senderId, const QByteArray &data)
{
    qDebug() << "[GameSession] onReliableReceived:" << senderId << "data:" << data;
    GameMessageType::Value type;
    QJsonObject payload;

    if (!GameProtocol::unpack(data, type, payload)) {
        qWarning() << "[GameSession] Failed to unpack reliable packet from" << senderId;
        return;
    }

    if (type == GameMessageType::MapSync) {
        emit mapSyncReceived(senderId, payload.value("map").toObject());

    } else if (type == GameMessageType::MinigameSnapshot) {
        emit minigameSnapshotReceived(senderId, payload);

        // Hôte : re-broadcast le snapshot aux autres joueurs
        if (m_isHost) {
            const QByteArray packet = GameProtocol::pack(type, payload);
            Catway *catway = Catway::instance();
            const int count = catway->playersCount();
            for (int i = 0; i < count; ++i) {
                PlayerNetwork *p = catway->playerAt(i);
                if (p && p->playerId() != senderId && p->isP2pConnected())
                    catway->sendReliableToPlayer(p, packet);
            }
        }

    } else {
        emit boardEventReceived(static_cast<int>(type), senderId, payload);

        // Hôte : relay l'événement à tous les autres joueurs
        if (m_isHost) {
            const QByteArray packet = GameProtocol::pack(type, payload);
            Catway *catway = Catway::instance();
            const int count = catway->playersCount();
            for (int i = 0; i < count; ++i) {
                PlayerNetwork *p = catway->playerAt(i);
                if (p && p->playerId() != senderId && p->isP2pConnected())
                    catway->sendReliableToPlayer(p, packet);
            }
        }
    }
}

void GameSession::onUdpReceived(const QString &senderId, const QString &message)
{
    // qDebug() << "[GameSession] onUdpReceived:" << senderId << "message:" << message;
    qreal x, y, vx, vy;
    // if (GameProtocol::unpackMinigameInput(message, x, y, vx, vy)) {
        // emit minigameInputReceived(senderId, x, y, vx, vy);

        // // Hôte : re-broadcast la position aux autres joueurs
        // if (m_isHost) {
        //     Catway *catway = Catway::instance();
        //     const int count = catway->playersCount();
        //     for (int i = 0; i < count; ++i) {
        //         PlayerNetwork *p = catway->playerAt(i);
        //         if (p && p->playerId() != senderId && p->isP2pConnected())
        //             catway->sendUdpDatagram(p, message);
        //     }
        // }
    // }
}
