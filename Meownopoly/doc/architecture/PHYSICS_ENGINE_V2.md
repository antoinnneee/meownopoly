# 🐾 Moteur physique Pattounx v2

> Doc fonctionnelle du moteur **Pattounx v2** tel qu'il vit dans le repo
> aujourd'hui (post-Phase 9). Remplace `PHYSICS_ENGINE.md` (legacy V1, voir
> §10.4 du plan de refactor pour l'audit des erreurs à ignorer).
> Pour l'historique des décisions et la roadmap, lire
> `PHYSICS_REFACTOR_PLAN.md`. Cette doc-ci ne décrit **que ce qui est
> implémenté et utilisé**.

Ce document s'adresse aux développeurs qui veulent :
- comprendre comment la physique s'intègre dans Meownopoly,
- ajouter un nouvel actor (joueur, PNJ, objet posable),
- toucher aux paramètres d'une caisse `PhysicalObjectTile`,
- brancher un canal réseau supplémentaire,
- diagnostiquer un comportement bizarre (jitter, collision qui passe à
  travers, body endormi qui ne se réveille pas, etc.).

---

## 1. Vue d'ensemble

Pattounx v2 est un moteur 2D **dédié à Meownopoly**, qui résout :

- collisions cercle-polygone (zones d'exclusion / d'effet) avec CCD analytique
  (sweep cercle-segment / cercle-vertex),
- collisions cercle-cercle body-body avec sweep + résolution d'impulsion
  (pour les caisses),
- intégration semi-implicite Euler indépendante du framerate
  (`linearDamping` exponentiel),
- friction Coulomb avec moyenne géométrique des coefficients (statique +
  dynamique),
- "sleep system" pour endormir les bodies quasi-immobiles.

Particularités vs V1 :

| Trait | V1 (legacy, supprimé) | V2 (actuel) |
|---|---|---|
| Cœur moteur | `PattounX_engine` QObject | `pattounx::PattounX_engine` Qt-free |
| Bodies | `PattounX_body` QObject (1 par entité) | `BodySpec` POD + `InternalBody` privé |
| Zones | `PattounX_zone` QObject (couplé `ItemSnapable*`) | `ZoneSpec` POD (chaînes absolues, agnostique éditeur) |
| Threading | Thread GUI | `QThread` worker dédié |
| Sync GUI ↔ moteur | Q_PROPERTY directe | Triple buffer Fraser-Harris lock-free |
| Multi-bodies | 1 seul `body("player")` codé en dur | N actors instanciables |
| Body-body | ❌ | ✅ cercle-cercle (caisses) |
| Sync live des zones | one-shot `setZonesFromSnapables` | `upsertZone`/`removeZone` à 30 Hz debounce |
| Réseau | ❌ | State-sync host-authoritative (`PhysicsSession`) |
| Y visuel 2.5D | ❌ | `PhysicsActor.visualY` + `jump()`/`wave()` |

### 1.1 Architecture en bref

