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

// ---------------------------------------------------------------------------
// Worker Implementation (Threaded Networking)
// ---------------------------------------------------------------------------

CatwayWorker::CatwayWorker(QObject *parent) : QObject(parent)
{
    m_stunManager = new StunManager(this);
}

CatwayWorker::~CatwayWorker()
{
}

void CatwayWorker::initReliable()
{
    reliable_init();
    reliable_log_level(RELIABLE_LOG_LEVEL_DEBUG);
    reliable_set_printf_function(catway_reliable_printf);
    qDebug() << "[CatwayWorker] reliable init in thread:" << QThread::currentThreadId();
}

void CatwayWorker::startReliableTimer()
{
    m_reliableClock.start();
    m_reliableUpdateTimer = new QTimer(this);
    m_reliableUpdateTimer->setInterval(16); // ~60 Hz
    connect(m_reliableUpdateTimer, &QTimer::timeout, this, &CatwayWorker::onReliableUpdate);
    m_reliableUpdateTimer->start();
}

void CatwayWorker::startStunServer()
{
    m_stunManager->startServer();
}

void CatwayWorker::stopServer()
{
    m_stunManager->stopServer();
}

void CatwayWorker::sendStunRequest()
{
    m_stunManager->sendStunRequest();
}

void CatwayWorker::setStunServerInfo(const QString &host, quint16 port)
{
    m_stunManager->setStunServer(host, port);
}

UdpSocketInfo* CatwayWorker::takeSocket()
{
    UdpSocketInfo *info = m_stunManager->takeSocket();
    if (info) {
        // MUST move from the thread it currently belongs to (NetworkThread)
        // push it to the GUI thread.
        info->moveToThread(Catway::instance()->thread());
    }
    return info;
}

void CatwayWorker::onReliableUpdate()
{
    double timeSeconds = m_reliableClock.elapsed() / 1000.0;
    
    // Accéder aux players via le singleton Catway.
    // Note : bien que les QObjects vivent sur le thread GUI, les pointeurs `reliable_endpoint_t*`
    // sont manipulés exclusivement pour les E/S réseau.
    Catway *catway = Catway::instance();
    if (!catway) return;

    for (int i = 0; i < catway->playersCount(); ++i) {
        PlayerNetwork *player = catway->playerAt(i);
        reliable_endpoint_t *ep = player ? player->endpoint() : nullptr;
        if (!ep) continue;
        reliable_endpoint_update(ep, timeSeconds);
        reliable_endpoint_clear_acks(ep);
    }
}

void CatwayWorker::onSocketReadyRead()
{
    QUdpSocket *socket = qobject_cast<QUdpSocket *>(sender());
    if (!socket) return;

    while (socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(socket->pendingDatagramSize());
        QHostAddress senderAddr;
        quint16 senderPort;
        socket->readDatagram(datagram.data(), datagram.size(), &senderAddr, &senderPort);

        // --- NEW: Handle reliable packets directly on the network thread ---
        if (!datagram.isEmpty() && datagram[0] == '\x01') {
             Catway *catway = Catway::instance();
             if (catway) {
                 PlayerNetwork *targetPlayer = nullptr;
                 for (int i = 0; i < catway->playersCount(); ++i) {
                     PlayerNetwork *p = catway->playerAt(i);
                     if (p && p->socketInfo() && p->socketInfo()->socket() == socket) {
                         // Robust security check: use QHostAddress comparison
                         if (!p->ip().isEmpty() && QHostAddress(p->ip()) == senderAddr && senderPort == p->port()) {
                             targetPlayer = p;
                             break;
                         }
                     }
                 }

                 if (targetPlayer && targetPlayer->isP2pConnected() && targetPlayer->endpoint()) {
                     const uint8_t *reliableData = reinterpret_cast<const uint8_t *>(datagram.constData()) + 1;
                     int reliableSize = datagram.size() - 1;
                     reliable_endpoint_receive_packet(targetPlayer->endpoint(), const_cast<uint8_t *>(reliableData), reliableSize);
                     continue; // Don't relay to Catway GUI thread
                 } else if (targetPlayer) {
                     qDebug() << "[reliable] Received reliable packet from" << targetPlayer->playerId() 
                              << "but p2pConnected=" << targetPlayer->isP2pConnected() 
                              << "endpoint=" << (targetPlayer->endpoint() != nullptr);
                 }
             }
        }
        // ------------------------------------------------------------------

        emit datagramReceived(socket, datagram, senderAddr, senderPort);
    }
}

