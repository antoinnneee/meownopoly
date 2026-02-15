#include "player_network.h"
#include <QQmlEngine>

PlayerNetwork::PlayerNetwork(QObject *parent)
    : QObject(parent)
{
}

void PlayerNetwork::registerQml()
{
    qmlRegisterType<PlayerNetwork>("Catway", 1, 0, "PlayerNetwork");
}

void PlayerNetwork::setPlayerId(const QString &id)
{
    if (m_playerId != id) {
        m_playerId = id;
        emit playerIdChanged();
    }
}

void PlayerNetwork::setNickname(const QString &name)
{
    if (m_nickname != name) {
        m_nickname = name;
        emit nicknameChanged();
    }
}

void PlayerNetwork::setSocketInfo(UdpSocketInfo *info)
{
    if (m_socketInfo != info) {
        m_socketInfo = info;
        if (info) {
            if (m_ip != info->publicAddress()) {
                m_ip = info->publicAddress();
                emit ipChanged();
            }
            if (m_port != info->publicPort()) {
                m_port = info->publicPort();
                emit portChanged();
            }
        } else {
            if (!m_ip.isEmpty()) { m_ip.clear(); emit ipChanged(); }
            if (m_port != 0) { m_port = 0; emit portChanged(); }
        }
        emit socketInfoChanged();
    }
}

void PlayerNetwork::setIp(const QString &ip)
{
    if (m_ip != ip) {
        m_ip = ip;
        emit ipChanged();
    }
}

void PlayerNetwork::setPort(quint16 port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}
