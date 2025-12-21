# Système de Caméra et Déplacement - Architecture Globale

## Vue d'ensemble

Le projet utilise un système **hybride 2D/3D** où :
- La **grille 2D** (`GridManager`) sert de référence pour le placement des éléments
- La **scène 3D** (`GameScene`) affiche le modèle 3D et suit les mêmes coordonnées
- Les deux systèmes doivent rester **synchronisés** en permanence

```
┌─────────────────────────────────────────────────────────────────┐
│                         ÉCRAN (Window)                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Base_Board                           │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │                   GridManager                     │  │    │
│  │  │  (Grille 2D - déplaçable via drag)               │  │    │
│  │  │  ┌─────────────────────────────────────────────┐  │  │    │
│  │  │  │              Base_WorkArea                  │  │  │    │
│  │  │  │  ┌───────────────────────────────────────┐  │  │  │    │
│  │  │  │  │            GameScene                  │  │  │  │    │
│  │  │  │  │  (View3D + OrthographicCamera)       │  │  │  │    │
│  │  │  │  │  Position: -grid.x, -grid.y          │  │  │  │    │
│  │  │  │  └───────────────────────────────────────┘  │  │  │    │
│  │  │  │  + SnapableElements (2D)                    │  │  │    │
│  │  │  └─────────────────────────────────────────────┘  │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  │                                                         │    │
│  │  GlobalMa (MouseArea - capture souris)                 │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Composants Principaux

### 1. GridManager (`qml/component/grid/GridManager.qml`)

**Rôle** : Grille 2D de référence, gère les coordonnées et le zoom.

**Propriétés clés** :
```qml
property int mmSize: 12              // Taille en mm (contrôle le zoom)
property real scaleLevel: mmSize / defaultMmSize  // Niveau de zoom (1.0 = 100%)
property int gridSize: Screen.pixelDensity * mmSize  // Taille d'une case en pixels
property int boardSize: gridSize * croisillons  // Taille totale

// Position de la grille (déplacement = scroll)
x: ...  // Position X de la grille dans le board
y: ...  // Position Y de la grille dans le board
```

**Fonctions utilitaires** :
- `getGridPosition(x, y)` → Convertit pixels en coordonnées grille (entières)
- `getGridRealPosition(x, y)` → Convertit pixels en coordonnées grille (réelles)
- `getGridPixelPosition(x, y)` → Convertit coordonnées grille en pixels
- `snapElement2(element)` → Snap un élément sur la grille

---

### 2. GameScene (`qml/component/GameScene.qml`)

**Rôle** : Contient la scène 3D avec la caméra orthographique.

**Structure** :
```qml
Item {
    View3D {
        camera: cameraOrthographic
        importScene: sceneNode
    }
    
    Node (sceneNode) {
        OrthographicCamera (cameraOrthographic) {
            x: 0, y: 1000, z: 600
            eulerRotation.x: -55°  // Vue isométrique
            horizontalMagnification: cameraMagnification  // Liée au zoom 2D
            verticalMagnification: cameraMagnification
        }
        
        Node (entityNode) {
            // Modèle 3D du personnage
        }
    }
}
```

**Positionnement** :
```qml
// Dans Editor.qml / GameBoard.qml
GameScene {
    x: -gameGrid.x  // Compensation du déplacement de la grille
    y: -gameGrid.y
    cameraMagnification: gameGrid.scaleLevel  // Synchronisation du zoom
}
```

**Principe** : La scène 3D a une position **inverse** à la grille 2D pour rester visuellement alignée.

---

### 3. OrthographicCamera

**Type** : Caméra orthographique (pas de perspective)

**Propriétés importantes** :
```qml
OrthographicCamera {
    x: 0          // Position X dans le monde 3D
    y: 1000       // Hauteur (fixe, vue du dessus)
    z: 600        // Profondeur (ajustée pour l'angle)
    
    eulerRotation.x: -55  // Angle de vue (plongée)
    eulerRotation.y: 0
    eulerRotation.z: 0
    
    // Zoom via magnification (pas de déplacement Z)
    horizontalMagnification: scaleLevel
    verticalMagnification: scaleLevel
    
    clipNear: -10000  // Plans de clipping larges
    clipFar: 1000055
}
```

**Note** : Le zoom est contrôlé par `magnification`, pas par la distance Z (contrairement à une caméra perspective).

---

### 4. GlobalMa (`qml/component/GlobalMa.qml`)

**Rôle** : MouseArea globale qui capture tous les événements souris.

**Fonctionnement** :
```qml
MouseArea {
    drag.target: gameGrid  // La grille est la cible du drag
    
    onPressed → mouseLogic.pressedLeft/Right()
    onReleased → mouseLogic.release()
    onPositionChanged → mouseLogic.positionChanged()
    onClicked → mouseLogic.clickedLeft/Right()
}
```

**Principe** : Tous les événements sont routés vers le `mouseLogic` actif.

---

### 5. MouseLogic_Base (`qml/editor/logic/MouseLogic_Base.qml`)

**Rôle** : Gère la synchronisation caméra 3D ↔ grille 2D.

**Propriétés clés** :
```qml
property var view3D        // Référence à la View3D
property GridManager grid  // Référence à la grille
property point lastGridPos // Dernière position connue de la grille
```

**Fonctions de synchronisation** :

#### `updateCameraPosition()`
Appelé quand la grille 2D bouge (drag). Met à jour la caméra 3D pour suivre.

```javascript
function updateCameraPosition() {
    var dx = grid.x - lastGridPos.x
    var dy = grid.y - lastGridPos.y
    
    // Convertir le delta 2D en delta 3D
    var center = Qt.point(view3D.width / 2, view3D.height / 2)
    var target = Qt.point(center.x - dx, center.y - dy)
    
    var pCenter = view3D.mapTo3DScene(center)
    var pTarget = view3D.mapTo3DScene(target)
    var worldDelta = pTarget.minus(pCenter)
    
    // Appliquer à la caméra
    cam.x += worldDelta.x
    cam.y += worldDelta.y
    cam.z += worldDelta.z
    
    lastGridPos = Qt.point(grid.x, grid.y)
}
```

#### `prepareZoom()` / `applyZoom()`
Gère le zoom centré sur la souris.

```javascript
function prepareZoom(mouseX, mouseY) {
    // Capturer le point 3D sous la souris AVANT le zoom
    zoomPointStart = view3D.mapTo3DScene(Qt.point(mouseX, mouseY))
}

