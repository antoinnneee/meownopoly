# Système de Caméra et Déplacement — Architecture Globale (V2)

> **Version 2.0 (post-Phase 9 du refactor physique)**. Réécriture complète
> de la doc V1 (chemins faux, singletons disparus). Pour le moteur physique
> qui produit les positions consommées ici, voir `PHYSICS_ENGINE_V2.md`.
> Pour l'historique des décisions de refactor, voir
> `PHYSICS_REFACTOR_PLAN.md`.

## Vue d'ensemble

Le projet utilise un système **hybride 2D/3D** où :
- La **grille 2D** (`GridManager`) sert de référence pour le placement des éléments éditeur (snap, sélection, drag).
- La **scène 3D** (`World3D`) affiche les modèles 3D animés et suit les mêmes coordonnées que la grille via un mapping affine stable.
- Les deux systèmes restent **synchronisés** : drag de la grille → la caméra 3D compense ; lerp caméra 3D (mode Follow) → la grille 2D est repoussée pour rester alignée.

```
┌─────────────────────────────────────────────────────────────────┐
│                         ÉCRAN (Window)                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Base_Board                           │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │                   GridManager                     │  │    │
│  │  │  (Grille 2D — déplaçable via drag, scaleLevel)    │  │    │
│  │  │  ┌─────────────────────────────────────────────┐  │  │    │
│  │  │  │              Base_WorkArea                  │  │  │    │
│  │  │  │  ┌───────────────────────────────────────┐  │  │  │    │
│  │  │  │  │              World3D                  │  │  │  │    │
│  │  │  │  │  (View3D + OrthographicCamera +       │  │  │  │    │
│  │  │  │  │   helpers grid↔world + registry des   │  │  │  │    │
│  │  │  │  │   PhysicsActor + CameraRig)           │  │  │  │    │
│  │  │  │  │  Position: -grid.x, -grid.y           │  │  │  │    │
│  │  │  │  └───────────────────────────────────────┘  │  │  │    │
│  │  │  │  + SnapableElements (2D)                    │  │  │    │
│  │  │  └─────────────────────────────────────────────┘  │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  │                                                         │    │
│  │  GlobalMa (MouseArea — capture souris)                  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Composants Principaux

### 1. GridManager (`qml/meowComponent/grid/GridManager.qml`)

**Rôle** : Grille 2D de référence, gère les coordonnées et le zoom.

**Propriétés clés** :
```qml
property real mmSize: 12.0                            // Taille en mm (contrôle le zoom)
property real scaleLevel: mmSize / defaultMmSize      // Niveau de zoom (1.0 = 100%)
property real gridSize: Screen.pixelDensity * mmSize  // Taille d'une case en pixels
property real boardSize: gridSize * croisillons       // Taille totale

