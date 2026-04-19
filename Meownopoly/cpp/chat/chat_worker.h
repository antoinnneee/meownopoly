#ifndef CHAT_WORKER_H
#define CHAT_WORKER_H

#include <QObject>
#include <QWebSocket>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>

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
    /// RTT mesuré par un WebSocket ping frame. Emis à chaque pong reçu.
    void pongReceived(quint64 elapsedMs);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onError(QAbstractSocket::SocketError error);
    void onPong(quint64 elapsedTime, const QByteArray &payload);
    void sendPingFrame();

private:
    QWebSocket *m_webSocket;
    QTimer *m_pingTimer = nullptr;
};

#endif // CHAT_WORKER_H

