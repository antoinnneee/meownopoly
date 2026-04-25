#include "physics_worker.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QElapsedTimer>
#include <QThread>
#include <algorithm>

PhysicsWorker::PhysicsWorker(QObject *parent)
    : QObject(parent)
{
}

PhysicsWorker::~PhysicsWorker() = default;

void PhysicsWorker::setSnapshotSink(std::atomic<pattounx::WorldSnapshot *> *pending,
                                    pattounx::WorldSnapshot *initialBack)
{
    m_pending = pending;
    m_workerBack = initialBack;
}

void PhysicsWorker::requestStop()
{
    m_stopRequested.store(true);
}

void PhysicsWorker::setTargetTickRateHz(int hz)
{
    if (hz < 1) hz = 1;
    if (hz > 480) hz = 480;
    m_tickHz.store(hz);
}

void PhysicsWorker::setSimulationEnabled(bool on)
{
    m_simEnabled.store(on);
}

void PhysicsWorker::cmdUpsertBody(pattounx::BodySpec spec)
{
    m_engine.upsertBody(spec);
}

void PhysicsWorker::cmdRemoveBody(QString id)
{
    m_engine.removeBody(id);
}

void PhysicsWorker::cmdSetBodyPosition(QString id, QVector2D pos)
{
    m_engine.setBodyPosition(id, pos);
}

void PhysicsWorker::cmdApplyImpulse(QString id, QVector2D impulse)
{
    m_engine.applyImpulse(id, impulse);
}

void PhysicsWorker::cmdPushInput(QString actorId, QVector2D input)
{
    m_engine.setBodyInput(actorId, input);
}

void PhysicsWorker::cmdUpsertZone(pattounx::ZoneSpec spec)
{
    m_engine.upsertZone(spec);
}

void PhysicsWorker::cmdRemoveZone(QString id)
{
    m_engine.removeZone(id);
}

void PhysicsWorker::cmdClearZones()
{
    m_engine.clearZones();
}

void PhysicsWorker::runLoop()
{
    QElapsedTimer clock;
    clock.start();

    qint64 lastTickHz = m_tickHz.load();
    qint64 stepNs = 1'000'000'000LL / lastTickHz;
    qint64 nextNs = clock.nsecsElapsed();

    while (!m_stopRequested.load()) {
        // Drainage des commandes queued (cmdXxx) avant le step.
        QCoreApplication::processEvents(QEventLoop::AllEvents);

        // Adapter stepNs si tickHz a changé
        int hz = m_tickHz.load();
        if (hz != lastTickHz) {
            lastTickHz = hz;
            stepNs = 1'000'000'000LL / hz;
        }

        qint64 now = clock.nsecsElapsed();
        if (now < nextNs) {
            qint64 sleepUs = std::max<qint64>(0, (nextNs - now) / 1000);
            // Yield au minimum, jamais > 5 ms (réactivité aux commandes)
            QThread::usleep(std::min<qint64>(sleepUs, 5000));
            continue;
        }

        if (m_simEnabled.load()) runStep();
        ++m_tick;
        nextNs += stepNs;

        // Anti spiral-of-death : si on a > 5 ticks de retard, on resync
        if (now - nextNs > stepNs * 5) nextNs = now + stepNs;
    }

    // Drainage final pour éventuelles commandes en file
    QCoreApplication::processEvents(QEventLoop::AllEvents);

    emit stopped();
}

void PhysicsWorker::runStep()
{
    qreal dt = 1.0 / static_cast<qreal>(m_tickHz.load());
    m_engine.step(dt);

    if (m_pending && m_workerBack) {
        qint64 nowNs = QDateTime::currentMSecsSinceEpoch() * 1'000'000LL;
        m_engine.writeSnapshot(*m_workerBack, m_tick, nowNs);

        // Atomic swap : on dépose m_workerBack dans m_pending et on récupère
        // ce qui s'y trouvait. En régime établi le résultat est non-null —
        // soit le buffer que la GUI vient de céder, soit notre publication
        // précédente que la GUI n'a pas encore consommée.
        pattounx::WorldSnapshot *prev
            = m_pending->exchange(m_workerBack, std::memory_order_acq_rel);
        if (prev) {
            m_workerBack = prev;
        }
        // Si prev est null, on garde notre buffer courant pour la prochaine
        // écriture — la GUI en a un qu'elle est en train de lire.
        qint64 stepNs = 1'000'000'000LL / m_tickHz.load();
        emit snapshotPublished(m_tick, nowNs, stepNs);
    }

    // Drainer événements et émettre signaux queued
    auto events = m_engine.takeEvents();
    for (const auto &e : events.entered)
        emit actorEnteredZone(e.first, e.second);
    for (const auto &e : events.exited)
        emit actorExitedZone(e.first, e.second);
    for (const auto &c : events.collisions)
        emit actorCollided(c.bodyId, c.other, c.normal, c.impactSpeed);
}
