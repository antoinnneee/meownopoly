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

    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(m_heartbeatInterval);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &CatwayWorker::onHeartbeat);
    m_heartbeatTimer->start();
}

CatwayWorker::~CatwayWorker()
{
}

// ---------------------------------------------------------------------------
// P1 + P8 — Snapshot
// ---------------------------------------------------------------------------

void CatwayWorker::setPlayerSnapshots(QList<PlayerSnapshot> snapshots)
{
    m_playerSnapshots = std::move(snapshots);
}

const PlayerSnapshot *CatwayWorker::findSnapshot(const QString &playerId) const
{
    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (s.playerId == playerId)
            return &s;
    }
    return nullptr;
}

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// STUN proxies
// ---------------------------------------------------------------------------

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

UdpSocketInfo* CatwayWorker::takeStunSocket()
{
    UdpSocketInfo *info = m_stunManager->takeSocket();
    if (info) {
        // Repousser vers le thread GUI avant de retourner à Catway
        info->moveToThread(Catway::instance()->thread());
    }
    return info;
}

void CatwayWorker::onReliableUpdate()
{
    double timeSeconds = m_reliableClock.elapsed() / 1000.0;

    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.endpoint) continue;
        reliable_endpoint_update(s.endpoint, timeSeconds);
        reliable_endpoint_clear_acks(s.endpoint);
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

        if (!datagram.isEmpty() && datagram[0] == '\x01') {
            // Recherche du joueur dans les snapshots (thread réseau uniquement)
            const PlayerSnapshot *targetSnap = nullptr;
            for (const PlayerSnapshot &s : m_playerSnapshots) {
                if (s.socket == socket) {
                    if (!s.ip.isEmpty() && QHostAddress(s.ip) == senderAddr && senderPort == s.port) {
                        targetSnap = &s;
                        break;
                    }
                }
            }

            if (targetSnap && targetSnap->p2pConnected && targetSnap->endpoint) {
                const uint8_t *reliableData = reinterpret_cast<const uint8_t *>(datagram.constData()) + 1;
                int reliableSize = datagram.size() - 1;
                reliable_endpoint_receive_packet(targetSnap->endpoint, const_cast<uint8_t *>(reliableData), reliableSize);
                continue;
            } else if (targetSnap) {
                qDebug() << "[reliable] Received reliable packet from" << targetSnap->playerId
                         << "but p2pConnected=" << targetSnap->p2pConnected
                         << "endpoint=" << (targetSnap->endpoint != nullptr);
            }
        }

        emit datagramReceived(socket, datagram, senderAddr, senderPort);
    }
}

// ---------------------------------------------------------------------------
// P1 — Heartbeat — utilise uniquement m_playerSnapshots
// ---------------------------------------------------------------------------

void CatwayWorker::onHeartbeat()
{
    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.p2pConnected || !s.socket || s.ip.isEmpty() || s.port == 0)
            continue;
        sendDatagram(s.socket, QStringLiteral("HP:PING").toLatin1(), QHostAddress(s.ip), s.port);
    }
}

// ---------------------------------------------------------------------------
// Envoi
// ---------------------------------------------------------------------------

void CatwayWorker::sendDatagram(QUdpSocket *socket, const QByteArray &data, const QHostAddress &address, quint16 port)
{
    if (socket && socket->thread() == QThread::currentThread()) {
        socket->writeDatagram(data, address, port);
    } else if (socket) {
        qWarning() << "[CatwayWorker] sendDatagram called on wrong thread for socket" << socket;
    }
}

// P1 — broadcastReliable utilise uniquement m_playerSnapshots
void CatwayWorker::broadcastReliable(const QByteArray &data)
{
    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.p2pConnected || !s.endpoint) continue;
        reliable_endpoint_send_packet(s.endpoint,
                                      reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())),
                                      data.size());
    }
}

// P1 — sendReliablePacket(QString) utilise findSnapshot au lieu de Catway::instance()
void CatwayWorker::sendReliablePacket(const QString &playerId, const QByteArray &data)
{
    const PlayerSnapshot *snap = findSnapshot(playerId);
    if (!snap || !snap->endpoint) {
        qDebug() << "[reliable] Error: No snapshot/endpoint for player" << playerId;
        return;
    }
    reliable_endpoint_send_packet(snap->endpoint,
                                  reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())),
                                  data.size());
}

void CatwayWorker::sendReliablePacket(PlayerNetwork *player, const QByteArray &data)
{
    if (!player) return;
    reliable_endpoint_t *ep = player->endpoint();
    if (!ep) {
        qDebug() << "[reliable] Error: No endpoint for player" << player->playerId();
        return;
    }
    reliable_endpoint_send_packet(ep,
                                  reinterpret_cast<uint8_t *>(const_cast<char *>(data.constData())),
                                  data.size());
}

void CatwayWorker::tearDown()
{
    if (m_reliableUpdateTimer)
        m_reliableUpdateTimer->stop();
}
