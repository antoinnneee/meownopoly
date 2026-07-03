/*
 *      PattounX v2 — PhysicsWorker
 *
 * Hôte du moteur Qt-free `pattounx::PattounX_engine` dans un QThread
 * dédié. Reçoit les commandes via signaux/slots queued, publie les
 * snapshots dans une boîte aux lettres atomique partagée avec la GUI
 * (cf. `PhysicsWorld` pour la lecture côté GUI).
 */
#ifndef PHYSICS_WORKER_H
#define PHYSICS_WORKER_H

#include "pattounx_engine_v2.h"
#include "pattounx_types.h"

#include <QObject>
#include <QString>
#include <QVector2D>
#include <atomic>

class PhysicsWorker : public QObject
{
    Q_OBJECT

public:
    explicit PhysicsWorker(QObject *parent = nullptr);
    ~PhysicsWorker() override;

    /**
     * Initialise le worker avec le buffer de back qu'il possède au
     * démarrage, le pointeur atomique partagé `pending`, et l'atomique
     * `pendingTick` (tick de la dernière publication, mis à jour APRÈS le
     * dépôt dans `pending`). La GUI peek `pendingTick` au lieu de
     * déréférencer le buffer pending — qu'elle ne possède pas encore
     * (déréférencer serait une data race : le worker peut le récupérer et
     * y écrire pendant la lecture).
     * Doit être appelé AVANT runLoop, depuis le thread GUI ou via
     * BlockingQueuedConnection.
     */
    void setSnapshotSink(std::atomic<pattounx::WorldSnapshot *> *pending,
                         std::atomic<quint64> *pendingTick,
                         pattounx::WorldSnapshot *initialBack);

public slots:
    void runLoop();
    void requestStop();

    void setTargetTickRateHz(int hz);
    void setSimulationEnabled(bool on);

    // Commandes (queued depuis PhysicsWorld) :
    void cmdUpsertBody(pattounx::BodySpec spec);
    void cmdRemoveBody(QString id);
    void cmdSetBodyPosition(QString id, QVector2D pos);
    void cmdApplyImpulse(QString id, QVector2D impulse);
    void cmdPushInput(QString actorId, QVector2D input);

    void cmdUpsertZone(pattounx::ZoneSpec spec);
    void cmdRemoveZone(QString id);
    void cmdClearZones();

signals:
    void actorEnteredZone(QString actorId, QString zoneId);
    void actorExitedZone(QString actorId, QString zoneId);
    void actorCollided(QString actorId, QString other,
                       QVector2D normal, qreal impactSpeed);
    void snapshotPublished(quint64 tick, qint64 timestampNs, qint64 stepDurationNs);
    void stopped();

private:
    void runStep();

    pattounx::PattounX_engine m_engine;

    std::atomic<bool> m_stopRequested { false };
    std::atomic<bool> m_simEnabled { true };
    std::atomic<int> m_tickHz { 60 };
    quint64 m_tick = 0;

    std::atomic<pattounx::WorldSnapshot *> *m_pending = nullptr;
    std::atomic<quint64> *m_pendingTick = nullptr;
    pattounx::WorldSnapshot *m_workerBack = nullptr;
};

#endif // PHYSICS_WORKER_H
