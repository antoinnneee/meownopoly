#ifndef SERVER_MANAGER_H
#define SERVER_MANAGER_H

#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>

class ServerManager : public QObject
{
    Q_OBJECT
public:
    explicit ServerManager(QObject *parent = nullptr);
    ~ServerManager();

    Q_INVOKABLE void startServer();
    Q_INVOKABLE void stopServer();
    Q_INVOKABLE void sendStunRequest();

signals:
    void log(QString message);
    void serverStarted(quint16 localPort);
    void externalAddressReceived(QString ip, quint16 port);

private slots:
    void onReadyRead();

private:
    QUdpSocket *m_socket;
};

#endif // SERVER_MANAGER_H
