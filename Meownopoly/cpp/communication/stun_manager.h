#ifndef STUN_MANAGER_H
#define STUN_MANAGER_H

#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>
#include <QTimer>

class UdpSocketInfo;

class StunManager : public QObject
{
    Q_OBJECT
public:
    explicit StunManager(QObject *parent = nullptr);
    ~StunManager();

    Q_INVOKABLE bool startServer();
    Q_INVOKABLE void stopServer();
    Q_INVOKABLE void sendStunRequest();
    Q_INVOKABLE void setStunServer(QString ip, quint16 port);
    Q_INVOKABLE QString getStunServer() const;
    Q_INVOKABLE quint16 getStunPort() const;
    Q_INVOKABLE void setPublicPort(quint16 port);
    Q_INVOKABLE void setStunSenderAddress(QString ip);
    Q_INVOKABLE void setStunSenderPort(quint16 port);
    Q_INVOKABLE QString getExternalIp() const;
    Q_INVOKABLE quint16 getExternalPort() const;

    Q_INVOKABLE void setPeer(QString ip, quint16 port);
    Q_INVOKABLE void sendMessageToPeer(QString message);

    /// Retourne le socket UDP actuel (peut être nullptr). Ne transfère pas la propriété.
    QUdpSocket *getSocket() const;
    /// Retourne l'info du socket actuel (publicAddress, publicPort, socket). Ne transfère pas la propriété.
    UdpSocketInfo *currentSocketInfo() const;
    /// Détache l'UdpSocketInfo actuel (à gérer par l'appelant) et en crée un nouveau, prêt pour un prochain setup UDP punching (sans bind).
    UdpSocketInfo *takeSocket();

public slots:
    void handleStunResponse(const QByteArray &datagram, const QHostAddress &sender, quint16 senderPort);

signals:
    void log(QString message);
    void serverStarted(quint16 localPort);
    void externalAddressReceived(QString ip, quint16 port);
    void stunFailed(); // Emitted on timeout

private slots:
    void onReadyRead();
    void onStunTimeout();

private:
    UdpSocketInfo *m_socketInfo;
    QString m_stunServerIp = "stun.l.google.com";
    quint16 m_stunServerPort = 19302;

    QHostAddress m_stunSenderAddress;
    quint16 m_stunSenderPort;

    QHostAddress m_peerAddress;
    quint16 m_peerPort;
    QTimer *m_stunTimeout;
};

#endif // STUN_MANAGER_H
