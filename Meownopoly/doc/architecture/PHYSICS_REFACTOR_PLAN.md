# Plan de refactoring — Couche physique & 3D (Pattounx v2)

> Document de planification. Reflète les décisions prises pendant la phase de
> cadrage. À mettre à jour au fil des implémentations. Voir
> `PHYSICS_ENGINE.md` pour la doc fonctionnelle de l'existant.

---

## 1. Contexte et motivation

L'éditeur Meownopoly possède aujourd'hui un moteur physique custom (`PattounX`)
appelé "3D" mais en réalité 100 % 2D, intégré au thread GUI via
`EntityEngine.qml` qui joue à la fois le rôle d'orchestrateur d'input,
d'instance moteur, de boucle de simulation et de pont 2D/3D. Cette structure
empêche les évolutions suivantes :

- **Multi-joueurs** : un seul `body("player")` codé en dur, un seul
  `entityNode` dans `GameScene`.
- **Sync live des zones d'exclusion** : les zones sont chargées une fois au
  `setZone()` et jamais re-poussées au moteur, ce qui casse la collab édition.
- **Performance/responsabilité** : la simu tourne dans le thread de rendu, ce
  qui couple physique et frame-rate.
- **Objets posables** (caisse à pousser à terme) : le moteur ne fait que
  body-zone, pas de body-body.
- **Réseau gameplay** : aucune brique d'export d'état physique.

Cible : rendre l'ensemble extensible, isoler la simu dans un thread dédié,
unifier les conversions 2D/3D, supporter N actors, brancher la sync live des
zones, et préparer le terrain au gameplay multi-joueurs (state-sync
host-authoritative en première approche).

## 2. État actuel — résumé

### 2.1 Couches existantes

| Couche | Fichier | Rôle | Problème |
|---|---|---|---|
| Moteur 2D | `cpp/game/physics/pattounx_engine.{h,cpp}` | step + CCD + solver | `QObject`, instancié par EntityEngine, `createZone(ItemSnapable*)` couplé éditeur |
| Body | `cpp/game/physics/pattounx_body.{h,cpp}` | état cinématique | `QObject` exposé direct à QML (cross-thread incompatible) |
| Zone | `cpp/game/physics/pattounx_zone.{h,cpp}` | polygone d'exclusion/effet | tient un `ItemSnapable*`, écoute ses signaux |
| Collision2D | `cpp/game/physics/collision2d.{h,cpp}` | primitives | propre, à conserver tel quel + body-body à ajouter |
| Engine QML | `qml/utils/EntityEngine.qml` (singleton) | god-object | input + body + freeCam + frame loop + 3D sync |
| Camera | `qml/utils/CameraController.qml` (singleton) | follow + freeCam | mono-target |
| Conversions | `qml/utils/World3DTools.qml` (singleton) | 2D↔3D | 4 fonctions redondantes, deux philosophies |
| Scène 3D | `qml/meowComponent/GameScene.qml` | View3D + camera + 1 entity | mono-entity, pas de registry |
| GameBoard | `qml/board/GameBoard.qml` | ébauche jeu | **mort, à retirer** |

### 2.2 Pipeline actuel

```
Keys → EntityEngine → playerBody.inputVector (mutation directe)
       └─ FrameAnimation.onTriggered ─→ engine.updateAll(dt)
                                        ├─ playerBody.position (Q_PROPERTY)
                                        └─ targetEntity.x/z = gridPositionTo3D(pos)
```

Limites bloquantes :
- 1 seul body, 1 seul entityNode
- `setZonesFromSnapables` appelé une seule fois
- `frameTime` brut = simu non déterministe
- `playerBody.position` lu cross-thread serait UB après refactor

## 3. Décisions actées

| # | Décision | Notes |
|---|---|---|
| 1 | Cible **2.5D** (X+Y_grille en physique, Y_visuel en présentation) | Saut/étages purement cosmétiques |
| 2 | **Multi-joueurs court terme** | N actors instanciables dès Phase 4 |
| 3 | **Sync live des zones prioritaire** | Phase 3 |
| 4 | **Moteur en thread C++ séparé** | `QThread` + worker `moveToThread` |
| 5 | **Snapshot lock-free triple buffer** (pattern Fraser-Harris) | 3 buffers, 1 atomic pointer `pending` ; voir 5.4 pour détails |
| 6 | **Interpolation rendu** entre snapshots N-1 et N | OutLinear, alpha = (now - tNs) / stepNs |
| 7 | **Sync zones par-zone** (`upsertZone`/`removeZone`) | id stable = `ItemSnapable.uniqueId` |
| 8 | **`PhysicsWorld` instancié par scène** | Pas de singleton service |
| 9 | **Suppression nette** de `EntityEngine`, `CameraController`, `World3DTools` | Pas de façade legacy |
| 10 | **State-sync host-authoritative** pour le réseau | Migration possible vers input-sync si perf |
| 11 | **Body-body collision** (cercle-cercle) intégré dès Phase 1 | Pour les futures caisses |
| 12 | **Format snapshot réseau compact** (quantifié int32 × 1000) | Range ±2.1M cases, 3 décimales — voir 5.5 |
| 13 | **Arrêt thread graceful + timeout 500 ms** | `terminate()` en dernier recours avec warning |
| 14 | **Cmd via `processEvents` queued** (simple) | Migration queue lock-free si latence mesurée |
| 15 | **Coords polygones absolues côté GUI** | Worker ne connaît rien de l'éditeur |
| 16 | Namespace `pattounx`, module QML `Pattounx 1.0` | |
| 17 | `GameBoard.qml` retiré de la build | Mort, ébauche obsolète |
| 18 | `ItemSnapable.uniqueId` confirmé stable | Vérifié, sert de zoneId |
| 19 | **Bodies créés par orchestrateur externe**, composants QML sont des **présentateurs** | Cohérent avec le pattern actuel (`SnapableElement` ne crée pas le `ItemSnapable`). `PhysicsActor`/`PhysicsObject` QML lisent juste `bodyState(id)` ; la création passe par `EditorPhysicsBridge` (zones, caisses) ou par un `LocalPlayerSpawner` (joueur local). |
| 20 | **`PhysicsMessageType` séparé** (pas dans Editor/Game) | Header `cpp/game/physics/physics_message_type.h` ; types réutilisables par éditeur ET futur mode jeu. |

## 4. Architecture cible

```
┌─ THREAD GUI (rendu Qt) ─────────────────────────────────────────┐
│                                                                 │
│  Editor.qml                                                     │
│    └─ World3D { id: world; gridManager: gameGrid }              │
│         ├─ View3D { camera: camera }                            │
│         ├─ OrthographicCamera { id: camera }                    │
│         ├─ PhysicsWorld { id: physics; tickRate: 60 }           │
│         ├─ CameraRig { view3D; world3D; target: localActor }    │
│         ├─ InputController { actorId: "p1"; physics }           │
│         ├─ PhysicsActor { actorId: "p1"; node3D: chatModel }    │
│         ├─ PhysicsActor { actorId: "p2"; node3D: chatModel2 }   │
│         └─ PhysicsObject { id: "crate1"; node3D: crateModel }   │
│                                                                 │
│  EditorPhysicsBridge (auto)                                     │
│    └─ écoute ItemSnapable PhysicZone create/move/resize/edit    │
│       → physics.upsertZoneFromSnapable / removeZone             │
│                                                                 │
│  Pull snapshot chaque FrameAnimation tick →                     │
│    actor.pullAndApply(alpha)                                    │
└─────────────────────────────────────────────────────────────────┘
           │ commandes queued ↓        ↑ snapshot publish (lock-free)
┌──────────┴──────────────────────────────────────────────────────┐
│ THREAD PHYSIQUE                                                 │
│                                                                 │
│  PhysicsWorker (QObject, moveToThread)                          │
│    ├─ runLoop : QElapsedTimer + step fixe 60 Hz                 │
│    ├─ processEvents au début de chaque tick (drain commandes)   │
│    ├─ engine.step(stepDt)                                       │
│    ├─ writeSnapshot → buffer back → atomic exchange front       │
│    ├─ takeEvents → emit queued vers GUI                         │
│    └─ setSimulationEnabled(false) côté client state-sync        │
│                                                                 │
│  pattounx::PattounX_engine                                      │
│    ├─ Bodies (Static / Kinematic / Dynamic)                     │
│    ├─ Zones (ZoneSpec POD)                                      │
│    ├─ step() : intégration → CCD body-zone → CCD body-body      │
│    │           → solver itératif → corrections → événements     │
│    └─ Qt-free (pas de QObject, pas de signaux, pas d'I/O)       │
└─────────────────────────────────────────────────────────────────┘
```

