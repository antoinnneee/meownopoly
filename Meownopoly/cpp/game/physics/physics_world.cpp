#include "physics_world.h"

#include "physics_worker.h"

#include <QDataStream>
#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>
#include <QMetaType>
#include <QSet>
#include <QThread>
#include <QtQml>
#include <cmath>

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
        if (vf.canConvert<QVector2D>()) {
            vForce = vf.value<QVector2D>();
        } else {
            // Fallback objet JS {x, y} — même tolérance que les points de
            // polygone ci-dessous (un {x,y} passé depuis QML était
            // silencieusement perdu → force nulle sans erreur).
            const QVariantMap m = vf.toMap();
            if (m.contains(QStringLiteral("x")) && m.contains(QStringLiteral("y"))) {
                vForce = QVector2D(m.value(QStringLiteral("x")).toFloat(),
                                   m.value(QStringLiteral("y")).toFloat());
            }
        }
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

    // Uncreatable : un `PhysicsWorld {}` déclaré par erreur en QML créerait
    // un SECOND thread physique concurrent du monde global. Le type reste
    // enregistré pour les propriétés/paramètres typés, mais l'instanciation
    // passe par la contextProperty `pattounxWorld` (cf. qmlapp.cpp).
    qmlRegisterUncreatableType<PhysicsWorld>(
        "Pattounx", 1, 0, "PhysicsWorld",
        QStringLiteral("PhysicsWorld est une instance globale unique — "
                       "utiliser la contextProperty pattounxWorld"));
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
    m_pendingTick.store(0, std::memory_order_release);

    m_thread = new QThread(this);
    m_thread->setObjectName(QStringLiteral("PhysicsWorker"));

    m_worker = new PhysicsWorker();
    m_worker->moveToThread(m_thread);
    m_worker->setTargetTickRateHz(m_tickRate);
    m_worker->setSimulationEnabled(m_simEnabled);
    m_worker->setSnapshotSink(&m_pending, &m_pendingTick, &m_buffers[0]);

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

    // Évents physique → GUI. Gardés sur m_running : les événements queued
    // émis par le worker juste avant l'arrêt sont délivrés APRÈS
    // runningChanged(false) — un handler QML les recevrait sur un monde
    // arrêté (états gameplay ressuscités post-stop).
    connect(m_worker, &PhysicsWorker::actorEnteredZone, this,
            [this](const QString &actorId, const QString &zoneId) {
                if (m_running) emit actorEnteredZone(actorId, zoneId);
            });
    connect(m_worker, &PhysicsWorker::actorExitedZone, this,
            [this](const QString &actorId, const QString &zoneId) {
                if (m_running) emit actorExitedZone(actorId, zoneId);
            });
    connect(m_worker, &PhysicsWorker::actorCollided, this,
            [this](const QString &actorId, const QString &other,
                   QVector2D normal, qreal impactSpeed) {
                if (m_running) emit actorCollided(actorId, other, normal, impactSpeed);
            });
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

    if (m_worker && m_thread) {
        // Arrêt SANS nested event loop : l'ancienne QEventLoop::exec()
        // traitait des événements GUI arbitraires pendant l'attente — un
        // handler QML réagissant à runningChanged (émis trop tôt) pouvait
        // ré-entrer start() et réinitialiser m_buffers pendant que le
        // worker écrivait encore dedans. Appelé depuis le destructeur,
        // l'exec() tournait en plus sur un objet à moitié détruit.
        //
        // cmdRequestStop est en DirectConnection (flag atomique) : runLoop
        // sort de sa boucle en ≤ 5 ms (durée max de son usleep), draine,
        // émet stopped() et rend la main à exec() — que quit() a déjà fait
        // sortir. wait() bloque sans traiter d'événements → aucune
        // réentrance possible.
        emit cmdRequestStop();
        m_thread->quit();

        // Pas de terminate() : tuer un thread en plein step moteur est un
        // comportement indéfini documenté par Qt (locks jamais relâchés,
        // heap potentiellement corrompu). Si le wait échoue (moteur bloqué
        // — ne devrait jamais arriver vu le usleep ≤ 5 ms), on fuit le
        // thread plutôt que de corrompre le process ; et on ne deleteLater
        // PAS un QThread encore running (crash assuré).
        if (m_thread->wait(5000)) {
            m_thread->deleteLater();
        } else {
            qCritical() << "[PhysicsWorld] Worker thread did not stop within 5 s —"
                        << "leaking the thread (terminate() would be UB).";
        }
        m_worker = nullptr; // delete via QThread::finished -> deleteLater
        m_thread = nullptr;
    }

    m_pending.store(nullptr, std::memory_order_release);
    m_pendingTick.store(0, std::memory_order_release);
    m_guiInUse = nullptr;

    // Publier l'état APRÈS le teardown complet : un handler QML de
    // runningChanged peut rappeler start() immédiatement — il doit trouver
    // un monde propre, pas un worker en cours d'arrêt.
    m_running = false;
    emit runningChanged();
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
    // Le peek lit m_pendingTick (atomique dédié, stocké par le worker
    // APRÈS son exchange) — JAMAIS `m_pending->tick` : la GUI ne possède
    // pas le buffer pending, le worker peut le récupérer et y réécrire
    // pendant la lecture (data race UB). Le store post-exchange garantit
    // (release/acquire) que si on observe tick T, m_pending contient un
    // buffer de tick ≥ T ; au pire on voit un tick en retard d'une
    // publication et on rejoue la même frame (correct : rattrapé à la
    // frame suivante).
    //
    // On ne consomme que si pendingTick > m_guiInUse->tick. Race possible :
    // entre le load et l'exchange, le worker peut publier — mais il dépose
    // toujours un tick ≥ celui observé, donc l'exchange ne peut que ramener
    // un tick ≥ peek.
    const quint64 pendingTick = m_pendingTick.load(std::memory_order_acquire);
    if (pendingTick <= m_guiInUse->tick) return;

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
    if (!m_running) return; // événement queued résiduel post-stop (cf. start())
    m_lastTick = tick;
    m_lastTimestampNs = timestampNs;
    m_lastStepDurationNs = stepDurationNs;
    // Auto-expiration du verrou d'avancement GUI : sans FrameAnimation
    // active (ex : hôte réseau headless qui sérialise à 30 Hz sans scène 3D
    // montée), personne n'appelle beginFrame() et bodyState resterait figé
    // sur la première frame pour toujours. Une nouvelle publication worker
    // ré-autorise un avancement — au plus un par publication, la garantie
    // "une frame physique max par frame de rendu" reste tenue quand
    // beginFrame est appelé (les queued sont délivrés entre les frames).
    m_guiAdvancedThisFrame = false;
    emit snapshotAvailable(tick);
}