x: ...  // Position X de la grille dans le board
y: ...  // Position Y de la grille dans le board
```

> **Note** : `mmSize` et `gridSize` sont délibérément typés `real` (et non `int`).
> C'est indispensable pour le zoom multiplicatif continu (×1.1 par cran) : un
> typage `int` ré-arrondirait `mmSize * 1.1` à chaque cran et le zoom ne
> progresserait que par paliers d'une unité de `mmSize`.

**Fonctions utilitaires** :
- `getGridPosition(x, y)` → Convertit pixels en coordonnées grille (entières)
- `getGridRealPosition(x, y)` → Convertit pixels en coordonnées grille (réelles)
- `getGridPixelPosition(x, y)` → Convertit coordonnées grille en pixels
- `snapElement2(element)` → Snap un élément sur la grille

---

### 2. World3D (`qml/world3d/World3D.qml`)

**Rôle** : Scène 3D autonome — remplace l'ancien `GameScene.qml` **et** absorbe l'ex-singleton `World3DTools` (helpers de conversion 2D↔3D).

**Structure** :
```qml
Item {
    id: root
    required property GridManager gridManager
    readonly property var physicsWorld: pattounxWorld   // contextProperty global

    property alias view3D: view3D
    property alias scene: sceneNode
    property alias camera: cameraOrthographic
    property alias entity: entityNode    // joueur principal
    property alias entity2: entity2Node  // 2e joueur (Phase 6 multi-actors local)

    View3D {
        id: view3D
        camera: cameraOrthographic
        importScene: sceneNode
    }

    Node (sceneNode) {
        OrthographicCamera (cameraOrthographic) {
            x: 0; y: 1000; z: 600
            eulerRotation.x: -55       // Vue isométrique
            horizontalMagnification: cameraMagnification
            verticalMagnification: cameraMagnification
        }
        Node (entityNode) { /* modèle 3D du personnage principal */ }
        Node (entity2Node) { /* modèle 3D du 2e joueur (optionnel) */ }
    }

    // Registry interne des PhysicsActor (auto-enregistrés). Tickés à chaque
    // FrameAnimation : pull bodyState → smoothing → écriture node3D.
    QtObject { id: registry; property var actors: [] }
    FrameAnimation {
        running: physicsWorld && physicsWorld.running
        onTriggered: {
            physicsWorld.beginFrame()      // débloque le buffer le plus récent
            for (let i = 0; i < registry.actors.length; i++)
                registry.actors[i].pullAndApply(alpha)
        }
    }
}
```

**Positionnement** :
```qml
// Dans Editor.qml
World3D {
    id: world3d
    gridManager: gameGrid
    x: -gameGrid.x   // Compensation du déplacement de la grille 2D
    y: -gameGrid.y
    cameraMagnification: gameGrid.scaleLevel
}
```

**Principe** : la scène 3D a une position **inverse** à la grille 2D pour rester visuellement alignée.

**Helpers grid ↔ world** (ex-`World3DTools`) — exposés en méthodes du `World3D` :
- `gridToWorld(gx, gy)` — symétrique, **sans** projection caméra : `(gx*gridSize, 0, -gy*gridSize)`. Utilisable même avant que `view3D` n'ait une taille.
- `worldToGrid(x3D, z3D)` — inverse symétrique.
- `gridToWorldStable(gx, gy)` — **mapping affine figé** : `origin/b1/b2` capturés au premier appel via `gridPositionTo3D`, puis réutilisés. Évite le tremblement basse fréquence dû au coupling caméra↔mapping (cf. §1 ci-dessous). C'est la version utilisée par `PhysicsActor.pullAndApply`.
- `gridPositionTo3D(gx, gy)` — passe par `mapTo3DScene` + intersection plan Y=0. Dépend de la caméra, donc peut bouger si la caméra bouge.
- `position3dToGridRealPosition(x, y, z)` — inverse, via `mapFrom3DScene` + `mapToItem(gridManager)`.
- `getGroundIntersection(viewX, viewY)` — projette un point écran sur Y=0.
- `moveEntityToGridPixelPosition(node, gridPixelX, gridPixelY)` / `moveEntityToGridPosition(node, gx, gy)` — déplace un node 3D directement à une case logique.

---

### 3. OrthographicCamera

**Type** : caméra orthographique (pas de perspective).

**Propriétés importantes** :
```qml
OrthographicCamera {
    x: 0; y: 1000; z: 600       // Vue plongeante
    eulerRotation.x: -55        // Angle de plongée (mode Follow par défaut)
    horizontalMagnification: scaleLevel
    verticalMagnification: scaleLevel
    clipNear: -10000
    clipFar: 1000055
}
```

Le zoom est contrôlé par `magnification`, pas par la distance Z (contrairement à une caméra perspective). Un changement de mode caméra (cf. `CameraRig`) peut modifier `eulerRotation.x` (90° en `FixedTopDown`, dynamique en `OrbitDebug`).

---

### 4. GlobalMa (`qml/meowComponent/GlobalMa.qml`)

**Rôle** : MouseArea globale qui capture tous les événements souris.

**Fonctionnement** :
```qml
MouseArea {
    drag.target: null          // assigné par Base_Board via Component.onCompleted: drag.target = gameGrid

    onPressed → mouseLogic.pressedLeft/Right()
    onReleased → mouseLogic.release()
    onPositionChanged → mouseLogic.positionChanged()
    onClicked → mouseLogic.clickedLeft/Right()
}
```

**Principe** : tous les événements sont routés vers le `mouseLogic` actif (chargé dynamiquement par `EditorLogic` selon le mode courant — Selection, Pose, Game, etc.).

---

### 5. MouseLogic_Base (`qml/editor/logic/MouseLogic_Base.qml`)

**Rôle** : classe de base abstraite des modes souris ; gère la synchronisation caméra 3D ↔ grille 2D pour le drag de grille et le zoom.

**Propriétés clés** :
```qml
property var view3D         // Référence à la View3D (via World3D.view3D)
property GridManager grid   // Référence à la grille
property point lastGridPos  // Dernière position connue de la grille
```

**Fonctions de synchronisation** :

#### `updateCameraPosition()`
Appelé quand la grille 2D bouge (drag). Met à jour la caméra 3D pour suivre.

```javascript
function updateCameraPosition() {
    var dx = grid.x - lastGridPos.x
    var dy = grid.y - lastGridPos.y

    var center = Qt.point(view3D.width / 2, view3D.height / 2)
    var target = Qt.point(center.x - dx, center.y - dy)

    var pCenter = view3D.mapTo3DScene(center)
    var pTarget = view3D.mapTo3DScene(target)
    var worldDelta = pTarget.minus(pCenter)

    cam.x += worldDelta.x
    cam.y += worldDelta.y
    cam.z += worldDelta.z

    lastGridPos = Qt.point(grid.x, grid.y)
}
```

#### `prepareZoom()` / `applyZoom()`
Gère le zoom centré sur la souris : on capture le point 3D sous la souris **avant** le changement de magnification, on l'évalue **après**, puis on corrige la position caméra pour que le point reste sous le curseur.

---

### 6. ScrollLogic (`qml/editor/logic/ScrollLogic.qml`)

**Rôle** : Gère le zoom via la molette (Ctrl + Wheel).

```javascript
function scrollGrid(wheel, deltaSize) {
    if (wheel.modifiers & Qt.ControlModifier) {
        logic.mouseLogic.prepareZoom(wheel.x, wheel.y)         // 1. AVANT
        var ratio = newMmSize / oldMmSize
        var newGridX = mouseX - (mouseX - editorGrid.x) * ratio
        var newGridY = mouseY - (mouseY - editorGrid.y) * ratio
        editorGrid.mmSize = newMmSize                          // 2. CHANGE
        editorGrid.x = newGridX
        editorGrid.y = newGridY
        logic.mouseLogic.applyZoom(wheel.x, wheel.y)           // 3. APRÈS
    }
}
```

---

### 7. InputController (`qml/world3d/InputController.qml`)

**Rôle** : capte les événements clavier et pousse un vecteur d'input normalisé vers le moteur physique. Remplace l'ancien singleton `EntityEngine` côté input.

**Propriétés clés** :
```qml
required property string actorId            // id du body Kinematic à piloter
required property var physicsWorld          // référence à pattounxWorld
property bool routeViaSession: true         // si true, route via PhysicsSession en client
property bool enabled: true
property var keymap: ({                     // configurable (multi-joueurs local)
    up:    [Qt.Key_Z, Qt.Key_Up],
    down:  [Qt.Key_S, Qt.Key_Down],
    left:  [Qt.Key_Q, Qt.Key_Left],
    right: [Qt.Key_D, Qt.Key_Right],
    sprint:        Qt.Key_Shift,
    freeCamToggle: Qt.Key_F
})

