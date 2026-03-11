#include "catway.h"
#include "stun_manager.h"
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

CatwayWorker::CatwayWorker(QObject *parent) : QObject(parent)
{
    m_stunManager = new StunManager(this);

    // Timer du Heartbeat P2P
    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(m_heartbeatInterval);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &CatwayWorker::onHeartbeat);
    m_heartbeatTimer->start();

}

CatwayWorker::~CatwayWorker()
{
}

void CatwayWorker::initReliable()
{
    reliable_init();
    reliable_log_level(RELIABLE_LOG_LEVEL_NONE);
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

void CatwayWorker::stopStunServer()
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

void CatwayWorker::broadcastReliable(const QByteArray &data)
{
    Catway *catway = Catway::instance();
    if (!catway) return;

    for (int i = 0; i < catway->playersCount(); ++i) {
        PlayerNetwork *player = catway->playerAt(i);
        if (player && player->isP2pConnected())
            sendReliablePacket(player, data);
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

    reliable_endpoint_send_packet(ep, reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())), data.size());
}

void CatwayWorker::sendReliablePacket(PlayerNetwork *player, const QByteArray &data)
{
    if (!player) return;

    reliable_endpoint_t *ep = player->endpoint();
    if (!ep) {
        qDebug() << "[reliable] Error: No endpoint for player" << player->playerId();
        return;
    }

    reliable_endpoint_send_packet(ep, reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())), data.size());
}

void CatwayWorker::tearDown()
{
    if (m_reliableUpdateTimer) {
        m_reliableUpdateTimer->stop();
    }
}


// Removed Catway::onReliableUpdate as it is now in CatwayWorker
void CatwayWorker::onHeartbeat()
{
    Catway *catway = Catway::instance();
    if (!catway) return;


    for (int i = 0; i < catway->playersCount(); ++i) {
        PlayerNetwork *player = catway->playerAt(i);
        if (player && player->isP2pConnected()) {
            UdpSocketInfo *si = player->socketInfo();
            if (!si || !si->socket()) continue;

            QHostAddress addr(player->ip());

            sendDatagram(si->socket(), QStringLiteral("HP:PING").toLatin1(), addr, player->port());
        }
    }
}

