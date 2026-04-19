#ifndef CATWAY_H
#define CATWAY_H

#include "chat/chat_client.h"
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QHostAddress>
#include <QTimer>
#include <QList>
#include <QHash>
#include <QJsonObject>
#include <QElapsedTimer>
#include <QThread>

class QUdpSocket;
class StunManager;
class CatwayWorker;
struct reliable_endpoint_t;
#include "udp_socket_info.h"
#include "player_network.h"

// Copie thread-réseau des infos joueur (mise à jour depuis le GUI via setPlayerSnapshots).
struct PlayerSnapshot {
    QString playerId;
    QString ip;
    quint16 port       = 0;
    bool p2pConnected  = false;
    reliable_endpoint_t *endpoint = nullptr; // valide tant que le joueur est dans m_players
    QUdpSocket *socket            = nullptr; // valide tant que socketInfo est en vie
    qint64 lastReceivedMs = 0; // timestamp du dernier paquet reçu (pour timeout)
    int strikeRetryCount  = 0; // compteur de retries HP:STRIKE (max avant abandon)
};
Q_DECLARE_METATYPE(QList<PlayerSnapshot>)

class CatwayWorker : public QObject
{
    Q_OBJECT
public:
    explicit CatwayWorker(QObject *parent = nullptr);
    ~CatwayWorker();

    StunManager *stunManager() const { return m_stunManager; }

    /// Recherche un snapshot par playerId. Doit être appelé depuis le thread réseau uniquement.
    const PlayerSnapshot *findSnapshot(const QString &playerId) const;

    /// Appelé depuis catway_process_packet (thread réseau) pour les paquets non-keepalive.
    void markReliableReceived(const QString &playerId);

public slots:
    void initReliable();
    void startReliableTimer();
    void tearDown();

    void startStunServer();
    void stopStunServer();
    void sendStunRequest();
    void setStunServerInfo(const QString &host, quint16 port);
    UdpSocketInfo* takeStunSocket();

    void sendDatagram(QUdpSocket *socket, const QByteArray &data, const QHostAddress &address, quint16 port);
    void sendReliablePacket(const QString &playerId, const QByteArray &data);
    void onSocketReadyRead();

    /// Envoie un paquet fiable à tous les joueurs P2P connectés.
    void broadcastReliable(const QByteArray &data);

    /// Met à jour la copie locale des snapshots joueurs (appelé depuis le thread GUI via QueuedConnection).
    void setPlayerSnapshots(QList<PlayerSnapshot> snapshots);

    /// Initialise le timestamp de réception pour un joueur (appelé quand le hole punch réussit).
    void initLastReceived(const QString &playerId);

private slots:
    void onReliableUpdate();
    void onHeartbeat();

signals:
    void datagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress sender, quint16 port);
    /// Émis quand un joueur P2P n'a pas répondu depuis trop longtemps.
    void playerTimedOut(QString playerId);

private:
    StunManager *m_stunManager;
    QTimer *m_reliableUpdateTimer = nullptr;
    QElapsedTimer m_reliableClock;
    QTimer *m_heartbeatTimer = nullptr;
    int m_heartbeatInterval = 10000;

    // Suivi ACK-flush et keepalive (ms depuis m_reliableClock.start)
    qint64 m_lastKeepaliveMs = 0;
    QHash<QString, qint64> m_lastReliableReceivedMs; // réception d'un paquet reliable
    QHash<QString, qint64> m_lastReliableSentMs;     // dernier envoi reliable (op ou keepalive)

    QList<PlayerSnapshot> m_playerSnapshots;
    /// Timestamps persistés par playerId (survit aux rebuilds de snapshots)
    QHash<QString, qint64> m_lastReceivedByPlayer;
    /// Compteurs de retries HP:STRIKE persistés par playerId
    QHash<QString, int> m_strikeRetryByPlayer;
};

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

    /// Retourne le socket UDP actuel (pour usage C++). Ne transfère pas la propriété.
    Q_INVOKABLE QObject *getSocket() const;
    /// Retourne l'info du socket actuel (publicAddress, publicPort, socket).
    Q_INVOKABLE QObject *currentSocketInfo() const;
    /// Détache le socket actuel et en prépare un nouveau dans StunManager. L'ancien UdpSocketInfo est ajouté à localPorts et est retourné.
    Q_INVOKABLE UdpSocketInfo *takeStunSocket();

    /// Liste des infos de ports locaux (sockets récupérés via takeStunSocket).
    Q_PROPERTY(QQmlListProperty<UdpSocketInfo> localPorts READ localPorts NOTIFY localPortsChanged)
    QQmlListProperty<UdpSocketInfo> localPorts();

    /// Liste des joueurs réseau (playerId, nickname, socketInfo).
    Q_PROPERTY(QQmlListProperty<PlayerNetwork> players READ players NOTIFY playersChanged)
    QQmlListProperty<PlayerNetwork> players();

    /// Client de chat intégré (accessible en QML via Catway.chatClient).
    /// IMPORTANT: m_chatClient peut pointer vers un objet possédé par QML. On utilise
    /// QPointer pour qu'il s'auto-nullifie quand QML le détruit, sinon on récupère un
    /// dangling pointer lors du teardown du thread réseau (datagrammes UDP en vol qui
    /// appellent sendCommand → use-after-free → crash à la fermeture).
    Q_PROPERTY(ChatClient *chatClient READ chatClient WRITE setChatClient NOTIFY chatClientChanged)
    ChatClient *chatClient() const { return m_chatClient.data(); }
    Q_INVOKABLE void setChatClient(ChatClient *client);

    Q_INVOKABLE void addPlayer(PlayerNetwork *player);
    Q_INVOKABLE void removePlayer(PlayerNetwork *player);
    Q_INVOKABLE PlayerNetwork *playerAt(int index) const;
    Q_INVOKABLE int playersCount() const;
    /// Retourne le joueur dont le playerId correspond, ou null.
    Q_INVOKABLE PlayerNetwork *playerById(const QString &playerId) const;

    /// Accès QML aux sockets STUN-assignés (après takeStunSocket).
    /// Le dernier est typiquement celui qu'on vient de générer via setupNewPort,
    /// utilisable pour sendRequestConnectionInfo.
    Q_INVOKABLE QObject *localPortAt(int index) const;
    Q_INVOKABLE int      localPortCount() const;
    Q_INVOKABLE QObject *lastLocalPort() const;

    Q_INVOKABLE void initiateHolePunch(PlayerNetwork *player);
    Q_INVOKABLE void sendUdpMessageToPlayer(PlayerNetwork *player, const QString &message);
    void sendUdpDatagram(PlayerNetwork *player, const QByteArray &data);
    void sendUdpDatagram(PlayerNetwork *player, const QString &content);

    /// Envoie des données via l'endpoint reliable du joueur (ACK garanti).
    /// À n'utiliser qu'après que la connexion UDP est établie (HP:FINAL reçu).
    Q_INVOKABLE void sendReliableToPlayer(PlayerNetwork *player, const QByteArray &data);

    /// Envoie un paquet fiable à tous les joueurs P2P connectés.
    Q_INVOKABLE void broadcastReliable(const QByteArray &data);

    /// Envoie un message UDP brut à tous les joueurs P2P connectés (lossy, minijeux).
    Q_INVOKABLE void broadcastRaw(const QString &message);

