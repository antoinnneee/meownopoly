#include "catway.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QHostAddress>

#include "../tools/server_manager.h"
#include "../account/account_manager.h"

Catway *Catway::m_pThis = nullptr;

Catway::Catway(QObject *parent)
    : QObject(parent)
{
    // Create ServerManager owned by Catway
    m_serverManager = new ServerManager(this);

    // Relay signals from ServerManager
    connect(m_serverManager, &ServerManager::log, this, &Catway::log);
    connect(m_serverManager, &ServerManager::serverStarted, this, &Catway::serverStarted);
    connect(m_serverManager, &ServerManager::externalAddressReceived, this, &Catway::externalAddressReceived);

    // Sync STUN parameters from AccountManager
    auto *am = AccountManager::instance();
    connect(am, &AccountManager::stunServerChanged, this, &Catway::onAccountStunChanged);
    connect(am, &AccountManager::stunPortChanged, this, &Catway::onAccountStunChanged);

    // Initialize STUN params from current AccountManager values
    onAccountStunChanged();

    // Setup STUN timeout timer (single-shot)
    m_stunTimeout = new QTimer(this);
    m_stunTimeout->setSingleShot(true);
    m_stunTimeout->setInterval(5000);
    connect(m_stunTimeout, &QTimer::timeout, this, &Catway::onStunTimeout);
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
    m_serverManager->startServer();
}

void Catway::stopServer()
{
    m_serverManager->stopServer();
}

void Catway::sendMessageToPeer(QString message)
{
    m_serverManager->sendMessageToPeer(message);
}

void Catway::setPeer(QString ip, quint16 port)
{
    m_serverManager->setPeer(ip, port);
}

void Catway::setPublicPort(quint16 port)
{
    m_serverManager->setPublicPort(port);
}

void Catway::setStunServer(QString ip)
{
    m_serverManager->setStunServer(ip, m_serverManager->getStunPort());
}

void Catway::setStunPort(quint16 port)
{
    m_serverManager->setStunServer(m_serverManager->getStunServer(), port);
}

void Catway::setStunSenderAddress(QString ip)
{
    m_serverManager->setStunSenderAddress(ip);
}

void Catway::setStunSenderPort(quint16 port)
{
    m_serverManager->setStunSenderPort(port);
}

QString Catway::getExternalIp() const
{
    return m_serverManager->getExternalIp();
}

quint16 Catway::getExternalPort() const
{
    return m_serverManager->getExternalPort();
}

// --- STUN scoped handling ---

void Catway::sendStunRequest()
{
    // Connect STUN handler only for this request
    m_stunConnection = connect(m_serverManager, &ServerManager::stunResponseReceived,
                               this, &Catway::onStunResponse);

    m_serverManager->sendStunRequest();

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

    // Delegate actual parsing to ServerManager
    m_serverManager->handleStunResponse(datagram, sender, senderPort);
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
    m_serverManager->setStunServer(am->stunServer(), am->stunPort());
}
