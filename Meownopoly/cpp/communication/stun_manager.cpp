#include "stun_manager.h"
#include "udp_socket_info.h"
#include <QDataStream>
#include <QRandomGenerator>

#include <QHostInfo>
#include <QTimer>

StunManager::StunManager(QObject *parent)
    : QObject(parent)
{
    m_socketInfo = new UdpSocketInfo(this);
    QUdpSocket *sock = new QUdpSocket(m_socketInfo);
    m_socketInfo->setSocket(sock);

    m_stunTimeout = new QTimer(this);
    m_stunTimeout->setSingleShot(true);
    m_stunTimeout->setInterval(5000);
    connect(m_stunTimeout, &QTimer::timeout, this, &StunManager::onStunTimeout);
    disconnect(sock, &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
}

void StunManager::onStunTimeout()
{
    emit stunFailed();
    m_stunTimeout->stop();
    disconnect(m_stunTimeout, &QTimer::timeout, this, &StunManager::onStunTimeout);
    emit log("STUN request timed out, handler disconnected");
}

StunManager::~StunManager()
{
    stopServer();
}

bool StunManager::startServer()
{
    QUdpSocket *s = m_socketInfo->socket();
    if (!s || s->state() == QAbstractSocket::BoundState) {
        if (s)
            emit log("Server already running on port " + QString::number(s->localPort()));
        emit currentSocketInfoChanged(m_socketInfo);
        return true;
    }

    if (s->bind(QHostAddress::AnyIPv4, 0)) {
        emit serverStarted(s->localPort());
        emit currentSocketInfoChanged(m_socketInfo);
        return true;
    }
    emit log("Failed to bind UDP socket: " + s->errorString());
    return false;
}

void StunManager::stopServer()
{
    QUdpSocket *s = m_socketInfo->socket();
    if (s && s->state() == QAbstractSocket::BoundState) {
        s->close();
        emit log("UDP port punching stopped");
    }
}

void StunManager::setStunServer(QString ip, quint16 port)
{
    m_stunServerIp = ip;
    m_stunServerPort = port;
    emit log("STUN Server set to: " + m_stunServerIp + ":" + QString::number(m_stunServerPort));
}

QString StunManager::getExternalIp() const
{
    return m_socketInfo ? m_socketInfo->publicAddress() : QString();
}

quint16 StunManager::getExternalPort() const
{
    return m_socketInfo ? m_socketInfo->publicPort() : 0;
}

QString StunManager::getStunServer() const
{
    return m_stunServerIp;
}

quint16 StunManager::getStunPort() const
{
    return m_stunServerPort;
}

void StunManager::setPublicPort(quint16 port)
{
    if (m_socketInfo)
        m_socketInfo->setPublicPort(port);
}

void StunManager::setStunSenderAddress(QString ip)
{
    m_stunSenderAddress = QHostAddress(ip);
}

void StunManager::setStunSenderPort(quint16 port)
{
    m_stunSenderPort = port;
}

void StunManager::sendStunRequest()
{
    m_stunTimeout->start();
    connect(m_socketInfo->socket(), &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
    QByteArray packet;
    QDataStream out(&packet, QIODevice::WriteOnly);
    out.setByteOrder(QDataStream::BigEndian);

    // STUN Header
    out << (quint16)0x0001; // Message Type: Binding Request
    out << (quint16)0x0000; // Message Length: 0 (no attributes)
    out << (quint32)0x2112A442; // Magic Cookie

    for (int i = 0; i < 3; ++i) {
        out << QRandomGenerator::global()->generate();
    }

    emit log("Resolving " + m_stunServerIp + "...");
    QHostInfo::lookupHost(m_stunServerIp, [this, packet](const QHostInfo &host) {
        if (host.error() != QHostInfo::NoError) {
            emit log("DNS Lookup failed: " + host.errorString());
            return;
        }

        if (host.addresses().isEmpty()) {
            emit log("No IP addresses found for " + m_stunServerIp);
            return;
        }

        QHostAddress stunAddress;
        for (const auto &addr : host.addresses()) {
            if (addr.protocol() == QAbstractSocket::IPv4Protocol) {
                stunAddress = addr;
                break;
            }
        }

        if (stunAddress.isNull()) {
            emit log("No IPv4 address found for " + m_stunServerIp);
            stunAddress = host.addresses().first();
        }

        emit log("Sending STUN request to " + stunAddress.toString() + ":" + QString::number(m_stunServerPort) + "...");
        if (m_socketInfo && m_socketInfo->socket())
            m_socketInfo->socket()->writeDatagram(packet, stunAddress, m_stunServerPort);
    });
}

void StunManager::onReadyRead()
{
    QUdpSocket *s = m_socketInfo ? m_socketInfo->socket() : nullptr;
    if (!s) return;

    while (s->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(s->pendingDatagramSize());
        QHostAddress sender;
        quint16 senderPort;

        s->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        bool stunOk = false;
        if (datagram.size() >= 20) {
            QDataStream peek(datagram);
            peek.setByteOrder(QDataStream::BigEndian);
            quint16 msgType;
            peek >> msgType;
            if (msgType == 0x0101) {
                handleStunResponse(datagram, sender, senderPort);
                stunOk = true;
            }
        }
        if (!stunOk) {
            QString msg = QString::fromUtf8(datagram);
            emit log("Received Message from " + sender.toString() + ":" + QString::number(senderPort) + " -> " + msg);
        }
    }
}

QUdpSocket *StunManager::getSocket() const
{
    return m_socketInfo ? m_socketInfo->socket() : nullptr;
}

UdpSocketInfo *StunManager::currentSocketInfo() const
{
    return m_socketInfo;
}

UdpSocketInfo *StunManager::takeSocket()
{
    UdpSocketInfo *oldInfo = m_socketInfo;
    if (oldInfo && oldInfo->socket())
        disconnect(oldInfo->socket(), &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
    m_socketInfo = new UdpSocketInfo(this);
    QUdpSocket *newSock = new QUdpSocket(m_socketInfo);
    m_socketInfo->setSocket(newSock);
    connect(m_socketInfo->socket(), &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
    if (oldInfo)
        oldInfo->setParent(nullptr);
    emit currentSocketInfoChanged(m_socketInfo);
    emit log("New UDP socket prepared for punching (previous socket taken)");
    return oldInfo;
}

void StunManager::handleStunResponse(const QByteArray &datagram, const QHostAddress &sender, quint16 senderPort)
{
    QDataStream in(datagram);
    in.setByteOrder(QDataStream::BigEndian);
    quint16 msgType;
    in >> msgType;

    if (msgType == 0x0101) {
        emit log("Received STUN Binding Response from " + sender.toString() + ":" + QString::number(senderPort));

        m_stunSenderAddress = sender;
        m_stunSenderPort = senderPort;

        const int datagramSize = datagram.size();
        int pos = 20;
        while (pos < datagramSize) {
            if (pos + 4 > datagramSize) break;

            quint16 attrType = (quint8)datagram[pos] << 8 | (quint8)datagram[pos+1];
            quint16 attrLen = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];

            pos += 4;
            if (pos + attrLen > datagramSize) break;

            if (attrType == 0x0001) {
                quint16 port = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];
                quint8 a = (quint8)datagram[pos+4];
                quint8 b = (quint8)datagram[pos+5];
                quint8 c = (quint8)datagram[pos+6];
                quint8 d = (quint8)datagram[pos+7];

                QString ip = QString("%1.%2.%3.%4").arg(a).arg(b).arg(c).arg(d);
                if (m_socketInfo) {
                    m_socketInfo->setPublicAddress(ip);
                    m_socketInfo->setPublicPort(port);
                }
                emit log("External Address (MAPPED-ADDRESS): " + ip + ":" + QString::number(port));
                emit externalAddressReceived(ip, port);
                m_stunTimeout->stop();
                return;
            } else if (attrType == 0x0020) {
                quint16 xPort = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];
                quint32 xIp = (quint8)datagram[pos+4] << 24 | (quint8)datagram[pos+5] << 16 | (quint8)datagram[pos+6] << 8 | (quint8)datagram[pos+7];

                quint16 port = xPort ^ 0x2112;
                quint32 ipVal = xIp ^ 0x2112A442;

                QString ip = QHostAddress(ipVal).toString();
                if (m_socketInfo) {
                    m_socketInfo->setPublicAddress(ip);
                    m_socketInfo->setPublicPort(port);
                }
                emit log("External Address (XOR-MAPPED-ADDRESS): " + ip + ":" + QString::number(port));
                emit externalAddressReceived(ip, port);
                m_stunTimeout->stop();
                return;
            }

            pos += attrLen;
            int padding = (4 - (attrLen % 4)) % 4;
            pos += padding;
        }
    }
}
