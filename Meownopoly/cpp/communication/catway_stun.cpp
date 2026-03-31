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
    // Call takeStunSocket on worker thread and wait for result (BlockingQueuedConnection)
    QMetaObject::invokeMethod(m_worker, "takeStunSocket", Qt::BlockingQueuedConnection, Q_RETURN_ARG(UdpSocketInfo*, info));

    if (info) {
        info->setParent(this);

        m_localSocketInfos.append(info);
        if (info->socket()) {
            info->socket()->setParent(nullptr);
            info->socket()->moveToThread(m_networkThread);

            // Connect socket signals to worker slots (both on network thread)
            connect(info->socket(), &QUdpSocket::readyRead, m_worker, &CatwayWorker::onSocketReadyRead);
        }
        emit localPortsChanged();
    }
    return info;
}


// --- STUN scoped handling ---

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
    takeStunSocket();
}

// ---------------------------------------------------------------------------
// P4 — Logique commune de mise en file STUN pour les commandes chat en attente
// ---------------------------------------------------------------------------

void Catway::triggerStunForPendingCommand(const QString &senderId, const QString &commandType, const QJsonObject &data)
{
    m_pendingCommands.append({senderId, commandType, data});

    // Ne démarrer un cycle STUN que si c'est la première commande en attente.
    // Si m_pendingCommands.size() > 1, un cycle est déjà en cours : la commande
    // sera traitée quand onPendingCommandReady() rejoue toute la file.
    if (m_pendingCommands.size() == 1) {
        // setupNewPort() connecte externalAddressReceived → onExternalAddressReceivedTakePort
        // (qui appellerait takeStunSocket() pour un usage non lié aux commandes en attente).
        // On déconnecte ce handler pour éviter qu'il ne s'exécute à la place du nôtre.
        disconnect(m_externalAddressTakePortConnection);

        // Connecter externalAddressReceived → onPendingCommandReady une seule fois.
        // Le handle m_pendingCommandConnection permet de déconnecter explicitement
        // après traitement (dans onPendingCommandReady) ou en cas d'échec STUN
        // (dans onStunRequestFailed), empêchant tout déclenchement parasite ultérieur.
        auto *am = AccountManager::instance();
        m_pendingCommandConnection = connect(m_worker->stunManager(), &StunManager::externalAddressReceived,
                                             this, &Catway::onPendingCommandReady);
        QMetaObject::invokeMethod(m_worker, "setStunServerInfo", Qt::QueuedConnection,
                                  Q_ARG(QString, am->stunServer()), Q_ARG(quint16, am->stunPort()));
        QMetaObject::invokeMethod(m_worker, "startStunServer", Qt::QueuedConnection);
        QMetaObject::invokeMethod(m_worker, "sendStunRequest", Qt::QueuedConnection);
    }
}