void CatwayWorker::sendDatagram(QUdpSocket *socket, const QByteArray &data, const QHostAddress &address, quint16 port)
{
    if (socket && socket->thread() == QThread::currentThread()) {
        socket->writeDatagram(data, address, port);
    } else if (socket) {
        qWarning() << "[CatwayWorker] sendDatagram called on wrong thread for socket" << socket;
    }
}

void CatwayWorker::sendReliablePacket(const QString &playerId, const QByteArray &data)
{
    Catway *catway = Catway::instance();
    if (!catway) return;

    PlayerNetwork *player = catway->playerById(playerId);
    if (!player) return;

    reliable_endpoint_t *ep = player->endpoint();
    if (!ep) {
        qDebug() << "[reliable] Error: No endpoint for player" << playerId;
        return;
    }

    qDebug() << "[reliable] Sending packet to" << playerId << "size" << data.size();
    reliable_endpoint_send_packet(ep, reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())), data.size());
}

void CatwayWorker::tearDown()
{
    if (m_reliableUpdateTimer) {
        m_reliableUpdateTimer->stop();
    }
}

// ---------------------------------------------------------------------------
// Callbacks C statiques pour reliable
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
    if (!player) return;

    UdpSocketInfo *si = player->socketInfo();
    QString targetIp = player->ip();
    quint16 targetPort = player->port();

    if (!si || !si->socket() || targetIp.isEmpty() || targetPort == 0) {
        qDebug() << "[reliable] Skip transmit: socket or target address missing for player" << (player ? player->playerId() : "unknown");
        return;
    }

    QByteArray datagram;
    datagram.reserve(1 + packet_bytes);
    datagram.append('\x01');
    datagram.append(reinterpret_cast<const char *>(packet_data), packet_bytes);
    
    // Check if we are on the thread owning the socket
    if (si->socket()->thread() == QThread::currentThread()) {
        si->socket()->writeDatagram(datagram, QHostAddress(targetIp), targetPort);
    } else {
        // Fallback to Catway's thread-safe delegator if called from another thread
        Catway::instance()->sendUdpPunch(player, datagram);
    }
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
        emit ctx->catway->reliableMessageReceivedString(senderId, QString::fromUtf8(data));
    }, Qt::QueuedConnection);
    return 1; // 1 = ACK le paquet
}

Catway *Catway::m_pThis = nullptr;

Catway::Catway(QObject *parent)
    : QObject(parent)
{
    // qDebug() << "INIT CATWAY";
    // === Threaded Networking Setup ===
    m_networkThread = new QThread(this);
    m_worker = new CatwayWorker();
    
    // Le Worker gère désormais le StunManager

    m_worker->moveToThread(m_networkThread);
    
    // Lancer la lib `reliable` dans le nouveau thread une fois démarré
    connect(m_networkThread, &QThread::started, m_worker, &CatwayWorker::initReliable);
    connect(m_networkThread, &QThread::started, m_worker, &CatwayWorker::startReliableTimer);

    // Mettre fin au worker proprement quand le thread s'arrête
    connect(m_networkThread, &QThread::finished, m_worker, &QObject::deleteLater);

    m_networkThread->start();
    // =================================

    // Client de chat intégré (exposé en QML via la propriété chatClient)
    m_chatClient = new ChatClient(this);
    connect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

    // Relay signals from StunManager
    connect(m_worker->stunManager(), &StunManager::log, this, &Catway::log);
    connect(m_worker->stunManager(), &StunManager::serverStarted, this, &Catway::stunServerStarted);
    connect(m_worker->stunManager(), &StunManager::stunFailed, this, &Catway::onStunRequestFailed);

    // Sync STUN parameters from AccountManager
    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    // Initialize STUN params from current AccountManager values
    onAccountStunChanged();

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

void Catway::setChatClient(ChatClient *client)
{
    if (m_chatClient == client)
        return;

    if (m_chatClient)
        disconnect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

    m_chatClient = client;

    if (m_chatClient)
        connect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

    emit chatClientChanged();
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

void Catway::startStunServer()
{
    QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
}

void Catway::stopServer()
{
    QMetaObject::invokeMethod(m_worker, "stopServer", Qt::QueuedConnection);
}

void Catway::setStunPort(quint16 port)
{
    QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, m_worker->stunManager()->getStunServer()), Q_ARG(quint16, port));
}
void Catway::setStunServerURL(QString url)
{
    QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, url), Q_ARG(quint16, m_worker->stunManager()->getStunPort()));
}