```
┌─ THREAD GUI ─────────────────────────────────────────────────────┐
│                                                                  │
│   World3D (QML)                                                  │
│     ├── physicsWorld → PhysicsWorld (singleton C++)              │
│     ├── PhysicsActor / PhysicsObjectSpawner                      │
│     │     pull bodyState(id) chaque FrameAnimation tick          │
│     ├── EditorPhysicsBridge                                      │
│     │     écoute ItemSnapableEvents → upsertZone/createDynamic.. │
│     ├── LocalPlayerSpawner                                       │
│     │     createKinematicActor(bodyId, pos)                      │
│     ├── InputController → physicsWorld.pushInput(actorId, vec)   │
│     └── CameraRig → suit un actor en lerp                        │
│                                                                  │
│   PhysicsSession (singleton C++)                                 │
│     host → broadcastSnapshot 30 Hz reliable                      │
│     client → applyRemoteSnapshot, route inputs reliable host     │
└──────────────────────────────────────────────────────────────────┘
                ↑ snapshot (lock-free triple buffer)
                │ commandes (signaux QueuedConnection)
                ↓
┌─ THREAD PHYSIQUE ────────────────────────────────────────────────┐
│                                                                  │
│   PhysicsWorker (QObject)                                        │
│     runLoop : tick fixe 60 Hz                                    │
│       ├── processEvents (drain commandes)                        │
│       ├── engine.step(dt)                                        │
│       ├── writeSnapshot → buffer back → atomic exchange          │
│       └── takeEvents → emit signals queued vers GUI              │
│                                                                  │
│   pattounx::PattounX_engine (Qt-free)                            │
│     ├── m_bodies / m_zones (QHash → InternalBody/Zone)           │
│     ├── integrateBodies(dt)                                      │
│     ├── resolveBodyZoneCCD (sweep + rewind)                      │
│     ├── resolveBodyBodyCCD (cercle-cercle)                       │
│     ├── runStaticPass (contacts résiduels)                       │
│     └── correctPositions (anti-pénétration)                      │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Fichiers clés

| Couche | Fichier | Rôle |
|---|---|---|
| Types POD | `cpp/game/physics/pattounx_types.h` | `BodySpec`, `ZoneSpec`, `BodySnapshot`, `WorldSnapshot`, enums `BodyType`/`ShapeType` |
| Cœur Qt-free | `cpp/game/physics/pattounx_engine_v2.{h,cpp}` | Pipeline simu (intégration → CCD → solver → corrections) |
| Primitives | `cpp/game/physics/collision2d.{h,cpp}` | Sweep cercle-segment, cercle-cercle, point-in-polygon, applyBounce |
| Worker | `cpp/game/physics/physics_worker.{h,cpp}` | Boucle 60 Hz, publication snapshot, pump commandes |
| Façade GUI | `cpp/game/physics/physics_world.{h,cpp}` | API QML, triple buffer, codec réseau |
| Réseau | `cpp/game/physics/physics_session.{h,cpp}` | Host-authoritative, broadcast snapshot 30 Hz |
|  | `cpp/game/physics/physics_message_type.h` | Plage 0x40+ (Snapshot, BodiesAnnounce, InputUpdate, Hello) |
|  | `cpp/game/physics/physics_protocol.{h,cpp}` | Pack/unpack `[type byte][payload]` |
| Bridge éditeur | `cpp/game/physics/item_snapable_events.{h,cpp}` | Singleton agrégateur de signaux tile-by-tile |
| Présentation | `qml/world3d/World3D.qml` | View3D + camera + helpers grid↔world |
|  | `qml/world3d/PhysicsActor.qml` | Présentateur 3D (pull bodyState, lissage, Y visuel) |
|  | `qml/world3d/PhysicsObjectSpawner.qml` | Spawn Model+Actor sur `PhysicalObjectTile` |
|  | `qml/world3d/LocalPlayerSpawner.qml` | Crée le body Kinematic du joueur local |
|  | `qml/world3d/EditorPhysicsBridge.qml` | Pousse zones et caisses depuis l'éditeur |
|  | `qml/world3d/InputController.qml` | Clavier → `pushInput(actorId, vec)` |
|  | `qml/world3d/CameraRig.qml` | Stratégies Follow / Free / FixedTopDown |
| Snapable | `cpp/game/item_snapable/physicalobjectparameter.{h,cpp}` | `mass`/`bounceFactor`/`frictionStrength`/`linearDamping` (par tile) |
|  | `qml/meowComponent/snapable/SnapablePhysicalObject.qml` | Présentation 2D éditeur (cercle, couleur ∝ masse) |

---

## 2. Threading et cycle de vie

### 2.1 Démarrage

`PhysicsWorld` est instancié comme singleton C++ et exposé sous le module
QML `Pattounx 1.0` (cf. `qmlapp.cpp`). Au boot :

```cpp
PhysicsWorld::registerQml();             // Pattounx.PhysicsWorld
PhysicsSession::registerQml();           // Pattounx.PhysicsSession (singleton)
ItemSnapableEvents::registerQml();       // Pattounx.ItemSnapableEvents (singleton)
```

`World3D` consomme l'instance globale via `pattounxWorld` (context property).
À l'instanciation d'un `World3D`, **rien n'est démarré** : c'est le côté C++
qui crée le `QThread` et appelle `runLoop()` quand `PhysicsWorld::start()` est
appelé pour la première fois.

```qml
World3D {
    id: world
    gridManager: gameGrid
    Component.onCompleted: physicsWorld.start()   // une seule fois, au boot
}
```

`PhysicsWorld::stop()` est graceful : `requestStop()` atomic, attend
`stopped()` avec timeout 500 ms via `QEventLoop` + `QTimer::singleShot`. Si
timeout : `qWarning()` + `m_thread->terminate()` + `m_thread->wait(100)`.

### 2.2 Thread du worker

Le `PhysicsWorker` vit dans un `QThread` dédié. Sa boucle :

```cpp
void PhysicsWorker::runLoop() {
    QElapsedTimer clock; clock.start();
    qint64 stepNs = 1'000'000'000LL / m_tickHz.load();
    qint64 nextNs = clock.nsecsElapsed();
    while (!m_stopRequested.load()) {
        QCoreApplication::processEvents();        // draine les commandes queued
        qint64 now = clock.nsecsElapsed();
        if (now < nextNs) { QThread::usleep((nextNs - now) / 1000); continue; }
        if (m_simEnabled.load()) runStep();
        ++m_tick;
        nextNs += stepNs;
        if (now - nextNs > stepNs * 5)            // anti spiral-of-death
            nextNs = now + stepNs;
    }
    emit stopped();
}
```

Implications :
- toute commande passée à `PhysicsWorld` (méthodes `Q_INVOKABLE`) émet
  un signal `cmdXxx` côté GUI, automatiquement `QueuedConnection` vers
  le slot `cmdXxx` du worker. **Aucune mutation directe du moteur depuis
  le thread GUI.**
- les signaux émis depuis le worker (`actorEnteredZone`, `snapshotPublished`,
  etc.) sont également queued vers GUI.
- `processEvents` doit drainer en < 1 ms pour ne pas faire sauter un tick.
  Mesure recommandée si on observe des hoquets (tracer avec `QElapsedTimer`).

### 2.3 Conventions de coordonnées

- **Worker** : tout en grille, `QVector2D(gx, gy)`. Aucune connaissance de
  `gridSize` ni de View3D.
- **GUI** : conversion via `World3D.gridToWorld(gx, gy)` (X3D = gx × gridSize,
  Z3D = -gy × gridSize, Y3D = 0). Inverse `World3D.worldToGrid(x, z)`.
- Pour le pick souris : `World3D.gridPositionTo3D(...)` (mapTo3DScene + ray
  Y=0). Voir `World3D.qml:50–95` pour le mapping affine **stable** utilisé
  par `PhysicsActor.pullAndApply` (évite le jitter caméra-induit).

---

## 3. Types POD partagés

`cpp/game/physics/pattounx_types.h` définit ce qui voyage entre GUI et
worker. Tout est sans `QObject`, sans signaux : c'est de la donnée pure
qu'on copie librement.

### 3.1 Enums

```cpp
enum class BodyType : uint8_t {
    Static,     // immobile, pas d'intégration
    Kinematic,  // input-driven (joueur), ignore les forces externes
    Dynamic,    // simulé : forces, masse, collisions body-body (caisses)
};

