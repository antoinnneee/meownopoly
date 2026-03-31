#include "catway.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QHostAddress>
#include <QUdpSocket>
#include <QVariant>
#include <QElapsedTimer>
#include <QDebug>
#include <cstdarg>
#include <cstdio>

#include "../tools/logger.h"


static void catway_transmit_packet(
    void *context, uint64_t /*id*/, uint16_t /*sequence*/,
    uint8_t *packet_data, int packet_bytes)
{
    auto *ctx = static_cast<CatwayReliableContext *>(context);
    if (!ctx || !ctx->player || !ctx->catway || !ctx->worker) return;

    // Lire ip/port/socket depuis le snapshot du worker (thread réseau) — P8
    const PlayerSnapshot *snap = ctx->worker->findSnapshot(ctx->player->playerId());
    if (!snap || snap->ip.isEmpty() || snap->port == 0 || !snap->socket) {
        qDebug() << "[reliable] Skip transmit: no snapshot or missing address for player"
                 << (ctx->player ? ctx->player->playerId() : QStringLiteral("unknown"));
        return;
    }

    QByteArray datagram;
    datagram.reserve(1 + packet_bytes);
    datagram.append('\x01');
    datagram.append(reinterpret_cast<const char *>(packet_data), packet_bytes);

    snap->socket->writeDatagram(datagram, QHostAddress(snap->ip), snap->port);
}

static int catway_process_packet(
    void *context, uint64_t /*id*/, uint16_t /*sequence*/,
    uint8_t *packet_data, int packet_bytes)
{
    auto *ctx = static_cast<CatwayReliableContext *>(context);
    if (!ctx || !ctx->catway) return 0;
    QByteArray data(reinterpret_cast<const char *>(packet_data), packet_bytes);
    QString senderId = ctx->player->playerId();
    // Émettre le signal via le QThread GUI pour ne pas crasher les bindings QML
    QMetaObject::invokeMethod(ctx->catway, [ctx, senderId, data]() {
        emit ctx->catway->reliableMessageReceived(senderId, data);
    }, Qt::QueuedConnection);
    return 1; // 1 = ACK le paquet
}


void Catway::pushPlayerSnapshots()
{
    QList<PlayerSnapshot> snapshots;
    snapshots.reserve(m_players.size());
    for (PlayerNetwork *p : m_players) {
        if (!p) continue;
        PlayerSnapshot s;
        s.playerId     = p->playerId();
        s.ip           = p->ip();
        s.port         = p->port();
        s.p2pConnected = p->isP2pConnected();
        s.endpoint     = p->endpoint();
        s.socket       = p->socketInfo() ? p->socketInfo()->socket() : nullptr;
        snapshots.append(s);
    }
    QMetaObject::invokeMethod(m_worker, "setPlayerSnapshots", Qt::QueuedConnection,
                              Q_ARG(QList<PlayerSnapshot>, snapshots));
}

void Catway::addPlayer(PlayerNetwork *player)
{
    if (!player || m_players.contains(player))
        return;

    if (player->socketInfo() && player->socketInfo() == currentSocketInfo()) {
        player->setSocketInfo(takeStunSocket());
    } else if (player->socketInfo() && player->socketInfo()->socket()) {
        QUdpSocket *sock = player->socketInfo()->socket();
        if (sock->thread() != m_networkThread) {
            sock->setParent(nullptr);
            sock->moveToThread(m_networkThread);
        }
        connect(sock, &QUdpSocket::readyRead, m_worker, &CatwayWorker::onSocketReadyRead,
                Qt::UniqueConnection);
        // P5 — datagramReceived déjà connecté en constructeur, pas de reconnexion ici
    }

    player->setParent(this);
    m_players.append(player);
    m_playersById.insert(player->playerId(), player);
    m_playerIdByPlayer.insert(player, player->playerId());
    connect(player, &PlayerNetwork::playerIdChanged, this, &Catway::onPlayerNetworkPlayerIdChanged,
            Qt::UniqueConnection);
    emit playersChanged();

    // Initialiser l'endpoint reliable pour ce joueur.
    auto *ctx = new CatwayReliableContext{player, this, m_worker};
    // P6 — Stocker le contexte dans un QHash typé
    m_reliableContexts[player] = ctx;
    player->initReliable(ctx, catway_transmit_packet, catway_process_packet);

    // P1+P8 — Pousser un snapshot initial, puis se connecter aux changements de propriétés
    connect(player, &PlayerNetwork::ipChanged,          this, &Catway::pushPlayerSnapshots);
    connect(player, &PlayerNetwork::portChanged,        this, &Catway::pushPlayerSnapshots);
    connect(player, &PlayerNetwork::p2pConnectedChanged,this, &Catway::pushPlayerSnapshots);
    connect(player, &PlayerNetwork::socketInfoChanged,  this, &Catway::pushPlayerSnapshots);
    pushPlayerSnapshots();
}

