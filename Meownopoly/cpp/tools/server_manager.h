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
    Q_INVOKABLE void setStunServer(QString ip, quint16 port);

signals:
    void log(QString message);
    void serverStarted(quint16 localPort);
    void externalAddressReceived(QString ip, quint16 port);

private slots:
    void onReadyRead();

private:
    QUdpSocket *m_socket;
    QString m_stunServerIp = "stun.l.google.com";
    quint16 m_stunServerPort = 19302;
    
    void handleStunResponse(const QByteArray &datagram, const QHostAddress &sender, quint16 senderPort);
    
    QHostAddress m_publicAddress;
    quint16 m_publicPort;
    QHostAddress m_stunSenderAddress;
    quint16 m_stunSenderPort;
};

#endif // SERVER_MANAGER_H