signal toggleFreeCamRequested()             // au CameraRig de switcher
```

**Fonctionnement** :
- À chaque `Keys.onPressed` / `Keys.onReleased`, met à jour un état de touches interne.
- Calcule `inputVec = (right−left, down−up)` normalisé, puis appelle `physicsWorld.pushInput(actorId, inputVec)`.
- En mode multi-joueurs **local** (Phase 6), instancier deux `InputController` avec des `keymap` distincts (ZQSD pour P1, flèches pour P2) et des `actorId` différents.
- En mode multi-joueurs **réseau** (Phase 7), `routeViaSession=true` envoie l'input à `PhysicsSession.pushOrSendInput()` qui décide : push direct si l'instance est l'hôte, sinon `InputUpdate` reliable vers l'hôte.

---

### 8. PhysicsActor (`qml/world3d/PhysicsActor.qml`)

**Rôle** : présentateur 3D — ne crée **pas** de body côté C++, lit `bodyState(bodyId)` à chaque frame de rendu et applique la position au `node3D` avec un lissage exponentiel.

**Propriétés clés** :
```qml
required property string bodyId
required property var world3D
property Node node3D: null
property real visualY: 0          // Y visuel 2.5D (jump/wave) — hors physique
property real smoothing: 0.3      // 70 % du chemin en ~50 ms à 60 Hz
property bool autoOrient: true
property real orientLerp: 0.2
```

**Boucle d'application** (appelée par `World3D` à chaque frame de rendu) :
```javascript
function pullAndApply(alpha) {
    const s = world3D.physicsWorld.bodyState(bodyId)
    if (!s.id) return

    // Mapping affine figé (origin + base capturés au démarrage).
    const pos3D = world3D.gridToWorldStable(s.position.x, s.position.y)

    // Lissage exponentiel impératif (Binding cassait l'écriture sur eulerRotation.y).
    node3D.x += (pos3D.x - node3D.x) * smoothing
    node3D.z += (pos3D.z - node3D.z) * smoothing
    node3D.y = visualY

    // Orientation auto depuis la velocity (lerp doux pour éviter le jitter).
    if (autoOrient && s.velocity.length() > 0.1) {
        const target = Math.atan2(s.velocity.x, s.velocity.y) * 180 / Math.PI
        node3D.eulerRotation.y = lerp(node3D.eulerRotation.y, target, orientLerp)
    }
}
```

La création du body est de la responsabilité de l'orchestrateur :
- **`LocalPlayerSpawner.qml`** pour le joueur local (Kinematic).
- **`EditorPhysicsBridge.qml`** pour les caisses Dynamic posées en éditeur (`PhysicalObjectTile` → `createDynamicCircle` + zones d'exclusion via `upsertZone`).

---

### 9. CameraRig (`qml/world3d/CameraRig.qml`)

**Rôle** : pilote la caméra du `World3D`. Composant **instanciable** (pas singleton) — remplace l'ancien `CameraController` singleton.

**Modes** (`enum Mode { Follow, FreeCam, FixedTopDown, OrbitDebug }`) :
- **Follow** : suit `target` (un Node) avec lerp `1 - exp(-smoothSpeed * dt)` frame-rate independent. Sync grid 2D côté éditeur (la grille est repoussée pour rester alignée avec la cible à l'écran).
- **FreeCam** : pas de suivi automatique ; déplacement manuel via `moveManual(dx, dy, speed, dt)` (boucle externe qui lit l'input).
- **FixedTopDown** : caméra figée (`eulerRotation.x = -90°`), pas de suivi. Utile pour inspection statique.
- **OrbitDebug** : orbite autour de `target` (yaw/pitch/distance configurables). Pas de sync grid 2D.

**API** :
```qml
required property var world3D
property Node target: null
property Item grid2D: null            // grille à décaler en mode Follow
property var  mouseLogicRef: null     // pour rafraîchir lastGridPos
property int  mode: CameraRig.Follow
property real smoothSpeed: 2.0
property vector3d offset

