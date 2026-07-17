#include "catway.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QHostAddress>
#include <QUdpSocket>
#include <QVariant>
#include <QDebug>
#include <QSet>

#include "stun_manager.h"
#include "../account/account_manager.h"
#include "../tools/logger.h"

Catway *Catway::m_pThis = nullptr;


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
QObject *Catway::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return Catway::instance();
}


Catway::Catway(QObject *parent)
    : QObject(parent)
{
    // Réseau sur thread dédié : instance() peut être appelé avant la fin du constructeur.
    Q_ASSERT_X(m_pThis == nullptr, "Catway::Catway", "Catway doit être un singleton");
    m_pThis = this;

    qRegisterMetaType<QList<PlayerSnapshot>>("QList<PlayerSnapshot>");

    m_networkThread = new QThread(this);
    m_worker = new CatwayWorker();

    m_worker->moveToThread(m_networkThread);

    connect(m_networkThread, &QThread::started, m_worker, &CatwayWorker::initReliable);
    connect(m_networkThread, &QThread::started, m_worker, &CatwayWorker::startReliableTimer);
    connect(m_networkThread, &QThread::finished, m_worker, &QObject::deleteLater);

    m_networkThread->start();

    m_chatClient = new ChatClient(this);
    connect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

    connect(m_worker->stunManager(), &StunManager::log, this, &Catway::log);
    connect(m_worker->stunManager(), &StunManager::serverStarted, this, &Catway::stunServerStarted);
    connect(m_worker->stunManager(), &StunManager::stunFailed, this, &Catway::onStunRequestFailed);

    connect(m_worker->stunManager(), &StunManager::currentSocketInfoChanged,
            this, &Catway::onCurrentSocketInfoChanged, Qt::QueuedConnection);

    connect(m_worker, &CatwayWorker::datagramReceived,
            this, &Catway::onDatagramReceived, Qt::QueuedConnection);

    connect(m_worker, &CatwayWorker::playerTimedOut, this, [this](const QString &playerId) {
        PlayerNetwork *p = playerById(playerId);
        if (p && p->isP2pConnected()) {
            p->setP2pConnected(false);
            emit log(QString("Player %1 timed out — marked as disconnected").arg(playerId));
        }
        // relay aux couches session (EditorSession, GameSession).
        emit playerTimedOut(playerId);
    }, Qt::QueuedConnection);

    // B2 : relais GUI des issues d'envoi V3 (ACK applicatif / échec définitif).
    connect(m_worker, &CatwayWorker::v3MessageAcked,
            this, &Catway::v3MessageAcked, Qt::QueuedConnection);
    connect(m_worker, &CatwayWorker::v3MessageFailed,
            this, &Catway::v3MessageFailed, Qt::QueuedConnection);

    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    onAccountStunChanged();
}

Catway::~Catway()
{
    // Détacher le ChatClient (souvent possédé par QML, déjà détruit à ce stade) AVANT
    // de stopper le réseau. On évite que des datagrammes en vol ne déréférencent un
    // pointeur dangling pendant la phase de teardown du thread réseau.
    if (m_chatClient) {
        disconnect(m_chatClient.data(), &ChatClient::commandReceived,
                   this, &Catway::onChatCommandReceived);
        m_chatClient.clear();
    }

    if (m_networkThread) {
        // Arrêter proprement les timers et la boucle reliable avant de quitter le thread
        QMetaObject::invokeMethod(m_worker, "tearDown", Qt::BlockingQueuedConnection);
        m_networkThread->quit();
        if (!m_networkThread->wait(3000)) {
            m_networkThread->terminate();
            m_networkThread->wait();
        }
    }
}


void Catway::setChatClient(ChatClient *client)
{
    if (m_chatClient.data() == client)
        return;

    if (m_chatClient) {
        disconnect(m_chatClient.data(), &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);
        if (m_chatClient->parent() == this)
            m_chatClient->deleteLater();
    }

    m_chatClient = client;

    if (m_chatClient)
        connect(m_chatClient.data(), &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

    emit chatClientChanged();
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

void Catway::onAccountStunChanged()
{
    auto *am = AccountManager::instance();
    QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection, Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
}

QString Catway::nicknameFromChat(const QString &playerId) const
{
    if (!m_chatClient)
        return playerId;
    const QVariantList list = m_chatClient->participants();
    for (const QVariant &v : list) {
        QVariantMap m = v.toMap();
        if (m[QStringLiteral("player_id")].toString() == playerId)
            return m[QStringLiteral("player_nickname")].toString();
    }
    return playerId;
}


void Catway::sendUdpMessageToPlayer(PlayerNetwork *player, const QString &message)
{
    if (!player) return;
    sendUdpDatagram(player, message);
}

void Catway::sendUdpDatagram(PlayerNetwork *player, const QString &content)
{
    sendUdpDatagram(player, content.toUtf8());
}

void Catway::sendUdpDatagram(PlayerNetwork *player, const QByteArray &data)
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

    if (data.startsWith("HP:") && data != "HP:PING") {
        emit log(QString("Sent UDP Punch [%1] to %2:%3").arg(QString::fromUtf8(data), player->ip(), QString::number(player->port())));
    }
}

void Catway::onDatagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress senderAddr, quint16 senderPort)
{
    using HolePunchDatagramHandler = void (Catway::*)(PlayerNetwork *);
    static const QHash<QString, HolePunchDatagramHandler> kHolePunchHandlers = {
        { QStringLiteral("HP:REPLY"),  &Catway::handleHolePunchReply },
        { QStringLiteral("HP:FINAL"),  &Catway::handleHolePunchFinal },
        { QStringLiteral("HP:STRIKE"), &Catway::handleHolePunchStrike },
        { QStringLiteral("HP:PING"),   &Catway::handleHolePunchPing },
    };

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

    if (targetPlayer->ip().isEmpty() || senderAddr.toString() != targetPlayer->ip() || senderPort != targetPlayer->port()) {
        qWarning() << "[SÉCURITÉ] Paquet UDP spoofé ou inconnu ignoré. Provenance:"
                    << senderAddr.toString() << ":" << senderPort
                    << "- Attendu:" << targetPlayer->ip() << ":" << targetPlayer->port();
        return;
    }

    if (!datagram.isEmpty() && datagram[0] == '\x01') {
        qWarning() << "[Catway GUI] Paquet fiable (0x01) reçu côté GUI (attendu dans CatwayWorker::onSocketReadyRead)";
        return;
    }

    QString msg = QString::fromUtf8(datagram);
    const HolePunchDatagramHandler handler = kHolePunchHandlers.value(msg);
    if (handler) {
        (this->*handler)(targetPlayer);
        return;
    }
    emit udpMessageReceived(targetPlayer->playerId(), msg);
}