### 4.1 Conventions de coordonnées

- **Worker** : tout en grille (`QVector2D`, unités de grille). Aucune connaissance
  de `gridSize` ni de View3D.
- **GUI** : `World3D.gridToWorld(gx, gy)` et `worldToGrid(x, z)` font la
  conversion via `gridManager.gridSize` et l'inversion Y_grille ↔ Z_world.
- Pour pick souris : `World3D.screenToGround(viewX, viewY)` reste basé sur
  `mapTo3DScene + ray vs Y=0` (seule fonction qui dépend de la caméra).

## 5. Spécification API

### 5.1 Types POD partagés (`cpp/game/physics/pattounx_types.h`)

```cpp
namespace pattounx {

enum class BodyType : uint8_t {
    Static,     // immobile, pas d'intégration
    Kinematic,  // input-driven (joueur), ignore forces externes
    Dynamic,    // simulé : forces, masse, collisions body-body (caisse)
};

enum class ShapeType : uint8_t {
    Circle,     // (radius)
    Polygon,    // (polygonPoints absolus)
    // Box : à ajouter plus tard si besoin
};

struct ShapeSpec {
    ShapeType type = ShapeType::Circle;
    qreal radius = 0.2;
    QVector<QVector2D> polygonPoints;  // absolus, grille
};

struct BodySpec {
    QString id;
    BodyType type = BodyType::Kinematic;
    ShapeSpec shape;
    QVector2D position;
    qreal mass = 1.0;                  // ignoré si Static
    qreal acceleration = 30.0;         // pour Kinematic (input → vCible)
    qreal maxSpeed = 300.0;
    qreal bounceFactor = 0.1;
    qreal slideFactor = 1.0;
    qreal linearDamping = 0.1;
    qreal staticFriction = 0.4;
    qreal dynamicFriction = 0.2;
    qreal restitution = 0.3;
};

struct ZoneSpec {
    QString id;                        // = ItemSnapable::uniqueId().toString()
    QVector<QVector2D> polygon;        // points absolus grille
    bool exclusion = false;            // mur (collision)
    bool trigger = true;               // émet enteredZone/exitedZone
    qreal frictionStrength = 0.5;
    qreal accelerationMultiplier = 1.0;
    qreal speedMultiplier = 1.0;
    QVector2D velocityForce { 0, 0 };
};

struct BodySnapshot {
    QString id;
    QVector2D position;
    QVector2D velocity;
    bool isSleeping = false;
    bool isColliding = false;
};

struct WorldSnapshot {
    quint64 tick = 0;
    qint64  timestampNs = 0;
    QHash<QString, BodySnapshot> bodies;
};

} // namespace pattounx

Q_DECLARE_METATYPE(pattounx::BodySpec)
Q_DECLARE_METATYPE(pattounx::ZoneSpec)
Q_DECLARE_METATYPE(pattounx::WorldSnapshot)
```

### 5.2 `pattounx::PattounX_engine` (cœur Qt-free)

```cpp
namespace pattounx {

class PattounX_engine {
public:
    // Mutations (commandes)
    void upsertBody(const BodySpec &spec);
    void removeBody(const QString &id);
    void setBodyPosition(const QString &id, QVector2D pos);
    void setBodyInput(const QString &actorId, QVector2D input);
    void applyImpulse(const QString &id, QVector2D impulse);

    void upsertZone(const ZoneSpec &spec);
    void removeZone(const QString &id);
    void clearZones();

    // 1 step à dt fixe
    void step(qreal dt);

    // Snapshot pour publication (copie cinématique uniquement)
    void writeSnapshot(WorldSnapshot &out, quint64 tick, qint64 timestampNs) const;

    // Événements survenus depuis le dernier appel
    struct Events {
        QVector<std::pair<QString, QString>> entered;  // actorId, zoneId
        QVector<std::pair<QString, QString>> exited;
        struct Collision {
            QString bodyId;
            QString other;             // zoneId OU bodyId (body-body)
            QVector2D normal;
            qreal impactSpeed;
        };
        QVector<Collision> collisions;
    };
    Events takeEvents();

    int bodyCount() const;
    int zoneCount() const;

private:
    // Implémentation interne :
    QHash<QString, /*Body*/...> m_bodies;
    QHash<QString, /*Zone*/...> m_zones;
    QHash<QString, QSet<QString>> m_activeZonesPerBody;
    Events m_pendingEvents;

    void integrateBodies(qreal dt);
    void resolveBodyZoneCCD();         // sweep + rewind (existe déjà)
    void resolveBodyBodyCCD();         // NOUVEAU : cercle-cercle CCD
    void runStaticPass(qreal dt);      // contacts résiduels (existe déjà)
    void correctPositions();
};

} // namespace pattounx
```

**Body-body cercle-cercle** (à implémenter dans `Collision2D`) :
- Sweep analytique : `|P1(t) - P2(t)| = r1 + r2`. Quadratique en t, déjà
  proche du sweep cercle-vertex existant.
- Solver : impulsion symétrique sur les deux bodies, masse pondérée
  `(invMassA + invMassB)`. Si l'autre est `Static` ou `Kinematic`, il ne
  reçoit pas de réponse (masse infinie effective).
- Friction Coulomb body-body avec moyenne géométrique des coefficients.

### 5.3 `PhysicsWorker` (vit dans le thread)

```cpp
class PhysicsWorker : public QObject {
    Q_OBJECT
public:
    explicit PhysicsWorker(QObject *parent = nullptr);
    // Initialise le worker avec le pointeur atomique partagé `pending` et
    // le buffer initial dans lequel le worker écrira (les 2 autres buffers
    // sont chez la GUI / dans `pending` au démarrage). Voir 5.4.
    void setSnapshotSink(std::atomic<pattounx::WorldSnapshot*> *pending,
                         pattounx::WorldSnapshot *initialBack);

public slots:
    void runLoop();                              // démarre la boucle interne
    void requestStop();                          // sortie graceful
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
    void cmdApplyRemoteSnapshot(pattounx::WorldSnapshot snap);

signals:
    void actorEnteredZone(QString actorId, QString zoneId);
    void actorExitedZone(QString actorId, QString zoneId);
    void actorCollided(QString actorId, QString other,
                       QVector2D normal, qreal impactSpeed);
    void snapshotPublished(quint64 tick);
    void stopped();

private:
    void runStep();

    pattounx::PattounX_engine m_engine;
    std::atomic<bool> m_running { false };
    std::atomic<bool> m_simEnabled { true };
    std::atomic<bool> m_stopRequested { false };
    int m_tickHz = 60;
    quint64 m_tick = 0;

    std::atomic<pattounx::WorldSnapshot*> *m_pending = nullptr;  // partagé avec PhysicsWorld
    pattounx::WorldSnapshot *m_workerBack = nullptr;             // possédé par worker
};
```

**Boucle interne** (référence) :
```cpp
void PhysicsWorker::runLoop() {
    m_running.store(true);
    QElapsedTimer clock; clock.start();
    qint64 stepNs = 1'000'000'000LL / m_tickHz;
    qint64 nextNs = clock.nsecsElapsed();

    while (!m_stopRequested.load()) {
        QCoreApplication::processEvents();          // draine commandes queued
        qint64 now = clock.nsecsElapsed();
        if (now < nextNs) {
            QThread::usleep(std::max<qint64>(0, (nextNs - now) / 1000));
            continue;
        }
        if (m_simEnabled.load()) runStep();
        ++m_tick;
        nextNs += stepNs;
        // Anti spiral-of-death : si on a > 5 ticks de retard, on resync
        if (now - nextNs > stepNs * 5) nextNs = now + stepNs;
    }
    m_running.store(false);
    emit stopped();
}

void PhysicsWorker::runStep() {
    qreal dt = 1.0 / m_tickHz;
    m_engine.step(dt);

    // Publication via triple buffer Fraser-Harris (cf. 5.4 pour le pattern complet)
    qint64 nowNs = QDateTime::currentMSecsSinceEpoch() * 1'000'000LL;
    m_engine.writeSnapshot(*m_workerBack, m_tick, nowNs);

    // Atomic swap : on dépose m_workerBack dans m_pending, on récupère ce qui
    // s'y trouvait. Si pending était non-null → la GUI n'avait pas encore
    // consommé la frame précédente, on reprend ce buffer pour la suite.
    pattounx::WorldSnapshot *prev = m_pending->exchange(m_workerBack,
                                                       std::memory_order_acq_rel);
    m_workerBack = prev;  // toujours non-null en régime établi (cf. init dans 5.4)
    emit snapshotPublished(m_tick);

    // Drainer événements et émettre signaux queued
    auto events = m_engine.takeEvents();
    for (auto &[actor, zone] : events.entered)
        emit actorEnteredZone(actor, zone);
    for (auto &[actor, zone] : events.exited)
        emit actorExitedZone(actor, zone);
    for (auto &c : events.collisions)
        emit actorCollided(c.bodyId, c.other, c.normal, c.impactSpeed);
}
```