function setMode(newMode)             // switch à chaud sans téléporter
function setTarget(node, grid2D, mouseLogicRef)
function recomputeOffset()            // ré-évalue offset depuis l'angle caméra
function snapToTarget()                // pose la caméra sans lerp
function moveManual(dx, dy, speed, dt) // FreeCam
function orbitDelta(yaw, pitch, dist)  // OrbitDebug
```

**Boucle Follow** (extrait) :
```javascript
FrameAnimation {
    running: mode === CameraRig.Follow && target && world3D && world3D.camera
    onTriggered: {
        const cam = world3D.camera, view3D = world3D.view3D, dt = frameTime

        // Pré-mesure de la position écran de la cible (pour repoussage grid 2D).
        const screenPosPre = view3D.mapFrom3DScene(target.position)

        // Lerp frame-rate independent.
        const t = 1.0 - Math.exp(-smoothSpeed * dt)
        cam.x += (target.x + offset.x - cam.x) * t
        cam.y += (target.y + offset.y - cam.y) * t
        cam.z += (target.z + offset.z - cam.z) * t

        // Sync grid 2D : la grille suit la cible à l'écran.
        const screenPosPost = view3D.mapFrom3DScene(target.position)
        grid2D.x += screenPosPost.x - screenPosPre.x
        grid2D.y += screenPosPost.y - screenPosPre.y
        if (mouseLogicRef)
            mouseLogicRef.lastGridPos = Qt.point(grid2D.x, grid2D.y)
    }
}
```

---

## Flux de données

### Déplacement (Drag de la grille)

Comportement éditeur classique, inchangé depuis V1 :

```
Utilisateur drag la grille
        ↓
