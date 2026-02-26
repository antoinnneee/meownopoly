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

#include "stun_manager.h"
#include "../account/account_manager.h"
#include "../tools/logger.h"
#include "reliable.h"

// ---------------------------------------------------------------------------
// Debug reliable : redirection des logs vers qDebug
// ---------------------------------------------------------------------------
static int catway_reliable_printf(const char *fmt, ...)
{
    char buf[4096];
    va_list args;
    va_start(args, fmt);
    int n = std::vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (n > 0)
        qDebug().noquote() << "[reliable]" << buf;
    return n;
}

// ---------------------------------------------------------------------------
// Callbacks C statiques pour reliable (doivent être des fonctions C, pas des
// lambdas capturantes). Le contexte est un PlayerNetwork*.
// ---------------------------------------------------------------------------

struct CatwayReliableContext {
    PlayerNetwork *player;
    Catway        *catway;
};

static void catway_transmit_packet(
    void *context, uint64_t /*id*/, uint16_t /*sequence*/,
    uint8_t *packet_data, int packet_bytes)
{
    auto *ctx = static_cast<CatwayReliableContext *>(context);
    if (!ctx || !ctx->player || !ctx->catway) return;
    PlayerNetwork *player = ctx->player;
    UdpSocketInfo *si = player->socketInfo();
    if (!si || !si->socket() || player->ip().isEmpty() || player->port() == 0) return;
    // Préfixer avec le magic byte 0x01 pour distinguer les paquets reliable des raw UDP
    QByteArray datagram;
    datagram.reserve(1 + packet_bytes);
    datagram.append('\x01');
    datagram.append(reinterpret_cast<const char *>(packet_data), packet_bytes);
    si->socket()->writeDatagram(datagram, QHostAddress(player->ip()), player->port());
}

static int catway_process_packet(
    void *context, uint64_t /*id*/, uint16_t /*sequence*/,
    uint8_t *packet_data, int packet_bytes)
{
    auto *ctx = static_cast<CatwayReliableContext *>(context);
    if (!ctx || !ctx->catway) return 0;
    QByteArray data(reinterpret_cast<const char *>(packet_data), packet_bytes);
    QString senderId = ctx->player->playerId();
    emit ctx->catway->reliableMessageReceived(senderId, data);
    emit ctx->catway->reliableMessageReceivedString(senderId, QString::fromUtf8(data));
    return 1; // 1 = ACK le paquet
}

Catway *Catway::m_pThis = nullptr;

Catway::Catway(QObject *parent)
    : QObject(parent)
{
    // Create StunManager owned by Catway
    m_stunManager = new StunManager(this);

    // Client de chat intégré (exposé en QML via la propriété chatClient)
    m_chatClient = new ChatClient(this);
    connect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

    // Relay signals from StunManager
    connect(m_stunManager, &StunManager::log, this, &Catway::log);
    connect(m_stunManager, &StunManager::serverStarted, this, &Catway::serverStarted);

    // Sync STUN parameters from AccountManager
    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    // Initialize STUN params from current AccountManager values
    onAccountStunChanged();

    // Timer de mise à jour des endpoints reliable (~60 Hz)
    reliable_init();
    reliable_log_level(RELIABLE_LOG_LEVEL_DEBUG);
    reliable_set_printf_function(catway_reliable_printf);
    qDebug() << "Catway: reliable debug activé (niveau DEBUG). Les logs [reliable] apparaîtront quand le canal fiable est utilisé (sendReliableToPlayer ou paquets reçus avec préfixe 0x01).";
    m_reliableClock.start();
    m_reliableUpdateTimer = new QTimer(this);
    m_reliableUpdateTimer->setInterval(16); // ~60 Hz
    connect(m_reliableUpdateTimer, &QTimer::timeout, this, &Catway::onReliableUpdate);
    m_reliableUpdateTimer->start();

    // Timer du Heartbeat P2P
    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(m_heartbeatInterval);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &Catway::onHeartbeat);
    m_heartbeatTimer->start();
}

void Catway::registerQml()
{
    qmlRegisterType<UdpSocketInfo>("Catway", 1, 0, "UdpSocketInfo");
    qmlRegisterSingletonType<Catway>("Catway", 1, 0, "Catway", &Catway::qmlInstance);
}