### 5.4 `PhysicsWorld` (façade QML, vit dans GUI)

```cpp
class PhysicsWorld : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(int tickRate READ tickRate WRITE setTickRate NOTIFY tickRateChanged)
    Q_PROPERTY(bool simulationEnabled READ simulationEnabled
               WRITE setSimulationEnabled NOTIFY simulationEnabledChanged)

public:
    explicit PhysicsWorld(QObject *parent = nullptr);
    ~PhysicsWorld() override;

    static void registerQml();                       // module Pattounx 1.0

    Q_INVOKABLE void start();                        // démarre le thread + worker
    Q_INVOKABLE void stop();                         // graceful + timeout 500 ms

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

    // --- Zones (sync live) ---
    Q_INVOKABLE void upsertZoneFromSnapable(QObject *snapable);   // adaptateur
    Q_INVOKABLE void upsertZone(const QString &zoneId,
                                const QVariantList &polygonAbsolute,
                                QVariantMap params);
    Q_INVOKABLE void removeZone(const QString &zoneId);
    Q_INVOKABLE void clearZones();

    // --- Snapshot read (lock-free) ---
    Q_INVOKABLE QVariantMap bodyState(const QString &id) const;
    Q_INVOKABLE QStringList allBodyIds() const;
    Q_INVOKABLE quint64 currentTick() const;
    Q_INVOKABLE qint64 currentTimestampNs() const;
    Q_INVOKABLE qint64 stepDurationNs() const;

    // --- Réseau (state-sync host-authoritative) ---
    Q_INVOKABLE QByteArray serializeSnapshot() const;
    Q_INVOKABLE void applyRemoteSnapshot(const QByteArray &data);

signals:
    void runningChanged();
    void tickRateChanged();
    void simulationEnabledChanged();
    void actorEnteredZone(const QString &actorId, const QString &zoneId);
    void actorExitedZone(const QString &actorId, const QString &zoneId);
    void actorCollided(const QString &actorId, const QString &other,
                       QVector2D normal, qreal impactSpeed);
    void snapshotAvailable(quint64 tick);

private:
    QThread *m_thread = nullptr;
    PhysicsWorker *m_worker = nullptr;

    // Triple buffer Fraser-Harris :
    //   - m_buffers[0..2] : les 3 snapshots physiques
    //   - m_pending : "boîte aux lettres" atomique (peut contenir le buffer
    //                 le plus récent publié par le worker, ou nullptr si la
    //                 GUI vient juste de le consommer)
    //   - m_guiInUse : le buffer que la GUI lit actuellement (privé GUI)
    //   - le worker possède son back buffer (cf. PhysicsWorker::m_workerBack)
    //
    // Init :  worker_back=&m_buffers[0], guiInUse=&m_buffers[1], pending=&m_buffers[2]
    //
    // Cycle worker  : pending = exchange(worker_back) ;
    //                 worker_back = ce que pending contenait (toujours non-null
    //                 en régime établi : si GUI a consommé → c'était l'ancien
    //                 guiInUse ; sinon → c'est notre publication précédente
    //                 qu'on récupère pour réécriture).
    //
    // Cycle GUI     : nouveau = exchange(guiInUse) ;
    //                 si nouveau != nullptr → guiInUse = nouveau (frame plus
    //                 récente) ; sinon → on garde guiInUse (pas de nouvelle
    //                 frame depuis la dernière lecture).
    //
    // Garantie : worker n'écrit jamais dans le buffer que la GUI lit.
    pattounx::WorldSnapshot m_buffers[3];
    std::atomic<pattounx::WorldSnapshot*> m_pending { nullptr };
    pattounx::WorldSnapshot *m_guiInUse = nullptr;  // mutable pour bodyState() const
};
```

