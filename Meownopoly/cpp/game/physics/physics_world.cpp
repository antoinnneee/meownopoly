#include "physics_world.h"

#include "physics_worker.h"

#include <QDebug>
#include <QEventLoop>
#include <QMetaType>
#include <QThread>
#include <QTimer>
#include <QtQml>

using namespace pattounx;

namespace {

BodySpec specFromKinematic(const QString &id, QVector2D pos, qreal radius,
                           const QVariantMap &p)
{
    BodySpec s;
    s.id = id;
    s.type = BodyType::Kinematic;
    s.shape.type = ShapeType::Circle;
    s.shape.radius = radius;
    s.position = pos;
    s.mass = p.value(QStringLiteral("mass"), 1.0).toReal();
    s.acceleration = p.value(QStringLiteral("acceleration"), 30.0).toReal();
    s.maxSpeed = p.value(QStringLiteral("maxSpeed"), 5.0).toReal();
    s.bounceFactor = p.value(QStringLiteral("bounceFactor"), 0.1).toReal();
    s.slideFactor = p.value(QStringLiteral("slideFactor"), 1.0).toReal();
    s.linearDamping = p.value(QStringLiteral("linearDamping"), 0.1).toReal();
    s.staticFriction = p.value(QStringLiteral("staticFriction"), 0.4).toReal();
    s.dynamicFriction = p.value(QStringLiteral("dynamicFriction"), 0.2).toReal();
    s.restitution = p.value(QStringLiteral("restitution"), 0.3).toReal();
    return s;
}

BodySpec specFromDynamic(const QString &id, QVector2D pos, qreal radius,
                         qreal mass, const QVariantMap &p)
{
    BodySpec s = specFromKinematic(id, pos, radius, p);
    s.type = BodyType::Dynamic;
    s.mass = mass > 0.0 ? mass : 1.0;
    return s;
}

BodySpec specFromStatic(const QString &id, QVector2D pos, qreal radius)
{
    BodySpec s;
    s.id = id;
    s.type = BodyType::Static;
    s.shape.type = ShapeType::Circle;
    s.shape.radius = radius;
    s.position = pos;
    return s;
}

ZoneSpec zoneFromVariant(const QString &zoneId,
                         const QVariantList &polygonAbsolute,
                         const QVariantMap &p)
{
    ZoneSpec z;
    z.id = zoneId;
    z.exclusion = p.value(QStringLiteral("exclusion"), false).toBool();
    z.trigger = p.value(QStringLiteral("trigger"), true).toBool();
    z.frictionStrength = p.value(QStringLiteral("frictionStrength"), 0.5).toReal();
    z.accelerationMultiplier = p.value(QStringLiteral("accelerationMultiplier"), 1.0).toReal();
    z.speedMultiplier = p.value(QStringLiteral("speedMultiplier"), 1.0).toReal();
    QVector2D vForce;
    if (p.contains(QStringLiteral("velocityForce"))) {
        QVariant vf = p.value(QStringLiteral("velocityForce"));
        if (vf.canConvert<QVector2D>()) vForce = vf.value<QVector2D>();
    }
    z.velocityForce = vForce;

    z.polygon.reserve(polygonAbsolute.size());
    for (const QVariant &v : polygonAbsolute) {
        if (v.canConvert<QVector2D>()) {
            z.polygon.append(v.value<QVector2D>());
            continue;
        }
        QVariantMap m = v.toMap();
        if (m.contains(QStringLiteral("x")) && m.contains(QStringLiteral("y"))) {
            z.polygon.append(QVector2D(
                m.value(QStringLiteral("x")).toFloat(),
                m.value(QStringLiteral("y")).toFloat()));
        }
    }
    return z;
}

} // namespace

void PhysicsWorld::registerQml()
{
    qRegisterMetaType<pattounx::BodySpec>("pattounx::BodySpec");
    qRegisterMetaType<pattounx::ZoneSpec>("pattounx::ZoneSpec");
    qRegisterMetaType<pattounx::BodySnapshot>("pattounx::BodySnapshot");
    qRegisterMetaType<pattounx::WorldSnapshot>("pattounx::WorldSnapshot");
    qRegisterMetaType<QVector2D>("QVector2D");

    qmlRegisterType<PhysicsWorld>("Pattounx", 1, 0, "PhysicsWorld");
}

PhysicsWorld::PhysicsWorld(QObject *parent)
    : QObject(parent)
{
}

PhysicsWorld::~PhysicsWorld()
{
    if (m_running) stop();
}

quint64 PhysicsWorld::currentTick() const { return m_lastTick; }
qint64 PhysicsWorld::currentTimestampNs() const { return m_lastTimestampNs; }
qint64 PhysicsWorld::stepDurationNs() const { return m_lastStepDurationNs; }

void PhysicsWorld::setTickRate(int hz)
{
    if (hz < 1) hz = 1;
    if (m_tickRate == hz) return;
    m_tickRate = hz;
    emit tickRateChanged();
    if (m_running) emit cmdSetTickRate(hz);
}

