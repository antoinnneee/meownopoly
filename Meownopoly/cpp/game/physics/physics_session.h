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

    // ── Canal combat (CombatController) ────────────────────────────────────
    /// Client → hôte : requête de combat (JSON libre, ex. {type:"attack"}).
    /// No-op si session inactive ou si on est l'hôte (résolution locale).
    Q_INVOKABLE void sendCombatRequest(const QVariantMap &payload);

    /// Hôte → tous : broadcast reliable d'un événement de combat résolu.
    /// No-op si session inactive ou si on n'est pas l'hôte.
    Q_INVOKABLE void broadcastCombatEvent(const QVariantMap &payload);

    /// Hôte : actorIds revendiqués par les clients distants (cibles
    /// potentielles de l'IA de combat, en plus du joueur local de l'hôte).
    Q_INVOKABLE QStringList remoteClaimedActors() const
    { return QStringList(m_remoteClaims.values().begin(), m_remoteClaims.values().end()); }

signals:
    void activeChanged();
    void isHostChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();
    void snapshotHzChanged();
    void snapshotsSentChanged();
    void snapshotsReceivedChanged();
    void claimedActorIdChanged();

    /// Hôte : un client demande une action de combat (à résoudre par le
    /// CombatController autoritaire).
    void combatRequestReceived(const QString &senderId, const QVariantMap &payload);
    /// Client : l'hôte a résolu un événement de combat (à appliquer sur les
    /// miroirs locaux).
    void combatEventReceived(const QVariantMap &payload);
    /// Hôte : la table des claims distants a changé (Hello / timeout).
    void remoteClaimsChanged();

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
    /// `removed` peut être omis (cas re-broadcast full table).
    static QJsonObject buildAnnouncePayload(const QVariantMap &added,
                                            const QVariantList &removed = {});

    QPointer<PhysicsWorld> m_world;

    bool    m_active = false;
    bool    m_isHost = false;
    QString m_localPlayerId;
    QString m_hostPlayerId;

    int m_snapshotHz = 30;
    QTimer m_snapshotTimer;
    QTimer m_fullTableTimer; // re-broadcast périodique de la table (couvre late-join + paquets perdus)

    QString m_claimedActorId;

    // Hôte uniquement : suivi des actorId revendiqués par chaque client
    // distant. Renseigné via le payload du Hello reçu d'un peer. Sert à
    // ignorer les pushInput locaux pour des actors qu'un client contrôle
    // déjà — sinon les flèches du host se battent avec les InputUpdate du
    // client. Purgé à playerTimedOut + stop.
    QHash<QString, QString> m_remoteClaims; // senderId → actorId

    quint64 m_snapshotsSent = 0;
    quint64 m_snapshotsReceived = 0;

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_timeoutConn;
};

#endif // PHYSICS_SESSION_H