enum class ShapeType : uint8_t { Circle, Polygon };
```

`Kinematic` a `invMass() == 0` côté solver body-body : il ne reçoit pas de
réponse à un contact, mais il pousse les `Dynamic`. Un `Dynamic` reçoit
`1.0/mass`. Un `Static` est figé (pas d'intégration, pas de réponse).

### 3.2 BodySpec

```cpp
struct BodySpec {
    QString    id;
    BodyType   type = BodyType::Kinematic;
    ShapeSpec  shape;            // Circle (radius) usuellement
    QVector2D  position;
    qreal      mass = 1.0;       // ignoré si Static / Kinematic
    qreal      acceleration = 30.0;
    qreal      maxSpeed = 300.0;
    qreal      bounceFactor = 0.1;
    qreal      slideFactor = 1.0;
    qreal      linearDamping = 0.1;
    qreal      staticFriction = 0.4;
    qreal      dynamicFriction = 0.2;
    qreal      restitution = 0.3;
};
```

Notes :
- `acceleration` est utilisé pour les `Kinematic` : `v_cible = input × maxSpeed`,
  puis `v ← lerp(v, v_cible, acceleration × dt)`.
- `bounceFactor` / `slideFactor` régissent le rewind CCD (rebond dur sur la
  trajectoire). `restitution` régit le solver itératif (contacts résiduels).
- `linearDamping` est exponentiel et indépendant du framerate :
  `v ← v × pow(1 - damping, dt × 60)`.

### 3.3 ZoneSpec

```cpp
struct ZoneSpec {
    QString id;
    QVector<QVector2D> polygon;  // points absolus en grille
    bool exclusion = false;
    bool trigger = true;
    qreal frictionStrength = 0.5;
    qreal accelerationMultiplier = 1.0;
    qreal speedMultiplier = 1.0;
    QVector2D velocityForce { 0, 0 };
};
```

Une zone non-exclusion sert typiquement de modificateur (ralentit le chat,
ajoute une vitesse de fond, etc.). Une zone d'exclusion = mur.

### 3.4 Snapshot

```cpp
struct BodySnapshot {
    QString    id;
    QVector2D  position;
    QVector2D  velocity;
    bool       isSleeping  = false;
    bool       isColliding = false;
};

struct WorldSnapshot {
    quint64                          tick = 0;
    qint64                           timestampNs = 0;
    QHash<QString, BodySnapshot>     bodies;
};
```

Tous les snapshots sont **copies cinématiques uniquement** : pas de référence
vers les objets internes. La GUI peut lire en parallèle pendant que le
worker écrit le suivant (cf. §6).

---

## 4. API QML — `PhysicsWorld`

C'est la façade. Toutes les méthodes sont `Q_INVOKABLE` : appelables
depuis QML directement comme `physicsWorld.createKinematicActor(...)`.

### 4.1 Cycle de vie

```qml
physicsWorld.start()                  // crée QThread + lance runLoop
physicsWorld.stop()                   // graceful + timeout 500 ms
physicsWorld.tickRate = 60            // ré-applicable à chaud
physicsWorld.simulationEnabled = false// pause (côté client state-sync ex.)
```

### 4.2 Bodies

```qml
// Joueur (input-driven, pas de réponse body-body)
physicsWorld.createKinematicActor("player1",
    Qt.vector2d(10, 5),               // position grille
    0.4,                              // radius (cercle inscrit)
    { acceleration: 30, maxSpeed: 8 }) // params optionnels (override BodySpec)

// Caisse à pousser
physicsWorld.createDynamicCircle("crate-uuid",
    Qt.vector2d(12, 5), 0.5, 1.0,     // pos, radius, mass
    { bounceFactor: 0.3, linearDamping: 0.1,
      staticFriction: 0.4, dynamicFriction: 0.2 })

// Obstacle figé
physicsWorld.createStaticCircle("post-1", Qt.vector2d(0, 0), 0.3)

physicsWorld.removeBody("crate-uuid")
physicsWorld.setBodyPosition("player1", Qt.vector2d(0, 0))
physicsWorld.applyImpulse("crate-uuid", Qt.vector2d(0, 5))
```

### 4.3 Inputs

```qml
// Vecteur unitaire (normalisé en amont, |v| ≤ 1) :
physicsWorld.pushInput("player1", Qt.vector2d(1, 0))     // droite
physicsWorld.pushInput("player1", Qt.vector2d(0, 0))     // arrêt
```

Au tick suivant, le worker applique `setBodyInput(actorId, v)`. Réservé
aux `Kinematic`. Les `Dynamic` utilisent `applyImpulse`.

### 4.4 Zones

```qml
const polygon = [
    Qt.vector2d(0, 0), Qt.vector2d(2, 0),
    Qt.vector2d(2, 1), Qt.vector2d(0, 1)
]
physicsWorld.upsertZone("ice-1", polygon, {
    exclusion: false, trigger: true,
    frictionStrength: 0.05,
    speedMultiplier: 1.2,
    accelerationMultiplier: 0.5,
    velocityForce: Qt.vector2d(0, 0)
})