namespace {
QVariantMap bodySnapshotToMap(const pattounx::BodySnapshot &src)
{
    QVariantMap out;
    out.insert(QStringLiteral("id"), src.id);
    out.insert(QStringLiteral("position"), QVariant::fromValue(src.position));
    out.insert(QStringLiteral("velocity"), QVariant::fromValue(src.velocity));
    out.insert(QStringLiteral("isSleeping"), src.isSleeping);
    out.insert(QStringLiteral("isColliding"), src.isColliding);
    return out;
}
} // namespace

const pattounx::WorldSnapshot *PhysicsWorld::readableSnapshot()
{
    if (m_useRemoteBuffer) {
        // Côté client en mode remote : pas d'avancement GUI/triple buffer
        // (le worker est typiquement off via setSimulationEnabled(false)).
        return &m_remoteBuffer;
    }
    tryAdvanceGuiBuffer();
    return m_guiInUse;
}

QVariantMap PhysicsWorld::bodyState(const QString &id)
{
    const pattounx::WorldSnapshot *snap = readableSnapshot();
    if (!snap) return {};
    const auto it = snap->bodies.constFind(id);
    if (it == snap->bodies.constEnd()) return {};
    return bodySnapshotToMap(it.value());
}

QVariantList PhysicsWorld::bodyStates(const QStringList &ids)
{
    // Version batch de bodyState : un seul appel QML→C++ par frame de rendu
    // pour tous les actors (au lieu de N QVariantMap churn à 144 Hz × 20
    // entités). Retourne une liste ALIGNÉE sur `ids` — entrée vide ({}) pour
    // un body inconnu, comme bodyState.
    QVariantList out;
    out.reserve(ids.size());
    const pattounx::WorldSnapshot *snap = readableSnapshot();
    for (const QString &id : ids) {
        if (snap) {
            const auto it = snap->bodies.constFind(id);
            if (it != snap->bodies.constEnd()) {
                out.append(bodySnapshotToMap(it.value()));
                continue;
            }
        }
        out.append(QVariantMap());
    }
    return out;
}