GlobalMa.onPositionChanged()
        ↓
drag.target = grid → grid.x/y changent
        ↓
mouseLogic.positionChanged()
        ↓
mouseLogic.updateCameraPosition()
        ↓
Caméra 3D déplacée pour compenser
```

### Zoom (Ctrl + Molette)

Inchangé depuis V1 :

```
Utilisateur scroll avec Ctrl
        ↓
WheelHandler.onWheel()
        ↓
scrollLogic.scrollUp/Down()
        ↓
mouseLogic.prepareZoom()    ← Capture point 3D sous souris
        ↓
grid.mmSize change → scaleLevel change → magnification change
grid.x/y ajustés pour centrer sur souris
        ↓
mouseLogic.applyZoom()       ← Corrige position caméra 3D
```

### Mode Jeu — pipeline V2

Le déplacement du personnage passe désormais par le moteur physique sur **thread dédié**, plus par un singleton QML god-object. La caméra ne bouge **jamais** par effet de bord du déplacement entité — elle a sa propre boucle (`CameraRig.Follow`) qui suit le `entityNode`.

```
Utilisateur appuie ZQSD / Flèches
        ↓
InputController.handlePress(event)             [thread GUI]
        ↓
inputVec = normalize(right−left, down−up)
        ↓
physicsWorld.pushInput(actorId, inputVec)      ← QueuedConnection vers worker
        ↓                                         (ou InputUpdate reliable
                                                   si client réseau)
─ THREAD PHYSIQUE ─────────────────────────────────────────
PhysicsWorker.runStep() @ 60 Hz                [thread worker]
        ↓
engine.integrateBodies(dt)                     ← v_cible = inputVec × maxSpeed
                                                  v ← lerp(v, v_cible, accel × dt)
        ↓
engine.resolveBodyZoneCCD()                    ← sweep + rewind
engine.resolveBodyBodyCCD()                    ← cercle-cercle pour caisses
engine.runStaticPass() + correctPositions()
        ↓
worker.writeSnapshot() → triple buffer atomic
─ THREAD GUI ──────────────────────────────────────────────
World3D.FrameAnimation onTriggered
        ↓
physicsWorld.beginFrame()                      ← consomme le snapshot le plus récent
        ↓
for actor in registry: actor.pullAndApply(alpha)
        ↓
PhysicsActor:
  s = physicsWorld.bodyState(bodyId)
  pos3D = world3D.gridToWorldStable(s.position)  ← mapping affine figé
  node3D.x += (pos3D.x - node3D.x) * smoothing
  node3D.z += (pos3D.z - node3D.z) * smoothing
  node3D.y = visualY                              ← Y visuel 2.5D
        ↓
─ Boucle indépendante ─────────────────────────
CameraRig.Follow.FrameAnimation onTriggered
        ↓
cam.x += (target.x + offset.x - cam.x) * (1 - exp(-smoothSpeed*dt))
        ↓
sync grid 2D : grid2D.x/y += deltaScreen        ← la grille repoussée pour rester
                                                   alignée à la cible à l'écran
        ↓