void Catway::removePlayer(PlayerNetwork *player)
{
    if (!player || !m_players.removeOne(player))
        return;
    qDebug() << "[Catway] removePlayer:" << player->playerId() << "- déconnexion du joueur (endpoint reliable détruit)";

    // Déconnecter les signaux de propriétés
    disconnect(player, &PlayerNetwork::playerIdChanged,    this, &Catway::onPlayerNetworkPlayerIdChanged);
    disconnect(player, &PlayerNetwork::ipChanged,          this, &Catway::pushPlayerSnapshots);
    disconnect(player, &PlayerNetwork::portChanged,        this, &Catway::pushPlayerSnapshots);
    disconnect(player, &PlayerNetwork::p2pConnectedChanged,this, &Catway::pushPlayerSnapshots);
    disconnect(player, &PlayerNetwork::socketInfoChanged,  this, &Catway::pushPlayerSnapshots);

    m_playersById.remove(m_playerIdByPlayer.value(player));
    m_playerIdByPlayer.remove(player);

    // Libérer le socket si plus utilisé
    UdpSocketInfo *si = player->socketInfo();
    if (si) {
        bool inUse = false;
        if (m_currentStunSocketInfo == si) {
            inUse = true;
        } else {
            for (PlayerNetwork *p : m_players) {
                if (p->socketInfo() == si) {
                    inUse = true;
                    break;
                }
            }
        }
        if (!inUse) {
            m_localSocketInfos.removeOne(si);
            si->deleteLater();
            emit localPortsChanged();
        }
    }

    player->destroyReliable();

    // P6 — Libérer le contexte depuis le QHash
    CatwayReliableContext *ctx = m_reliableContexts.take(player);
    delete ctx;

    player->setParent(nullptr);
    emit playersChanged();
    pushPlayerSnapshots();
}


PlayerNetwork *Catway::playerAt(int index) const
{
    if (index < 0 || index >= m_players.size())
        return nullptr;
    return m_players.at(index);
}

int Catway::playersCount() const
{
    return m_players.size();
}

PlayerNetwork *Catway::playerById(const QString &playerId) const
{
    return m_playersById.value(playerId);
}

void Catway::onPlayerNetworkPlayerIdChanged()
{
    auto *p = qobject_cast<PlayerNetwork *>(sender());
    if (!p || !m_playerIdByPlayer.contains(p))
        return;
    const QString oldId = m_playerIdByPlayer.value(p);
    const QString newId = p->playerId();
    if (oldId == newId)
        return;
    m_playersById.remove(oldId);
    if (!newId.isEmpty())
        m_playersById.insert(newId, p);
    m_playerIdByPlayer[p] = newId;
}

PlayerNetwork *Catway::getOrCreatePlayer(const QString &playerId)
{
    PlayerNetwork *player = playerById(playerId);
    if (player)
        return player;

    UdpSocketInfo *current = qobject_cast<UdpSocketInfo *>(currentSocketInfo());
    if (!current || current->publicAddress().isEmpty() || current->publicPort() == 0)
    {
        Logger::instance()->error("Failed to get current socket info", "Catway");
        return nullptr;
    }

    UdpSocketInfo *socketInfo = takeStunSocket();
    if (!socketInfo)
    {
        Logger::instance()->error("Failed to take socket", "Catway");
        return nullptr;
    }

    player = new PlayerNetwork(this);
    player->setPlayerId(playerId);
    player->setNickname(nicknameFromChat(playerId));
    player->setSocketInfo(socketInfo);
    addPlayer(player);

    return player;
}