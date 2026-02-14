#ifndef CATWAY_H
#define CATWAY_H

#include <QObject>
#include <QQmlEngine>
#include <QHostAddress>
#include <QTimer>

class QUdpSocket;
class StunManager;

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
    Q_INVOKABLE void setPublicPort(quint16 port);
    Q_INVOKABLE void setStunServer(QString ip);
    Q_INVOKABLE void setStunPort(quint16 port);
    Q_INVOKABLE void setStunSenderAddress(QString ip);
    Q_INVOKABLE void setStunSenderPort(quint16 port);
    Q_INVOKABLE QString getExternalIp() const;
    Q_INVOKABLE quint16 getExternalPort() const;

    /// Retourne le socket UDP actuel (pour usage C++). Ne transfère pas la propriété.
    Q_INVOKABLE QObject *getSocket() const;
    /// Détache le socket actuel et en prépare un nouveau dans StunManager (sans startServer). Retourne l'ancien socket (à gérer par l'appelant).
    Q_INVOKABLE QObject *takeSocket();

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

    StunManager *m_stunManager;
    QMetaObject::Connection m_stunConnection;
    QTimer *m_stunTimeout;
};

#endif // CATWAY_H