mouseLogicRef.lastGridPos = Qt.point(grid2D.x, grid2D.y)
```

**Différences par rapport à V1** :
- Plus de mutation directe `targetEntity.x += dx` dans une `FrameAnimation` QML.
- Plus de god-object singleton (`EntityEngine`/`CameraController`/`World3DTools` → `InputController` + `PhysicsActor` + `CameraRig` + `World3D`, tous instanciables).
- Décorrélation **simu / rendu / caméra** : trois boucles indépendantes (worker physique 60 Hz, FrameAnimation rendu, FrameAnimation caméra).
- Le mapping grid → 3D utilisé par `PhysicsActor` est **stable** (basis figée) : pas de jitter quand la caméra lerp.

---

## Points d'attention

### 1. Stabilité du mapping grid ↔ world (jitter caméra-induit)

`gridPositionTo3D` passe par `view3D.mapTo3DScene`, qui dépend de la position/orientation de la caméra. Or la caméra lerp à part du tick physique. Conséquence : même position grille → positions 3D très légèrement différentes selon la frame de rendu → tremblement visible (jitter basse fréquence).

**Solution** : `gridToWorldStable` capture `origin/b1/b2` au premier appel (quand `view3D` est prêt) et réutilise toujours ces coefficients. La projection ortho étant affine, les vecteurs de base sont constants dans le temps. C'est ce que `PhysicsActor.pullAndApply` utilise.

Si on change `gridSize` à chaud ou repositionne la caméra hors d'un suivi continu, appeler `World3D.invalidateGridBasis()` pour reforcer une recalibration au prochain appel.

### 2. `lastGridPos` — variable critique

**But** : éviter les corrections doubles de la caméra.

**Problème** : si la grille bouge programmatiquement (ex: via le mode `Follow` du `CameraRig` qui repousse `grid2D.x/y` chaque frame) sans que `lastGridPos` soit mis à jour, `updateCameraPosition()` croit qu'il y a un drag utilisateur et déplace la caméra une deuxième fois.

**Solution** : `CameraRig.Follow` met lui-même à jour `mouseLogicRef.lastGridPos` après chaque frame de sync grid 2D. Tout autre site qui mute `grid.x/y` programmatiquement doit faire pareil.

### 3. Conversion 2D ↔ 3D — quelle helper utiliser

| Besoin | Helper | Caractéristique |
|---|---|---|
| Position 3D **stable** d'une case (rendu d'actor, carrés synchros) | `gridToWorldStable(gx, gy)` | Affine figé, immune au mouvement caméra |
| Position 3D d'une case **avec projection caméra courante** (clic souris, pose éditeur) | `gridPositionTo3D(gx, gy)` | Dépend de `mapTo3DScene` |
| Conversion symétrique sans projection | `gridToWorld` / `worldToGrid` | Pas besoin que view3D soit rendu |
| Inverse (node 3D → case logique) | `position3dToGridRealPosition` ou `getEntityGridRealPosition` | Via `mapFrom3DScene` + `mapToItem` |
| Pick souris écran → sol 3D | `getGroundIntersection(viewX, viewY)` | Intersection ray plan Y=0 |

`view3D.mapTo3DScene` / `mapFrom3DScene` dépendent de la caméra à l'instant de l'appel — les éviter dans des contextes où la caméra peut bouger entre deux appels supposés produire la même valeur.

### 4. Ordre des opérations pour le zoom

```
1. prepareZoom()  ← AVANT tout changement
2. Modifier mmSize, grid.x/y
3. applyZoom()    ← APRÈS tous les changements
```

Si l'ordre n'est pas respecté, le point sous la souris va « sauter ».

### 5. `World3D.x/y` inverse de `grid.x/y`

```qml
World3D {
    x: -gameGrid.x
    y: -gameGrid.y
}
```

La scène 3D se déplace dans le sens **opposé** à la grille pour rester visuellement alignée avec les éléments 2D.

### 6. Switch de mode caméra à chaud

`CameraRig.setMode(newMode)` gère les transitions sans téléporter :
- Vers `Follow` : recompute `offset` depuis l'angle caméra courant.
- Vers `FixedTopDown` : snap `eulerRotation.x = -90°` mais conserve XZ courants.
- Vers `OrbitDebug` : initialise yaw/pitch/distance depuis le delta target↔cam pour ne pas téléporter.
- Vers `FreeCam` : ne touche à rien, juste arrête la boucle Follow / Orbit (binding `running`).

---

## Schéma des systèmes de coordonnées

```
              Écran (pixels)
    ┌───────────────────────────────┐
    │ (0,0)                         │
    │   ┌─────────────────────────┐ │
    │   │    Grille 2D            │ │
    │   │    (grid.x, grid.y)     │ │
    │   │                         │ │
    │   │   ┌─────────────────┐   │ │
    │   │   │  Élément 2D     │   │ │
    │   │   │  pixelX = gx * gridSize + grid.x
    │   │   │  pixelY = gy * gridSize + grid.y
    │   │   └─────────────────┘   │ │
    │   │                         │ │
    │   └─────────────────────────┘ │
    │                               │
    │       Monde 3D (caméra ortho) │
    │       X3D = +gx * gridSize    │
    │       Y3D = 0 (sol) + visualY │
    │       Z3D = -gy * gridSize    │
    │                               │
    │   gridToWorldStable           │
    │     gx → X3D                  │
    │     gy → Z3D (négatif)        │
    └───────────────────────────────┘