function applyZoom(mouseX, mouseY) {
    // Calculer où est ce même point APRÈS le zoom
    var zoomPointEnd = view3D.mapTo3DScene(Qt.point(mouseX, mouseY))
    
    // Corriger la position de la caméra pour que le point reste sous la souris
    var worldCorrection = zoomPointEnd.minus(zoomPointStart)
    cam.x -= worldCorrection.x
    cam.y -= worldCorrection.y
    cam.z -= worldCorrection.z
    
    lastGridPos = Qt.point(grid.x, grid.y)
}
```

---

### 6. ScrollLogic (`qml/editor/logic/ScrollLogic.qml`)

**Rôle** : Gère le zoom via la molette.

**Flux de zoom** :
```javascript
function scrollGrid(wheel, deltaSize) {
    if (wheel.modifiers & Qt.ControlModifier) {
        // 1. Capturer l'état 3D avant
        logic.mouseLogic.prepareZoom(wheel.x, wheel.y)
        
        // 2. Calculer le nouveau niveau de zoom
        var ratio = newMmSize / oldMmSize
        
        // 3. Repositionner la grille 2D (zoom centré sur la souris)
        var newGridX = mouseX - (mouseX - editorGrid.x) * ratio
        var newGridY = mouseY - (mouseY - editorGrid.y) * ratio
        
        // 4. Appliquer (mmSize change → scaleLevel → magnification caméra)
        editorGrid.mmSize = newMmSize
        editorGrid.x = newGridX
        editorGrid.y = newGridY
        
        // 5. Corriger la caméra 3D
        logic.mouseLogic.applyZoom(wheel.x, wheel.y)
    }
}
```

---

### 7. EntityController (`qml/utils/EntityController.qml`)

**Rôle** : Contrôle le déplacement du personnage 3D et le suivi caméra (mode jeu).

**Type** : Singleton (`pragma Singleton`)

**Fonctionnement** :
```qml
FrameAnimation {
    onTriggered: {
        // 1. Déplacer l'entité selon les inputs clavier (ZQSD)
        targetEntity.x += dx
        targetEntity.z += dz
        
        // 2. Faire suivre la caméra (avec lissage)
        var screenPosPre = view3D.mapFrom3DScene(targetEntity.position)
        
        // Lerp vers la position cible
        cam.x += (targetCamX - cam.x) * t
        cam.z += (targetCamZ - cam.z) * t
        
        // 3. Synchroniser la grille 2D
        var screenPosPost = view3D.mapFrom3DScene(targetEntity.position)
        var dxScreen = screenPosPost.x - screenPosPre.x
        var dyScreen = screenPosPost.y - screenPosPre.y
        
        grid2D.x += dxScreen
        grid2D.y += dyScreen
        
        // IMPORTANT: Mettre à jour lastGridPos pour éviter les corrections doubles
        logic.mouseLogic.lastGridPos = Qt.point(grid2D.x, grid2D.y)
    }
}
```

---

## Flux de données

### Déplacement (Drag de la grille)

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

```
Utilisateur scroll avec Ctrl
        ↓