QStringList PhysicsWorld::allBodyIds()
{
    if (m_useRemoteBuffer) {
        QStringList out;
        out.reserve(m_remoteBuffer.bodies.size());
        for (auto it = m_remoteBuffer.bodies.begin();
             it != m_remoteBuffer.bodies.end(); ++it)
            out.append(it.key());
        return out;
    }
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
    if (m_useRemoteBuffer) return m_remoteBuffer.tick;
    tryAdvanceGuiBuffer();
    return m_guiInUse ? m_guiInUse->tick : 0;
}

// ── Réseau (sérialisation snapshot, table idIndex) ──────────────────────────

namespace {
constexpr float k_quantScale = 1000.0f; // 3 décimales (cf. plan §5.5)
}

QByteArray PhysicsWorld::serializeSnapshot()
{
    // Force la promotion vers la frame physique la plus récente puis snapshot
    // l'état GUI courant. On ne touche jamais m_workerBack — read-only ici.
    tryAdvanceGuiBuffer();
    QByteArray out;
    if (!m_guiInUse) return out;

    QDataStream ds(&out, QIODevice::WriteOnly);
    ds.setByteOrder(QDataStream::BigEndian);
    ds.setVersion(QDataStream::Qt_6_5);

    // Détecte les bodies actifs côté snapshot et synchronise la table
    // idIndex. Cible : un idIndex stable par actorId tant que le body existe.
    QSet<QString> liveIds;
    liveIds.reserve(m_guiInUse->bodies.size());
    for (auto it = m_guiInUse->bodies.begin(); it != m_guiInUse->bodies.end(); ++it) {
        const QString &actorId = it.key();
        liveIds.insert(actorId);
        if (!m_idIndexByActor.contains(actorId)) {
            // Allocation : recycler d'abord les index libérés (FIFO — le
            // plus anciennement libéré en premier, les clients ont eu le
            // temps de voir sa suppression via la full table 1 Hz). Sans
            // recyclage, m_nextIdIndex wrappait vers 0 (sentinel !) après
            // 65535 spawns cumulés puis produisait des collisions d'index.
            quint16 idx;
            if (!m_freeIdIndices.isEmpty()) {
                idx = m_freeIdIndices.takeFirst();
            } else {
                idx = m_nextIdIndex++;
                if (m_nextIdIndex == 0) {
                    // 65535 bodies VIVANTS simultanément — pathologique.
                    qCritical() << "[PhysicsWorld] table idIndex saturée,"
                                << "wrap forcé (collisions d'index probables)";
                    m_nextIdIndex = 1;
                }
            }
            m_idIndexByActor.insert(actorId, idx);
            m_actorByIdIndex.insert(idx, actorId);
            m_pendingAnnouncements.added.insert(idx, actorId);
            // Si le même actorId avait été marqué removed précédemment dans
            // le même cycle (rare mais possible), annule le removal.
            m_pendingAnnouncements.removed.removeAll(actorId);
        }
    }
    // Bodies disparus depuis le dernier serialize → marquer removed.
    QStringList toErase;
    for (auto it = m_idIndexByActor.begin(); it != m_idIndexByActor.end(); ++it) {
        if (!liveIds.contains(it.key())) toErase.append(it.key());
    }
    for (const QString &actorId : toErase) {
        const quint16 idx = m_idIndexByActor.take(actorId);
        m_actorByIdIndex.remove(idx);
        m_freeIdIndices.append(idx); // recyclable (cf. allocation ci-dessus)
        if (m_pendingAnnouncements.added.remove(idx) == 0) {
            // Pas dans added (le body avait déjà été annoncé) → publier removal.
            m_pendingAnnouncements.removed.append(actorId);
        }
    }

    const quint32 tick = static_cast<quint32>(m_guiInUse->tick & 0xFFFFFFFFULL);
    const qint64 ts    = m_guiInUse->timestampNs;
    const quint16 count = static_cast<quint16>(
        std::min<int>(m_guiInUse->bodies.size(), 0xFFFF));

    ds << tick << ts << count;

    int written = 0;
    for (auto it = m_guiInUse->bodies.begin();
         it != m_guiInUse->bodies.end() && written < count; ++it, ++written) {
        const BodySnapshot &b = it.value();
        const quint16 idx = m_idIndexByActor.value(b.id, 0);
        const qint32 px = static_cast<qint32>(std::lround(b.position.x() * k_quantScale));
        const qint32 py = static_cast<qint32>(std::lround(b.position.y() * k_quantScale));
        const qint32 vx = static_cast<qint32>(std::lround(b.velocity.x() * k_quantScale));
        const qint32 vy = static_cast<qint32>(std::lround(b.velocity.y() * k_quantScale));
        quint8 flags = 0;
        if (b.isSleeping)  flags |= 0x01;
        if (b.isColliding) flags |= 0x02;
        ds << idx << px << py << vx << vy << flags;
    }

    return out;
}

