#ifndef CHAT_CLIENT_H
#define CHAT_CLIENT_H

#include <QObject>
#include <QtQml>
#include <QThread>
#include <QThreadPool>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

#include "account_manager.h"
#include "chat_crypto.h"
#include "chat_database.h"
#include "chat_worker.h"
#include "chat_image_provider.h"
#include "chat_command_helper.h"
#include <QQmlEngine>

class ChatClient : public QObject
{



    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString sessionId READ sessionId WRITE setSessionId NOTIFY sessionIdChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(QVariantList participants READ participants NOTIFY participantsChanged)
    Q_PROPERTY(int participantCount READ participantCount NOTIFY participantsChanged)
    Q_PROPERTY(QVariantList availableSessions READ availableSessions NOTIFY availableSessionsChanged)

public:

    enum ErrorSession {
        SESSION_DOES_NOT_EXIST,
        INVALID_PASSWORD,
        OTHER
    };
    Q_ENUM (ErrorSession)

    explicit ChatClient(QObject *parent = nullptr);
    ~ChatClient();

    bool isConnected() const { return m_connected; }
    QString sessionId() const { return m_sessionId; }
    void setSessionId(const QString &id);
    QVariantList messages() const { return m_messages; }
    QVariantList participants() const { return m_participants; }
    int participantCount() const { return m_participants.size(); }
    QVariantList availableSessions() const { return m_availableSessions; }

    Q_INVOKABLE void connectToServer(const QString &url);

    Q_INVOKABLE void createSession(QString nameSession, QString pwdSession, QString idSession = AccountManager::getNewUniqueId());

    /// Phase 8 — host migration : renommer la session courante (même
    /// session_id, même participants). Utilisé par le client élu pour
    /// réécrire le prefix `[EDIT:<hostId>]` sans casser le canal chat.
    Q_INVOKABLE void renameSession(const QString &newName);

    Q_INVOKABLE void connectToSessionDirect(const QString &sessionId, const QString &password);
    Q_INVOKABLE void connectToSession(const QString &playerId, const QString &password, const QString &nickname = QString());
    Q_INVOKABLE void joinSession();

    Q_INVOKABLE void sendMessage(const QString &text, const QString &recipientId = QString(), const QString &recipientNickname = QString());
    Q_INVOKABLE void sendImage(const QString &filePath);
    Q_INVOKABLE void sendTextFile(const QString &filePath);
    Q_INVOKABLE void saveTextToFile(const QString &filePath, const QString &content);
    Q_INVOKABLE void loadHistory();
    Q_INVOKABLE void requestHistory(int beforeId = -1);

    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void saveImageToFile(const QString &imageId, const QString &filePath);
    Q_INVOKABLE void copyImageToClipboard(const QString &imageId);
    Q_INVOKABLE void requestParticipants();

    Q_INVOKABLE void requestSessionsList();

    Q_INVOKABLE void kickPlayer(const QString &targetPlayerId);
    Q_INVOKABLE void sendPing(const QString &targetPlayerId = QString());
    Q_INVOKABLE void sendRequestConnectionInfo(const QString &recipientId = QString(), const QString &ip = QString(), quint16 port = 0, quint16 localPort = 0);
    Q_INVOKABLE void sendShareConnection(const QString &recipientId = QString());
    Q_INVOKABLE void sendCommand(const QString &commandType, const QJsonObject &data, const QString &recipientId = QString());

    static void registerQml(QQmlEngine *engine = nullptr) {
        qmlRegisterType<ChatClient>("Meownopoly.Chat", 1, 0, "ChatClient");
        if (engine) {
            engine->addImageProvider(QLatin1String("chat_images"), new ChatImageProvider());
        }
    }

signals:
    void connectedChanged();
    void sessionIdChanged();
    void messagesChanged();
    void participantsChanged();
    void participantJoined(const QString &playerId, const QString &playerNickname);
    void participantLeft(const QString &playerId);
    void errorOccurred(const QString &error, ChatClient::ErrorSession errorType = ChatClient::OTHER);
    void availableSessionsChanged();
    void commandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data);
    void sessionCreated(const QString &sessionId, const QString &sessionName);
    /** Émis quand le serveur indique qu'une session a été créée par un autre client. */
    void sessionCreatedBroadcast(const QString &sessionId, const QString &sessionName);

    /// Phase 8 — host migration : broadcast du chat server quand une session a
    /// été renommée. availableSessions est déjà rafraîchi au moment de l'émission.
    void sessionRenamed(const QString &sessionId, const QString &sessionName);
    /** Émis quand on a été expulsé de la session par le host. */
    void kicked(const QString &sessionId, const QString &reason);
    /** Émis quand un autre participant a été expulsé. */
    void participantKicked(const QString &sessionId, const QString &playerId);
    /** Émis quand la session a été supprimée (par le host). */
    void sessionEnded(const QString &sessionId, const QString &reason);
    /** Émis quand un quitter explicite (LEAVE_SESSION) a été acquitté par le serveur. */
    void leftSession(const QString &sessionId);
    /** Émis quand le serveur a réinitialisé toutes les sessions (admin). */
    void serverReset(const QString &message);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onWorkerError(const QString &error);