physicsWorld.removeZone("ice-1")
physicsWorld.clearZones()
```

En pratique, le code applicatif n'appelle pas ça directement : c'est
`EditorPhysicsBridge` qui le fait (§7).

### 4.5 Lecture snapshot

```qml
const s = physicsWorld.bodyState("player1")
// s = { id, position: vec2, velocity: vec2, isSleeping, isColliding }
// Si l'id est inconnu (body pas encore créé, race) → s.id == "" → skip render

const ids = physicsWorld.allBodyIds()
const tick = physicsWorld.currentGuiTick()        // tick de la frame lue
const stepNs = physicsWorld.stepDurationNs()      // ~16.7 ms à 60 Hz
```

### 4.6 Cycle GUI

`bodyState` est appelée plusieurs fois par frame de rendu (1× par actor).
Pour ne pas consommer plusieurs frames physiques pendant le même rendu :

```qml
FrameAnimation {
    onTriggered: {
        physicsWorld.beginFrame()           // autorise un avancement à la frame N+1
        for (const a of actors) a.pullAndApply()
    }
}
```

`beginFrame()` reset `m_guiAdvancedThisFrame = false`. La première
`bodyState()` du tick fait `tryAdvanceGuiBuffer()` (atomic exchange avec
`m_pending`) ; les suivantes lisent dans le même `m_guiInUse`.

### 4.7 Signaux

```qml
Connections {
    target: physicsWorld
    function onActorEnteredZone(actorId, zoneId) { /* SFX */ }
    function onActorExitedZone(actorId, zoneId)  { /* fin SFX */ }
    function onActorCollided(actorId, other, normal, impactSpeed) {
        if (impactSpeed > 5) playThumpSound(impactSpeed)
    }
    function onSnapshotAvailable(tick) { /* rare : utile pour télémétrie */ }
}
```

`actorCollided` est dédupliqué par paire `bodyId/other` sur un tick :
même si le body touche plusieurs segments d'une zone, un seul signal sort.

---

## 5. Pipeline d'un step

`PattounX_engine::step(dt)` exécute la séquence suivante (cf.
`pattounx_engine_v2.cpp`) :

1. **`integrateBodies(dt)`**
   - pour chaque body non-sleeping :
     - `applyGroundFrictionAndZones(body)` : remet à zéro les multiplicateurs
       de zone (recalculés en CCD si la zone est encore active),
     - **Kinematic** : `v_cible = input × maxSpeed × zoneSpeedMul`, puis
       `v ← lerp(v, v_cible, acceleration × zoneAccelMul × dt)`,
     - **Dynamic** : `v += (forceAccumulator / mass + zoneVelocityForce) × dt`,
       puis `forceAccumulator = 0`,
     - damping : `v *= pow(1 - linearDamping, dt × 60)`,
     - intégration : `previousPosition = position`, `position += v × dt`.

2. **`resolveBodyZoneCCD()`** (sweep + rewind)
   - pour chaque body en mouvement, broadphase AABB pour filtrer les zones
     à tester,
   - pour chaque zone restante : sweep cercle-segment + cercle-vertex via
     `Collision2D::sweepCirclePolygon`. Le plus petit `t ∈ [0, 1]` donne
     le point d'impact,
   - body rembobiné à `previousPosition + v × t × dt`,
   - bounce/slide appliqué sur la vélocité avec `bounceFactor` /
     `slideFactor` du `BodySpec`,
   - `enteredZone` / `exitedZone` mis à jour (set par body).

3. **`resolveBodyBodyCCD()`** (cercle-cercle)
   - pairs uniques des bodies en mouvement,
   - `Collision2D::sweepCircleCircle(p1, v1, r1, p2, v2, r2, dt)` →
     premier `t` de contact,
   - réponse symétrique avec masse pondérée :
     `J = -(1 + e) × (v_rel · n) / (invA + invB)`,
     `vA += J × applyA × n`, `vB -= J × applyB × n`.
     Friction Coulomb tangentielle avec moyenne géométrique.
   - **Masse inertielle vs masse d'application** : un Kinematic contribue à
     `invA`/`invB` (masse finie pour le calcul de `J`) mais pas à
     `applyA`/`applyB` (sa velocity reste pilotée par l'input). Sans cette
     distinction, Kinematic = masse infinie → la masse de l'autre body
     s'annule mathématiquement et toutes les caisses sont poussées
     identiquement. Cf. test `bodyBody_kinematicPush_massAffectsResponse`
     dans `tst_pattounx_engine.cpp`.

4. **`runStaticPass()`** (contacts résiduels)
   - pour chaque body, test statique cercle-polygone à la position
     courante (corps appuyé contre un mur),
   - accumule `ResidualContact { normal, closestPoint, penetration }`.

5. **Solver itératif** (`VELOCITY_ITERATIONS = 4` passes)
   - friction Coulomb : si `|jt| < jn × √(μs_body × μs_zone)` → friction
     statique (impulsion qui annule la vitesse tangentielle), sinon
     dynamique avec `μd = √(μd_body × μd_zone)`,
   - rebond solver utilise `restitution` (constante 0.3 par défaut).

6. **`correctPositions()`**
   - pour chaque contact résiduel : si pénétration > `PENETRATION_SLOP`
     (0.01), on déplace le body de
     `POSITION_CORRECTION_PERCENT × (penetration - slop)` le long de la
     normale. Évite la dérive sur les contacts soutenus.

7. **Sleep system**
   - si `|v| < SLEEP_VELOCITY_THRESHOLD` (0.5) pendant
     `SLEEP_FRAMES_REQUIRED` (30) frames consécutifs → `isSleeping = true`,
     pas d'intégration ni de CCD pour ce body au step suivant,
   - `setBodyInput`, `applyImpulse`, `setBodyPosition` réveillent
     automatiquement (`wakeUp(body)`).

8. **Événements**
   - les paires (body, zone) entrées/sorties et les collisions sont
     accumulées dans `m_pendingEvents`,
   - `takeEvents()` (appelé par le worker après `step`) vide la file et
     déclenche les signaux Qt vers GUI.

---

## 6. Snapshot et triple buffer

### 6.1 Pattern Fraser-Harris

3 buffers + 1 atomic pointer (`m_pending`) :

```
état initial :
  worker_back  = &m_buffers[0]
  m_guiInUse   = &m_buffers[1]
  m_pending    = &m_buffers[2]

