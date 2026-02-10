#ifndef CATWAY_H
#define CATWAY_H

#include <QObject>
#include <QQmlEngine>
#include <QHostAddress>
#include <QTimer>

class ServerManager;

class Catway : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static Catway *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void startServer();
    Q_INVOKABLE void stopServer();
    Q_INVOKABLE void sendStunRequest();
    Q_INVOKABLE void sendMessageToPeer(QString message);
    Q_INVOKABLE void setPeer(QString ip, quint16 port);

signals:
    void log(QString message);
    void serverStarted(quint16 port);
    void externalAddressReceived(QString ip, quint16 port);

private slots:
    void onAccountStunChanged();
    void onStunResponse(const QByteArray &datagram, const QHostAddress &sender, quint16 senderPort);
    void onStunTimeout();

private:
    explicit Catway(QObject *parent = nullptr);
    static Catway *m_pThis;

    ServerManager *m_serverManager;
    QMetaObject::Connection m_stunConnection;
    QTimer *m_stunTimeout;
};

#endif // CATWAY_H
