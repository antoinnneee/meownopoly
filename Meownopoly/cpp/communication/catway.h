#ifndef CATWAY_H
#define CATWAY_H

#include "chat/chat_client.h"
#include <QObject>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QHostAddress>
#include <QTimer>
#include <QList>
#include <QJsonObject>
#include <QElapsedTimer>
#include <QThread>

class QUdpSocket;
class StunManager;
class CatwayWorker;
#include "udp_socket_info.h"
#include "player_network.h"

// ---------------------------------------------------------------------------
// Worker pour exécuter les sockets UDP et timer reliable hors du Main Thread
// ---------------------------------------------------------------------------
class CatwayWorker : public QObject
{
    Q_OBJECT
public:
    explicit CatwayWorker(QObject *parent = nullptr);
    ~CatwayWorker();

    StunManager *stunManager() const { return m_stunManager; }

    static void catway_transmit_packet(void *context, uint64_t id, uint16_t sequence, uint8_t *packet_data, int packet_bytes);
    static int catway_process_packet(void *context, uint64_t id, uint16_t sequence, uint8_t *packet_data, int packet_bytes);

public slots:
    void initReliable();
    void startReliableTimer();
    void tearDown();

    // STUN & Socket control (Proxied to StunManager on worker thread)
    void startStunServer();
    void stopStunServer();
    void sendStunRequest();
    void setStunServerInfo(const QString &host, quint16 port);
    UdpSocketInfo* takeSocket();

    // --- Thread-safe I/O ---
    void sendDatagram(QUdpSocket *socket, const QByteArray &data, const QHostAddress &address, quint16 port);
    void sendReliablePacket(const QString &playerId, const QByteArray &data);
    void onSocketReadyRead();

private slots:
    void onReliableUpdate();

signals:
    void reliableMessageReceived(QString senderId, QByteArray data);
    void reliableMessageReceivedString(QString senderId, QString message);
    void datagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress sender, quint16 port);

private:
    StunManager *m_stunManager;
    QTimer *m_reliableUpdateTimer = nullptr;
    QElapsedTimer m_reliableClock;
};

// ---------------------------------------------------------------------------
// Classe Main (UI Thread)
// ---------------------------------------------------------------------------
class Catway : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static Catway *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);


    Q_INVOKABLE void startStunServer();
    Q_INVOKABLE void stopStunServer();
    Q_INVOKABLE void sendStunRequest();
    Q_INVOKABLE QString getExternalIp() const;
    Q_INVOKABLE quint16 getExternalPort() const;

    /// Retourne le socket UDP actuel (pour usage C++). Ne transfère pas la propriété.
    Q_INVOKABLE QObject *getSocket() const;
    /// Retourne l'info du socket actuel (publicAddress, publicPort, socket).
    Q_INVOKABLE QObject *currentSocketInfo() const;
    /// Détache le socket actuel et en prépare un nouveau dans StunManager. L'ancien UdpSocketInfo est ajouté à localPorts et retourné.
    Q_INVOKABLE UdpSocketInfo *takeSocket();

    /// Liste des infos de ports locaux (sockets récupérés via takeSocket).
    Q_PROPERTY(QQmlListProperty<UdpSocketInfo> localPorts READ localPorts NOTIFY localPortsChanged)
    QQmlListProperty<UdpSocketInfo> localPorts();

    /// Intervalle d'envoi du battement de cœur P2P (Heartbeat) en millisecondes. Défaut : 10000ms.
    Q_PROPERTY(int heartbeatInterval READ heartbeatInterval WRITE setHeartbeatInterval NOTIFY heartbeatIntervalChanged)
    int heartbeatInterval() const;
    void setHeartbeatInterval(int intervalMs);

    /// Liste des joueurs réseau (playerId, nickname, socketInfo).
    Q_PROPERTY(QQmlListProperty<PlayerNetwork> players READ players NOTIFY playersChanged)
    QQmlListProperty<PlayerNetwork> players();

    /// Client de chat intégré (accessible en QML via Catway.chatClient).
    Q_PROPERTY(ChatClient *chatClient READ chatClient WRITE setChatClient NOTIFY chatClientChanged)
    ChatClient *chatClient() const;
    Q_INVOKABLE void setChatClient(ChatClient *client);

    Q_INVOKABLE void addPlayer(PlayerNetwork *player);
    Q_INVOKABLE void removePlayer(PlayerNetwork *player);
    Q_INVOKABLE PlayerNetwork *playerAt(int index) const;
    int playersCount() const;
    /// Retourne le joueur dont le playerId correspond, ou null.
    Q_INVOKABLE PlayerNetwork *playerById(const QString &playerId) const;

    Q_INVOKABLE void initiateHolePunch(PlayerNetwork *player);
    Q_INVOKABLE void sendUdpMessageToPlayer(PlayerNetwork *player, const QString &message);
    void sendUdpDatagram(PlayerNetwork *player, const QByteArray &data);
    void sendUdpDatagram(PlayerNetwork *player, const QString &content);

    /// Envoie des données via l'endpoint reliable du joueur (ACK garanti).
    /// À n'utiliser qu'après que la connexion UDP est établie (HP:FINAL reçu).
    Q_INVOKABLE void sendReliableToPlayer(PlayerNetwork *player, const QByteArray &data);

public slots:
    Q_INVOKABLE void setupNewPort();

signals:
    void log(QString message);
    void stunServerStarted(quint16 port);
    void externalAddressReceived(QString ip, quint16 port);
    void udpMessageReceived(QString senderId, QString message);
    void localPortsChanged();
    void playersChanged();
    /// Émis quand un paquet fiable (via reliable) est reçu et acquitté.
    void reliableMessageReceived(QString senderId, QByteArray data);
    /// Même contenu en QString (UTF-8), pratique pour le QML (draw, chat, etc.).
    void reliableMessageReceivedString(QString senderId, QString message);
    void heartbeatIntervalChanged();
    void chatClientChanged();

private slots:
    void onAccountStunChanged();
    void onExternalAddressReceivedTakePort(QString ip, quint16 port);
    void onChatCommandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data);
    void onPendingCommandReady(QString ip, quint16 port);
    void onDatagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress sender, quint16 port);
    void onHeartbeat();
    void onStunRequestFailed();

private:
    struct PendingCommand {
        QString senderId;
        QString commandType;
        QJsonObject data;
    };
    QList<PendingCommand> m_pendingCommands;

    explicit Catway(QObject *parent = nullptr);
    static Catway *m_pThis;

    static qsizetype localPortsCount(QQmlListProperty<UdpSocketInfo> *p);
    static UdpSocketInfo *localPortsAt(QQmlListProperty<UdpSocketInfo> *p, qsizetype index);
    static qsizetype playersCount(QQmlListProperty<PlayerNetwork> *p);
    static PlayerNetwork *playersAt(QQmlListProperty<PlayerNetwork> *p, qsizetype index);

    PlayerNetwork *getOrCreatePlayer(const QString &playerId);
    QString nicknameFromChat(const QString &playerId) const;

    CatwayWorker *m_worker;
    QThread *m_networkThread;
    
    ChatClient *m_chatClient;
    QList<UdpSocketInfo *> m_localSocketInfos;
    QList<PlayerNetwork *> m_players;
    QMetaObject::Connection m_stunConnection;
    QMetaObject::Connection m_externalAddressTakePortConnection;
    QMetaObject::Connection m_pendingCommandConnection;
    QTimer *m_heartbeatTimer = nullptr;
    int m_heartbeatInterval = 10000;
};

#endif // CATWAY_H
