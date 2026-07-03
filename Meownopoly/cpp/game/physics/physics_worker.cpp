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
                                    std::atomic<quint64> *pendingTick,
                                    pattounx::WorldSnapshot *initialBack)
{
    m_pending = pending;
    m_pendingTick = pendingTick;
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
            // Clamp [100 µs, 5 ms] : jamais 0 (usleep(0) = busy-spin qui
            // sature un cœur), jamais > 5 ms (réactivité aux commandes).
            qint64 sleepUs = (nextNs - now) / 1000;
            QThread::usleep(std::clamp<qint64>(sleepUs, 100, 5000));
            continue;
        }

        if (m_simEnabled.load()) {
            // Tick incrémenté AVANT le step : le premier snapshot publié
            // porte tick=1 > tick initial 0 des buffers GUI (sinon il est
            // rejeté par le peek et jamais consommé, off-by-one). Et
            // UNIQUEMENT quand on steppe : sinon une pause sim fait sauter
            // des ticks à la reprise — dangereux pour tout dt dérivé de
            // Δtick.
            ++m_tick;
            runStep();
        }
        nextNs += stepNs;

        // Anti spiral-of-death : re-échantillonner APRÈS le step — un step
        // long rendait `now` périmé et le retard sous-estimé (resync raté).
        now = clock.nsecsElapsed();
        if (now - nextNs > stepNs * 5) nextNs = now + stepNs;
    }

    // Drainage final pour éventuelles commandes en file
    QCoreApplication::processEvents(QEventLoop::AllEvents);

    emit stopped();
}

// INVARIANT (load-bearing pour la GUI) : chaque publication dépose dans
// `m_pending` un buffer dont le `tick` est strictement plus récent que la
// publication précédente — autrement dit, le tick monotone du worker
// (`m_tick++`) est intégralement reflété dans la séquence des buffers
// publiés. Cet invariant est exploité par `PhysicsWorld::tryAdvanceGuiBuffer`
// (peek + swap conditionnel) pour garantir que le tick observé côté GUI
// est strictement croissant, même quand le rendu tire plus vite que la
// publication. Si on introduit un jour un mécanisme qui republierait un
// tick antérieur (ex : keyframe de resync, rollback, lockstep…), il
// faudra revoir le contrat côté GUI — sinon on retombe dans le bug
// "GUI tick oscille" résolu par fix(physics): GUI triple buffer regression.
void PhysicsWorker::runStep()
{
    qreal dt = 1.0 / static_cast<qreal>(m_tickHz.load());
    m_engine.step(dt);

    if (m_pending && m_workerBack) {
        qint64 nowNs = QDateTime::currentMSecsSinceEpoch() * 1'000'000LL;
        m_engine.writeSnapshot(*m_workerBack, m_tick, nowNs);

        // Atomic swap : on dépose m_workerBack (qui contient le tick le plus
        // récent qu'on vienne d'écrire) dans m_pending et on récupère ce qui
        // s'y trouvait. En régime établi le résultat est non-null — soit le
        // buffer que la GUI vient de céder, soit notre publication précédente
        // que la GUI n'a pas encore consommée. Dans tous les cas, le buffer
        // récupéré porte un tick STRICTEMENT INFÉRIEUR à `m_tick` (preuve :
        // m_workerBack était l'antéprédécesseur publié, donc tick < m_tick - 1
        // ou tick == m_tick - 1).
        pattounx::WorldSnapshot *prev
            = m_pending->exchange(m_workerBack, std::memory_order_acq_rel);
        // Invariant triple buffer : l'exchange retourne toujours un buffer
        // (3 buffers pour 2 acteurs). Un null signifierait un invariant
        // cassé — garder alors m_workerBack (déjà déposé dans m_pending)
        // serait un ALIASING : la prochaine écriture ciblerait le buffer
        // que la GUI peut être en train de lire. On coupe la publication
        // (m_workerBack = nullptr → le garde en tête de bloc skippe)
        // plutôt que de corrompre.
        Q_ASSERT_X(prev, "PhysicsWorker::runStep",
                   "triple buffer : exchange a retourné null (invariant cassé)");
        m_workerBack = prev;

        // Publier le tick APRÈS le dépôt dans m_pending (release) : quand
        // la GUI observe ce tick (acquire), le buffer correspondant — ou
        // un plus récent — est garanti présent dans m_pending. La GUI peek
        // ce tick au lieu de déréférencer le buffer pending (data race :
        // le worker pourrait le récupérer et y écrire pendant la lecture).
        // Le store étant post-exchange, la GUI peut voir un tick en retard
        // d'une publication → au pire elle rejoue une frame, jamais l'inverse.
        if (m_pendingTick)
            m_pendingTick->store(m_tick, std::memory_order_release);

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