void PhysicsWorld::setSimulationEnabled(bool on)
{
    if (m_simEnabled == on) return;
    m_simEnabled = on;
    emit simulationEnabledChanged();
    if (m_running) emit cmdSetSimulationEnabled(on);
}

void PhysicsWorld::start()
{
    if (m_running) return;

    // Initialisation triple buffer :
    //   m_buffers[0] -> back du worker
    //   m_buffers[1] -> guiInUse (lecture GUI courante)
    //   m_buffers[2] -> pending (boîte aux lettres atomique)
    m_buffers[0] = pattounx::WorldSnapshot();
    m_buffers[1] = pattounx::WorldSnapshot();
    m_buffers[2] = pattounx::WorldSnapshot();
    m_guiInUse = &m_buffers[1];
    m_pending.store(&m_buffers[2], std::memory_order_release);

    m_thread = new QThread(this);
    m_thread->setObjectName(QStringLiteral("PhysicsWorker"));

    m_worker = new PhysicsWorker();
    m_worker->moveToThread(m_thread);
    m_worker->setTargetTickRateHz(m_tickRate);
    m_worker->setSimulationEnabled(m_simEnabled);
    m_worker->setSnapshotSink(&m_pending, &m_buffers[0]);

    // Pilotage par signaux queued
    connect(this, &PhysicsWorld::startLoop, m_worker, &PhysicsWorker::runLoop);
    connect(this, &PhysicsWorld::cmdRequestStop, m_worker,
            &PhysicsWorker::requestStop, Qt::DirectConnection);
    connect(this, &PhysicsWorld::cmdSetTickRate, m_worker,
            &PhysicsWorker::setTargetTickRateHz);
    connect(this, &PhysicsWorld::cmdSetSimulationEnabled, m_worker,
            &PhysicsWorker::setSimulationEnabled);
    connect(this, &PhysicsWorld::cmdUpsertBody, m_worker,
            &PhysicsWorker::cmdUpsertBody);
    connect(this, &PhysicsWorld::cmdRemoveBody, m_worker,
            &PhysicsWorker::cmdRemoveBody);
    connect(this, &PhysicsWorld::cmdSetBodyPosition, m_worker,
            &PhysicsWorker::cmdSetBodyPosition);
    connect(this, &PhysicsWorld::cmdApplyImpulse, m_worker,
            &PhysicsWorker::cmdApplyImpulse);
    connect(this, &PhysicsWorld::cmdPushInput, m_worker,
            &PhysicsWorker::cmdPushInput);
    connect(this, &PhysicsWorld::cmdUpsertZone, m_worker,
            &PhysicsWorker::cmdUpsertZone);
    connect(this, &PhysicsWorld::cmdRemoveZone, m_worker,
            &PhysicsWorker::cmdRemoveZone);
    connect(this, &PhysicsWorld::cmdClearZones, m_worker,
            &PhysicsWorker::cmdClearZones);

    // Évents physique → GUI
    connect(m_worker, &PhysicsWorker::actorEnteredZone, this,
            &PhysicsWorld::actorEnteredZone);
    connect(m_worker, &PhysicsWorker::actorExitedZone, this,
            &PhysicsWorld::actorExitedZone);
    connect(m_worker, &PhysicsWorker::actorCollided, this,
            &PhysicsWorld::actorCollided);
    connect(m_worker, &PhysicsWorker::snapshotPublished, this,
            &PhysicsWorld::onSnapshotPublished);

    connect(m_thread, &QThread::finished, m_worker, &QObject::deleteLater);

    m_thread->start();
    emit startLoop();

    m_running = true;
    emit runningChanged();
}

void PhysicsWorld::stop()
{
    if (!m_running) return;
    m_running = false;
    emit runningChanged();

    if (!m_worker || !m_thread) return;

    // Bloque l'attente que `stopped()` soit émis avec timeout 500 ms.
    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    bool stoppedCleanly = false;

    auto onStopped = [&]() {
        stoppedCleanly = true;
        loop.quit();
    };
    connect(m_worker, &PhysicsWorker::stopped, &loop, onStopped);
    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);

    emit cmdRequestStop();
    timeout.start(500);
    loop.exec();

    if (!stoppedCleanly) {
        qWarning() << "[PhysicsWorld] Worker did not stop cleanly within 500 ms,"
                   << "forcing thread terminate.";
        m_thread->terminate();
        m_thread->wait(100);
    } else {
        m_thread->quit();
        m_thread->wait(500);
    }

    m_worker = nullptr; // delete via QThread::finished -> deleteLater
    m_thread->deleteLater();
    m_thread = nullptr;

    m_pending.store(nullptr, std::memory_order_release);
    m_guiInUse = nullptr;
}

// --- Bodies ---

void PhysicsWorld::createKinematicActor(const QString &actorId, QVector2D position,
                                        qreal radius, QVariantMap params)
{
    emit cmdUpsertBody(specFromKinematic(actorId, position, radius, params));
}

void PhysicsWorld::createDynamicCircle(const QString &id, QVector2D position,
                                       qreal radius, qreal mass, QVariantMap params)
{
    emit cmdUpsertBody(specFromDynamic(id, position, radius, mass, params));
}

