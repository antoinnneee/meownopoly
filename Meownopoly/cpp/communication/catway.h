#ifndef CATWAY_H
#define CATWAY_H

#include "chat/chat_client.h"
#include <QObject>
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

// ---------------------------------------------------------------------------
// Snapshot immuable d'un joueur, utilisé exclusivement sur le thread réseau.
// Mis à jour depuis le thread GUI via CatwayWorker::setPlayerSnapshots().
// ---------------------------------------------------------------------------
struct PlayerSnapshot {
    QString playerId;
    QString ip;
    quint16 port       = 0;
    bool p2pConnected  = false;
    reliable_endpoint_t *endpoint = nullptr; // valide tant que le joueur est dans m_players
    QUdpSocket *socket            = nullptr; // valide tant que socketInfo est en vie
};
Q_DECLARE_METATYPE(QList<PlayerSnapshot>)

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

    /// Recherche un snapshot par playerId. Doit être appelé depuis le thread réseau uniquement.
    const PlayerSnapshot *findSnapshot(const QString &playerId) const;

public slots:
    void initReliable();
    void startReliableTimer();
    void tearDown();

    // STUN & Socket control (Proxied to StunManager on worker thread)
    void startStunServer();
    void stopStunServer();
    void sendStunRequest();
    void setStunServerInfo(const QString &host, quint16 port);
    UdpSocketInfo* takeStunSocket();

    // --- Thread-safe I/O ---
    void sendDatagram(QUdpSocket *socket, const QByteArray &data, const QHostAddress &address, quint16 port);
    void sendReliablePacket(PlayerNetwork *player, const QByteArray &data);
    void sendReliablePacket(const QString &playerId, const QByteArray &data);
    void onSocketReadyRead();

    /// Envoie un paquet fiable à tous les joueurs P2P connectés.
    void broadcastReliable(const QByteArray &data);

    /// Met à jour la copie locale des snapshots joueurs (appelé depuis le thread GUI via QueuedConnection).
    void setPlayerSnapshots(QList<PlayerSnapshot> snapshots);

private slots:
    void onReliableUpdate();
    void onHeartbeat();

signals:
    void reliableMessageReceived(QString senderId, QByteArray data);
    void reliableMessageReceivedString(QString senderId, QString message);
    void datagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress sender, quint16 port);

private:
    StunManager *m_stunManager;
    QTimer *m_reliableUpdateTimer = nullptr;
    QElapsedTimer m_reliableClock;
    QTimer *m_heartbeatTimer = nullptr;
    int m_heartbeatInterval = 10000;

    // Copie locale des joueurs — accédée uniquement depuis le thread réseau, jamais depuis le GUI.
    QList<PlayerSnapshot> m_playerSnapshots;
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
    Q_PROPERTY(ChatClient *chatClient READ chatClient WRITE setChatClient NOTIFY chatClientChanged)
    ChatClient *chatClient() const { return m_chatClient; }
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
    /// Émis quand un paquet fiable (via reliable) est reçu et acquitté.
    void reliableMessageReceived(QString senderId, QByteArray data);
    /// Même contenu en QString (UTF-8), pratique pour le QML (draw, chat, etc.).
    void reliableMessageReceivedString(QString senderId, QString message);
    void chatClientChanged();

private slots:
    void onAccountStunChanged();
    void onExternalAddressReceivedTakePort(QString ip, quint16 port);
    void onChatCommandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data);
    void onPendingCommandReady(QString ip, quint16 port);
    void onDatagramReceived(QUdpSocket *socket, QByteArray datagram, QHostAddress sender, quint16 port);
    void onStunRequestFailed();
    void onCurrentSocketInfoChanged(UdpSocketInfo *info);

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

    CatwayWorker *m_worker;
    QThread *m_networkThread;

    ChatClient *m_chatClient;
    QList<UdpSocketInfo *> m_localSocketInfos;
    QList<PlayerNetwork *> m_players;

    /// Cache du socket STUN courant, mis à jour via StunManager::currentSocketInfoChanged (P3).
    UdpSocketInfo *m_currentStunSocketInfo = nullptr;

    /// Contextes reliable indexés par joueur — remplace le stockage void* via QVariant (P6).
    QHash<PlayerNetwork*, struct CatwayReliableContext*> m_reliableContexts;

    QMetaObject::Connection m_externalAddressTakePortConnection;
    QMetaObject::Connection m_pendingCommandConnection;
};

struct CatwayReliableContext {
    PlayerNetwork *player;
    Catway        *catway;
    CatwayWorker  *worker;
};
#endif // CATWAY_H