QString Catway::getExternalIp() const
{
    if (!m_localSocketInfos.isEmpty()) {
        UdpSocketInfo *last = m_localSocketInfos.last();
        QString addr = last->publicAddress();
        if (!addr.isEmpty())
            return addr;
    }
    QString res;
    QMetaObject::invokeMethod(m_worker->stunManager(), "getExternalIp", Qt::BlockingQueuedConnection, Q_RETURN_ARG(QString, res));
    return res;
}

quint16 Catway::getExternalPort() const
{
    if (!m_localSocketInfos.isEmpty()) {
        UdpSocketInfo *last = m_localSocketInfos.last();
        if (last->publicPort() != 0)
            return last->publicPort();
    }
    quint16 res = 0;
    QMetaObject::invokeMethod(m_worker->stunManager(), "getExternalPort", Qt::BlockingQueuedConnection, Q_RETURN_ARG(quint16, res));
    return res;
}

QObject *Catway::getSocket() const
{
    QUdpSocket *res = nullptr;
    QMetaObject::invokeMethod(m_worker->stunManager(), "getSocket", Qt::BlockingQueuedConnection, Q_RETURN_ARG(QUdpSocket*, res));
    return res;
}

QObject *Catway::currentSocketInfo() const
{
    UdpSocketInfo *res = nullptr;
    QMetaObject::invokeMethod(m_worker->stunManager(), "currentSocketInfo", Qt::BlockingQueuedConnection, Q_RETURN_ARG(UdpSocketInfo*, res));
    return res;
}

