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
        emit socketInfoChanged();
    }
}
