#include "catway.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QHostAddress>
#include <QUdpSocket>

#include "stun_manager.h"
#include "../account/account_manager.h"

Catway *Catway::m_pThis = nullptr;

Catway::Catway(QObject *parent)
    : QObject(parent)
{
    // Create StunManager owned by Catway
    m_stunManager = new StunManager(this);

    // Client de chat intégré (exposé en QML via la propriété chatClient)
    m_chatClient = new ChatClient(this);

    // Relay signals from StunManager
    connect(m_stunManager, &StunManager::log, this, &Catway::log);
    connect(m_stunManager, &StunManager::serverStarted, this, &Catway::serverStarted);

    // Sync STUN parameters from AccountManager
    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    // Initialize STUN params from current AccountManager values
    onAccountStunChanged();

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
    player->setParent(this);
    m_players.append(player);
    emit playersChanged();
}

void Catway::removePlayer(PlayerNetwork *player)
{
    if (!player || !m_players.removeOne(player))
        return;
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
