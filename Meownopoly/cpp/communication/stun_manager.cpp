#include "stun_manager.h"
#include <QDataStream>
#include <QRandomGenerator>

#include <QHostInfo>

StunManager::StunManager(QObject *parent)
    : QObject(parent), m_socket(new QUdpSocket(this))
{
    connect(m_socket, &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
}

StunManager::~StunManager()
{
    stopServer();
}

void StunManager::startServer()
{
    if (m_socket->state() == QAbstractSocket::BoundState) {
        emit log("Server already running on port " + QString::number(m_socket->localPort()));
        return;
    }

    // Bind explicitly to AnyIPv4 to avoid IPv6 issues if STUN server is IPv4 only or network stack issues
    if (m_socket->bind(QHostAddress::AnyIPv4, 0)) {
        emit log("UDP Server started on local port: " + QString::number(m_socket->localPort()));
        emit serverStarted(m_socket->localPort());
    } else {
        emit log("Failed to bind UDP socket: " + m_socket->errorString());
    }
}

void StunManager::stopServer()
{
    if (m_socket->state() == QAbstractSocket::BoundState) {
        m_socket->close();
        emit log("UDP Server stopped");
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
    return m_publicAddress.toString();
}

quint16 StunManager::getExternalPort() const
{
    return m_publicPort;
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
    m_publicPort = port;
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
    // Simple STUN Binding Request
    QByteArray packet;
    QDataStream out(&packet, QIODevice::WriteOnly);
    out.setByteOrder(QDataStream::BigEndian);

    // STUN Header
    out << (quint16)0x0001; // Message Type: Binding Request
    out << (quint16)0x0000; // Message Length: 0 (no attributes)
    out << (quint32)0x2112A442; // Magic Cookie

    // Transaction ID (12 bytes random)
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

        // Filter for IPv4
        QHostAddress stunAddress;
        for (const auto &addr : host.addresses()) {
            if (addr.protocol() == QAbstractSocket::IPv4Protocol) {
                stunAddress = addr;
                break;
            }
        }

        if (stunAddress.isNull()) {
             emit log("No IPv4 address found for " + m_stunServerIp);
             // Fallback to first available if no IPv4 (unlikely with google but safe)
             if (!host.addresses().isEmpty()) stunAddress = host.addresses().first();
        }

        emit log("Sending STUN request to " + stunAddress.toString() + ":" + QString::number(m_stunServerPort) + "...");
        m_socket->writeDatagram(packet, stunAddress, m_stunServerPort);
    });
}

void StunManager::onReadyRead()
{
    emit log("onReadyRead");

    while (m_socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(m_socket->pendingDatagramSize());
        QHostAddress sender;
        quint16 senderPort;

        m_socket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        // Check if it's a STUN response (starts with 0x0101 Binding Success Response)
        if (datagram.size() >= 20) {
            QDataStream peek(datagram);
            peek.setByteOrder(QDataStream::BigEndian);
            quint16 msgType;
            peek >> msgType;
            if (msgType == 0x0101) {
                // STUN response — emit signal (Catway connects/disconnects handler)
                emit stunResponseReceived(datagram, sender, senderPort);
            } else {
                // Non-STUN large packet — treat as text
                QString msg = QString::fromUtf8(datagram);
                emit log("Received Message from " + sender.toString() + ":" + QString::number(senderPort) + " -> " + msg);
            }
        } else {
             // Assume text message
             QString msg = QString::fromUtf8(datagram);
             emit log("Received Message from " + sender.toString() + ":" + QString::number(senderPort) + " -> " + msg);
        }
    }
}

void StunManager::setPeer(QString ip, quint16 port)
{
    m_peerAddress = QHostAddress(ip);
    m_peerPort = port;
    emit log("Peer set to: " + m_peerAddress.toString() + ":" + QString::number(m_peerPort));
}

QUdpSocket *StunManager::getSocket() const
{
    return m_socket;
}