**`bodyState()`** : appelle d'abord `tryAdvanceGuiBuffer()` qui fait
`m_pending.exchange(m_guiInUse, std::memory_order_acq_rel)` — si non-null, met
à jour `m_guiInUse` vers la frame plus récente (le buffer cédé devient dispo
pour le worker). Puis copie le `BodySnapshot` correspondant à `id` dans un
`QVariantMap` `{id, position, velocity, isSleeping, isColliding}`. Si `id`
absent → map vide (l'`Actor` skip la frame de rendu).

**`bodyState` est appelée plusieurs fois par frame de rendu** (1× par actor).
Pour éviter de "consommer" plusieurs frames pendant un même rendu,
`tryAdvanceGuiBuffer()` n'est appelée qu'une fois par tick GUI — on tag
`m_guiAdvancedThisTick` qui se reset au prochain `FrameAnimation.onTriggered`
côté QML via `physics.beginFrame()` (helper Q_INVOKABLE).

**`stop()`** : `m_worker->requestStop()` (atomic), attend `stopped()` avec
timeout 500 ms via `QEventLoop` + `QTimer::singleShot`. Si timeout :
`qWarning()` + `m_thread->terminate()` + `m_thread->wait(100)`.

### 5.5 Format binaire snapshot (réseau, compact)

Objectif : ~19 octets par body au lieu de ~50 (QDataStream brut).

Quantification :
- Position : grille en `int32` × 1000 (3 décimales, range ±2.1M cases).
  Couvre largement n'importe quelle map réaliste avec une précision
  millimétrique en unités de grille (à `mmSize=12mm`, ça fait ~12 µm de
  résolution monde — ridicule, mais on s'en fiche, le débit est OK).
- Velocity : `int32` × 1000 (mêmes unités/s, range ±2.1M).
- Flags : 1 octet (bit 0 = sleeping, bit 1 = colliding).
- ID : `quint16` index dans une table d'ids partagée hôte→client (envoyée
  une fois à la création). Permet d'éviter de retransmettre les chaînes.

```
[u32 tick][i64 timestampNs][u16 bodyCount]
  bodyCount × { [u16 idIndex][i32 px][i32 py][i32 vx][i32 vy][u8 flags] }
                                                                = 19 octets
```

Coût bande passante : 8 actors × 30 Hz × 19 octets ≈ **4.5 KB/s** côté hôte
upload. Acceptable même en 4G/uplink résidentiel.

**Table d'ids** : émise via un message séparé `BodiesAnnounce` quand un body
est créé/supprimé. Le client maintient `idIndex → QString actorId`. Si un
client reçoit un `idIndex` inconnu (race), il drop le body de cette frame.

### 5.6 QML — `World3D.qml` (remplace `GameScene.qml`)

```qml
import QtQuick
import QtQuick3D
import Pattounx 1.0

Item {
    id: root

    property alias view3D: view3D
    property alias camera: camera
    required property var gridManager
    property real cameraMagnification: 1.0

    PhysicsWorld {
        id: physics
        tickRate: 60
    }
    readonly property alias physicsWorld: physics

    // Conversions centralisées (remplacent World3DTools)
    function gridToWorld(gx, gy) {
        var s = gridManager.gridSize
        return Qt.vector3d(gx * s, 0, -gy * s)
    }
    function worldToGrid(x, z) {
        var s = gridManager.gridSize
        return Qt.vector2d(x / s, -z / s)
    }
    function screenToGround(viewX, viewY) { /* mapTo3DScene + ray Y=0 */ }

    Component.onCompleted: physics.start()
    Component.onDestruction: physics.stop()

    // Registre + tick rendu
    QtObject {
        id: registry
        property var actors: []
        function add(a) { actors.push(a) }
        function remove(a) {
            var i = actors.indexOf(a)
            if (i >= 0) actors.splice(i, 1)
        }
    }
    property alias registryRef: registry

    FrameAnimation {
        running: physics.running
        onTriggered: {
            var stepNs = physics.stepDurationNs()
            var nowNs = Date.now() * 1e6
            var snapNs = physics.currentTimestampNs()
            var alpha = stepNs > 0 ? Math.min(1, (nowNs - snapNs) / stepNs) : 1
            for (var i = 0; i < registry.actors.length; ++i)
                registry.actors[i].pullAndApply(alpha)
        }
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: camera
        environment: SceneEnvironment {
            antialiasingMode: SceneEnvironment.ProgressiveAA
            backgroundMode: SceneEnvironment.Transparent
        }
        Node {
            id: sceneNode
            DirectionalLight { ... }
            OrthographicCamera {
                id: camera
                x: 0; y: 1000; z: 600
                eulerRotation.x: -55
                horizontalMagnification: root.cameraMagnification
                verticalMagnification: root.cameraMagnification
                clipNear: -10000
                clipFar: 1000055
            }
        }
    }
}
```

### 5.7 QML — `PhysicsActor.qml` (présentateur)

> **Important** : `PhysicsActor` ne crée **PAS** de body côté C++. Il se
> contente de lire `bodyState(bodyId)` à chaque frame et de positionner
> le `node3D`. La création du body est de la responsabilité de l'orchestrateur
> (`EditorPhysicsBridge` pour les zones/objets posés depuis l'éditeur,
> `LocalPlayerSpawner` pour le joueur local) — cf. décision #19.

```qml
import QtQuick
import QtQuick3D

Item {
    id: root
    required property string bodyId                   // id existant côté worker
    required property var world3D                     // World3D parent
    property Node node3D: null
    property real visualY: 0                          // 2.5D animé hors physique
    property bool interpolate: true
    property bool autoOrient: true                    // rotation depuis velocity
    property real orientLerp: 0.2

    property var _prev: null
    property var _curr: null

    function pullAndApply(alpha) {
        var s = world3D.physicsWorld.bodyState(bodyId)
        if (!s.id) return                             // body pas (encore) créé
        _prev = _curr; _curr = s
        if (!node3D) return

        var px = s.position.x, py = s.position.y
        if (interpolate && _prev) {
            px = _prev.position.x + (s.position.x - _prev.position.x) * alpha
            py = _prev.position.y + (s.position.y - _prev.position.y) * alpha
        }
        var pos3D = world3D.gridToWorld(px, py)
        node3D.x = pos3D.x
        node3D.z = pos3D.z
        node3D.y = visualY

        if (autoOrient && s.velocity.length() > 0.1) {
            var target = Math.atan2(s.velocity.x, s.velocity.y) * 180 / Math.PI
            var cur = node3D.eulerRotation.y
            var d = target - cur
            while (d < -180) d += 360
            while (d > 180) d -= 360
            node3D.eulerRotation.y = cur + d * orientLerp
        }
    }

    Component.onCompleted: world3D.registryRef.add(this)
    Component.onDestruction: world3D.registryRef.remove(this)
}
```

### 5.8 QML — `PhysicsObject.qml` (présentateur)

Identique à `PhysicsActor` côté QML : un présentateur qui lit
`bodyState(bodyId)` et positionne un `node3D`. La différence est sémantique
(et dans le `BodyType` du body côté worker, fixé à création par le bridge :
`Kinematic` pour `PhysicsActor`, `Dynamic` pour `PhysicsObject`).

Cas d'usage : caisse posée par l'éditeur. Le bridge crée le `Dynamic` body
quand la `PhysicalObjectTile` est posée, et un `PhysicsObject` QML est
instancié en parallèle pour afficher le node3D de la caisse.

À terme : `shape` configurable (Circle / Box) côté `BodySpec` à la création.

### 5.9 QML — `InputController.qml`

```qml
Item {
    id: root
    required property string actorId
    required property var physicsWorld
    property var keymap: ({
        up: Qt.Key_Z, down: Qt.Key_S, left: Qt.Key_Q, right: Qt.Key_D,
        sprint: Qt.Key_Shift
    })
    property bool _u: false; property bool _d: false
    property bool _l: false; property bool _r: false
    property bool sprint: false
    property real maxSpeed: 30
    property real sprintMultiplier: 2

    function _push() {
        var v = Qt.vector2d((_r?1:0)-(_l?1:0), (_d?1:0)-(_u?1:0))
        if (v.length() > 1) v = v.normalized()
        physicsWorld.pushInput(actorId, v)
    }

    function handlePress(event) {
        if (event.isAutoRepeat) return
        switch (event.key) {
        case keymap.up: _u = true; break
        case keymap.down: _d = true; break
        case keymap.left: _l = true; break
        case keymap.right: _r = true; break
        case keymap.sprint: sprint = true; break
        default: return
        }
        _push()
    }
    function handleRelease(event) {
        if (event.isAutoRepeat) return
        switch (event.key) {
        case keymap.up: _u = false; break
        case keymap.down: _d = false; break
        case keymap.left: _l = false; break
        case keymap.right: _r = false; break
        case keymap.sprint: sprint = false; break
        default: return
        }
        _push()
    }

    property Item keysHandler: Item {
        focus: true
        Keys.onPressed: e => root.handlePress(e)
        Keys.onReleased: e => root.handleRelease(e)
    }
}
```

### 5.10 QML — `CameraRig.qml`

```qml
Item {
    id: root
    required property var view3D
    required property var world3D
    property Node target: null
    enum Mode { Follow, Free, FixedTopDown }
    property int mode: CameraRig.Follow
    property real smoothSpeed: 2.0
    property vector3d offset: Qt.vector3d(0, 0, 0)

    // Stratégie Follow : copie de l'actuel CameraController
    // Stratégie Free : moveManual depuis input externe
    // Stratégie FixedTopDown : caméra figée, pas de suivi

    FrameAnimation {
        running: root.target !== null && view3D.camera !== null
        onTriggered: {
            if (mode === CameraRig.Follow)      _stepFollow(frameTime)
            else if (mode === CameraRig.Free)   { /* géré ailleurs */ }
            else if (mode === CameraRig.FixedTopDown) { /* rien */ }
        }
    }

    function _stepFollow(dt) { /* lerp + sync grid 2D */ }
    function setOffsetFromCameraAngle(cam) { /* helper repris du CameraController */ }
}
```

### 5.11 Adaptateur sync zones et objets — `EditorPhysicsBridge.qml`

Le bridge **centralise toute la création de bodies** depuis l'éditeur (cf.
décision #19) : zones d'exclusion (`PhysicZoneTile`) ET objets dynamiques
(`PhysicalObjectTile`, futur). Les composants QML `PhysicsActor` /
`PhysicsObject` ne font qu'afficher.

```qml
import QtQuick

Item {
    id: bridge
    required property var physicsWorld

    Connections {
        target: ItemSnapableEvents              // singleton agrégateur (cf. Phase 3)
        function onTileCreated(tile) {
            const id = tile.snapableParameters.uniqueId.toString()
            switch (tile.tileType) {
            case ItemSnapable.PhysicZoneTile:
                physicsWorld.upsertZoneFromSnapable(tile.snapableParameters)
                break
            case ItemSnapable.PhysicalObjectTile:   // Phase 9
                physicsWorld.createDynamicCircleFromSnapable(tile.snapableParameters)
                break
            }
        }
        function onTileDeleted(tileId, tileType) {
            // tileType passé pour router vers removeZone vs removeBody sans
            // garder le pointeur snapable (déjà détruit).
            switch (tileType) {
            case ItemSnapable.PhysicZoneTile:    physicsWorld.removeZone(tileId); break
            case ItemSnapable.PhysicalObjectTile: physicsWorld.removeBody(tileId); break
            }
        }
        function onTileMoved(tile) {
            const id = tile.snapableParameters.uniqueId.toString()
            switch (tile.tileType) {
            case ItemSnapable.PhysicZoneTile:
                physicsWorld.upsertZoneFromSnapable(tile.snapableParameters)
                break
            case ItemSnapable.PhysicalObjectTile:
                physicsWorld.setBodyPosition(id, tile.snapableParameters.gridPosition)
                break
            }
        }
        function onZoneParameterChanged(tile) {
            if (tile.tileType === ItemSnapable.PhysicZoneTile)
                physicsWorld.upsertZoneFromSnapable(tile.snapableParameters)
        }
    }
}
```

`upsertZoneFromSnapable` côté C++ extrait :
- `polygonPoints` (relatifs) + `gridRelativePosition{X,Y}` → calcul absolu côté GUI
- `exclusion`, `frictionStrenght`, `velocityStrenght`/`velocityDirection`,
  `accelerationMultiplier`, `speedMultiplier` → recopiés dans `ZoneSpec`
- Construit `ZoneSpec`, appelle `cmdUpsertZone(spec)` queued au worker.

Aucun pointeur vers `ItemSnapable` ne traverse vers le thread physique.

### 5.12 Spawner du joueur local — `LocalPlayerSpawner.qml`

Pour les actors joueurs (Kinematic, input-driven), le `EditorPhysicsBridge`
n'est pas pertinent (le joueur n'est pas une tile). On utilise un spawner
dédié, instancié dans `World3D` ou directement dans `Editor.qml` :