public slots:
    Q_INVOKABLE void setupNewPort();

signals:
    void log(QString message);
    void stunServerStarted(quint16 port);
    void externalAddressReceived(QString ip, quint16 port);
    void udpMessageReceived(QString senderId, QString message);
    void localPortsChanged();
    void playersChanged();
    /// Émis quand un paquet fiable (via reliable) est reçu et acquitté (payload brut, souvent UTF-8).
    /// En QML : convertir avec `String.fromCharCode` / `TextDecoder` si besoin de texte.
    void reliableMessageReceived(QString senderId, QByteArray data);
    void chatClientChanged();
    /// relay du timeout depuis CatwayWorker (permet aux modules
    /// de niveau session — GameSession/EditorSession — de réagir sur le thread GUI).
    void playerTimedOut(QString playerId);

private slots:
    void onAccountStunChanged();
    void onExternalAddressReceivedTakePort(QString ip, quint16 port);
    void onChatCommandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data);
    void onPendingCommandReady(QString ip, quint16 port);
    void onDatagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress sender, quint16 port);
    void onStunRequestFailed();
    void onCurrentSocketInfoChanged(UdpSocketInfo *info);
    void onPlayerNetworkPlayerIdChanged();

private:
    struct PendingCommand {
        QString senderId;
        QString commandType;
        QJsonObject data;
    };
    QList<PendingCommand> m_pendingCommands;

    explicit Catway(QObject *parent = nullptr);
    ~Catway();
    static Catway *m_pThis;

    static qsizetype localPortsCount(QQmlListProperty<UdpSocketInfo> *p);
    static UdpSocketInfo *localPortsAt(QQmlListProperty<UdpSocketInfo> *p, qsizetype index);
    static qsizetype playersCount(QQmlListProperty<PlayerNetwork> *p);
    static PlayerNetwork *playersAt(QQmlListProperty<PlayerNetwork> *p, qsizetype index);

    PlayerNetwork *getOrCreatePlayer(const QString &playerId);
    QString nicknameFromChat(const QString &playerId) const;

    /// Construit un snapshot de m_players et l'envoie au worker via QueuedConnection.
    void pushPlayerSnapshots();

    /// Extrait la logique commune de mise en file d'attente STUN pour les commandes chat en attente.
    void triggerStunForPendingCommand(const QString &senderId, const QString &commandType, const QJsonObject &data);

    void handleHolePunchReply(PlayerNetwork *player);
    void handleHolePunchFinal(PlayerNetwork *player);
    void handleHolePunchStrike(PlayerNetwork *player);
    void handleHolePunchPing(PlayerNetwork *player);

    void handleChatReplyConnectionInfo(const QString &senderId, const QJsonObject &data, PlayerNetwork *player);
    void handleChatUdpHolePunchRequest(const QString &senderId, const QJsonObject &data, PlayerNetwork *player);
    void handleChatRequestConnectionInfo(const QString &senderId, const QJsonObject &data, PlayerNetwork *player);

    CatwayWorker *m_worker;
    QThread *m_networkThread;

    QPointer<ChatClient> m_chatClient;
    QList<UdpSocketInfo *> m_localSocketInfos;
    QList<PlayerNetwork *> m_players;
    /// Index playerId → joueur pour playerById en O(1). Synchronisé avec m_playerIdByPlayer.
    QHash<QString, PlayerNetwork *> m_playersById;
    /// Dernier id connu par joueur (pour réindexer après playerIdChanged).
    QHash<PlayerNetwork *, QString> m_playerIdByPlayer;

    UdpSocketInfo *m_currentStunSocketInfo = nullptr;

    QHash<PlayerNetwork*, struct CatwayReliableContext*> m_reliableContexts;

    QMetaObject::Connection m_externalAddressTakePortConnection;
    QMetaObject::Connection m_pendingCommandConnection;
};

struct CatwayReliableContext {
    PlayerNetwork *player;   // GUI-thread only — ne PAS accéder depuis le network thread
    QString        playerId; // copie thread-safe pour les callbacks réseau
    Catway        *catway;
    CatwayWorker  *worker;
};
#endif // CATWAY_H
