#include "server_manager.h"
#include <QDataStream>
#include <QRandomGenerator>

#include <QHostInfo>

ServerManager::ServerManager(QObject *parent)
    : QObject(parent), m_socket(new QUdpSocket(this))
{
    connect(m_socket, &QUdpSocket::readyRead, this, &ServerManager::onReadyRead);
}

ServerManager::~ServerManager()
{
    stopServer();
}

void ServerManager::startServer()
{
    if (m_socket->state() == QAbstractSocket::BoundState) {
        emit log("Server already running on port " + QString::number(m_socket->localPort()));
        return;
    }

    // Bind explicitly to AnyIPv4 to avoid IPv6 issues if STUN server is IPv4 only or network stack issues
    if (m_socket->bind(QHostAddress::AnyIPv4, 0)) {
        emit log("UDP Server started on local port: " + QString::number(m_socket->localPort()));
        emit serverStarted(m_socket->localPort());
        sendStunRequest();
    } else {
        emit log("Failed to bind UDP socket: " + m_socket->errorString());
    }
}

void ServerManager::stopServer()
{
    if (m_socket->state() == QAbstractSocket::BoundState) {
        m_socket->close();
        emit log("UDP Server stopped");
    }
}

void ServerManager::sendStunRequest()
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

    emit log("Resolving stun.l.google.com...");
    QHostInfo::lookupHost("stun.l.google.com", [this, packet](const QHostInfo &host) {
        if (host.error() != QHostInfo::NoError) {
            emit log("DNS Lookup failed: " + host.errorString());
            return;
        }

        if (host.addresses().isEmpty()) {
             emit log("No IP addresses found for stun.l.google.com");
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
             emit log("No IPv4 address found for stun.l.google.com");
             // Fallback to first available if no IPv4 (unlikely with google but safe)
             if (!host.addresses().isEmpty()) stunAddress = host.addresses().first();
        }

        emit log("Sending STUN request to " + stunAddress.toString() + ":19302...");
        m_socket->writeDatagram(packet, stunAddress, 19302); 
    });
}

void ServerManager::onReadyRead()
{
    emit log("onReadyRead");

    while (m_socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(m_socket->pendingDatagramSize());
        QHostAddress sender;
        quint16 senderPort;

        m_socket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        // Check if it's a STUN response (basic check)
        if (datagram.size() >= 20) {
            QDataStream in(datagram);
            in.setByteOrder(QDataStream::BigEndian);
            quint16 msgType;
            in >> msgType;

            if (msgType == 0x0101) { // Binding Success Response
                emit log("Received STUN Binding Response from " + sender.toString());
                
                // Parse attributes to find XOR-MAPPED-ADDRESS (0x0020) or MAPPED-ADDRESS (0x0001)
                // Skip header (20 bytes)
                int pos = 20;
                while (pos < datagram.size()) {
                    if (pos + 4 > datagram.size()) break;
                    
                    quint16 attrType = (quint8)datagram[pos] << 8 | (quint8)datagram[pos+1];
                    quint16 attrLen = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];
                    
                    pos += 4;
                    if (pos + attrLen > datagram.size()) break;

                    if (attrType == 0x0001) { // MAPPED-ADDRESS
                        quint8 family = (quint8)datagram[pos+1];
                        quint16 port = (quint8)datagram[pos+2] << 8 | (quint8)datagram[pos+3];
                        quint8 a = (quint8)datagram[pos+4];
                        quint8 b = (quint8)datagram[pos+5];
                        quint8 c = (quint8)datagram[pos+6];
                        quint8 d = (quint8)datagram[pos+7];
                        
                        QString ip = QString("%1.%2.%3.%4").arg(a).arg(b).arg(c).arg(d);
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
    }
}
