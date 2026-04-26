/*
 *      PattounX v2 — PhysicsWorld
 *
 * Façade QML qui pilote un `PhysicsWorker` exécuté dans un QThread
 * dédié. Lecture lock-free des snapshots via un triple buffer
 * (Fraser-Harris) ; mutations sérialisées vers le worker via signaux
 * QueuedConnection.
 */
#ifndef PHYSICS_WORLD_H
#define PHYSICS_WORLD_H

#include "pattounx_types.h"

#include <QByteArray>
#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector2D>
#include <atomic>

class QThread;
class PhysicsWorker;

class PhysicsWorld : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(int tickRate READ tickRate WRITE setTickRate NOTIFY tickRateChanged)
    Q_PROPERTY(bool simulationEnabled READ simulationEnabled
                   WRITE setSimulationEnabled NOTIFY simulationEnabledChanged)
    Q_PROPERTY(quint64 currentTick READ currentTick NOTIFY snapshotAvailable)
    Q_PROPERTY(qint64 currentTimestampNs READ currentTimestampNs NOTIFY snapshotAvailable)

public:
    explicit PhysicsWorld(QObject *parent = nullptr);
    ~PhysicsWorld() override;

    static void registerQml();

    bool isRunning() const { return m_running; }
    int tickRate() const { return m_tickRate; }
    bool simulationEnabled() const { return m_simEnabled; }
    quint64 currentTick() const;
    qint64 currentTimestampNs() const;

    void setTickRate(int hz);
    void setSimulationEnabled(bool on);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

    // --- Bodies ---
    Q_INVOKABLE void createKinematicActor(const QString &actorId,
                                          QVector2D position,
                                          qreal radius = 0.2,
                                          QVariantMap params = {});
    Q_INVOKABLE void createDynamicCircle(const QString &id,
                                         QVector2D position,
                                         qreal radius,
                                         qreal mass,
                                         QVariantMap params = {});
    Q_INVOKABLE void createStaticCircle(const QString &id,
                                        QVector2D position,
                                        qreal radius);
    Q_INVOKABLE void removeBody(const QString &id);
    Q_INVOKABLE void setBodyPosition(const QString &id, QVector2D pos);
    Q_INVOKABLE void applyImpulse(const QString &id, QVector2D impulse);

    // --- Inputs ---
    Q_INVOKABLE void pushInput(const QString &actorId, QVector2D input);

    // --- Zones ---
    Q_INVOKABLE void upsertZone(const QString &zoneId,
                                const QVariantList &polygonAbsolute,
                                QVariantMap params);
    Q_INVOKABLE void removeZone(const QString &zoneId);
    Q_INVOKABLE void clearZones();

    // --- Lecture snapshot (lock-free, GUI thread uniquement) ---
    Q_INVOKABLE QVariantMap bodyState(const QString &id);
    Q_INVOKABLE QStringList allBodyIds();
    Q_INVOKABLE qint64 stepDurationNs() const;
    // Tick de la frame physique actuellement lue par bodyState (=
    // m_guiInUse->tick). À utiliser pour détecter une nouvelle frame
    // côté QML : `currentTick` (la Q_PROPERTY) est mise à jour via
    // signal queued depuis le worker → désynchronisée avec ce que
    // bodyState retourne réellement.
    Q_INVOKABLE quint64 currentGuiTick();

    // Signal de cycle GUI : à appeler une fois par frame (FrameAnimation)
    // pour autoriser l'avancement vers la frame physique la plus récente.
    Q_INVOKABLE void beginFrame();

    // ── Réseau (state-sync host-authoritative, cf. PHYSICS_REFACTOR_PLAN §5.5) ──

    /// Hôte : sérialise le snapshot GUI courant au format binaire compact.
    /// Effet de bord : assigne un idIndex aux bodies nouveaux et marque
    /// les bodies disparus → cf. takePendingAnnouncements() pour récupérer
    /// le delta à envoyer en BodiesAnnounce reliable AVANT le snapshot.
    Q_INVOKABLE QByteArray serializeSnapshot();

    /// Client : applique un snapshot reçu de l'hôte. Active automatiquement
    /// le mode "remote buffer" (bodyState/allBodyIds lisent depuis le snapshot
    /// distant ; la simu locale est typiquement désactivée via
    /// setSimulationEnabled(false) côté client).
    /// Les bodies dont l'idIndex n'est pas connu (BodiesAnnounce pas encore
    /// reçu) sont droppés silencieusement de cette frame.
    Q_INVOKABLE void applyRemoteSnapshot(const QByteArray &payload);

    /// Hôte : table {idIndex → actorId} pour broadcast initial / re-announce
    /// périodique aux clients. Format QVariantMap avec clés en string décimale
    /// pour passer en QML/JSON.
    Q_INVOKABLE QVariantMap currentBodyTable() const;

    /// Hôte : delta cumulé depuis le dernier appel. Format :
    /// { added: [{i:int, id:str}], removed: [str] }. Vidé après lecture.
    Q_INVOKABLE QVariantMap takePendingAnnouncements();

    /// Client : applique un BodiesAnnounce reçu (mise à jour de la table
    /// idIndex → actorId). `addedMap` : {string idIndex → string actorId}.
    Q_INVOKABLE void applyBodiesAnnounce(const QVariantMap &addedMap,
                                         const QStringList &removed);

    /// Client : true si un snapshot remote a été appliqué au moins une fois
    /// (bodyState/allBodyIds lisent depuis m_remoteBuffer plutôt que le triple
    /// buffer du worker).
    Q_INVOKABLE bool useRemoteBuffer() const { return m_useRemoteBuffer; }

    /// Force la bascule du mode remote (true) ou local (false). Utile pour
    /// repasser en local après une déconnexion réseau côté client.
    Q_INVOKABLE void setUseRemoteBuffer(bool on);