```

Conventions :
- **Worker physique** : tout en grille, `QVector2D(gx, gy)`. Aucune connaissance de `gridSize` ni de `View3D`.
- **GUI** : conversion via `World3D.gridToWorld(gx, gy)` (X3D = gx × gridSize, Z3D = −gy × gridSize, Y3D = 0).

---

## Fichiers importants

| Fichier | Rôle |
|---------|------|
| `qml/meowComponent/grid/GridManager.qml` | Grille 2D, zoom, coordonnées |
| `qml/meowComponent/Base_Board.qml` | Structure de base du board (grille + fond + GlobalMa) |
| `qml/meowComponent/GlobalMa.qml` | Capture souris, routing vers `mouseLogic` |
| `qml/world3d/World3D.qml` | Scène 3D + caméra ortho + helpers grid↔world + registry actors (remplace `GameScene` + `World3DTools`) |
| `qml/world3d/PhysicsActor.qml` | Présentateur 3D : pull `bodyState`, lissage, Y visuel 2.5D |
| `qml/world3d/CameraRig.qml` | Modes caméra Follow / FreeCam / FixedTopDown / OrbitDebug (remplace `CameraController`) |
| `qml/world3d/InputController.qml` | Clavier → `pushInput(actorId, vec)` (remplace partie input de `EntityEngine`) |
| `qml/world3d/LocalPlayerSpawner.qml` | Crée le body Kinematic du joueur local |
| `qml/world3d/PhysicsObjectSpawner.qml` | Spawn auto pour les `PhysicalObjectTile` (caisses Dynamic) |
| `qml/world3d/EditorPhysicsBridge.qml` | Pousse zones et caisses depuis l'éditeur |
| `qml/editor/logic/MouseLogic_Base.qml` | Synchronisation caméra/grille (drag + zoom) |
| `qml/editor/logic/ScrollLogic.qml` | Gestion du zoom molette |
| `qml/editor/Editor_WheelHandler.qml` | Handler molette éditeur |
| `cpp/game/physics/physics_world.{h,cpp}` | Façade GUI du moteur physique (`pattounxWorld` context property) |
| `cpp/game/physics/pattounx_engine_v2.{h,cpp}` | Cœur Qt-free du moteur (intégration → CCD → solver) |

---

## Debugging

### Vérifier la synchronisation drag / zoom

```javascript
console.log("Grid pos:",   grid.x, grid.y)
console.log("lastGridPos:", lastGridPos.x, lastGridPos.y)
console.log("Camera pos:", cam.x, cam.y, cam.z)
console.log("Magnification:", cam.horizontalMagnification)
```

### Vérifier le mapping stable

```javascript
const a = world3d.gridToWorldStable(0, 0)
const b = world3d.gridPositionTo3D(0, 0)
console.log("stable:", a.x, a.z, "unstable:", b.x, b.z, "delta:", a.x - b.x, a.z - b.z)
```

Si `delta` varie d'une frame à l'autre alors que la caméra est statique, c'est que le mapping non-stable dérive — `gridToWorldStable` est précisément là pour ça.

### Trace jitter (PhysicsActor)

`PhysicsActor.startJitterTrace(180)` active un log CSV de 180 frames avec : tick physique, dTick, position grille, position stable, position non-stable, mapDx/mapDz (delta entre les deux), positions node3D pré/post lissage, position caméra. Format conçu pour être collé dans un tableur — précieux pour distinguer jitter physique vs jitter caméra-induit vs jitter de lissage.

### Problème courant : décalage après zoom

**Cause probable** : `lastGridPos` non mis à jour correctement.
**Solution** : vérifier que `applyZoom()` est appelé et met à jour `lastGridPos`.

### Problème courant : grille et 3D se déplacent différemment

**Cause probable** : `updateCameraPosition()` appelé alors qu'il ne devrait pas (mutation programmatique de `grid.x/y` sans mise à jour de `lastGridPos`).
**Solution** : tout site qui mute `grid.x/y` doit refresher `lastGridPos`. `CameraRig.Follow` le fait via `mouseLogicRef.lastGridPos`.

### Problème courant : tremblement basse fréquence du joueur

**Cause probable** : utilisation de `gridPositionTo3D` (caméra-dépendant) au lieu de `gridToWorldStable` pour le rendu d'actor.
**Solution** : `PhysicsActor` utilise `gridToWorldStable` par défaut. Si vous écrivez votre propre présentateur, faites pareil.