Catway *Catway::instance()
{
    if (m_pThis == nullptr)
    {
        m_pThis = new Catway;
    }
    return m_pThis;
}

ChatClient *Catway::chatClient() const
{
    return m_chatClient;
}

QObject *Catway::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return Catway::instance();
}

// --- Delegated methods ---

int Catway::heartbeatInterval() const
{
    return m_heartbeatInterval;
}

void Catway::setHeartbeatInterval(int intervalMs)
{
    if (m_heartbeatInterval != intervalMs) {
        m_heartbeatInterval = intervalMs;
        if (m_heartbeatTimer) {
            m_heartbeatTimer->setInterval(m_heartbeatInterval);
        }
        emit heartbeatIntervalChanged();
    }
}

void Catway::startServer()
{
    m_stunManager->startServer();
}

void Catway::stopServer()
{
    m_stunManager->stopServer();
}

void Catway::sendMessageToPeer(QString message)
{
    m_stunManager->sendMessageToPeer(message);
}

void Catway::setPeer(QString ip, quint16 port)
{
    m_stunManager->setPeer(ip, port);
}


void Catway::setStunServer(QString ip)
{
    m_stunManager->setStunServer(ip, m_stunManager->getStunPort());
}

void Catway::setStunPort(quint16 port)
{
    m_stunManager->setStunServer(m_stunManager->getStunServer(), port);
}

QString Catway::getExternalIp() const
{
    if (!m_localSocketInfos.isEmpty()) {
        UdpSocketInfo *last = m_localSocketInfos.last();
        QString addr = last->publicAddress();
        if (!addr.isEmpty())
            return addr;
    }
    return m_stunManager->getExternalIp();
}

quint16 Catway::getExternalPort() const
{
    if (!m_localSocketInfos.isEmpty()) {
        UdpSocketInfo *last = m_localSocketInfos.last();
        if (last->publicPort() != 0)
            return last->publicPort();
    }
    return m_stunManager->getExternalPort();
}

QObject *Catway::getSocket() const
{
    return m_stunManager->getSocket();
}

QObject *Catway::currentSocketInfo() const
{
    return m_stunManager->currentSocketInfo();
}

UdpSocketInfo *Catway::takeSocket()
{
    UdpSocketInfo *info = m_stunManager->takeSocket();
    if (info) {
        info->setParent(this);
        m_localSocketInfos.append(info);
        if (info->socket()) {
            connect(info->socket(), &QUdpSocket::readyRead, this, &Catway::onPlayerUdpReadyRead);
        }
        emit localPortsChanged();
    }
    return info;
}

QQmlListProperty<UdpSocketInfo> Catway::localPorts()
{
    return QQmlListProperty<UdpSocketInfo>(this, &m_localSocketInfos, &Catway::localPortsCount, &Catway::localPortsAt);
}

qsizetype Catway::localPortsCount(QQmlListProperty<UdpSocketInfo> *p)
{
    return static_cast<QList<UdpSocketInfo *> *>(p->data)->size();
}

UdpSocketInfo *Catway::localPortsAt(QQmlListProperty<UdpSocketInfo> *p, qsizetype index)
{
    return static_cast<QList<UdpSocketInfo *> *>(p->data)->at(index);
}

// --- Players list ---

QQmlListProperty<PlayerNetwork> Catway::players()
{
    return QQmlListProperty<PlayerNetwork>(this, &m_players, &Catway::playersCount, &Catway::playersAt);
}

qsizetype Catway::playersCount(QQmlListProperty<PlayerNetwork> *p)
{
    return static_cast<QList<PlayerNetwork *> *>(p->data)->size();
}

PlayerNetwork *Catway::playersAt(QQmlListProperty<PlayerNetwork> *p, qsizetype index)
{
    return static_cast<QList<PlayerNetwork *> *>(p->data)->at(index);
}