signals:
    void runningChanged();
    void tickRateChanged();
    void simulationEnabledChanged();
    void actorEnteredZone(const QString &actorId, const QString &zoneId);
    void actorExitedZone(const QString &actorId, const QString &zoneId);
    void actorCollided(const QString &actorId, const QString &other,
                       QVector2D normal, qreal impactSpeed);
    void snapshotAvailable(quint64 tick);

    // Internes : pilotent le worker via QueuedConnection
    void startLoop();
    void cmdUpsertBody(pattounx::BodySpec spec);
    void cmdRemoveBody(QString id);
    void cmdSetBodyPosition(QString id, QVector2D pos);
    void cmdApplyImpulse(QString id, QVector2D impulse);
    void cmdPushInput(QString actorId, QVector2D input);
    void cmdUpsertZone(pattounx::ZoneSpec spec);
    void cmdRemoveZone(QString id);
    void cmdClearZones();
    void cmdRequestStop();
    void cmdSetTickRate(int hz);
    void cmdSetSimulationEnabled(bool on);

private:
    void onSnapshotPublished(quint64 tick, qint64 timestampNs, qint64 stepDurationNs);
    void tryAdvanceGuiBuffer();

    QThread *m_thread = nullptr;
    PhysicsWorker *m_worker = nullptr;

    bool m_running = false;
    int m_tickRate = 60;
    bool m_simEnabled = true;

    // Triple buffer Fraser-Harris.
    pattounx::WorldSnapshot m_buffers[3];
    std::atomic<pattounx::WorldSnapshot *> m_pending { nullptr };
    pattounx::WorldSnapshot *m_guiInUse = nullptr;

    // Empêche `bodyState` de consommer plusieurs frames pendant le même
    // rendu : reset à chaque appel `beginFrame()`.
    bool m_guiAdvancedThisFrame = false;

    // Métadonnées de la frame GUI active (pour QML)
    quint64 m_lastTick = 0;
    qint64 m_lastTimestampNs = 0;
    qint64 m_lastStepDurationNs = 16'666'667; // 60 Hz par défaut

    // ── État réseau (host & client) ─────────────────────────────────────────
    // Hôte : table idIndex ↔ actorId attribuée incrémentalement à mesure que
    // les bodies apparaissent dans le snapshot. Rebuild à zéro entre sessions.
    // Client : peuplée via applyBodiesAnnounce. Indispensable pour décoder
    // les Snapshot reçus (qui n'embarquent que des idIndex u16).
    QHash<QString, quint16> m_idIndexByActor;
    QHash<quint16, QString> m_actorByIdIndex;
    quint16 m_nextIdIndex = 1; // 0 réservé sentinel "non assigné"

    // Hôte : delta cumulé entre serializeSnapshot() consécutifs. Vidé par
    // takePendingAnnouncements().
    struct PendingAnn {
        QHash<quint16, QString> added;
        QStringList removed;
    } m_pendingAnnouncements;

    // Client : buffer de réception du snapshot distant. Quand m_useRemoteBuffer
    // est true, bodyState/allBodyIds/currentGuiTick lisent depuis ce buffer
    // au lieu du triple buffer worker (qui peut être inactif si simEnabled=false).
    bool m_useRemoteBuffer = false;
    pattounx::WorldSnapshot m_remoteBuffer;
};

#endif // PHYSICS_WORLD_H
