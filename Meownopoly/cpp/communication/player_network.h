#ifndef PLAYER_NETWORK_H
#define PLAYER_NETWORK_H

#include <QObject>
#include <QString>
#include "udp_socket_info.h"

class PlayerNetwork : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString playerId READ playerId WRITE setPlayerId NOTIFY playerIdChanged)
    Q_PROPERTY(QString nickname READ nickname WRITE setNickname NOTIFY nicknameChanged)
    Q_PROPERTY(UdpSocketInfo *socketInfo READ socketInfo WRITE setSocketInfo NOTIFY socketInfoChanged)

public:
    explicit PlayerNetwork(QObject *parent = nullptr);

    static void registerQml();

    QString playerId() const { return m_playerId; }
    void setPlayerId(const QString &id);

    QString nickname() const { return m_nickname; }
    void setNickname(const QString &name);

    UdpSocketInfo *socketInfo() const { return m_socketInfo; }
    void setSocketInfo(UdpSocketInfo *info);

signals:
    void playerIdChanged();
    void nicknameChanged();
    void socketInfoChanged();

private:
    QString m_playerId;
    QString m_nickname;
    UdpSocketInfo *m_socketInfo = nullptr;
};

#endif // PLAYER_NETWORK_H
