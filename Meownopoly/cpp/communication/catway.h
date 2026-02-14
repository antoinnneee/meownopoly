#ifndef CATWAY_H
#define CATWAY_H

#include <QObject>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QHostAddress>
#include <QTimer>
#include <QList>

class QUdpSocket;
class StunManager;
#include "udp_socket_info.h"

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
    Q_INVOKABLE void setStunServer(QString ip);
    Q_INVOKABLE void setStunPort(quint16 port);
    Q_INVOKABLE QString getExternalIp() const;
    Q_INVOKABLE quint16 getExternalPort() const;

    /// Retourne le socket UDP actuel (pour usage C++). Ne transfère pas la propriété.
    Q_INVOKABLE QObject *getSocket() const;
    /// Retourne l'info du socket actuel (publicAddress, publicPort, socket).
    Q_INVOKABLE QObject *currentSocketInfo() const;
    /// Détache le socket actuel et en prépare un nouveau dans StunManager. L'ancien UdpSocketInfo est ajouté à localPorts et retourné.
    Q_INVOKABLE UdpSocketInfo *takeSocket();

    /// Liste des infos de ports locaux (sockets récupérés via takeSocket).
    Q_PROPERTY(QQmlListProperty<UdpSocketInfo> localPorts READ localPorts NOTIFY localPortsChanged)
    QQmlListProperty<UdpSocketInfo> localPorts();

public slots:
    Q_INVOKABLE void setupNewPort();
signals:
    void log(QString message);
    void serverStarted(quint16 port);
    void externalAddressReceived(QString ip, quint16 port);
    void localPortsChanged();

private slots:
    void onAccountStunChanged();
    void onExternalAddressReceivedTakePort(QString ip, quint16 port);

private:
    explicit Catway(QObject *parent = nullptr);
    static Catway *m_pThis;

    static qsizetype localPortsCount(QQmlListProperty<UdpSocketInfo> *p);
    static UdpSocketInfo *localPortsAt(QQmlListProperty<UdpSocketInfo> *p, qsizetype index);

    StunManager *m_stunManager;
    QList<UdpSocketInfo *> m_localSocketInfos;
    QMetaObject::Connection m_stunConnection;
    QMetaObject::Connection m_externalAddressTakePortConnection;
};

#endif // CATWAY_H