cycle worker (chaque tick) :
  écrire dans worker_back
  prev = m_pending.exchange(worker_back, memory_order_acq_rel)
  worker_back = prev          // toujours non-null en régime établi

cycle GUI (1× par frame) :
  candidate = m_pending.exchange(m_guiInUse, memory_order_acq_rel)
  if (candidate) m_guiInUse = candidate    // sinon : pas de nouveau frame
```

Garanties :
- jamais d'allocation, jamais de mutex, jamais de blocage,
- le worker n'écrit jamais dans le buffer que la GUI lit,
- si la GUI ralentit (ne lit pas chaque frame), le worker écrase la
  publication précédente — la GUI verra la dernière, pas une vieille.

### 6.2 Garde anti multi-consommation

`bodyState` est appelée plusieurs fois par frame de rendu. Pour ne pas
sauter accidentellement la frame intermédiaire :

```cpp
void PhysicsWorld::tryAdvanceGuiBuffer() {
    if (m_guiAdvancedThisFrame) return;
    auto *fresh = m_pending.exchange(m_guiInUse, std::memory_order_acq_rel);
    if (fresh) m_guiInUse = fresh;
    m_guiAdvancedThisFrame = true;
}
```

Reset à `beginFrame()`. Sans ça, la GUI consommait 144 frames physiques
pour 60 frames de rendu et ratait des positions intermédiaires (jitter
visible — historisé dans la mémoire `physics_actor_jitter_wip`).

---

## 7. Bridge éditeur — `EditorPhysicsBridge`

`qml/world3d/EditorPhysicsBridge.qml` est le **chokepoint** entre l'éditeur
et le moteur. Il écoute le singleton `ItemSnapableEvents` (cf. §7.1) et
pousse les zones/objets vers le worker. Il a deux comportements selon le
type de tile :

| `tile.tileType` | Action |
|---|---|
| `PhysicZoneTile` | `physicsWorld.upsertZone(uuid, polygonAbsolu, params)` / `removeZone` |
| `PhysicalObjectTile` | `physicsWorld.createDynamicCircle(uuid, center, radius, mass, params)` + `setBodyPosition` / `removeBody` |

Les events sont **debounced** à ~30 Hz pendant les drags (un drag = 60+
events/s sinon). Le timer redémarre à chaque event ; au repos > 33 ms,
flush. Les `removeZone`/`removeBody` sont émis immédiatement (pas de
debounce) pour éviter qu'une zone supprimée bloque encore un actor.

```qml
EditorPhysicsBridge {
    physicsWorld: pattounxWorld
    flushIntervalMs: 33
    verbose: false
}
```

### 7.1 `ItemSnapableEvents`

Singleton C++ (`cpp/game/physics/item_snapable_events.{h,cpp}`) qui
agrège les signaux par-tile en provenance de `Map`. Permet à
`EditorPhysicsBridge` (et à `PhysicsObjectSpawner`) de ne s'abonner qu'à
**un seul producteur** au lieu de scanner les signaux individuels de
chaque `ItemSnapable`.

Signaux exposés :

```cpp
signals:
    void tileCreated(ItemSnapable *tile);
    void tileMoved(ItemSnapable *tile);
    void tileDeleted(QUuid tileId, int tileType);
    void zoneParameterChanged(ItemSnapable *tile);
    void physicalObjectParameterChanged(ItemSnapable *tile);
