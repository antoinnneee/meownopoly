#include "catway.h"

void Catway::initiateHolePunch(PlayerNetwork *player)
{
    if (!player) return;
    UdpSocketInfo *si = player->socketInfo();
    if (!si || si->publicAddress().isEmpty() || si->publicPort() == 0) {
        emit log("Cannot initiate hole punch: No local public IP/Port for this player slot yet.");
        return;
    }

    emit log(QString("Initiating UDP hole punching for player %1 (%2)").arg(player->nickname(), player->playerId()));

    QJsonObject data;
    data[QStringLiteral("ip")] = si->publicAddress();
    data[QStringLiteral("port")] = static_cast<int>(si->publicPort());
    m_chatClient->sendCommand(QStringLiteral("UDP_HOLE_PUNCH_REQUEST"), data, player->playerId());

    sendUdpDatagram(player, QStringLiteral("HP:STRIKE"));
}


void Catway::handleHolePunchReply(PlayerNetwork *player)
{
    if (!player) return;
    player->setP2pConnected(true);
    sendUdpDatagram(player, QStringLiteral("HP:FINAL"));
    emit log("UDP Hole Punching: Received REPLY, sent FINAL. Connection should be open!");
}

void Catway::handleHolePunchFinal(PlayerNetwork *player)
{
    if (!player) return;
    player->setP2pConnected(true);
    emit log("UDP Hole Punching: Received FINAL. Punching SUCCESS!");
}

void Catway::handleHolePunchStrike(PlayerNetwork *player)
{
    Q_UNUSED(player)
    emit log("UDP Hole Punching: Received STRIKE. Other side is punching.");
}

void Catway::handleHolePunchPing(PlayerNetwork *player)
{
    Q_UNUSED(player)
}


void Catway::handleChatReplyConnectionInfo(const QString &senderId, const QJsonObject &data, PlayerNetwork *player)
{
    if (!player)
        triggerStunForPendingCommand(senderId, QStringLiteral("REPLY_CONNECTION_INFO"), data);
}

void Catway::handleChatUdpHolePunchRequest(const QString &senderId, const QJsonObject &data, PlayerNetwork *player)
{
    Q_UNUSED(data)
    if (!player)
        return;
    emit log(QString("Received UDP_HOLE_PUNCH_REQUEST from %1. Sending HP:REPLY...").arg(senderId));
    sendUdpDatagram(player, QStringLiteral("HP:REPLY"));
}

void Catway::handleChatRequestConnectionInfo(const QString &senderId, const QJsonObject &data, PlayerNetwork *player)
{
    UdpSocketInfo *socketInfo = player ? qobject_cast<UdpSocketInfo *>(player->socketInfo()) : nullptr;
    if (socketInfo) {
        QJsonObject replyData;
        replyData[QStringLiteral("ip")] = socketInfo->publicAddress();
        replyData[QStringLiteral("port")] = static_cast<int>(socketInfo->publicPort());
        m_chatClient->sendCommand(QStringLiteral("REPLY_CONNECTION_INFO"), replyData, senderId);
    } else {
        triggerStunForPendingCommand(senderId, QStringLiteral("REQUEST_CONNECTION_INFO"), data);
    }
}