void PhysicsWorld::applyRemoteSnapshot(const QByteArray &payload)
{
    QDataStream ds(payload);
    ds.setByteOrder(QDataStream::BigEndian);
    ds.setVersion(QDataStream::Qt_6_5);

    quint32 tick = 0;
    qint64 ts = 0;
    quint16 count = 0;
    ds >> tick >> ts >> count;
    if (ds.status() != QDataStream::Ok) {
        qWarning() << "[PhysicsWorld] applyRemoteSnapshot: header parse error";
        return;
    }

    // Validation : la taille du payload doit correspondre EXACTEMENT au
    // count annoncé (header 14 octets + 19 octets par body). Un count forgé
    // trop grand échouerait de toute façon en parse error par body, mais un
    // payload avec des octets excédentaires serait accepté silencieusement.
    constexpr int kHeaderSize = 14; // quint32 + qint64 + quint16
    constexpr int kBodySize   = 19; // quint16 + 4×qint32 + quint8
    if (payload.size() != kHeaderSize + count * kBodySize) {
        qWarning() << "[PhysicsWorld] applyRemoteSnapshot: taille invalide"
                   << payload.size() << "octets pour count =" << count
                   << "(attendu" << (kHeaderSize + count * kBodySize) << ")";
        return;
    }

    // Gate anti-obsolète : une retransmission reliable.io peut livrer un
    // snapshot APRÈS un plus récent — l'appliquer ferait reculer tous les
    // bodies d'une frame (rubber-banding). Comparaison wraparound-aware
    // sur quint32 (le tick réseau est tronqué depuis le quint64 moteur).
    // Prérequis de tout passage du transport en lossy (cf. review N12).
    if (m_hasRemoteTick && static_cast<qint32>(tick - m_lastRemoteTick) <= 0) {
        static int stale = 0;
        if ((stale++ & 0x1F) == 0) {
            qDebug() << "[PhysicsWorld] applyRemoteSnapshot: snapshot obsolète droppé"
                     << "(tick" << tick << "<= dernier" << m_lastRemoteTick
                     << "," << stale << "drops cumulés)";
        }
        return;
    }

    // On reconstruit intégralement m_remoteBuffer.bodies à chaque snapshot
    // — les bodies absents disparaissent naturellement (équivalent removeBody).
    pattounx::WorldSnapshot fresh;
    fresh.tick = tick;
    fresh.timestampNs = ts;
    fresh.bodies.reserve(count);

    int dropped = 0;
    for (int i = 0; i < count; ++i) {
        quint16 idx = 0;
        qint32 px = 0, py = 0, vx = 0, vy = 0;
        quint8 flags = 0;
        ds >> idx >> px >> py >> vx >> vy >> flags;
        if (ds.status() != QDataStream::Ok) {
            qWarning() << "[PhysicsWorld] applyRemoteSnapshot: body" << i << "parse error";
            return;
        }
        const auto it = m_actorByIdIndex.constFind(idx);
        if (it == m_actorByIdIndex.constEnd()) {
            // BodiesAnnounce pas encore reçu pour cet idIndex → drop ce body
            // de cette frame. Sera visible au prochain snapshot une fois la
            // table à jour.
            ++dropped;
            continue;
        }
        BodySnapshot b;
        b.id = it.value();
        b.position = QVector2D(px / k_quantScale, py / k_quantScale);
        b.velocity = QVector2D(vx / k_quantScale, vy / k_quantScale);
        b.isSleeping  = (flags & 0x01) != 0;
        b.isColliding = (flags & 0x02) != 0;
        fresh.bodies.insert(b.id, b);
    }
    if (dropped > 0) {
        qDebug() << "[PhysicsWorld] applyRemoteSnapshot: dropped" << dropped
                 << "bodies (idIndex inconnu)";
    }

    m_remoteBuffer = std::move(fresh);
    m_lastTick = tick;
    m_lastTimestampNs = ts;
    m_lastRemoteTick = tick;
    m_hasRemoteTick = true;
    if (!m_useRemoteBuffer) {
        m_useRemoteBuffer = true;
        qDebug() << "[PhysicsWorld] mode remote buffer activé";
    }
    emit snapshotAvailable(tick);
}