private:
    void handleInitSession(const QJsonObject &payload);
    void handleNewMessage(const QJsonObject &payload);
    void handleHistoryResult(const QJsonObject &payload);
    void handleKeyUpdate(const QJsonObject &payload);
    void handleNewParticipant(const QJsonObject &payload);
    void handleParticipantLeft(const QJsonObject &payload);
    void handleParticipantsList(const QJsonObject &payload);
    void handleSessionsList(const QJsonObject &payload);
    void handleSessionCreated(const QJsonObject &payload);
    void handleNewCommand(const QJsonObject &payload);
    void dispatchIncomingCommand(const QString &senderId, const QString &commandType, const QJsonObject &data);

    void onIncomingCommandPing(const QString &senderId, const QJsonObject &data);
    void onIncomingCommandPong(const QString &senderId, const QJsonObject &data);
    void handleError(const QJsonObject &payload);
    void handleHistoryCleared();
    void handleKicked(const QJsonObject &payload);
    void handleParticipantKicked(const QJsonObject &payload);
    void handleSessionEnded(const QJsonObject &payload);
    void handleLeftSession(const QJsonObject &payload);
    void handleServerReset(const QJsonObject &payload);
    void handleSessionCreatedBroadcast(const QJsonObject &payload);
    void handleSessionRenamed(const QJsonObject &payload);
    /** Vide totalement l'état de session côté client (clés, participants, messages). */
    void resetSessionState();
    void sendWebSocketMessage(const QJsonObject &message);
    void publishNewKey();
    QString processMessageText(const QString &text);
    void decodeImageAsync(const QString &senderId, const QString &text, const QString &ts);

    /** Charge les clés depuis la DB et les déchiffre avec m_lockKey. Met à jour m_sessionKeys. */
    void loadAndDecryptSessionKeys();

    /** Déchiffre un payload avec la clé de session (version). Retourne le texte brut ou un placeholder si clé manquante. */
    QByteArray decryptMessagePayload(const QByteArray &cipher, const QByteArray &nonce, int keyVersion);
    /** Extrait le timestamp d'un objet message JSON (server_timestamp ou timestamp). */
    static QString messageTimestamp(const QJsonObject &msg);
    /** Construit le QVariantMap pour un message déchiffré (image placeholder ou texte). *outIsImagePlaceholder = true si image async à lancer. */
    QVariantMap buildMessageMapFromDecryptedText(const QString &senderId, const QString &senderNickname,
        const QString &text, const QString &ts, bool isEphemeral, bool *outIsImagePlaceholder = nullptr);
    /** Retourne l'index du participant dans m_participants par player_id, ou -1. */
    int indexOfParticipant(const QString &playerId) const;

    // Worker thread for WebSocket
    QThread *m_workerThread;
    ChatWorker *m_worker;

    // Thread pool dédié aux tâches asynchrones du chat (déchiffrement, décodage image,
    // compression image). On en possède un membre plutôt que QThreadPool::globalInstance()
    // afin de pouvoir attendre la fin de TOUTES les tâches en vol dans le destructeur, sans
    // risquer un use-after-free quand une lambda capturant `this` continue à tourner après
    // la destruction de ChatClient.
    QThreadPool m_chatPool;
    
    bool m_connected = false;
    QString m_sessionId;
    QString m_playerId;
    QString m_nickname;
    QString m_password;
    QByteArray m_lockKey;
    QByteArray m_passwordHash;
    QMap<int, QByteArray> m_sessionKeys;
    int m_currentKeyVersion = 0;
    QVariantList m_messages;
    QVariantList m_participants;
    QVariantList m_availableSessions;
    
    ChatDatabase m_db;
    
    // For automatic retry upon KEY_ROTATION_REQUIRED.
    // File d'attente FIFO : tous les messages envoyés pendant qu'une rotation
    // de clé est en cours seront rejoués dans l'ordre lorsque KEY_UPDATE arrive.
    QStringList m_pendingMessages;
    bool m_retryPending = false;
};

#endif // CHAT_CLIENT_H