```

Le singleton suit la map active (`MapFileManager::currentMap`). Au
changement de map (load disque, FullSync collab), il :
- `detachMap` ancienne map (émet `tileDeleted` pour chaque tile
  attachée → le bridge purge le worker),
- `attachMap` nouvelle (émet `tileCreated` rétroactivement → le bridge
  reconstruit).

C'est ce qui rend la sync live des zones et des caisses **gratuite côté
collab** : `EditorOpBus.applyRemoteOp` recrée des `ItemSnapable` via la
factory → la `Map` émet `tileAddedToMap` → `ItemSnapableEvents` émet
`tileCreated` → le bridge pousse au worker.

### 7.2 Détails d'implémentation

`_upsertObjectNow(tile)` (cf. `EditorPhysicsBridge.qml:174`) :
- centre du body = `(gridRelativePositionX + W/2, gridRelativePositionY + H/2)`,
- radius = `min(W, H) / 2` (cercle inscrit dans la tile),
- `mass`, `bounceFactor`, `linearDamping`, `staticFriction`,
  `dynamicFriction` lus depuis `tile.physicalObjectParameter` (cf. §9),
- appel `createDynamicCircle(id, center, radius, mass, params)`. Le worker
  fait l'upsert : si le body existe déjà, on ne réécrit que la spec
  (rayon/masse), la position courante est préservée — donc on appelle
  `setBodyPosition(id, center)` immédiatement après pour recoller à la
  grille en cas de move depuis l'éditeur.

---

## 8. Présentation — `PhysicsActor` et spawners

### 8.1 `PhysicsActor`

Présentateur 3D **agnostique du type de body**. Il ne crée jamais le body
côté C++ : il en lit l'état via `bodyState(bodyId)` et place un `node3D`.

```qml
PhysicsActor {
    id: actor
    bodyId: "player1"
    world3D: world
    node3D: chatModel              // n'importe quel Node QtQuick3D
    interpolate: true              // lissage exponentiel
    smoothing: 0.3                 // 70 % du chemin en 3 frames
    autoOrient: true               // rotation depuis velocity
    orientLerp: 0.2
    visualY: 0                     // 2.5D présentation
    restY: 0
}
```

À chaque frame de rendu (FrameAnimation tick) :
1. `s = world3D.physicsWorld.bodyState(bodyId)` (lock-free, retourne
   `{ id, position, velocity, isSleeping, isColliding }`),
2. `pos3D = world3D.gridToWorldStable(s.position.x, s.position.y)` (mapping
   affine figé pour éviter le jitter caméra-induit, cf. `World3D.qml:60–106`),
3. lissage : `node3D.x += (pos3D.x - node3D.x) × smoothing`,
4. `node3D.y = visualY` (Y purement cosmétique),
5. orientation : si `|v| > 0.1`, lerp 20 % vers `atan2(v.x, v.y)`.

Si `bodyId` n'existe pas encore (race au démarrage, ou tile en cours de
création), `s.id` est vide et le presenter skip la frame.

### 8.2 Phase 8 — Y visuel 2.5D

`visualY` est animée hors physique via deux helpers :

```qml
actor.jump(1.0, 600)        // hauteur 1 case, durée 600 ms (parabole OutQuad/InQuad)
actor.wave(0.5, 800)        // sinusoïde infinie, amplitude 0.5, période 800 ms
actor.stopVisualY()         // stop + reset à restY
```

Implémentés via `SequentialAnimation` instanciée à la volée et stockée
dans `_yAnim` pour `destroy()` propre. Aucune modification du moteur :
le rayon de collision et la position grille restent inchangés. Pratique
pour un saut cosmétique, un flag "blob spawning", une mise en avant
visuelle d'un actor sélectionné.

`Component.onDestruction` appelle `stopVisualY()` avant de retirer du
registry — sinon l'anim continuait à muter `visualY` après démontage.

### 8.3 `LocalPlayerSpawner`

```qml
LocalPlayerSpawner {
    physicsWorld: world.physicsWorld
    actorId: "player1"
    initialPosition: Qt.vector2d(0, 0)
    radius: 0.4
}
```

6 lignes qui font `createKinematicActor(actorId, initialPosition, radius)`
au `Component.onCompleted` et `removeBody(actorId)` au
`Component.onDestruction`. C'est le contrat : "le body est créé là, pas
ailleurs". Pour le multi-joueurs, un `RemotePlayerSpawner` est créé sur
réception du `BodiesAnnounce` réseau.

### 8.4 `PhysicsObjectSpawner`

`qml/world3d/PhysicsObjectSpawner.qml` écoute `ItemSnapableEvents` et
instancie un `Model` 3D (`#Cube` orange scalé sur `unitSizeWidth × gridSize`)
+ un `PhysicsActor { autoOrient: false }` pour chaque `PhysicalObjectTile`
posée. Le presenter pose `visualY = halfSide` pour que la base du cube
touche le sol Y=0.

Le `bodyId` lie les deux côtés : c'est `tile.uniqueId.toString()`,
exactement comme le bridge. Bridge et spawner écoutent la même source →
convergence garantie sans communication directe entre eux.

---

## 9. `PhysicalObjectParameter` — caisse paramétrable

`cpp/game/item_snapable/physicalobjectparameter.{h,cpp}` est attaché à
chaque `ItemSnapable` de type `PhysicalObjectTile`. Il porte les
coefficients physiques de la caisse :

| Q_PROPERTY | Default | Effet moteur |
|---|---|---|
| `mass` | 1.0 | poids inertiel pour body-body (impulsion = `J × invMass`) |
| `bounceFactor` | 0.3 | rebond du rewind CCD body-zone |
| `frictionStrength` | 0.4 | `staticFriction = v` ; `dynamicFriction = 0.5 × v` (côté bridge) |
| `linearDamping` | 0.1 | amortissement exponentiel par-tick |

Sérialisation JSON par-tile (intégrée à `ItemSnapable::toJSON`/`applyJson`),
copies dans `operator==`, signaux de mutation câblés à
`ItemSnapableEvents::physicalObjectParameterChanged` → bridge → worker.
Les paramètres se mettent à jour à chaud en édition.

Côté présentation 2D (`SnapablePhysicalObject.qml`) : la couleur du cercle
de la tile dépend de la masse (orange clair → brun-rouge foncé sur la
plage 0.5 → 5.0). Plus c'est lourd, plus c'est sombre.

Côté `CrateTestPanel.qml` : badge dev qui spawn une caisse 1.5 case devant
le joueur et propose 5 stops `m = 0.5 / 1.0 / 2.0 / 3.5 / 5.0`. Pratique
pour valider l'équilibrage masse × accélération du chat.

---

## 10. Réseau — state-sync host-authoritative

### 10.1 Cible