namespace {

const QSet<QString> kChatCommandsWithConnectionInfo = {
    QStringLiteral("REPLY_CONNECTION_INFO"),
    QStringLiteral("UDP_HOLE_PUNCH_REQUEST"),
    QStringLiteral("REQUEST_CONNECTION_INFO"),
};

} // namespace

void Catway::onChatCommandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data)
{
    using ChatCommandHandler = void (Catway::*)(const QString &, const QJsonObject &, PlayerNetwork *);
    static const QHash<QString, ChatCommandHandler> kHandlers = {
        { QStringLiteral("REPLY_CONNECTION_INFO"), &Catway::handleChatReplyConnectionInfo },
        { QStringLiteral("UDP_HOLE_PUNCH_REQUEST"), &Catway::handleChatUdpHolePunchRequest },
        { QStringLiteral("REQUEST_CONNECTION_INFO"), &Catway::handleChatRequestConnectionInfo },
    };

    PlayerNetwork *player = nullptr;
    if (kChatCommandsWithConnectionInfo.contains(commandType)) {
        player = getOrCreatePlayer(senderId);
        if (player) {
            QString ip = data[QStringLiteral("ip")].toString();
            int port = data[QStringLiteral("port")].toInt();
            const int localPort = data[QStringLiteral("localPort")].toInt();

            // Détection same-network : si le peer a la même IP publique que nous,
            // on passe en loopback + port local (NAT hairpinning non garanti)
            if (localPort > 0 && !ip.isEmpty()) {
                bool samePublicIp = false;
                for (UdpSocketInfo *si : m_localSocketInfos) {
                    if (si && si->publicAddress() == ip) { samePublicIp = true; break; }
                }
                if (!samePublicIp && m_currentStunSocketInfo && m_currentStunSocketInfo->publicAddress() == ip)
                    samePublicIp = true;

                if (samePublicIp) {
                    emit log(QString("Same public IP detected (%1) — switching to 127.0.0.1:%2").arg(ip, QString::number(localPort)));
                    ip = QStringLiteral("127.0.0.1");
                    port = localPort;
                }
            }

            player->setIp(ip);
            player->setPort(port >= 1 && port <= 65535 ? static_cast<quint16>(port) : 0);
        }
    }

    const ChatCommandHandler handler = kHandlers.value(commandType);
    if (handler)
        (this->*handler)(senderId, data, player);
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

void Catway::sendReliableToPlayer(PlayerNetwork *player, const QByteArray &data)
{
    if (!player || data.isEmpty()) return;
    const QString playerId = player->playerId();
    if (playerId.isEmpty()) return;
    QMetaObject::invokeMethod(m_worker, "sendReliablePacket", Qt::QueuedConnection,
                              Q_ARG(QString, playerId),
                              Q_ARG(QByteArray, data));
}

void Catway::broadcastReliable(const QByteArray &data)
{
    QMetaObject::invokeMethod(m_worker, "broadcastReliable", Qt::QueuedConnection,
                              Q_ARG(QByteArray, data));
}

void Catway::sendV3Reliable(const QString &playerId, const QByteArray &packet,
                            const QString &messageId)
{
    if (playerId.isEmpty() || packet.isEmpty() || messageId.isEmpty()) return;
    QMetaObject::invokeMethod(m_worker, "sendV3Reliable", Qt::QueuedConnection,
                              Q_ARG(QString, playerId),
                              Q_ARG(QByteArray, packet),
                              Q_ARG(QString, messageId));
}

void Catway::broadcastV3Reliable(const QByteArray &packet, const QString &messageId)
{
    if (packet.isEmpty() || messageId.isEmpty()) return;
    QMetaObject::invokeMethod(m_worker, "broadcastV3Reliable", Qt::QueuedConnection,
                              Q_ARG(QByteArray, packet),
                              Q_ARG(QString, messageId));
}

void Catway::broadcastRaw(const QString &message)
{
    for (PlayerNetwork *player : m_players) {
        if (player && player->isP2pConnected())
            sendUdpDatagram(player, message);
    }
}
