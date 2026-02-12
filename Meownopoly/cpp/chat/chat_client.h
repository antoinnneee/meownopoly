#ifndef CHAT_CLIENT_H
#define CHAT_CLIENT_H

#include <QObject>
#include <QtQml>
#include <QThread>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
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
    Q_INVOKABLE void connectToSession(const QString &playerId, const QString &password, const QString &nickname = QString());
    Q_INVOKABLE void sendMessage(const QString &text, const QString &recipientId = QString());
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
    void errorOccurred(const QString &error);
    void availableSessionsChanged();
    void commandReceived(const QString &senderId, const QString &commandType, const QJsonObject &data);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);

private:
    void handleInitSession(const QJsonObject &payload);
    void handleNewMessage(const QJsonObject &payload);
    void handleHistoryResult(const QJsonObject &payload);
    void handleKeyUpdate(const QJsonObject &payload);
    void handleNewParticipant(const QJsonObject &payload);
    void handleParticipantLeft(const QJsonObject &payload);
    void handleParticipantsList(const QJsonObject &payload);
    void handleSessionsList(const QJsonObject &payload);
    void handleNewCommand(const QJsonObject &payload);
    void handleError(const QJsonObject &payload);
    void handleHistoryCleared();
    void sendWebSocketMessage(const QJsonObject &message);
    void publishNewKey();
    QString processMessageText(const QString &text);
    void decodeImageAsync(const QString &senderId, const QString &text, const QString &ts);

    /** Charge les clés depuis la DB et les déchiffre avec m_lockKey. Met à jour m_sessionKeys. */
    void loadAndDecryptSessionKeys();
    
    // Worker thread for WebSocket
    QThread *m_workerThread;
    ChatWorker *m_worker;
    
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
    
    // For automatic retry upon KEY_ROTATION_REQUIRED
    QString m_pendingMessage;
    bool m_retryPending = false;
};

#endif // CHAT_CLIENT_H