L'hôte tient la simu autoritaire. Les clients désactivent leur simu
locale (`setSimulationEnabled(false)`) et reçoivent un snapshot binaire
compact à 30 Hz. Leurs inputs clavier sont relayés à l'hôte en reliable
au lieu d'être appliqués localement.

Latence cible : ~RTT/2 + 33 ms (1 frame snapshot) pour voir bouger un
chat distant. Sur un LAN 10 ms, ~50 ms de bout en bout.

### 10.2 Types de message — `PhysicsMessageType`

Plage **0x40+** pour cohabiter avec `GameMessageType` (0x01–0x1F) et
`EditorMessageType` (0x20–0x3F) sur le même Catway :

```cpp
namespace PhysicsMessageType {
    Snapshot       = 0x40,   // hôte → tous, binaire compact, 30 Hz
    BodiesAnnounce = 0x41,   // hôte → tous, table {idIndex → actorId}
    InputUpdate    = 0x42,   // client → hôte, vec input
    Hello          = 0x43,   // client → hôte, "envoie-moi la full table"
};
```

Toute nouvelle valeur **doit être la plus haute** sinon
`PhysicsProtocol::isPhysicsPacket` filtre par plage et drop le paquet.

### 10.3 Format binaire snapshot

~19 octets par body au lieu de ~50 (`QDataStream` brut). Quantification
position/velocity en `int32 × 1000` (3 décimales, range ±2.1M cases) ;
`idIndex u16` au lieu d'une string :

```
[u32 tick][i64 timestampNs][u16 bodyCount]
  bodyCount × { [u16 idIndex][i32 px][i32 py][i32 vx][i32 vy][u8 flags] }
                                                                = 19 octets
```

Coût bande passante : 8 actors × 30 Hz × 19 octets ≈ **4.5 KB/s** uplink.
Acceptable même en 4G.

`flags` = bit 0 sleeping, bit 1 colliding.

### 10.4 BodiesAnnounce

Quand un body apparaît côté hôte (createKinematicActor / createDynamicCircle
qui ne connaissait pas l'id), un `idIndex u16` lui est attribué et ajouté
au `pendingAnnouncements`. À chaque tick de broadcast, on émet d'abord
le `BodiesAnnounce` reliable JSON :

```json
{ "added": { "1": "player1", "2": "crate-uuid" }, "removed": ["old-id"] }
```

…puis le snapshot binaire reliable (lui aussi). Le client décode le JSON,
peuple sa table `idIndex → actorId`, et est capable de mapper les bodies
du snapshot suivant.

Re-broadcast périodique de la table complète (1 Hz, `m_fullTableTimer`)
pour absorber les late-joins et les paquets perdus côté client. Si un
client reçoit un `idIndex` inconnu (race), il drop ce body de la frame.

Le client peut aussi envoyer un `Hello` reliable à l'hôte au moment de
basculer en mode CLIENT pour forcer une re-broadcast immédiate de la
table — évite la fenêtre de race où le delta initial est envoyé avant
que le client n'écoute reliable.

### 10.5 Inputs distants

Le client n'appelle pas `physicsWorld.pushInput` directement. Il passe
par `PhysicsSession::pushOrSendInput(actorId, vec)` :

```cpp
if (m_isHost || !m_active) physicsWorld->pushInput(actorId, vec);
else                       sendReliable(InputUpdate, { actorId, vec });
```

Côté hôte, on reçoit les `InputUpdate` reliable et on appelle
`pushInput(actorId, vec)` avant le prochain step. Pour éviter qu'un host
local ne se batte avec un input client (les flèches du host poussent
"player1", le client revendique aussi "player1"), `claimedActorId`
côté client + `m_remoteClaims` côté host filtrent : si un client a
revendiqué un actorId, le host n'applique plus ses propres pushInput
locaux pour cet actorId.

### 10.6 PhysicsSession — orchestration

Singleton calqué sur `EditorSession`. API minimale :

```qml
// Hôte
PhysicsSession.setPhysicsWorld(pattounxWorld)
PhysicsSession.startAsHost("player-host-id")

// Client
PhysicsSession.setPhysicsWorld(pattounxWorld)
PhysicsSession.startAsClient("player-client-id", "player-host-id")
PhysicsSession.claimedActorId = "player1"   // ce que je contrôle

// Stop (host ou client)
PhysicsSession.stop()
```

`startAsClient` :
1. `physicsWorld.setSimulationEnabled(false)` (sim locale OFF),
2. `physicsWorld.setUseRemoteBuffer(true)` (bodyState lit `m_remoteBuffer`),
3. envoie `Hello` reliable à l'hôte pour réclamer la full table,
4. arme la connexion à `Catway::reliableMessageReceived` pour décoder
   `Snapshot` / `BodiesAnnounce`.

`stop()` côté client : ré-active la sim locale, purge le remote buffer,
clear la table `idIndex`. Côté hôte : arrête le timer 30 Hz + clear
table.

Le state réseau est **purement additionnel** : sans `PhysicsSession`,
`PhysicsWorld` fonctionne comme un moteur local mono-joueur. La phase 7
n'a touché qu'à la sérialisation et au routage, pas au pipeline simu.

---

## 11. Tests

4 cibles ctest :

| Cible | Fichier | Couverture |
|---|---|---|
| `tst_collision2d` | `tests/tst_collision2d.cpp` | sweep cercle-segment, point-polygon, applyBounce, sweep cercle-cercle |
| `tst_pattounx_engine` | `tests/tst_pattounx_engine.cpp` | step idle, body bouge, contact zone, body-body, sleep system |
| `tst_physics_worker` | `tests/tst_physics_worker.cpp` | start/stop graceful, timeout 500 ms, commandes queued |
| `tst_snapshot_codec` | `tests/tst_snapshot_codec.cpp` | round-trip binaire, idIndex inconnu, table BodiesAnnounce |

Lancer avec :

```bash
cd build && ctest --output-on-failure
```

> Sur Windows, `Qt6Test.dll` doit être dans le PATH au runtime — exporter
> `/c/Qt/6.10.2/mingw_64/bin` avant de lancer ctest sinon exit 0xc0000135.

Les tests sont **Qt-free pour l'engine** (pas de `QObject`), ce qui les
rend rapides et isolables. Le worker test crée un vrai `QThread` mais
mocke les commandes via signaux directs.

---

## 12. Bonnes pratiques

- **Sleep system** : un body Dynamic posé sans input dort en 30 frames
  (~500 ms à 60 Hz). Visiblement immobile = invisible pour la simu →
  zéro coût CPU. Réveil automatique sur `applyImpulse`, `setBodyPosition`,
  `setBodyInput` ou si un autre body lui rentre dedans (le solver le
  réveille avant le contact résiduel).

- **Téléportation** : utilisez `setBodyPosition` plutôt qu'un déplacement
  par accumulation. La méthode reset `previousPosition`, ce qui annule le
  sweep CCD du frame courant — sinon le body se "bounce" sur les murs
  qu'il a "traversés" pendant la téléportation.

- **Forces continues** : `applyImpulse` est ponctuel (consommé en 1 step).
  Pour une force continue (vent, courant), accumuler chaque frame OU
  passer par une zone avec `velocityForce`.

- **Live-edit zone** : un drag de polygone produit ~60 events/s. Le
  bridge debounce à 30 Hz ; ne pas court-circuiter. Sur un polygone
  temporairement < 3 points (création en cours), le bridge appelle
  `removeZone` → no-op au worker, no-op visuel.

- **Réseau pause** : si l'hôte met `setSimulationEnabled(false)` (menu
  pause), broadcaster un flag pour que les clients arrêtent
  l'interpolation et ne rubber-bandent pas (à implémenter — pas encore
  fait, cf. §9.3 du plan refactor).