QVariantMap PhysicsWorld::currentBodyTable() const
{
    QVariantMap out;
    for (auto it = m_actorByIdIndex.constBegin();
         it != m_actorByIdIndex.constEnd(); ++it) {
        out.insert(QString::number(it.key()), it.value());
    }
    return out;
}

QVariantMap PhysicsWorld::takePendingAnnouncements()
{
    QVariantMap added;
    for (auto it = m_pendingAnnouncements.added.constBegin();
         it != m_pendingAnnouncements.added.constEnd(); ++it) {
        added.insert(QString::number(it.key()), it.value());
    }
    QVariantList removed;
    for (const QString &id : m_pendingAnnouncements.removed) removed.append(id);

    m_pendingAnnouncements.added.clear();
    m_pendingAnnouncements.removed.clear();

    QVariantMap out;
    out.insert(QStringLiteral("added"), added);
    out.insert(QStringLiteral("removed"), removed);
    return out;
}

void PhysicsWorld::applyBodiesAnnounce(const QVariantMap &addedMap,
                                       const QStringList &removed,
                                       bool fullTable)
{
    if (fullTable) {
        // État complet annoncé par l'hôte : on repart de zéro plutôt que de
        // merger — cf. doc du .h (mapping fantôme sur delta `removed` raté).
        m_actorByIdIndex.clear();
        m_idIndexByActor.clear();
    }
    for (auto it = addedMap.constBegin(); it != addedMap.constEnd(); ++it) {
        bool ok = false;
        const quint32 idx32 = it.key().toUInt(&ok);
        if (!ok || idx32 == 0 || idx32 > 0xFFFF) {
            qWarning() << "[PhysicsWorld] applyBodiesAnnounce: idIndex invalide" << it.key();
            continue;
        }
        const quint16 idx = static_cast<quint16>(idx32);
        const QString actorId = it.value().toString();
        if (actorId.isEmpty()) continue;
        // Réécrit toujours : les BodiesAnnounce ré-envoyés en re-broadcast
        // périodique doivent rester idempotents.
        m_actorByIdIndex.insert(idx, actorId);
        m_idIndexByActor.insert(actorId, idx);
    }
    for (const QString &actorId : removed) {
        const quint16 idx = m_idIndexByActor.take(actorId);
        if (idx != 0) m_actorByIdIndex.remove(idx);
        m_remoteBuffer.bodies.remove(actorId);
    }
}

void PhysicsWorld::setUseRemoteBuffer(bool on)
{
    if (m_useRemoteBuffer == on) return;
    m_useRemoteBuffer = on;
    if (!on) {
        // Réinjecter le dernier état distant dans le moteur local AVANT la
        // purge : sinon la sim locale reprend sur l'état d'avant-session et
        // tous les bodies se téléportent brutalement (perte d'hôte, stop
        // client). setBodyPosition no-ope pour les bodies inexistants
        // localement (ceux possédés par l'hôte, recréés par les spawners)
        // et synchronise previousPosition (pas de faux sweep CCD).
        for (auto it = m_remoteBuffer.bodies.constBegin();
             it != m_remoteBuffer.bodies.constEnd(); ++it) {
            emit cmdSetBodyPosition(it.key(), it.value().position);
        }
        resetNetworkState();
    }
    qDebug() << "[PhysicsWorld] setUseRemoteBuffer →" << on;
}

void PhysicsWorld::resetNetworkState()
{
    m_remoteBuffer = pattounx::WorldSnapshot();
    m_idIndexByActor.clear();
    m_actorByIdIndex.clear();
    m_nextIdIndex = 1;
    m_freeIdIndices.clear();
    m_pendingAnnouncements.added.clear();
    m_pendingAnnouncements.removed.clear();
    m_hasRemoteTick = false;
    m_lastRemoteTick = 0;
}