```qml
Item {
    required property var physicsWorld
    required property string actorId
    property vector2d initialPosition: Qt.vector2d(0, 0)
    property real radius: 0.2

    Component.onCompleted: physicsWorld.createKinematicActor(
        actorId, initialPosition, radius, {})
    Component.onDestruction: physicsWorld.removeBody(actorId)
}
```

C'est juste 6 lignes, mais ça centralise le contrat "le body est créé là,
pas ailleurs". Pour le multi-joueurs, un `LocalPlayerSpawner` pour le joueur
local + un `RemotePlayerSpawner` (créé sur réception du `BodiesAnnounce`
réseau) pour chaque joueur distant.

## 6. Phases d'implémentation

### Phase 0 — Nettoyage préalable

**Livrables** :
- Suppression de `qml/board/GameBoard.qml` (mort, ébauche obsolète, cf.
  décision #17)
- Suppression de `qml/board/Game_WheelHandler.qml` si plus aucun appelant
- Suppression de `qml/board/logic/*` si plus aucun appelant
- Retrait des entrées correspondantes dans `qml.qrc`
- Reconfigure CMake (cf. memory `project_cmake_glob_reconfigure`)
- Vérifier que la build passe et que l'éditeur démarre toujours

**Critère de sortie** : build verte, éditeur fonctionnel comme avant.
Aucun changement comportemental.

**Risque** : `GameBoard` peut référencer du code partagé encore utilisé
par l'éditeur — vérifier avec un grep final avant suppression.

### Phase 1 — Refonte cœur Qt-free + tests + body-body

**Livrables** :
- **Infra tests** : répertoire `tests/`, `tests/CMakeLists.txt`, target
  CMake `pattounx_tests`, dépendance `Qt6::Test`. Pas de système de tests
  configuré aujourd'hui (cf. CLAUDE.md).
- `cpp/game/physics/pattounx_types.h` : POD enums, BodySpec, ZoneSpec, BodySnapshot, WorldSnapshot
- `cpp/game/physics/pattounx_engine_v2.{h,cpp}` : nouveau moteur Qt-free
  (l'ancien reste en place pour ne pas casser EntityEngine pendant la
  transition — coexistence permise grâce au namespace `pattounx::`)
- Body-body cercle-cercle : sweep + impulse + friction Coulomb
- `tests/tst_collision2d.cpp` : tests unitaires QtTest sur `Collision2D`
  (point-segment, sweep cercle-segment, point-in-polygon, applyBounce,
  + le nouveau sweep cercle-cercle)
- `tests/tst_pattounx_engine.cpp` : smoke tests (création body, step,
  collision attendue, sleep system, body-body)

**Critère de sortie** : tests verts, ancien `pattounx_engine` toujours
fonctionnel pour EntityEngine actuel.

**Risques** : la friction Coulomb body-body peut être délicate à tuner —
tests avec scénarios "caisse poussée par chat sur sol glissant" attendus.

### Phase 2 — `PhysicsWorker` + `PhysicsWorld` + thread

**Livrables** :
- `cpp/game/physics/physics_worker.{h,cpp}` (vit dans le thread)
- `cpp/game/physics/physics_world.{h,cpp}` (façade GUI, exposé QML)
- Triple buffer + flip atomique + `bodyState()` lecture lock-free
- Module QML `Pattounx 1.0` enregistré, types exposés
- Branchement minimal dans une scène test (`qml/test/CatwayTest/PhysicsTestTab.qml` ?)

**Critère de sortie** : un body créé via QML, une zone d'exclusion, le
body bouge sur input, position mise à jour à 60 Hz dans QML, signaux
`actorEnteredZone` reçus.

**Risque clé** : `processEvents` dans `runLoop` doit drainer rapidement —
si > 1 ms de latence sur les commandes, basculer vers queue lock-free
maison (priorité Phase 2.5).

### Phase 3 — Sync live des zones

**Livrables** :
- **Agrégateur de signaux `ItemSnapableEvents`** (singleton C++ ou QML
  proxy) : émet `tileCreated(tile)`, `tileDeleted(id, tileType)`,
  `tileMoved(tile)`, `zoneParameterChanged(tile)`. Branché sur les hooks
  existants de `logic.tileLogic` (`createNewTileAtPosition`,
  `deleteElement`) + signaux `ZoneParameter::polygonPointsChanged` +
  `DisplayParameter::gridRelativePositionXChanged/Y`. Couvre aussi les
  ops réseau collab (qui passent par `ItemSnapableFactory.createItemSnapableFromJson`,
  cf. CLAUDE.md).
- `qml/world3d/EditorPhysicsBridge.qml` : abonnement à
  `ItemSnapableEvents` → `physicsWorld.upsertZone*`/`removeZone`.
  Rate-limiter à 30 Hz pendant un drag, push exact à la release (cf. 9.2).
- Test manuel : créer/déplacer/redimensionner une `PhysicZoneTile` dans
  l'éditeur et vérifier que le moteur reflète immédiatement.
- Test collab : modifier une zone côté hôte, vérifier que le client suit
  via le chemin `EditorOpBus.remoteOpReceived → applyRemoteOp →
  ItemSnapable signal → bridge → physicsWorld`.

**Critère de sortie** : édition collab d'une zone produit un comportement
physique cohérent sur tous les clients en < 200 ms.

### Phase 4 — Couche QML actor + rendering interpolé + remplacement complet

**Cette phase est volontairement lourde** : elle remplace d'un bloc les
trois singletons `EntityEngine` / `CameraController` / `World3DTools` par
les nouveaux composants instanciables. Faire la moitié casse l'éditeur
(plus de touches OU plus de caméra OU plus de chat affiché). Pour
sécuriser, on garde les anciens singletons en parallèle derrière un flag
QML `useNewPhysics` (cf. 8.2) le temps de stabiliser, puis on supprime.

**Livrables** :
- `qml/world3d/World3D.qml` (remplace `GameScene.qml`)
- `qml/world3d/PhysicsActor.qml` (présentateur, cf. 5.7)
- `qml/world3d/PhysicsObject.qml` (présentateur, cf. 5.8)
- `qml/world3d/InputController.qml` (cf. 5.9, version simple : keymap
  fixe ZQSD + Shift sprint, suffisant pour valider l'éditeur — la
  configurabilité keymap arrive en Phase 5)
- `qml/world3d/CameraRig.qml` (cf. 5.10, version simple : stratégie
  Follow + FreeCam fonctionnelles — les modes additionnels arrivent en
  Phase 5)
- `qml/world3d/LocalPlayerSpawner.qml` (cf. 5.12)
- Module `qml/world3d/qmldir`
- Refactor de `Editor.qml` :
  * `GameScene` → `World3D`
  * Bloc `World3DTools.init` + `EntityEngine.setContext/setZone/setCameraTarget`
    remplacé par instanciation de `World3D` + `LocalPlayerSpawner` +
    `InputController` + `CameraRig` + `EditorPhysicsBridge`
  * Routage des touches : `Keys.onPressed/onReleased` ne route plus vers
    `EntityEngine.keysHandler` mais vers `inputController.keysHandler`
- Suppression de `qml/utils/EntityEngine.qml`
- Suppression de `qml/utils/World3DTools.qml`
- Suppression de `qml/utils/CameraController.qml`
- Suppression du `qml/utils/qmldir` (ou nettoyage si d'autres composants)

**Critère de sortie** : éditeur fonctionnellement identique à avant
(1 chat naviguable au clavier, freeCam toggle Key_F, caméra qui suit le
chat, drag de la grille à la souris, zoom Ctrl+Molette, sélection
rectangle, etc.), code legacy supprimé, performance équivalente ou
meilleure (60 Hz physique stable).

### Phase 5 — Polish caméra + InputController configurable

**Livrables** :
- `CameraRig` enrichi : stratégies `FixedTopDown`, `OrbitDebug`, switch
  à chaud entre stratégies, helpers (`setOffsetFromCameraAngle`, etc.)
- `InputController` enrichi : keymap **configurable** via property
  exposée, support de plusieurs sources (clavier 1 = ZQSD, clavier 2 =
  flèches), gestion des conflits avec `EditorController` (séparer touches
  "édition" comme Delete/Escape/Ctrl+Z vs touches "personnage")

**Critère de sortie** : freeCam fonctionne, follow fonctionne, basculer
l'un vers l'autre fonctionne, keymap reconfigurable depuis QML.

### Phase 6 — Multi-actors local

**Livrables** :
- 2+ `PhysicsActor` instanciables dans la même scène
- 2 `InputController` (clavier 1 = ZQSD, clavier 2 = flèches) pour test
  local
- Vérifier collisions actor-actor (cercle-cercle Phase 1)

**Critère de sortie** : 2 chats sur la même map, qui se rentrent dedans
et glissent comme prévu.

### Phase 7 — Réseau state-sync host-authoritative

**Livrables** :
- `cpp/game/physics/physics_message_type.h` : nouveau enum
  `PhysicsMessageType` séparé d'`EditorMessageType`/`GameMessageType`
  (cf. décision #20). Types initiaux : `Snapshot`, `BodiesAnnounce`,
  `InputUpdate`. Plage de bytes propre (ex. `0x40+`) pour coexister sur
  Catway avec les autres types.
- Codec binaire compact int32 (cf. 5.5) : `serializeSnapshot()` /
  `applyRemoteSnapshot(QByteArray)` côté `PhysicsWorld`.
- Table d'ids `BodiesAnnounce` : émise en reliable quand un body est
  créé/supprimé, AVANT le premier snapshot qui le contient (cf. 9.3).
- Hôte : timer 30 Hz qui broadcast `Snapshot`.
- Client : `setSimulationEnabled(false)` + applique chaque snapshot reçu.
- Inputs distants : `InputUpdate` envoyé en reliable du client vers
  l'hôte, l'hôte fait `pushInput(remoteActorId, ...)`.

**Critère de sortie** : 2 instances P2P (`dual_test_p2p`), le chat de
l'instance 2 contrôlé via clavier de l'instance 2, vu en quasi-temps
réel sur l'instance 1 (latence ~1 RTT/2 + 33 ms).

### Phase 8 — Y visuel (2.5D présentation) ✅

**Livrables** :
- `PhysicsActor.visualY` animé via `SequentialAnimation` (deux
  `NumberAnimation` chaînés). Property `restY` (default 0) pour la
  hauteur de repos.
- API helpers : `actor.jump(height, duration)` (parabole OutQuad/InQuad,
  défauts 1.0 / 600 ms), `actor.wave(amplitude, period)` (sinusoïde
  InOutSine infinie, défauts 0.5 / 800 ms), `actor.stopVisualY()`
  (stop + reset à `restY`).
- `qml/editor/JumpTestPanel.qml` : badge top-right (sous
  PhysicsNetworkPanel, topMargin 156) avec boutons "Jump" + "Wave"
  (toggle). Cible le `playerActor` (P1) passé en property.
- Aucune modification du moteur : `visualY` est purement GUI ; les
  helpers ne touchent pas `pattounxWorld`. La collision (rayon, position
  grille) est déterminée par le snapshot du body, qui ne dépend pas de
  `visualY`. `pullAndApply` ré-écrit simplement `node3D.y = visualY`
  chaque frame.

**Critère de sortie** : un chat peut sauter visuellement sans que la
collision change. ✅

**Notes d'implémentation** :
- Les `Component`-templates (`_jumpAnim`, `_waveAnim`) utilisent un `id`
  sur la `SequentialAnimation` plutôt que `parent.X` depuis les
  `NumberAnimation` enfants — la sémantique `parent` n'est pas garantie
  pour les `Animation` (pas des `Item`).
- L'anim courante est stockée dans `_yAnim` puis `destroy()` à
  l'arrêt — sinon les instances éphémères s'accumulent à chaque clic.
- `Component.onDestruction` appelle `stopVisualY()` avant de retirer du
  registry pour éviter qu'une anim continue à modifier `visualY` après
  démontage du PhysicsActor.

### Phase 9 — `PhysicsObject` (caisse à pousser) ✅

**Livrables** :
- Nouveau `tileType` `ItemSnapable::PhysicalObjectTile = 3` côté C++
  (`cpp/game/item_snapable/ItemSnapable.h`). Range de validation JSON
  étendue (`ItemSnapable.cpp:61`). `operator==` couvre le nouveau cas
  via egalité de `displayParameter` (pas de `PhysicalObjectParameter`
  dédié pour l'instant — cf. note ci-dessous).
- `ItemSnapableFactory::createPhysicalObject()` qui pose un default 1×1
  case (cercle inscrit de rayon 0.5). Pas de paramètre `mass`/`bounce`
  exposé (defaults en dur côté bridge).
- `qml/meowComponent/snapable/SnapablePhysicalObject.qml` : présentation
  éditeur 2D (cercle orange hatché, croix centrale, label rayon en
  sélection). `isResizable: false` pour garder la cohérence
  édition↔physique.
- `EditorDynamicComponent.qml` : `snapablePhysicalObjectComponent` ;
  `TileLogic.createItemSnapableTile` étendu pour router le nouveau
  type vers ce composant.
- `EditorPhysicsBridge` étendu : `_isPhysicalObject(tile)` filtre +
  `_upsertObjectNow(tile)` qui appelle `physicsWorld.createDynamicCircle`
  (centre = origine + (W/2, H/2), radius = min(W,H)/2, mass = 1.0). Au
  `tileMoved`, on ré-upsert (équivalent à `setBodyPosition`). Au
  `tileDeleted`, on appelle `removeBody`. Le bridge gère désormais ZONE
  + OBJECT en parallèle, dispatchés dans `_flushPending` selon
  `_isPhysicZone` / `_isPhysicalObject`.
- `qml/world3d/PhysicsObject.qml` : présentateur 3D minimal (lit
  `bodyState`, place `node3D.x/z` avec lissage, `node3D.y = visualY`).
  Identique à `PhysicsActor` côté lecture, sans helpers Y visuel /
  orientation auto.
- `qml/world3d/PhysicsObjectSpawner.qml` : écoute `ItemSnapableEvents`,
  instancie un `Model` (cube `#Cube` orange scalé sur `unitSizeWidth *
  gridSize`) + un `PhysicsObject` pour chaque `PhysicalObjectTile`. Le
  spawner posse le `visualY = halfSide` pour que la base du cube touche
  le sol Y=0. À la suppression, détruit Model + presenter.
- `qml/editor/CrateTestPanel.qml` : badge top-right (sous JumpTestPanel,
  topMargin 192) avec deux boutons "Spawn" (pose une caisse 1.5 case
  devant le joueur) et "Clear" (supprime toutes les
  `PhysicalObjectTile` de la map courante). Passe par
  `TileLogic.createItemSnapableTile` + `Game.updateMap(EditDelta.TileAdded)`
  donc compatible collab et undo.

**Critère de sortie** : démo "chat pousse caisse sur glace" fonctionnelle.
Build + 4/4 ctest verts. Validation interactive en main (l'agent ne
peut pas piloter la GUI).

**Note pragmatique — pas de `PhysicalObjectParameter` Phase 9** :
Pour rester minimal, on n'a PAS créé de `PhysicalObjectParameter` C++.
Le rayon du body Dynamic est dérivé du `displayParameter.unitSizeWidth`
(cercle inscrit), la masse est fixée à 1.0 dans le bridge. Une future
itération exposera `mass`/`bounce`/`friction` via un nouveau parameter
type, et changera la `shape` configurable (Circle / Box) côté
`BodySpec`. La piste est ouverte mais pas encore implémentée.

## 7. Tests

### Tests unitaires C++ (QtTest)

| Cible | Fichier | Cas |
|---|---|---|
| `Collision2D::pointToSegmentDistance` | `tst_collision2d.cpp` | au sommet, milieu, hors segment |
| `Collision2D::sweepCircleSegment` | id | direct, oblique, parallèle, intersection multiple |
| `Collision2D::pointInPolygon` | id | concave, convexe, sur arête |
| `Collision2D::sweepCircleCircle` (NEW) | id | tête à tête, oblique, dépassement |
| `Collision2D::applyBounce` | id | bounce=0, bounce=1, slide=0, slide=1 |
| `pattounx::PattounX_engine` | `tst_pattounx_engine.cpp` | step idle, body bouge, contact zone, body-body |
| `PhysicsWorker` cycle de vie | `tst_physics_worker.cpp` | start/stop graceful, timeout |
| Sérialisation snapshot | `tst_snapshot_codec.cpp` | round-trip exact, bodies absents, idIndex inconnu |

### Tests d'intégration QML

- Smoke test `PhysicsActor` : créer, voir `_curr` se remplir après
  quelques frames.
- Sync live zones : créer une `PhysicZoneTile`, vérifier que le body bute
  contre.

### Tests réseau

- `dual_test_p2p` : Phase 7 doit produire un mouvement visible des deux
  côtés.

## 8. Migration

### 8.1 Fichiers à supprimer

| Fichier | Quand | Remplacé par |
|---|---|---|
| `qml/board/GameBoard.qml` | Phase 0 | rien (mort, ébauche obsolète) |
| `qml/board/Game_WheelHandler.qml` | Phase 0 si seul appelant | rien |
| `qml/board/logic/*` | Phase 0 si seuls appelants | rien |
| `qml/utils/EntityEngine.qml` | Phase 4 | `World3D` + `PhysicsActor` + `InputController` + `LocalPlayerSpawner` |
| `qml/utils/World3DTools.qml` | Phase 4 | méthodes de `World3D` |
| `qml/utils/CameraController.qml` | Phase 4 | `CameraRig` (créé en Phase 4, enrichi en Phase 5) |
| `cpp/game/physics/pattounx_engine.{h,cpp}` (ancien) | Phase 4 | `pattounx::PattounX_engine` (v2, créé en Phase 1) |
| `cpp/game/physics/pattounx_body.{h,cpp}` (QObject) | Phase 4 | type interne POD du moteur |
| `cpp/game/physics/pattounx_zone.{h,cpp}` (QObject) | Phase 4 | type interne POD du moteur |

### 8.2 Étapes prudentes

1. Phase 0 : nettoyage GameBoard avant tout pour ne pas trimballer du
   code mort dans le refactor.
2. Phase 1 : nouveau moteur en parallèle, ancien intact.
3. Phase 2-3 : nouveau moteur testé via panel test
   (`qml/test/CatwayTest/PhysicsTestTab.qml`).
4. Phase 4 : bascule de `Editor.qml` vers `World3D` + suppression des 3
   singletons + création de tous les composants présentateurs. C'est le
   commit risqué — feature flag QML `useNewPhysics: true` (par défaut) pour
   pouvoir revenir en arrière en 1 ligne le temps de stabiliser. La Phase
   4 est volontairement lourde pour éviter un état intermédiaire cassé
   (cf. justification dans la Phase 4).
5. Phase 4 fin : suppression du flag + suppression des fichiers legacy.

### 8.3 `qmldir` `utils/`

Avant :
```
module utils
singleton EntityEngine 1.0 EntityEngine.qml
singleton CameraController 1.0 CameraController.qml
singleton World3DTools 1.0 World3DTools.qml
```

Après Phase 4 : module `utils` peut disparaître si plus rien dedans, ou
garder uniquement des helpers résiduels.

Nouveau `qmldir` `qml/world3d/` :
```
module world3d
World3D 1.0 World3D.qml
PhysicsActor 1.0 PhysicsActor.qml
PhysicsObject 1.0 PhysicsObject.qml
CameraRig 1.0 CameraRig.qml
InputController 1.0 InputController.qml
LocalPlayerSpawner 1.0 LocalPlayerSpawner.qml
EditorPhysicsBridge 1.0 EditorPhysicsBridge.qml
```

Module C++ : `Pattounx 1.0` (enregistre `PhysicsWorld` + meta-types).

## 9. Risques et points d'attention

### 9.1 Threading

- **`processEvents` blocking** : si une commande prend > 1 ms, le tick
  saute. Mesurer avec `QElapsedTimer` autour du `processEvents`. Plan B :
  queue lock-free `moodycamel::ConcurrentQueue` ou similaire.
- **Snapshot stale** : si GUI ralentit, l'alpha d'interpolation peut
  dépasser 1.0 — `Math.min(1, alpha)` pour éviter overshoot.
- **Race au shutdown** : `requestStop` doit être atomic, et le
  `processEvents` peut continuer à traiter des commandes pendant
  l'arrêt — vider la queue dans `runLoop` après sortie.

### 9.2 Sync live zones

- **Spam de updates** : déplacer une zone par drag = 60+ `upsertZone` par
  seconde. Rate-limiter côté GUI à ~30 Hz pendant le drag, push final
  exact à la release.
- **Polygone temporairement invalide** (< 3 points) : ignorer côté
  worker plutôt que crasher.

### 9.3 Réseau state-sync

- **Création/suppression de body pendant transit** : les `idIndex`
  doivent être annoncés en reliable AVANT le premier snapshot qui les
  contient. Sinon le client drop des bodies (déjà géré, mais bruité).
- **Pause/resume** : à clarifier — quand l'hôte met `setSimulationEnabled(false)`
  (ex: menu pause), broadcaster une "pause flag" pour que les clients
  arrêtent l'interpolation et ne rubber-bandent pas.

### 9.4 Suppression des singletons

- `World3DTools.position3dToGridRealPosition` est utilisé dans plusieurs
  autres endroits que `EntityEngine` (cf. `GameScene.qml` `moveEntityToGridPosition`).
  Faire un grep complet avant Phase 4 et adapter les call-sites.
- `CameraController.setTarget` appelé depuis `EntityEngine` — la chaîne
  de remplacement doit être vérifiée bout à bout.

### 9.5 Compatibilité éditeur collab

> Note : "Phase 6 collab" et "Phase 7 collab" ci-dessous renvoient au
> **plan multijoueur éditeur** (CLAUDE.md, pas au présent plan dont les
> phases sont détaillées en section 6).

- L'`EditorOpBus` (Phase 6 collab du plan multijoueur) ne connaît pas la
  physique. Pas de modification nécessaire — la sync live des zones passe
  par les signaux `ItemSnapable` qui sont déjà déclenchés par
  `applyRemoteOp`.
- Vérifier que le full-sync initial (`Hello → MapChunks`, Phase 4 du plan
  multijoueur) reconstruit bien les zones physiques côté worker.
  Probablement OK si le bridge écoute les `tileCreated` émis pendant la
  reconstruction via `ItemSnapableFactory.createItemSnapableFromJson`.

## 10. Annexes

### 10.1 Helpers de migration recommandés

- Script `tools/find_legacy_physics.sh` (ou Grep) : chercher tous les
  usages de `EntityEngine.`, `CameraController.`, `World3DTools.`,
  `playerBody.`, `entityNode` pour planifier la migration.

### 10.2 Conventions de nommage

- C++ : `pattounx::*` pour le moteur, `PhysicsWorld`/`PhysicsWorker` au
  top-level.
- QML : module `Pattounx` pour `PhysicsWorld`, module `world3d` pour les
  composants UI (`World3D`, `PhysicsActor`, etc.).
- IDs : `actorId` pour les Kinematic (joueurs), `id` générique pour les
  Dynamic (caisses) et Static (préfère `"crate_<uuid>"`,
  `"wall_<uuid>"`).

### 10.3 Liens

- Doc fonctionnelle moteur actuel : `PHYSICS_ENGINE.md` (legacy V1, voir 10.4)
- Conversions et caméra actuelles : `CAMERA_ET_DEPLACEMENT.md` (legacy V1, voir 10.4)
- Architecture éditeur : `ANALYSE_ARCHITECTURE_EDITEUR.md`
- Pattern collab session : `COLLAB_SESSION_PATTERN.md`

### 10.4 Audit de la doc V1 (à NE PAS suivre aveuglément)

> Décision : on **ne corrige pas** les docs V1 (`PHYSICS_ENGINE.md` et
> `CAMERA_ET_DEPLACEMENT.md`). Elles seront supprimées en Phase 4 et
> remplacées par `PHYSICS_ENGINE_V2.md` + `WORLD3D_V2.md`. Cette section
> liste leurs erreurs pour ne pas s'y référer par accident pendant la
> transition (Phases 1 à 3 où l'ancien moteur tourne encore).

#### `PHYSICS_ENGINE.md` — erreurs à ignorer

**Erreurs factuelles**

1. **Section 2.4 — `applyForce` n'est PAS la "tension directionnelle constante"**.
   `applyForce` accumule dans `m_forceAccumulator`, consommé une fois
   dans `integrate(dt)` puis remis à zéro (`pattounx_body.cpp:108-117`,
   `:181-183`, `:219`). Pour une tension continue il faut rappeler
   chaque frame. **L'API réelle de mouvement** est `setInputVector` /
   `inputVector` Q_PROPERTY, totalement absente de la doc V1, alors
   que c'est ce qu'utilise toute la codebase (cf. `EntityEngine.qml:262-263`).

2. **Section 2.5 — `updateBody(body, dt)` ne fait PAS de collision**.
   Implémentation (`pattounx_engine.cpp:314-322`) : juste
   `applyGroundFrictionAndZones` + `body->integrate(dt)`. Aucun CCD,
   aucun solver. Utilisé seul, le body traverse les murs. C'est un
   détail interne, pas une alternative légitime à `updateAll`.

3. **Section 1 — "trois entités fondamentales"** mais quatre sont
   listées (engine, body, zone, Collision2D).

**Lacunes**

4. **Pas de mention de `setInputVector`** : pipeline réelle d'input
   `keyboard → updateInputVector() QML → body.inputVector = vec →
   moteur calcule v_cible = inputVector × maxSpeed → lerp avec
   acceleration × dt` (cf. `pattounx_body.cpp:165-179`).

5. **Dualité bounce / restitution non documentée** : deux mécanismes
   coexistent. Le rewind CCD (`pattounx_engine.cpp:273-275`) utilise
   `bounceFactor` + `slideFactor`. Le solver itératif
   (`pattounx_engine.cpp:343-347`) utilise `m_restitution` (constante
   0.3 dans le code, pas de setter public). Tuner `bounceFactor`
   n'affecte donc pas les contacts au repos.

6. **`setPosition` reset `previousPosition`** (`pattounx_body.cpp:23-26`)
   — important pour les téléportations, annule le sweep CCD du frame
   courant. Non documenté. `movePosition` (qui ne reset pas, usage
   solver) jamais mentionné non plus.

7. **Limites connues jamais listées** : pas de body-body collision,
   `setZonesFromSnapables` one-shot (pas de live update), couplage
   `ItemSnapable*` rend le moteur intestable hors contexte éditeur,
   aucun test unitaire. Tout ça est précisément ce que le refactor
   adresse.

8. **`getZoneParameters()` jamais montrée** dans un exemple (la doc
   présente `getZonesAtPoint` sans expliquer comment exploiter les
   paramètres récupérés).

**Cosmétique**

- "L'une des grandes [mot manquant] de PattounX est d'être totalement
  intégré…" (section 3).
- "Lorsque qu'un objet" → "Lorsqu'un".

#### `CAMERA_ET_DEPLACEMENT.md` — erreurs à ignorer

**Erreurs factuelles**

1. **Tous les chemins `qml/component/` sont faux** : le dossier réel
   est `qml/meowComponent/`. Affecte `GridManager`, `GameScene`,
   `GlobalMa`, `Base_Board` dans toute la doc (sections 1, 2, 4, et
   tableau récap "Fichiers importants").

2. **`qml/utils/EntityController.qml` n'existe pas**. Le fichier réel
   est `qml/utils/EntityEngine.qml`. Référencé en titre de section 7,
   dans le flux "Mode Jeu", et dans le tableau récapitulatif. Le code
   présenté en section 7 correspond en fait à un mélange de
   `EntityEngine.qml:297-317` (FrameAnimation, déplacement) et
   `CameraController.qml:111-155` (lerp caméra + sync grid 2D) — la
   doc fusionne deux singletons distincts dans une entité fictive.

3. **Le code du `MouseLogic_Base` (section 5) est illustratif** mais
   le vrai fichier n'a pas été audité ligne à ligne — à vérifier en
   Phase 5 si on a besoin d'extraire des invariants.

**Lacunes majeures**

4. **`World3DTools` jamais mentionné** alors que c'est LE singleton
   de conversion 2D ↔ 3D (`position3dToGridRealPosition`,
   `gridPositionTo3D`, `world3DToGrid2D`, `grid2DToWorld3D`,
   `getGroundIntersection`, `radius3DToGridRadius`). 6 fonctions de
   conversion dont 2 paires redondantes (mapTo3DScene-based vs
   gridSize-based) — confusion notable à clarifier dans la doc V2.

5. **`CameraController` (singleton) jamais mentionné** alors qu'il
   gère le suivi caméra avec lerp et la sync grille 2D inverse,
   utilisé par `EntityEngine` (`EntityEngine.qml:82, 90`). Toute la
   logique de "follow mode" décrite section 7 est en fait là.

6. **Pas de mention du couplage `EntityEngine ↔ CameraController ↔
   World3DTools`** : l'init en cascade (`World3DTools.init` →
   `EntityEngine.setContext/setZone/setCameraTarget` →
   `CameraController.setTarget` en interne) qui rend le démarrage
   fragile.

#### Politique pendant la transition (Phases 1-3)

- Pour comprendre le **comportement** du moteur actuel, lire
  directement `pattounx_engine.cpp` / `pattounx_body.cpp` / `EntityEngine.qml`,
  pas la doc V1.
- Pour comprendre les **conversions 2D/3D**, lire `World3DTools.qml`
  et `CameraController.qml` directement.
- La doc V1 reste utile uniquement pour le pipeline pédagogique
  (intégration → CCD → solver → corrections) qui est correct.

#### `ANALYSE_ARCHITECTURE_EDITEUR.md` — vérifié, largement fidèle

> Doc révisée 2026-02-25 (v1.1). Audit ciblé sur les éléments touchés par
> le refactor physique/3D : tous les chemins (`qml/meowComponent/`,
> `qml/editor/`, `qml/editor/logic/`), noms de fichiers (`EditorController.qml`,
> `Trackers.qml`, `SelectionRect.qml`, `GlobalMa.qml`, les 6
> `MouseLogic_*.qml`, `EditorDynamicComponent.qml`,
> `SnapableExclusionZone.qml`) et chemin C++ (`cpp/tools/editorenum.h`)
> sont **vérifiés exacts**.

**Lacunes structurelles (pas des erreurs)**

1. **La couche 3D et physique est totalement absente** : aucune mention
   de `GameScene`, `EntityEngine`, `World3DTools`, `CameraController`,
   `PattounX_engine`, ni de l'init en cascade dans `Editor.qml:90-115`
   (`World3DTools.init` → `EntityEngine.setContext/setZone/setCameraTarget`).
   Acceptable parce que ce scope est censé être dans
   `CAMERA_ET_DEPLACEMENT.md` (qui ne le couvre pas correctement non
   plus, cf. ci-dessus). À combler dans `WORLD3D_V2.md` post-refactor.

2. **Collab éditeur invisible** : `EditorOpBus`, `EditorSession`,
   `Catway`, `EditorMessageType` non mentionnés alors que c'est la grosse
   feature courante (Phases 1-8 du plan multijoueur, cf. `CLAUDE.md`).
   Hors scope direct du refactor physique mais à noter pour la cohérence
   doc — `Editor.qml` est gros parce qu'il porte aussi cette logique.

3. **Sauvegarde / map files invisibles** : `MapFileManager`, `Map`,
   `MapInfo`, `ItemSnapableFactory` non mentionnés. Pertinent pour la
   Phase 3 (sync live des zones) parce que le full-sync collab passe par
   `ItemSnapableFactory.createItemSnapableFromJson` — il faudra que le
   `EditorPhysicsBridge` écoute aussi cette voie de création.

**Note de mapping pour la Phase 3**

- Côté QML, le composant snapable s'appelle **`SnapableExclusionZone.qml`**.
- Côté C++ moteur, le tileType est **`ItemSnapable::PhysicZoneTile`**
  (cf. `pattounx_engine.cpp:183`).
- Côté `EditorDynamicComponent`, le Component s'appelle
  **`snapablePhysicZoneComponent`** (cf. doc section 7.2).

Trois noms pour la même chose. À unifier ou documenter explicitement
dans le bridge sync live de la Phase 3 pour éviter les confusions de
filtrage.

**Bilan : pas de modifications urgentes nécessaires sur cette doc.**
Elle reste référence valide pour la couche éditeur 2D pendant et après
le refactor physique. Les ajouts collab/sauvegarde sont à faire
indépendamment.