- **Multi-actors local** : 2+ `LocalPlayerSpawner` + 2+ `InputController`
  avec keymaps disjoints (ZQSD vs flèches) suffit. La collision
  actor-actor est gérée par body-body (Kinematic vs Kinematic ne se
  poussent pas mutuellement, mais une caisse Dynamic peut être prise en
  sandwich).

- **Body au démarrage** : la création est asynchrone (cmd queued). Si
  vous lisez `bodyState(id)` avant le 1er tick post-création, vous
  obtenez `{}`. `PhysicsActor` skip naturellement ce cas. Si du code
  applicatif a besoin d'un sync — utiliser `Connections {
  onSnapshotAvailable: ... }` ou poller jusqu'à `s.id !== ""`.

---

## 13. Constantes par défaut

Cf. `pattounx_engine_v2.h` :

```cpp
static constexpr int   VELOCITY_ITERATIONS         = 4;
static constexpr qreal PENETRATION_SLOP            = 0.01;
static constexpr qreal POSITION_CORRECTION_PERCENT = 0.6;
static constexpr qreal TUNNELING_BUFFER            = 0.02;
static constexpr qreal DEFAULT_GROUND_DAMPING      = 0.05;
static constexpr qreal SLEEP_VELOCITY_THRESHOLD    = 0.5;
static constexpr int   SLEEP_FRAMES_REQUIRED       = 30;
```

Pas de getter/setter QML : ce sont des constantes de tuning serveur.
Modifiables uniquement à la compilation (et avec un test qui regen les
golden snapshots).

---

## 14. Ce qui reste ouvert

Pistes connues mais pas implémentées :

- **`shape: Circle | Box`** côté `BodySpec` pour les caisses non-circulaires.
  Demande un sweep box-circle dans `Collision2D` (non trivial, narrowphase
  SAT).
- **Profiling worker** : si `processEvents` dépasse 1 ms en pratique, plan B
  = queue lock-free `moodycamel::ConcurrentQueue` ou similaire.
- **Pause flag réseau** : pour que les clients n'extrapolent pas pendant
  une pause hôte.
- **`PhysicsWorld` instancié par scène** au lieu d'un singleton global —
  décision §3 du plan, reportée parce que coût de re-création du thread à
  chaque navigation (Editor↔CatwayTest).
- **Multi-joueurs collab + physique** : `EditorSession` et `PhysicsSession`
  cohabitent sur Catway, mais le pipeline complet "rejoindre une session
  d'édition + démarrer simu commune" n'a pas été testé bout en bout.

---

## 15. Liens

- `PHYSICS_REFACTOR_PLAN.md` — plan phasé, décisions, audit doc V1.
- `CATWAY_ARCHITECTURE.md` — couche P2P / reliable.io qui transporte les
  paquets `PhysicsMessageType`.
- `ANALYSE_ARCHITECTURE_EDITEUR.md` — couche éditeur 2D, hors physique
  mais nécessaire pour comprendre `ItemSnapable` / `Map` /
  `MapFileManager` / `EditorOpBus`.
- `cpp/game/physics/` — sources du moteur (Qt-free) + worker + façade.
- `qml/world3d/` — composants présentateurs et bridge.
- `tests/` — 4 cibles ctest (collision, engine, worker, codec).