void Catway::addPlayer(PlayerNetwork *player)
{
    if (!player || m_players.contains(player))
        return;

    if (player->socketInfo() && player->socketInfo() == m_stunManager->currentSocketInfo()) {
        player->setSocketInfo(takeSocket());
    } else if (player->socketInfo() && player->socketInfo()->socket()) {
        // Just in case it was created freely, ensure readyRead is connected
        // although normally they should be in localPorts already via takeSocket()
        disconnect(player->socketInfo()->socket(), &QUdpSocket::readyRead, this, &Catway::onPlayerUdpReadyRead);
        connect(player->socketInfo()->socket(), &QUdpSocket::readyRead, this, &Catway::onPlayerUdpReadyRead);
    }

    player->setParent(this);
    m_players.append(player);
    emit playersChanged();

    // Initialiser l'endpoint reliable pour ce joueur.
    // On alloue le contexte sur le tas ; il sera libéré quand le joueur est supprimé.
    auto *ctx = new CatwayReliableContext{player, this};
    // Stocker le contexte dans une propriété dynamique pour pouvoir le libérer plus tard.
    player->setProperty("_reliableCtx", QVariant::fromValue<void *>(ctx));
    player->initReliable(ctx, catway_transmit_packet, catway_process_packet);
}

void Catway::removePlayer(PlayerNetwork *player)
{
    if (!player || !m_players.removeOne(player))
        return;
    qDebug() << "[Catway] removePlayer:" << player->playerId() << "- déconnexion du joueur (endpoint reliable détruit)";
    player->destroyReliable();
    // Libérer le contexte reliable
    void *ctxPtr = player->property("_reliableCtx").value<void *>();
    if (ctxPtr) {
        delete static_cast<CatwayReliableContext *>(ctxPtr);
        player->setProperty("_reliableCtx", QVariant());
    }
    player->setParent(nullptr);
    emit playersChanged();
}

PlayerNetwork *Catway::playerAt(int index) const
{
    if (index < 0 || index >= m_players.size())
        return nullptr;
    return m_players.at(index);
}

PlayerNetwork *Catway::playerById(const QString &playerId) const
{
    for (PlayerNetwork *p : m_players) {
        if (p && p->playerId() == playerId)
            return p;
    }
    return nullptr;
}

// --- STUN scoped handling ---

void Catway::sendStunRequest()
{
    m_stunManager->sendStunRequest();
}

void Catway::setupNewPort()
{
    auto *am = AccountManager::instance();
    qDebug()<<"setupNewPort";
    m_stunManager->setStunServer(am->stunServer(), am->stunPort());
    m_stunManager->startServer();
    m_stunManager->sendStunRequest();

    disconnect(m_externalAddressTakePortConnection);
    m_externalAddressTakePortConnection = connect(m_stunManager, &StunManager::externalAddressReceived,
                                                  this, &Catway::onExternalAddressReceivedTakePort);
}

void Catway::onExternalAddressReceivedTakePort(QString ip, quint16 port)
{
    Q_UNUSED(ip)
    Q_UNUSED(port)
    disconnect(m_externalAddressTakePortConnection);
    takeSocket();
}

// --- AccountManager sync ---

void Catway::onAccountStunChanged()
{
    auto *am = AccountManager::instance();
    m_stunManager->setStunServer(am->stunServer(), am->stunPort());
}

// --- Chat commands -> PlayerNetwork ---

