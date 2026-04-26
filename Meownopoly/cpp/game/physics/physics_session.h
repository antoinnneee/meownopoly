/*
 *      PattounX v2 — PhysicsSession (state-sync host-authoritative)
 *
 * Singleton orchestrateur réseau pour la physique. Calqué sur EditorSession :
 *  - Hôte  : autoritaire, sa simu locale est la vérité. Broadcast 30 Hz d'un
 *            snapshot binaire compact (cf. PhysicsWorld::serializeSnapshot)
 *            précédé d'un BodiesAnnounce reliable quand des bodies apparaissent
 *            ou disparaissent.
 *  - Client : `physicsWorld->setSimulationEnabled(false)` puis applique chaque
 *            snapshot reçu via `applyRemoteSnapshot`. Ses inputs sont relayés
 *            à l'hôte via `InputUpdate` reliable au lieu de pushInput direct.
 *
 * Coexiste sur Catway avec EditorSession et GameSession : démultiplexage par
 * plage de type-byte (PhysicsMessageType = 0x40+).
 */
#ifndef PHYSICS_SESSION_H
#define PHYSICS_SESSION_H

#include <QElapsedTimer>
#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>
#include <QVector2D>

class PhysicsWorld;

class PhysicsSession : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    Q_PROPERTY(QString localPlayerId READ localPlayerId NOTIFY localPlayerIdChanged)
    Q_PROPERTY(QString hostPlayerId READ hostPlayerId NOTIFY hostPlayerIdChanged)
    Q_PROPERTY(int snapshotHz READ snapshotHz WRITE setSnapshotHz NOTIFY snapshotHzChanged)
    /// nombre de snapshots envoyés (host) ou reçus (client) — utile au panel test.
    Q_PROPERTY(quint64 snapshotsSent READ snapshotsSent NOTIFY snapshotsSentChanged)
    Q_PROPERTY(quint64 snapshotsReceived READ snapshotsReceived NOTIFY snapshotsReceivedChanged)
    /// (client) acteur que ce pair revendique le droit de contrôler. Si non vide,
    /// les InputControllers d'autres actorId ne sont PAS relayés à l'hôte
    /// (évite que l'IC1 d'un client ne pousse "player1" alors que l'host le
    /// pilote lui-même). Vide = pas de filtre.
    Q_PROPERTY(QString claimedActorId READ claimedActorId WRITE setClaimedActorId NOTIFY claimedActorIdChanged)

public:
    static void registerQml();
    static PhysicsSession *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool active() const           { return m_active; }
    bool isHost() const           { return m_isHost; }
    QString localPlayerId() const { return m_localPlayerId; }
    QString hostPlayerId() const  { return m_hostPlayerId; }
    int snapshotHz() const        { return m_snapshotHz; }
    quint64 snapshotsSent() const     { return m_snapshotsSent; }
    quint64 snapshotsReceived() const { return m_snapshotsReceived; }
    QString claimedActorId() const    { return m_claimedActorId; }

    void setSnapshotHz(int hz);
    void setClaimedActorId(const QString &actorId);

    /// Lien vers le PhysicsWorld pilote. À appeler une fois au boot
    /// (qmlapp.cpp). PhysicsSession ne possède pas le world.
    Q_INVOKABLE void setPhysicsWorld(QObject *world);

    /// Démarre comme hôte autoritaire. La simu locale doit déjà être en cours
    /// (PhysicsWorld::start). Démarre le timer de broadcast snapshot.
    Q_INVOKABLE bool startAsHost(const QString &localPlayerId);

    /// Démarre comme client. Désactive la sim locale (setSimulationEnabled(false))
    /// — la position est dictée par les snapshots reçus via applyRemoteSnapshot.
    /// Bascule également physicsWorld vers le mode remote buffer.
    Q_INVOKABLE bool startAsClient(const QString &localPlayerId,
                                   const QString &hostPlayerId);

    /// Arrête la session. Côté client : ré-active la sim locale et purge le
    /// buffer remote. Côté host : arrête le timer et purge la table d'idIndex.
    Q_INVOKABLE void stop();

    /// API d'input unifié : appelé par InputController. Si client → InputUpdate
    /// reliable au host ; sinon (host ou monoposte) → pushInput direct.
    Q_INVOKABLE void pushOrSendInput(const QString &actorId, QVector2D input);

    /// Hôte uniquement : envoie immédiatement un BodiesAnnounce avec la table
    /// complète (utile au peer-connect ou re-sync manuel).
    Q_INVOKABLE void broadcastFullBodyTable();

signals:
    void activeChanged();
    void isHostChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();
    void snapshotHzChanged();
    void snapshotsSentChanged();
    void snapshotsReceivedChanged();
    void claimedActorIdChanged();

private slots:
    void onReliableReceived(const QString &senderId, const QByteArray &data);
    void onPlayerTimedOut(const QString &playerId);
    void onSnapshotTimerFired();

private:
    explicit PhysicsSession(QObject *parent = nullptr);
    static PhysicsSession *m_pThis;

    void connectToCatway();
    void disconnectFromCatway();

    /// Hôte : envoie BodiesAnnounce reliable si pending non vide.
    void flushPendingAnnouncements();

    /// Hôte : envoie le payload Snapshot (binaire) en reliable broadcast.
    void broadcastSnapshot();

    /// Construit le payload JSON BodiesAnnounce { added: {idx → id}, removed: [id] }.
    static QJsonObject buildAnnouncePayload(const QVariantMap &added,
                                            const QVariantList &removed);
    static QJsonObject buildAnnouncePayloadFromMap(const QVariantMap &fullTable);

    QPointer<PhysicsWorld> m_world;

    bool    m_active = false;
    bool    m_isHost = false;
    QString m_localPlayerId;
    QString m_hostPlayerId;

    int m_snapshotHz = 30;
    QTimer m_snapshotTimer;
    QTimer m_fullTableTimer; // re-broadcast périodique de la table (couvre late-join + paquets perdus)

    QString m_claimedActorId;

    quint64 m_snapshotsSent = 0;
    quint64 m_snapshotsReceived = 0;

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_timeoutConn;
};

#endif // PHYSICS_SESSION_H
