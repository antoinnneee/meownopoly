#ifndef CHAT_WORKER_H
#define CHAT_WORKER_H

#include <QObject>
#include <QWebSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

class ChatWorker : public QObject
{
    Q_OBJECT

public:
    explicit ChatWorker(QObject *parent = nullptr);
    ~ChatWorker();

public slots:
    void connectToServer(const QString &url);
    void sendTextMessage(const QString &message);
    void disconnectFromServer();

signals:
    // Signals emitted to the main thread
    void connected();
    void disconnected();
    void textMessageReceived(const QString &message);
    void errorOccurred(const QString &error);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onError(QAbstractSocket::SocketError error);

private:
    QWebSocket *m_webSocket;
};

#endif // CHAT_WORKER_H