QString Catway::nicknameFromChat(const QString &playerId) const
{
    const QVariantList list = m_chatClient->participants();
    for (const QVariant &v : list) {
        QVariantMap m = v.toMap();
        if (m[QStringLiteral("player_id")].toString() == playerId)
            return m[QStringLiteral("player_nickname")].toString();
    }
    return playerId;
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

    UdpSocketInfo *socketInfo = takeSocket();
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

void Catway::initiateHolePunch(PlayerNetwork *player)
{
    if (!player) return;
    UdpSocketInfo *si = player->socketInfo();
    if (!si || si->publicAddress().isEmpty() || si->publicPort() == 0) {
        emit log("Cannot initiate hole punch: No local public IP/Port for this player slot yet.");
        return;
    }

    emit log(QString("Initiating UDP hole punching for player %1 (%2)").arg(player->nickname(), player->playerId()));

    // 1. Send chat request
    QJsonObject data;
    data[QStringLiteral("ip")] = si->publicAddress();
    data[QStringLiteral("port")] = static_cast<int>(si->publicPort());
    m_chatClient->sendCommand(QStringLiteral("UDP_HOLE_PUNCH_REQUEST"), data, player->playerId());

    // 2. Emit UDP frame (HP:STRIKE)
    sendUdpPunch(player, QStringLiteral("HP:STRIKE"));
}

void Catway::sendUdpMessageToPlayer(PlayerNetwork *player, const QString &message)
{
    if (!player) return;
    sendUdpPunch(player, message);
}

void Catway::sendUdpPunch(PlayerNetwork *player, const QString &content)
{
    if (!player || player->ip().isEmpty() || player->port() == 0) return;
    UdpSocketInfo *si = player->socketInfo();
    if (!si || !si->socket()) return;

    QByteArray data = content.toUtf8();
    QHostAddress addr(player->ip());
    si->socket()->writeDatagram(data, addr, player->port());
    emit log(QString("Sent UDP Punch [%1] to %2:%3").arg(content, player->ip(), QString::number(player->port())));
}

void Catway::onPlayerUdpReadyRead()
{
    QUdpSocket *socket = qobject_cast<QUdpSocket *>(sender());
    if (!socket) return;

    while (socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(socket->pendingDatagramSize());
        QHostAddress senderAddr;
        quint16 senderPort;
        socket->readDatagram(datagram.data(), datagram.size(), &senderAddr, &senderPort);

        // Find which player this socket belongs to
        PlayerNetwork *targetPlayer = nullptr;
        for (PlayerNetwork *p : m_players) {
            if (p->socketInfo() && p->socketInfo()->socket() == socket) {
                targetPlayer = p;
                break;
            }
        }
        
        if (!targetPlayer) {
            QString msg = QString::fromUtf8(datagram);
            emit log(QString("UDP Recv on unassigned socket from %1:%2 -> %3").arg(senderAddr.toString(), QString::number(senderPort), msg));
            continue;
        }

        // Détection du type de paquet via le magic byte
        if (!datagram.isEmpty() && datagram[0] == '\x01') {
            // Paquet fiable (reliable) — les logs [reliable] s'afficheront ici
            qDebug() << "[Catway UDP] Paquet fiable (0x01) reçu, taille" << datagram.size() << "joueur" << targetPlayer->playerId();
            if (targetPlayer->endpoint()) {
                // On retire le magic byte avant de passer à reliable
                const uint8_t *reliableData = reinterpret_cast<const uint8_t *>(datagram.constData()) + 1;
                int reliableSize = datagram.size() - 1;
                
                reliable_endpoint_receive_packet(
                    targetPlayer->endpoint(),
                    const_cast<uint8_t *>(reliableData),
                    reliableSize
                );
            } else {
                qDebug() << "[Catway UDP] Pas d'endpoint reliable pour ce joueur, paquet ignoré.";
            }
        } else {
            // Paquet brut (raw) — chat/dessin/hole punch utilisent ce chemin
            if (datagram.size() <= 80)
                qDebug() << "[Catway UDP] Paquet raw reçu, taille" << datagram.size() << "joueur" << targetPlayer->playerId() << "->" << QString::fromUtf8(datagram);
            // Hole Punching, Chat legacy, Dessin legacy
            QString msg = QString::fromUtf8(datagram);
            
            if (msg == QStringLiteral("HP:REPLY")) {
                targetPlayer->setP2pConnected(true);
                sendUdpPunch(targetPlayer, QStringLiteral("HP:FINAL"));
                emit log("UDP Hole Punching: Received REPLY, sent FINAL. Connection should be open!");
            } else if (msg == QStringLiteral("HP:FINAL")) {
                targetPlayer->setP2pConnected(true);
                emit log("UDP Hole Punching: Received FINAL. Punching SUCCESS!");
            } else if (msg == QStringLiteral("HP:STRIKE")) {
                emit log("UDP Hole Punching: Received STRIKE. Other side is punching.");
            } else if (msg == QStringLiteral("HP:PING")) {
                // Heartbeat silencieux : sert à maintenir le port du routeur ouvert
                // Pas besoin de parser ou logger afin de ne pas spammer la console
            } else {
                // Message de jeu legacy (chat, dessin)
                emit udpMessageReceived(targetPlayer->playerId(), msg);
            }
        }
    }
}

void Catway::onChatCommandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data)
{
    if (commandType == QStringLiteral("REPLY_CONNECTION_INFO")) {
        PlayerNetwork *player = getOrCreatePlayer(senderId);
        if (player) {
            QString ip = data[QStringLiteral("ip")].toString();
            int port = data[QStringLiteral("port")].toInt();
            player->setIp(ip);
            player->setPort(port >= 1 && port <= 65535 ? static_cast<quint16>(port) : 0);
        } else {
            m_pendingCommands.append({senderId, commandType, data});
            if (m_pendingCommands.size() == 1) {
                disconnect(m_externalAddressTakePortConnection);
                m_pendingCommandConnection = connect(m_stunManager, &StunManager::externalAddressReceived,
                                                     this, &Catway::onPendingCommandReady);
                auto *am = AccountManager::instance();
                m_stunManager->setStunServer(am->stunServer(), am->stunPort());
                m_stunManager->startServer();
                m_stunManager->sendStunRequest();
            }
        }
        return;
    }
    if (commandType == QStringLiteral("UDP_HOLE_PUNCH_REQUEST")) {
        PlayerNetwork *player = getOrCreatePlayer(senderId);
        if (player) {
            QString ip = data[QStringLiteral("ip")].toString();
            int port = data[QStringLiteral("port")].toInt();
            player->setIp(ip);
            player->setPort(port >= 1 && port <= 65535 ? static_cast<quint16>(port) : 0);
            
            // Target side: Received chat request, send UDP REPLY
            emit log(QString("Received UDP_HOLE_PUNCH_REQUEST from %1. Sending HP:REPLY...").arg(senderId));
            sendUdpPunch(player, QStringLiteral("HP:REPLY"));
        }
        return;
    }
    if (commandType == QStringLiteral("REQUEST_CONNECTION_INFO")) {
        PlayerNetwork *player = getOrCreatePlayer(senderId);
        if (player) {
            QString ip = data[QStringLiteral("ip")].toString();
            int port = data[QStringLiteral("port")].toInt();
            player->setIp(ip);
            player->setPort(port >= 1 && port <= 65535 ? static_cast<quint16>(port) : 0);
        }
        UdpSocketInfo *socketInfo = player ? qobject_cast<UdpSocketInfo *>(player->socketInfo()) : nullptr;
        if (socketInfo) {
            QJsonObject replyData;
            replyData[QStringLiteral("ip")] = socketInfo->publicAddress();
            replyData[QStringLiteral("port")] = static_cast<int>(socketInfo->publicPort());
            m_chatClient->sendCommand(QStringLiteral("REPLY_CONNECTION_INFO"), replyData, senderId);
            return;
        } else {
            m_pendingCommands.append({senderId, commandType, data});
            if (m_pendingCommands.size() == 1) {
                disconnect(m_externalAddressTakePortConnection);
                m_pendingCommandConnection = connect(m_stunManager, &StunManager::externalAddressReceived,
                                                     this, &Catway::onPendingCommandReady);
                auto *am = AccountManager::instance();
                m_stunManager->setStunServer(am->stunServer(), am->stunPort());
                m_stunManager->startServer();
                m_stunManager->sendStunRequest();
            }
        }
    }
}

