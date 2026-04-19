#include "catway.h"
#include "stun_manager.h"
#include "reliable.h"
#include <QDateTime>
#include <QSet>


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convertit un QByteArray const en pointeur uint8_t* pour reliable.io
/// (l'API reliable ne modifie pas les données passées à send_packet).
static inline uint8_t *toReliableBytes(const QByteArray &ba)
{
    return reinterpret_cast<uint8_t *>(const_cast<char *>(ba.constData()));
}

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

    // Le timer sera démarré dans initReliable() (sur le network thread)
    m_heartbeatTimer = new QTimer(this);
    m_heartbeatTimer->setInterval(m_heartbeatInterval);
    connect(m_heartbeatTimer, &QTimer::timeout, this, &CatwayWorker::onHeartbeat);
}

CatwayWorker::~CatwayWorker()
{
}

void CatwayWorker::setPlayerSnapshots(QList<PlayerSnapshot> snapshots)
{
    // Restaurer l'état persisté dans les nouveaux snapshots
    for (PlayerSnapshot &s : snapshots) {
        auto it = m_lastReceivedByPlayer.constFind(s.playerId);
        if (it != m_lastReceivedByPlayer.constEnd())
            s.lastReceivedMs = it.value();

        auto rt = m_strikeRetryByPlayer.constFind(s.playerId);
        if (rt != m_strikeRetryByPlayer.constEnd())
            s.strikeRetryCount = rt.value();

        // Reset le compteur de retries si la connexion est établie
        if (s.p2pConnected)
            m_strikeRetryByPlayer.remove(s.playerId);
    }
    // Nettoyer les données de joueurs qui n'existent plus
    QSet<QString> activeIds;
    for (const PlayerSnapshot &s : snapshots)
        activeIds.insert(s.playerId);
    for (auto it = m_lastReceivedByPlayer.begin(); it != m_lastReceivedByPlayer.end(); ) {
        if (!activeIds.contains(it.key()))
            it = m_lastReceivedByPlayer.erase(it);
        else
            ++it;
    }
    for (auto it = m_strikeRetryByPlayer.begin(); it != m_strikeRetryByPlayer.end(); ) {
        if (!activeIds.contains(it.key()))
            it = m_strikeRetryByPlayer.erase(it);
        else
            ++it;
    }
    for (auto it = m_lastReliableReceivedMs.begin(); it != m_lastReliableReceivedMs.end(); ) {
        it = activeIds.contains(it.key()) ? ++it : m_lastReliableReceivedMs.erase(it);
    }
    for (auto it = m_lastReliableSentMs.begin(); it != m_lastReliableSentMs.end(); ) {
        it = activeIds.contains(it.key()) ? ++it : m_lastReliableSentMs.erase(it);
    }
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

void CatwayWorker::initReliable()
{
    reliable_init();
    reliable_log_level(RELIABLE_LOG_LEVEL_NONE);
    m_heartbeatTimer->start();
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

UdpSocketInfo* CatwayWorker::takeStunSocket()
{
    UdpSocketInfo *info = m_stunManager->takeSocket();
    if (info) {
        info->moveToThread(Catway::instance()->thread());
    }
    return info;
}

void CatwayWorker::onReliableUpdate()
{
    const qint64 nowMs       = m_reliableClock.elapsed();
    const double timeSeconds = nowMs / 1000.0;

    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.endpoint) continue;
        reliable_endpoint_update(s.endpoint, timeSeconds);
        reliable_endpoint_clear_acks(s.endpoint);
    }

    static const uint8_t kKeepalive[1] = { 0x00 };

    // ACK-flush : 100 ms après réception d'un paquet reliable, si aucun
    // envoi n'a eu lieu depuis → envoyer un keepalive pour piggyback les ACKs.
    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.p2pConnected || !s.endpoint) continue;
        const qint64 lastRecv = m_lastReliableReceivedMs.value(s.playerId, 0);
        const qint64 lastSent = m_lastReliableSentMs.value(s.playerId, 0);
        if (lastRecv > lastSent && (nowMs - lastRecv) >= 100) {
            reliable_endpoint_update(s.endpoint, timeSeconds);
            reliable_endpoint_send_packet(s.endpoint,
                                          const_cast<uint8_t *>(kKeepalive), 1);
            m_lastReliableSentMs[s.playerId] = nowMs;
        }
    }

    // Keepalive périodique toutes les 10 s pour maintenir les stats reliable
    // actives même en l'absence d'ops métier.
    if (nowMs - m_lastKeepaliveMs >= 10000) {
        m_lastKeepaliveMs = nowMs;
        for (const PlayerSnapshot &s : m_playerSnapshots) {
            if (!s.p2pConnected || !s.endpoint) continue;
            reliable_endpoint_update(s.endpoint, timeSeconds);
            reliable_endpoint_send_packet(s.endpoint,
                                          const_cast<uint8_t *>(kKeepalive), 1);
            m_lastReliableSentMs[s.playerId] = nowMs;
        }
    }
}

