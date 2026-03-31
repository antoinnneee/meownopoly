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
    // Assigner m_pThis immédiatement : le thread réseau (timer 16ms) peut appeler
    // instance() avant que le constructeur soit terminé → race condition sinon.
    Q_ASSERT_X(m_pThis == nullptr, "Catway::Catway", "Catway doit être un singleton");
    m_pThis = this;

    qRegisterMetaType<QList<PlayerSnapshot>>("QList<PlayerSnapshot>");

    // === Threaded Networking Setup ===
    m_networkThread = new QThread(this);
    m_worker = new CatwayWorker();

    m_worker->moveToThread(m_networkThread);

    connect(m_networkThread, &QThread::started, m_worker, &CatwayWorker::initReliable);
    connect(m_networkThread, &QThread::started, m_worker, &CatwayWorker::startReliableTimer);
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

    // P3 — Cache du socket STUN courant, évite les BlockingQueuedConnection
    connect(m_worker->stunManager(), &StunManager::currentSocketInfoChanged,
            this, &Catway::onCurrentSocketInfoChanged, Qt::QueuedConnection);

    // P5 — Connexion unique de datagramReceived, établie une seule fois ici
    connect(m_worker, &CatwayWorker::datagramReceived,
            this, &Catway::onDatagramReceived, Qt::QueuedConnection);

    // Sync STUN parameters from AccountManager
    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    onAccountStunChanged();
}

Catway::~Catway()
{
    if (m_networkThread) {
        m_networkThread->quit();
        if (!m_networkThread->wait(3000)) {
            m_networkThread->terminate();
            m_networkThread->wait();
        }
    }
}


void Catway::setChatClient(ChatClient *client)
{
    if (m_chatClient == client)
        return;

    if (m_chatClient) {
        disconnect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);
        if (m_chatClient->parent() == this)
            m_chatClient->deleteLater();
    }

    m_chatClient = client;

    if (m_chatClient)
        connect(m_chatClient, &ChatClient::commandReceived, this, &Catway::onChatCommandReceived);

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

    // --- FILTRE DE SÉCURITÉ (ANTI-SPOOFING) ---
    if (targetPlayer->ip().isEmpty() || senderAddr.toString() != targetPlayer->ip() || senderPort != targetPlayer->port()) {
        qWarning() << "[SÉCURITÉ] Paquet UDP spoofé ou inconnu ignoré. Provenance:"
                    << senderAddr.toString() << ":" << senderPort
                    << "- Attendu:" << targetPlayer->ip() << ":" << targetPlayer->port();
        return;
    }
    // ------------------------------------------

    if (!datagram.isEmpty() && datagram[0] == '\x01') {
        // Les paquets fiables sont traités directement dans CatwayWorker::onSocketReadyRead.
        qWarning() << "[Catway GUI] Paquet fiable (0x01) reçu mais ignoré (devrait être géré par le worker). Ce message ne devrais pas etre visible";
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
    // Table statique dans la méthode : les pointeurs sur handlers privés ne sont valides qu’ici (accès membre).
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
            const QString ip = data[QStringLiteral("ip")].toString();
            const int port = data[QStringLiteral("port")].toInt();
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

// ---------------------------------------------------------------------------
// reliable — send & update
// ---------------------------------------------------------------------------

void Catway::sendReliableToPlayer(PlayerNetwork *player, const QByteArray &data)
{
    if (!player || data.isEmpty()) return;
    QMetaObject::invokeMethod(m_worker, "sendReliablePacket", Qt::QueuedConnection,
                              Q_ARG(PlayerNetwork*, player),
                              Q_ARG(QByteArray, data));
}

void Catway::broadcastReliable(const QByteArray &data)
{
    QMetaObject::invokeMethod(m_worker, "broadcastReliable", Qt::QueuedConnection,
                              Q_ARG(QByteArray, data));
}

void Catway::broadcastRaw(const QString &message)
{
    for (PlayerNetwork *player : m_players) {
        if (player && player->isP2pConnected())
            sendUdpDatagram(player, message);
    }
}