void Catway::onPendingCommandReady(QString ip, quint16 port)
{
    Q_UNUSED(ip)
    Q_UNUSED(port)
    disconnect(m_pendingCommandConnection);
    const QList<PendingCommand> toProcess = m_pendingCommands;
    m_pendingCommands.clear();
    for (const PendingCommand &c : toProcess)
        onChatCommandReceived(c.senderId, c.commandType, c.data);
}

// ---------------------------------------------------------------------------
// reliable — send & update
// ---------------------------------------------------------------------------

void Catway::sendReliableToPlayer(PlayerNetwork *player, const QByteArray &data)
{
    if (!player || data.isEmpty()) return;
    reliable_endpoint_t *ep = player->endpoint();
    if (!ep) {
        emit log(QStringLiteral("sendReliableToPlayer: no endpoint for player %1").arg(player->playerId()));
        return;
    }
    reliable_endpoint_send_packet(
        ep,
        reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())),
        data.size()
    );
}

void Catway::onReliableUpdate()
{
    double timeSeconds = m_reliableClock.elapsed() / 1000.0;
    for (PlayerNetwork *player : m_players) {
        reliable_endpoint_t *ep = player ? player->endpoint() : nullptr;
        if (!ep) continue;
        reliable_endpoint_update(ep, timeSeconds);
        reliable_endpoint_clear_acks(ep);
    }
}

void Catway::onHeartbeat()
{
    for (PlayerNetwork *player : m_players) {
        if (player && player->isP2pConnected()) {
            sendUdpPunch(player, QStringLiteral("HP:PING"));
        }
    }
}