UdpSocketInfo *Catway::takeSocket()
{
    UdpSocketInfo *info = nullptr;
    // Call takeSocket on worker thread and wait for result (BlockingQueuedConnection)
    QMetaObject::invokeMethod(m_worker, "takeSocket", Qt::BlockingQueuedConnection, Q_RETURN_ARG(UdpSocketInfo*, info));

    if (info) {
        // Migration rule: must move to GUI thread before parenting to Catway
        // (Now performed by the worker before returning)
        info->setParent(this);
        
        m_localSocketInfos.append(info);
        if (info->socket()) {
            // The QUdpSocket itself stays in the network thread for processing
            info->socket()->setParent(nullptr); 
            info->socket()->moveToThread(m_networkThread);
            
            // Connect socket signals to worker slots (both on network thread)
            connect(info->socket(), &QUdpSocket::readyRead, m_worker, &CatwayWorker::onSocketReadyRead);
            // Relay datagrams from worker (network thread) to Catway (GUI thread)
            connect(m_worker, &CatwayWorker::datagramReceived, this, &Catway::onDatagramReceived, Qt::QueuedConnection);
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

    if (player->socketInfo() && player->socketInfo() == currentSocketInfo()) {
        player->setSocketInfo(takeSocket());
    } else if (player->socketInfo() && player->socketInfo()->socket()) {
        // Just in case it was created freely, ensure readyRead is connected
        // although normally they should be in localPorts already via takeSocket()
        QUdpSocket *sock = player->socketInfo()->socket();
        if (sock->thread() != m_networkThread) {
            sock->setParent(nullptr);
            sock->moveToThread(m_networkThread);
        }
        disconnect(sock, &QUdpSocket::readyRead, m_worker, &CatwayWorker::onSocketReadyRead);
        connect(sock, &QUdpSocket::readyRead, m_worker, &CatwayWorker::onSocketReadyRead);

        // disconnect(m_worker, &CatwayWorker::datagramReceived, this, &Catway::onDatagramReceived);
        connect(m_worker, &CatwayWorker::datagramReceived, this, &Catway::onDatagramReceived, Qt::QueuedConnection);
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
    
    // Libérer le socket si plus utilisé (Faille 5 - Fuite de Sockets)
    UdpSocketInfo *si = player->socketInfo();
    if (si) {
        bool inUse = false;
        if (currentSocketInfo() == si) {
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

int Catway::playersCount() const
{
    return m_players.size();
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
    QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);
}

void Catway::setupNewPort()
{
    auto *am = AccountManager::instance();
    qDebug()<<"setupNewPort";
    
    QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
    QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
    QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);

    disconnect(m_externalAddressTakePortConnection);
    m_externalAddressTakePortConnection = connect(m_worker->stunManager(), &StunManager::externalAddressReceived,
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
    QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
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
    sendUdpPunch(player, content.toUtf8());
}

void Catway::sendUdpPunch(PlayerNetwork *player, const QByteArray &data)
{
    if (!player || player->ip().isEmpty() || player->port() == 0) return;
    UdpSocketInfo *si = player->socketInfo();
    if (!si || !si->socket()) return;

    QHostAddress addr(player->ip());
    QMetaObject::invokeMethod(m_worker, "sendDatagram", Qt::QueuedConnection,
                              Q_ARG(QUdpSocket*, si->socket()),
                              Q_ARG(QByteArray, data),
                              Q_ARG(QHostAddress, addr),
                              Q_ARG(quint16, player->port()));
    
    if (data.size() > 0 && data[0] != '\x01') {
        emit log(QString("Sent UDP Punch [%1] to %2:%3").arg(QString::fromUtf8(data), player->ip(), QString::number(player->port())));
    }
}

void Catway::onDatagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress senderAddr, quint16 senderPort)
{
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
        return;
    }

    // --- FILTRE DE SÉCURITÉ (ANTI-SPOOFING) ---
    // On n'accepte le paquet que s'il vient de l'IP et du port publics du joueur ciblé.
    if (targetPlayer->ip().isEmpty() || senderAddr.toString() != targetPlayer->ip() || senderPort != targetPlayer->port()) {
        qWarning() << "[SÉCURITÉ] Paquet UDP spoofé ou inconnu ignoré. Provenance:" 
                    << senderAddr.toString() << ":" << senderPort 
                    << "- Attendu:" << targetPlayer->ip() << ":" << targetPlayer->port();
        return;
    }
    // ------------------------------------------

        // Détection du type de paquet via le magic byte
        if (!datagram.isEmpty() && datagram[0] == '\x01') {
            // NOTE: Les paquets fiables sont désormais traités directement dans CatwayWorker::onSocketReadyRead.
            // Si on arrive ici, c'est que le worker n'a pas pu identifier le joueur ou que la sécu a échoué.
            qDebug() << "[Catway GUI] Paquet fiable (0x01) reçu mais ignoré (devrait être géré par le worker)";
            return;
        } else {
        // Paquet brut (raw) — chat/dessin/hole punch utilisent ce chemin
        if (datagram.size() <= 80)
            // qDebug() << "[Catway UDP] Paquet raw reçu, taille" << datagram.size() << "joueur" << targetPlayer->playerId() << "->" << QString::fromUtf8(datagram);
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
                m_pendingCommandConnection = connect(m_worker->stunManager(), &StunManager::externalAddressReceived,
                                                     this, &Catway::onPendingCommandReady);
                auto *am = AccountManager::instance();
                QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
                QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
                QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);
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
                m_pendingCommandConnection = connect(m_worker->stunManager(), &StunManager::externalAddressReceived,
                                                     this, &Catway::onPendingCommandReady);
                auto *am = AccountManager::instance();
                QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
                QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
                QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);
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

void Catway::onStunRequestFailed()
{
    // Faille 6 (Deadlock): Si le STUN échoue, on doit vider la file d'attente
    // sinon Catway restera bloqué indéfiniment à attendre une adresse publique.
    if (!m_pendingCommands.isEmpty()) {
        emit log(QString("SÉCURITÉ: Requête STUN échouée. Annulation de %1 commandes en attente (évite le Deadlock).").arg(m_pendingCommands.size()));
        m_pendingCommands.clear();
        disconnect(m_pendingCommandConnection);
    }
}

// ---------------------------------------------------------------------------
// reliable — send & update
// ---------------------------------------------------------------------------

void Catway::sendReliableToPlayer(PlayerNetwork *player, const QByteArray &data)
{
    if (!player || data.isEmpty()) return;
    QMetaObject::invokeMethod(m_worker, "sendReliablePacket", Qt::QueuedConnection,
                              Q_ARG(QString, player->playerId()),
                              Q_ARG(QByteArray, data));
}

// Removed Catway::onReliableUpdate as it is now in CatwayWorker

void Catway::onHeartbeat()
{
    for (PlayerNetwork *player : m_players) {
        if (player && player->isP2pConnected()) {
            sendUdpPunch(player, QStringLiteral("HP:PING"));
        }
    }
}