void PhysicsWorld::createStaticCircle(const QString &id, QVector2D position, qreal radius)
{
    emit cmdUpsertBody(specFromStatic(id, position, radius));
}

void PhysicsWorld::removeBody(const QString &id)
{
    emit cmdRemoveBody(id);
}

void PhysicsWorld::setBodyPosition(const QString &id, QVector2D pos)
{
    emit cmdSetBodyPosition(id, pos);
}

void PhysicsWorld::applyImpulse(const QString &id, QVector2D impulse)
{
    emit cmdApplyImpulse(id, impulse);
}

void PhysicsWorld::pushInput(const QString &actorId, QVector2D input)
{
    emit cmdPushInput(actorId, input);
}

void PhysicsWorld::upsertZone(const QString &zoneId, const QVariantList &polygonAbsolute,
                              QVariantMap params)
{
    emit cmdUpsertZone(zoneFromVariant(zoneId, polygonAbsolute, params));
}

void PhysicsWorld::removeZone(const QString &zoneId)
{
    emit cmdRemoveZone(zoneId);
}

void PhysicsWorld::clearZones()
{
    emit cmdClearZones();
}

// --- Snapshot / triple buffer ---

void PhysicsWorld::beginFrame()
{
    m_guiAdvancedThisFrame = false;
}

void PhysicsWorld::tryAdvanceGuiBuffer()
{
    if (m_guiAdvancedThisFrame) return;
    m_guiAdvancedThisFrame = true;

    if (!m_guiInUse) return;

    // Peek d'abord, swap ensuite. CRUCIAL quand le rendu tire plus vite
    // que le worker physique (ex : moniteur 144 Hz vs tick 60 Hz). Sans
    // ce peek, deux exchanges successifs sans publication entre les deux
    // récupèrent le buffer qu'on venait de déposer = un tick antérieur,
    // donnant l'illusion que la position physique régresse → jitter.
    //
    // Avec le peek, on ne consomme que si pending->tick > m_guiInUse->tick.
    // Sinon on rejoue la même frame (correct : pas de nouvelle physique).
    //
    // Race possible : entre load et exchange, le worker peut publier. Mais
    // le worker dépose toujours un tick ≥ celui qui était dans pending
    // (worker_back contient le tick qu'il vient d'écrire, > publication
    // précédente). Donc l'exchange ne peut que ramener un tick ≥ peek.
    pattounx::WorldSnapshot *peek = m_pending.load(std::memory_order_acquire);
    if (!peek || peek->tick <= m_guiInUse->tick) return;

    const quint64 prevTick = m_guiInUse->tick;
    pattounx::WorldSnapshot *fresh
        = m_pending.exchange(m_guiInUse, std::memory_order_acq_rel);
    if (fresh) {
        // Garde-fou : l'invariant côté worker (cf. PhysicsWorker::runStep)
        // dit que toute publication a un tick > publication précédente.
        // Couplé au peek ci-dessus, l'exchange ne doit JAMAIS ramener un
        // tick antérieur à celui qu'on avait juste avant. Si ça se produit,
        // soit l'invariant worker a été cassé (cf. commentaire bloc dans
        // runStep), soit il y a une corruption mémoire. En debug on plante
        // tout de suite ; en release on laisse passer pour ne pas crasher
        // l'app (le pire qui arrive est un retour au comportement bugué).
        Q_ASSERT_X(fresh->tick >= prevTick,
                   "PhysicsWorld::tryAdvanceGuiBuffer",
                   "GUI tick regression — worker invariant violated");
        m_guiInUse = fresh;
    }
}

void PhysicsWorld::onSnapshotPublished(quint64 tick, qint64 timestampNs,
                                       qint64 stepDurationNs)
{
    m_lastTick = tick;
    m_lastTimestampNs = timestampNs;
    m_lastStepDurationNs = stepDurationNs;
    emit snapshotAvailable(tick);
}

QVariantMap PhysicsWorld::bodyState(const QString &id)
{
    tryAdvanceGuiBuffer();
    QVariantMap out;
    if (!m_guiInUse) return out;
    auto it = m_guiInUse->bodies.find(id);
    if (it == m_guiInUse->bodies.end()) return out;
    const pattounx::BodySnapshot &s = it.value();
    out.insert(QStringLiteral("id"), s.id);
    out.insert(QStringLiteral("position"), QVariant::fromValue(s.position));
    out.insert(QStringLiteral("velocity"), QVariant::fromValue(s.velocity));
    out.insert(QStringLiteral("isSleeping"), s.isSleeping);
    out.insert(QStringLiteral("isColliding"), s.isColliding);
    return out;
}

QStringList PhysicsWorld::allBodyIds()
{
    tryAdvanceGuiBuffer();
    QStringList out;
    if (!m_guiInUse) return out;
    out.reserve(m_guiInUse->bodies.size());
    for (auto it = m_guiInUse->bodies.begin(); it != m_guiInUse->bodies.end(); ++it)
        out.append(it.key());
    return out;
}

quint64 PhysicsWorld::currentGuiTick()
{
    tryAdvanceGuiBuffer();
    return m_guiInUse ? m_guiInUse->tick : 0;
}
