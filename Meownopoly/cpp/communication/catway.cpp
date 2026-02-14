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

    // Relay signals from StunManager
    connect(m_stunManager, &StunManager::log, this, &Catway::log);
    connect(m_stunManager, &StunManager::serverStarted, this, &Catway::serverStarted);
    connect(m_stunManager, &StunManager::externalAddressReceived, this, &Catway::externalAddressReceived);

    // Sync STUN parameters from AccountManager
    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    // Initialize STUN params from current AccountManager values
    onAccountStunChanged();

}

void Catway::registerQml()
{
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

void Catway::setPublicPort(quint16 port)
{
    m_stunManager->setPublicPort(port);
}

void Catway::setStunServer(QString ip)
{
    m_stunManager->setStunServer(ip, m_stunManager->getStunPort());
}

void Catway::setStunPort(quint16 port)
{
    m_stunManager->setStunServer(m_stunManager->getStunServer(), port);
}

void Catway::setStunSenderAddress(QString ip)
{
    m_stunManager->setStunSenderAddress(ip);
}

void Catway::setStunSenderPort(quint16 port)
{
    m_stunManager->setStunSenderPort(port);
}

QString Catway::getExternalIp() const
{
    return m_stunManager->getExternalIp();
}

quint16 Catway::getExternalPort() const
{
    return m_stunManager->getExternalPort();
}

QObject *Catway::getSocket() const
{
    return m_stunManager->getSocket();
}

QObject *Catway::takeSocket()
{
    return m_stunManager->takeSocket();
}

// --- STUN scoped handling ---

void Catway::sendStunRequest()
{
    // Connect STUN handler only for this request
    m_stunConnection = connect(m_stunManager, &StunManager::stunResponseReceived,
                               this, &Catway::onStunResponse);

    m_stunManager->sendStunRequest();

    // Start timeout to disconnect handler if no response
    m_stunTimeout->start();
    emit log("STUN request sent, handler connected (timeout 5s)");
}

void Catway::onStunResponse(const QByteArray &datagram, const QHostAddress &sender, quint16 senderPort)
{
    // Disconnect — we got our response
    disconnect(m_stunConnection);
    m_stunTimeout->stop();

    emit log("STUN response received, handler disconnected");

    // Delegate actual parsing to StunManager
    m_stunManager->handleStunResponse(datagram, sender, senderPort);
}

void Catway::onStunTimeout()
{
    // No response received — disconnect handler
    disconnect(m_stunConnection);
    emit log("STUN request timed out, handler disconnected");
}

// --- AccountManager sync ---

void Catway::onAccountStunChanged()
{
    auto *am = AccountManager::instance();
    m_stunManager->setStunServer(am->stunServer(), am->stunPort());
}
