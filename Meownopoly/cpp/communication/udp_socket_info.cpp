#include "udp_socket_info.h"

UdpSocketInfo::UdpSocketInfo(QObject *parent)
    : QObject(parent)
{
}

UdpSocketInfo::~UdpSocketInfo()
{
    if (m_socket) {
        disconnect(m_socket, nullptr, this, nullptr);
        // Toujours fermer et libérer le socket, même si le parent a été changé
        // (setParent(nullptr) est utilisé avant moveToThread)
        if (m_socket->thread() == thread())
            delete m_socket;
        else
            m_socket->deleteLater();
        m_socket = nullptr;
    }
}

void UdpSocketInfo::setPublicAddress(const QString &address)
{
    if (m_publicAddress != address) {
        m_publicAddress = address;
        emit publicAddressChanged();
    }
}

void UdpSocketInfo::setPublicPort(quint16 port)
{
    if (m_publicPort != port) {
        m_publicPort = port;
        emit publicPortChanged();
    }
}

void UdpSocketInfo::setSocket(QUdpSocket *sock, bool deleteOldSocket)
{
    if (m_socket == sock)
        return;
    if (m_socket) {
        disconnect(m_socket, nullptr, this, nullptr);
        if (m_socket->parent() == this) {
            if (deleteOldSocket)
                m_socket->deleteLater();
            else
                m_socket->setParent(nullptr);
        }
    }
    m_socket = sock;
    if (m_socket) {
        m_socket->setParent(this);
        connect(m_socket, &QUdpSocket::stateChanged, this, &UdpSocketInfo::onSocketStateChanged);
    }
    emit socketChanged();
    emit localPortChanged();
}

quint16 UdpSocketInfo::localPort() const
{
    return m_socket && m_socket->state() == QAbstractSocket::BoundState
           ? m_socket->localPort()
           : 0;
}

void UdpSocketInfo::onSocketStateChanged(QAbstractSocket::SocketState state)
{
    Q_UNUSED(state)
    emit localPortChanged();
}
