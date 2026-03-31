#include "catway.h"

#include <QUdpSocket>

#include "stun_manager.h"
#include "../account/account_manager.h"


void Catway::onCurrentSocketInfoChanged(UdpSocketInfo *info)
{
    m_currentStunSocketInfo = info;
}


void Catway::onStunRequestFailed()
{
    if (!m_pendingCommands.isEmpty()) {
        emit log(QString("SÉCURITÉ: Requête STUN échouée. Annulation de %1 commandes en attente (évite le Deadlock).").arg(m_pendingCommands.size()));
        m_pendingCommands.clear();
        disconnect(m_pendingCommandConnection);
    }
}

QObject *Catway::getSocket() const
{
    return m_currentStunSocketInfo ? m_currentStunSocketInfo->socket() : nullptr;
}

QObject *Catway::currentSocketInfo() const
{
    return m_currentStunSocketInfo;
}

UdpSocketInfo *Catway::takeStunSocket()
{
    UdpSocketInfo *info = nullptr;
    QMetaObject::invokeMethod(m_worker, "takeStunSocket", Qt::BlockingQueuedConnection, Q_RETURN_ARG(UdpSocketInfo*, info));

    if (info) {
        info->setParent(this);

        m_localSocketInfos.append(info);
        if (info->socket()) {
            info->socket()->setParent(nullptr);
            info->socket()->moveToThread(m_networkThread);

            connect(info->socket(), &QUdpSocket::readyRead, m_worker, &CatwayWorker::onSocketReadyRead);
        }
        emit localPortsChanged();
    }
    return info;
}

void Catway::startStunServer()
{
    QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
}

void Catway::stopStunServer()
{
    QMetaObject::invokeMethod(m_worker, "stopStunServer", Qt::QueuedConnection);
}

void Catway::sendStunRequest()
{
    QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);
}

void Catway::setupNewPort()
{
    auto *am = AccountManager::instance();

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
    takeStunSocket();
}

void Catway::triggerStunForPendingCommand(const QString &senderId, const QString &commandType, const QJsonObject &data)
{
    m_pendingCommands.append({senderId, commandType, data});

    if (m_pendingCommands.size() == 1) {
        disconnect(m_externalAddressTakePortConnection);

        auto *am = AccountManager::instance();
        m_pendingCommandConnection = connect(m_worker->stunManager(), &StunManager::externalAddressReceived,
                                             this, &Catway::onPendingCommandReady);
        QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection,
                                  Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
        QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
        QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);
    }
}
