#ifndef CHAT_CLIENT_H
#define CHAT_CLIENT_H

#include <QObject>
#include <QtQml>

class ChatClient; // Forward decl

// ... (rest of ChatClient defined elsewhere)

#include <QObject>
#include <QWebSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include "chat_crypto.h"
#include "chat_database.h"

class ChatClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString sessionId READ sessionId WRITE setSessionId NOTIFY sessionIdChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)

public:
    explicit ChatClient(QObject *parent = nullptr);

    bool isConnected() const { return m_connected; }
    QString sessionId() const { return m_sessionId; }
    void setSessionId(const QString &id);
    QVariantList messages() const { return m_messages; }

    Q_INVOKABLE void connectToServer(const QString &url, const QString &playerId);
    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void sendImage(const QString &filePath);
    Q_INVOKABLE void loadHistory();
    Q_INVOKABLE void requestHistory(int beforeId = -1);

    static void registerQml() {
        qmlRegisterType<ChatClient>("Meownopoly.Chat", 1, 0, "ChatClient");
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
    
    QWebSocket m_webSocket;
    bool m_connected = false;
    QString m_sessionId;
    QString m_playerId;
    QByteArray m_lockKey;
    QByteArray m_sessionKey;
    QVariantList m_messages;
    
    ChatDatabase m_db;
};

#endif // CHAT_CLIENT_H
