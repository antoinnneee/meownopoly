#ifndef UDP_SOCKET_INFO_H
#define UDP_SOCKET_INFO_H

#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>

class UdpSocketInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString publicAddress READ publicAddress WRITE setPublicAddress NOTIFY publicAddressChanged)
    Q_PROPERTY(quint16 publicPort READ publicPort WRITE setPublicPort NOTIFY publicPortChanged)
    Q_PROPERTY(quint16 localPort READ localPort NOTIFY localPortChanged)

public:
    explicit UdpSocketInfo(QObject *parent = nullptr);
    ~UdpSocketInfo();

    QString publicAddress() const { return m_publicAddress; }
    void setPublicAddress(const QString &address);
    quint16 publicPort() const { return m_publicPort; }
    void setPublicPort(quint16 port);

    /// Socket (ownership transférée à cet objet si setSocket est appelé avec un nouveau socket).
    /// \a deleteOldSocket si true (défaut), l'ancien socket est détruit ; sinon il est seulement détaché (setParent(nullptr)).
    QUdpSocket *socket() const { return m_socket; }
    void setSocket(QUdpSocket *sock, bool deleteOldSocket = true);

    quint16 localPort() const;

signals:
    void publicAddressChanged();
    void publicPortChanged();
    void socketChanged();
    void localPortChanged();

private slots:
    void onSocketStateChanged(QAbstractSocket::SocketState state);

private:
    QString m_publicAddress;
    quint16 m_publicPort = 0;
    QUdpSocket *m_socket = nullptr;
};

#endif // UDP_SOCKET_INFO_H