WheelHandler.onWheel()
        ↓
scrollLogic.scrollUp/Down()
        ↓
mouseLogic.prepareZoom() ← Capture point 3D sous souris
        ↓
grid.mmSize change → scaleLevel change → magnification change
grid.x/y ajustés pour centrer sur souris
        ↓
mouseLogic.applyZoom() ← Corrige position caméra 3D
```

### Mode Jeu (EntityController)

```
Utilisateur appuie ZQSD
        ↓
EntityController.handleKeyPress()
        ↓
inputVector mis à jour
        ↓
FrameAnimation.onTriggered (chaque frame)
        ↓
1. targetEntity.x/z déplacés
2. Caméra suit avec lerp
3. grid2D.x/y ajustés pour synchronisation
4. lastGridPos mis à jour
```

---

## Points d'attention

### 1. `lastGridPos` - Variable critique

**But** : Éviter les corrections doubles de la caméra.

**Problème** : Si la grille bouge (ex: via EntityController) mais que `lastGridPos` n'est pas mis à jour, `updateCameraPosition()` va recalculer un delta et déplacer la caméra une deuxième fois.

**Solution** : Toujours mettre à jour `lastGridPos` après avoir déplacé la grille programmatiquement.

### 2. Conversion 2D ↔ 3D

**Fonctions clés** :
- `view3D.mapTo3DScene(point2D)` → Convertit coordonnées écran en point 3D monde
- `view3D.mapFrom3DScene(point3D)` → Convertit point 3D monde en coordonnées écran

**Attention** : Ces fonctions dépendent de la position/orientation/magnification de la caméra au moment de l'appel.

### 3. Ordre des opérations pour le zoom

```
1. prepareZoom() ← AVANT tout changement
2. Modifier mmSize, grid.x/y
3. applyZoom() ← APRÈS tous les changements
```

Si l'ordre n'est pas respecté, le point sous la souris va "sauter".

### 4. GameScene.x/y inverse de grid.x/y

```qml
GameScene {
    x: -gameGrid.x
    y: -gameGrid.y
}
```

La scène 3D se déplace dans le sens **opposé** à la grille pour rester visuellement alignée avec les éléments 2D.

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
    │   │   │  x = gridPosX * gridSize + grid.x
    │   │   │  y = gridPosY * gridSize + grid.y
    │   │   └─────────────────┘   │ │
    │   │                         │ │
    │   └─────────────────────────┘ │
    │                               │
    │       Monde 3D                │
    │       (caméra ortho)          │
    │       X = droite              │
    │       Y = haut (ciel)         │
    │       Z = profondeur          │
    └───────────────────────────────┘
```

---

## Fichiers importants

| Fichier | Rôle |
|---------|------|
| `qml/component/grid/GridManager.qml` | Grille 2D, zoom, coordonnées |
| `qml/component/GameScene.qml` | Scène 3D, caméra orthographique |
| `qml/component/GlobalMa.qml` | Capture souris, routing vers mouseLogic |
| `qml/editor/logic/MouseLogic_Base.qml` | Synchronisation caméra/grille |
| `qml/editor/logic/ScrollLogic.qml` | Gestion du zoom molette |
| `qml/utils/EntityController.qml` | Déplacement personnage (mode jeu) |
| `qml/component/Base_Board.qml` | Structure de base du board |
| `qml/editor/Editor_WheelHandler.qml` | Handler molette éditeur |

---

## Debugging

### Vérifier la synchronisation

```javascript
console.log("Grid pos:", grid.x, grid.y)
console.log("lastGridPos:", lastGridPos.x, lastGridPos.y)
console.log("Camera pos:", cam.x, cam.y, cam.z)
console.log("Magnification:", cam.horizontalMagnification)
```

### Problème courant : décalage après zoom

**Cause probable** : `lastGridPos` non mis à jour correctement
**Solution** : Vérifier que `applyZoom()` est appelé et met à jour `lastGridPos`

### Problème courant : grille et 3D se déplacent différemment

**Cause probable** : `updateCameraPosition()` appelé alors qu'il ne devrait pas
**Solution** : Vérifier que `lastGridPos` est mis à jour après chaque déplacement programmatique de la grille