void CatwayWorker::onSocketReadyRead()
{
    QUdpSocket *socket = qobject_cast<QUdpSocket *>(sender());
    if (!socket) return;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();

    while (socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(socket->pendingDatagramSize());
        QHostAddress senderAddr;
        quint16 senderPort;
        socket->readDatagram(datagram.data(), datagram.size(), &senderAddr, &senderPort);

        if (!datagram.isEmpty() && datagram[0] == '\x01') {
            PlayerSnapshot *targetSnap = nullptr;
            for (PlayerSnapshot &s : m_playerSnapshots) {
                if (s.socket == socket) {
                    if (!s.ip.isEmpty() && QHostAddress(s.ip) == senderAddr && senderPort == s.port) {
                        targetSnap = &s;
                        break;
                    }
                }
            }
            if (targetSnap) {
                targetSnap->lastReceivedMs = now;
                m_lastReceivedByPlayer[targetSnap->playerId] = now;
            }

            if (targetSnap && targetSnap->p2pConnected && targetSnap->endpoint) {
                const uint8_t *reliableData = reinterpret_cast<const uint8_t *>(datagram.constData()) + 1;
                int reliableSize = datagram.size() - 1;
                // time précis avant receive pour que le RTT calculé à
                // partir des ACKs contenus reflète la vraie latence plutôt
                // que la granularité du timer d'update (16 ms en 60 Hz).
                const double timeSeconds = m_reliableClock.nsecsElapsed() / 1e9;
                reliable_endpoint_update(targetSnap->endpoint, timeSeconds);
                reliable_endpoint_receive_packet(targetSnap->endpoint, const_cast<uint8_t *>(reliableData), reliableSize);
                m_lastReliableReceivedMs[targetSnap->playerId] = m_reliableClock.elapsed();
                continue;
            } else if (targetSnap) {
                qDebug() << "[reliable] Received reliable packet from" << targetSnap->playerId
                         << "but p2pConnected=" << targetSnap->p2pConnected
                         << "endpoint=" << (targetSnap->endpoint != nullptr);
            }
        }

        // Tracker la réception pour les paquets raw UDP aussi
        for (PlayerSnapshot &s : m_playerSnapshots) {
            if (s.socket == socket && !s.ip.isEmpty()
                && QHostAddress(s.ip) == senderAddr && senderPort == s.port) {
                s.lastReceivedMs = now;
                m_lastReceivedByPlayer[s.playerId] = now;
                break;
            }
        }

        emit datagramReceived(socket, datagram, senderAddr, senderPort);
    }
}

void CatwayWorker::onHeartbeat()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    constexpr qint64 kTimeoutMs = 30000; // 30s sans réponse → timeout

    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.socket || s.ip.isEmpty() || s.port == 0)
            continue;

        if (s.p2pConnected) {
            // Détecter les connexions mortes
            if (s.lastReceivedMs > 0 && (now - s.lastReceivedMs) > kTimeoutMs) {
                qWarning() << "[Catway] Player" << s.playerId << "timed out (no data for"
                           << (now - s.lastReceivedMs) / 1000 << "s)";
                emit playerTimedOut(s.playerId);
                continue;
            }
            sendDatagram(s.socket, QStringLiteral("HP:PING").toLatin1(), QHostAddress(s.ip), s.port);
        } else if (s.ip.isEmpty() || s.port == 0) {
            continue; // Pas encore d'adresse connue
        } else if (s.strikeRetryCount < 15) {
            // Retry hole punch : renvoyer HP:STRIKE (max 15 essais = ~150s)
            sendDatagram(s.socket, QStringLiteral("HP:STRIKE").toLatin1(), QHostAddress(s.ip), s.port);
            // Incrémenter via le hash persisté pour survivre aux rebuilds de snapshots
            m_strikeRetryByPlayer[s.playerId] = s.strikeRetryCount + 1;
        }
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

void CatwayWorker::broadcastReliable(const QByteArray &data)
{
    // Rafraîchir endpoint->time juste avant l'envoi : sans ça, tous les
    // paquets envoyés dans le même tick du timer d'update partagent la même
    // `time`, ce qui donne rtt=0 et bandwidth=0 en local (où les ACKs
    // reviennent dans le même tick). `reliable_endpoint_update` écrit time
    // et recalcule les stats — coût négligeable vs l'erreur de mesure.
    const qint64 nowMs       = m_reliableClock.elapsed();
    const double timeSeconds = nowMs / 1000.0;
    for (const PlayerSnapshot &s : m_playerSnapshots) {
        if (!s.p2pConnected || !s.endpoint) continue;
        reliable_endpoint_update(s.endpoint, timeSeconds);
        reliable_endpoint_send_packet(s.endpoint,
                                      toReliableBytes(data),
                                      data.size());
        m_lastReliableSentMs[s.playerId] = nowMs;
    }
}

void CatwayWorker::initLastReceived(const QString &playerId)
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    m_lastReceivedByPlayer[playerId] = now;
    for (PlayerSnapshot &s : m_playerSnapshots) {
        if (s.playerId == playerId) {
            s.lastReceivedMs = now;
            break;
        }
    }
}

void CatwayWorker::sendReliablePacket(const QString &playerId, const QByteArray &data)
{
    const PlayerSnapshot *snap = findSnapshot(playerId);
    if (!snap || !snap->p2pConnected || !snap->endpoint) {
        qDebug() << "[reliable] Skip send: player" << playerId
                 << (snap ? (snap->p2pConnected ? "no endpoint" : "not p2pConnected") : "no snapshot");
        return;
    }
    const qint64 nowMs       = m_reliableClock.elapsed();
    const double timeSeconds = nowMs / 1000.0;
    reliable_endpoint_update(snap->endpoint, timeSeconds);
    reliable_endpoint_send_packet(snap->endpoint,
                                  toReliableBytes(data),
                                  data.size());
    m_lastReliableSentMs[playerId] = nowMs;
}

void CatwayWorker::tearDown()
{
    if (m_reliableUpdateTimer)
        m_reliableUpdateTimer->stop();
    if (m_heartbeatTimer)
        m_heartbeatTimer->stop();
}
