#ifndef PLAYER_NETWORK_H
#define PLAYER_NETWORK_H

#include <QObject>
#include <QString>
#include "udp_socket_info.h"
#include "reliable.h"

class PlayerNetwork : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString playerId READ playerId WRITE setPlayerId NOTIFY playerIdChanged)
    Q_PROPERTY(QString nickname READ nickname WRITE setNickname NOTIFY nicknameChanged)
    /// Socket local associé au joueur (publicAddress/publicPort = notre côté). Distinct de l’adresse de destination.
    Q_PROPERTY(UdpSocketInfo *socketInfo READ socketInfo WRITE setSocketInfo NOTIFY socketInfoChanged)
    /// Adresse de destination pour envoyer des données à ce joueur (peut différer du publicAddress du socket).
    Q_PROPERTY(QString ip READ ip WRITE setIp NOTIFY ipChanged)
    /// Port de destination pour envoyer des données à ce joueur (peut différer du publicPort du socket).
    Q_PROPERTY(quint16 port READ port WRITE setPort NOTIFY portChanged)

    /// Indique si la connexion UDP (Hole Punching) a réussi et est prête pour l'échange bidirectionnel.
    Q_PROPERTY(bool p2pConnected READ isP2pConnected WRITE setP2pConnected NOTIFY p2pConnectedChanged)

public:
    explicit PlayerNetwork(QObject *parent = nullptr);
    ~PlayerNetwork();

    static void registerQml();

    // --- reliable endpoint ---
    /// Initialise l'endpoint reliable pour ce joueur.
    /// context : pointeur arbitraire passé aux callbacks (généralement PlayerNetwork*).
    void initReliable(
        void *context,
        void (*transmitFn)(void*, uint64_t, uint16_t, uint8_t*, int),
        int  (*processFn)(void*, uint64_t, uint16_t, uint8_t*, int)
    );
    void destroyReliable();
    reliable_endpoint_t *endpoint() const { return m_endpoint; }

    QString playerId() const { return m_playerId; }
    void setPlayerId(const QString &id);

    QString nickname() const { return m_nickname; }
    void setNickname(const QString &name);

    UdpSocketInfo *socketInfo() const { return m_socketInfo; }
    void setSocketInfo(UdpSocketInfo *info);

    QString ip() const { return m_ip; }
    void setIp(const QString &ip);

    quint16 port() const { return m_port; }
    void setPort(quint16 port);

    bool isP2pConnected() const { return m_p2pConnected; }
    void setP2pConnected(bool connected);

signals:
    void playerIdChanged();
    void nicknameChanged();
    void socketInfoChanged();
    void ipChanged();
    void portChanged();

private:
    QString m_playerId;
    QString m_nickname;
    UdpSocketInfo *m_socketInfo = nullptr;
    QString m_ip;
    quint16 m_port = 0;
    bool m_p2pConnected = false;
    reliable_endpoint_t *m_endpoint = nullptr;
};

#endif // PLAYER_NETWORK_H