QUdpSocket *StunManager::takeSocket()
{
    QUdpSocket *old = m_socket;
    m_socket = new QUdpSocket(this);
    connect(m_socket, &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
    if (old) {
        disconnect(old, &QUdpSocket::readyRead, this, &StunManager::onReadyRead);
        old->setParent(nullptr);
    }
    emit log("New UDP socket prepared for punching (previous socket taken)");
    return old;
}

void StunManager::sendMessageToPeer(QString message)
{
    if (m_peerAddress.isNull() || m_peerPort == 0) {
        emit log("Peer not configured/invalid.");
        return;
    }
    if (!m_socket || m_socket->state() != QAbstractSocket::BoundState) {
        emit log("Socket not bound, cannot send to peer.");
        return;
    }
    QByteArray data = message.toUtf8();
    qint64 bytes = m_socket->writeDatagram(data, m_peerAddress, m_peerPort);
    if (bytes == -1) {
        emit log("Failed to send to peer: " + m_socket->errorString());
    } else {
        emit log("Sent to " + m_peerAddress.toString() + ":" + QString::number(m_peerPort) + " via Main Port: " + message);
    }
}

void StunManager::handleStunResponse(const QByteArray &datagram, const QHostAddress &sender, quint16 senderPort)
{
    QDataStream in(datagram);
    in.setByteOrder(QDataStream::BigEndian);
    quint16 msgType;
    in >> msgType;

    if (msgType == 0x0101) { // Binding Success Response
        emit log("Received STUN Binding Response from " + sender.toString() + ":" + QString::number(senderPort));

        m_stunSenderAddress = sender;
        m_stunSenderPort = senderPort;

        // Parse attributes to find XOR-MAPPED-ADDRESS (0x0020) or MAPPED-ADDRESS (0x0001)
        // Skip header (20 bytes)
        int pos = 20;
        int datagramSize = datagram.size(); // Store size locally to avoid repeated calls/potential issues if modified
        while (pos < datagramSize) {
            if (pos + 4 > datagramSize) break;

            quint16 attrType = (quint8)datagram[pos] << 8 | (quint8)datagram[pos+1];
            quint16 attrLen = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];

            pos += 4;
            if (pos + attrLen > datagramSize) break;

            if (attrType == 0x0001) { // MAPPED-ADDRESS
                quint8 family = (quint8)datagram[pos+1];
                quint16 port = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];
                quint8 a = (quint8)datagram[pos+4];
                quint8 b = (quint8)datagram[pos+5];
                quint8 c = (quint8)datagram[pos+6];
                quint8 d = (quint8)datagram[pos+7];

                QString ip = QString("%1.%2.%3.%4").arg(a).arg(b).arg(c).arg(d);
                m_publicAddress = QHostAddress(ip);
                m_publicPort = port;

                emit log("External Address (MAPPED-ADDRESS): " + ip + ":" + QString::number(port));
                emit externalAddressReceived(ip, port);
                return; // Found it
            }
            else if (attrType == 0x0020) { // XOR-MAPPED-ADDRESS
                 quint8 family = (quint8)datagram[pos+1];
                 quint16 xPort = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];
                 quint32 xIp = (quint8)datagram[pos+4] << 24 | (quint8)datagram[pos+5] << 16 | (quint8)datagram[pos+6] << 8 | (quint8)datagram[pos+7];

                 quint16 port = xPort ^ 0x2112; // Magic cookie high 16 bits
                 quint32 ipVal = xIp ^ 0x2112A442;

                 QString ip = QHostAddress(ipVal).toString();
                 m_publicAddress = QHostAddress(ip);
                 m_publicPort = port;

                 emit log("External Address (XOR-MAPPED-ADDRESS): " + ip + ":" + QString::number(port));
                 emit externalAddressReceived(ip, port);
                 return; // Found it
            }

            pos += attrLen;
            // Attributes are padded to 4 bytes
            int padding = (4 - (attrLen % 4)) % 4;
            pos += padding;
        }
    }
}
