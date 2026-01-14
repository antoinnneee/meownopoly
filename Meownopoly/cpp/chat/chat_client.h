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
#include <QQmlEngine>

class ChatClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString sessionId READ sessionId WRITE setSessionId NOTIFY sessionIdChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)

public:
    explicit ChatClient(QObject *parent = nullptr);
    ~ChatClient();

    bool isConnected() const { return m_connected; }
    QString sessionId() const { return m_sessionId; }
    void setSessionId(const QString &id);
    QVariantList messages() const { return m_messages; }

    Q_INVOKABLE void connectToServer(const QString &url, const QString &playerId);
    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void sendImage(const QString &filePath);
    Q_INVOKABLE void loadHistory();
    Q_INVOKABLE void requestHistory(int beforeId = -1);

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
    void errorOccurred(const QString &error);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);

private:
    void handleInitSession(const QJsonObject &payload);
    void handleNewMessage(const QJsonObject &payload);
    void handleHistoryResult(const QJsonObject &payload);
    void sendWebSocketMessage(const QJsonObject &message);
    QString processMessageText(const QString &text);
    
    // Worker thread for WebSocket
    QThread *m_workerThread;
    ChatWorker *m_worker;
    
    bool m_connected = false;
    QString m_sessionId;
    QString m_playerId;
    QByteArray m_lockKey;
    QByteArray m_sessionKey;
    QVariantList m_messages;
    
    ChatDatabase m_db;
};

#endif // CHAT_CLIENT_H
