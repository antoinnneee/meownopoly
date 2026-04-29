# Analyse Complète de l'Architecture de l'Éditeur Meownopoly

## Vue d'Ensemble

L'éditeur de Meownopoly est un éditeur de cartes sophistiqué construit en QML/Qt qui permet de créer et modifier des plateaux de jeu avec un système de grille, de snapable elements (accrochage), de zoom, de connexions entre cases, et de sélection par rectangle.

---

## 1. Structure des Dossiers QML

### `/qml/editor/` - Dossier Principal de l'Éditeur

L'éditeur hérite de **`meowComponent/Base_Board.qml`** (grille, fond, `GlobalMa`) et instancie **`meowComponent/Base_WorkArea.qml`** pour la zone de travail. La logique hérite de **`meowComponent/Base_logic.qml`**.

#### **Fichiers Racine**
- **`Editor.qml`** : Point d'entrée principal de l'éditeur
  - Étend `Base_Board` ; gère le layout global (grille `gameGrid`, `workArea`, panneaux)
  - Contient le `MouseArea` principal (`mainMa`, fourni par `Base_Board`) qui capture tous les événements souris
  - Instancie `workArea` (Base_WorkArea), `logic` (EditorLogic), `selectionPanel`, `sidePanel` (BottomSidePanel), `mapInfoPanel`
  - Gère les raccourcis clavier (Delete, Escape)

- **`EditorLogic.qml`** : Cerveau de l'éditeur
  - Étend `Base_logic` ; centralise toute la logique métier
  - Charge dynamiquement les modes de souris via un `Loader` (source = `editorDynamicComponent.mouseLogic_*_comp`)
  - Contient `snapableTilesList`, `editorGrid`, `selectionRect`, `workArea`, `tileLogic`, `planLogic`
  - Gère la sélection par rectangle

- **`EditorDynamicComponent.qml`** : Fabrique d'éléments et de logiques
  - Contient les `Component` pour créer dynamiquement :
    - `SnapableCaseTile`, `SnapableDecoration`, `SnapableExclusionZone` (zones physiques)
    - Modes souris : `MouseLogic_Selection`, `MouseLogic_Pose`, `MouseLogic_Game`, `MouseLogic_Selection_link`, `MouseLogic_DrawPolygon`, `MouseLogic_Template`
    - Scroll : `ScrollLogic`, `ScrollLogic_POSE`
  - Gère les événements de suppression et configuration des éléments

- **`Editor_WheelHandler.qml`** : Gestionnaire de molette
  - Capture les événements de la molette et délègue au `ScrollLogic` approprié

- **`EditorEscMenu.qml`** : Menu Escape (chargement de carte, options, etc.)

- **`EditorController.qml`** : Contrôleur (initialisation, raccourcis, etc.)

- **`Trackers.qml`** : Composants de suivi (prévisualisation polygone, lien, template)

- **`MenuMapAtStart.qml`** : Menu de démarrage
  - Permet de créer/charger une carte au lancement

**Composants partagés** (dans **`/qml/meowComponent/`**) :
- **`Background.qml`** : Image de fond de la carte (utilisée par Base_Board)
- **`SelectionRect.qml`** : Rectangle de sélection (instancié dans Editor.qml)

#### **Sous-dossier `/qml/editor/logic/`** - Logique Métier

**Architecture modulaire basée sur des états (State Machine)**

**Logique de la Souris** (6 modes) :
- **`MouseLogic_Base.qml`** : Classe de base abstraite
  - Définit l'interface commune ; propriétés : `grid`, `clickElement`, `selectedElements`
  - Méthodes : `pressedLeft()`, `clickedLeft()`, `release()`, etc.
  - Gère la configuration des cases dans le panneau

- **`MouseLogic_Selection.qml`** : Mode NORMAL (sélection/déplacement)
  - Gestion de la sélection, déplacement par drag & drop, **sélection par rectangle**
  - Support de la multi-sélection avec Ctrl ; utilise `groupeSelection`

- **`MouseLogic_Pose.qml`** : Mode POSE (placement d'éléments)
  - Permet de placer des assets/cases sur la grille

- **`MouseLogic_Selection_link.qml`** : Mode SELECTION_LINK (création de connexions)
  - Hérite de `MouseLogic_Selection` ; utilise `linkSourceCase` et `kind` (previous/next)

- **`MouseLogic_Game.qml`** : Mode GAME (jeu / test)

- **`MouseLogic_DrawPolygon.qml`** : Mode dessin de polygones (zones)

- **`MouseLogic_Template.qml`** : Mode TEMPLATE (sélection par zone / templates)
  - Hérite de `MouseLogic_Selection`

**Logique de Scroll** (2 modes) :
- **`ScrollLogic.qml`** : Scroll normal — Ctrl + Molette = Zoom (`editorGrid.mmSize`)
- **`ScrollLogic_POSE.qml`** : Scroll en mode pose

**Logique des Tuiles et Plans** :
- **`TileLogic.qml`** : Création/suppression d'éléments (`createNewTileAtPosition`, `deleteElement`, zones d'exclusion), connexions, désélection, ordre Z
- **`PlanLogic.qml`** : Gestion des plans/calques Z (visibilité par plage de plans)

#### **Composants partagés `/qml/meowComponent/`** - Grille, Snapables, Cases

**Grille** (`/qml/meowComponent/grid/`) :
- **`GridManager.qml`** : ⭐ Composant central de la grille
  - Dessine la grille avec un seul `Repeater` optimisé (lignes verticales + horizontales)
  - Propriétés : `gridSize = Screen.pixelDensity * mmSize`, `boardSize = gridSize * croisillons` (600), `croisillons`, `mmSize`, `scaleLevel`
  - Fonctions : `getGridPosition(x, y)`, `snapElement2(element)` (utilise `snapableParameters.displayParameter`)
  - Mode redimensionnement visuel (`resizeMode`), signal `selectedElementSnapped`

**À la racine de meowComponent** :
- **`SelectionRect.qml`** : Rectangle de sélection ; `show()/hide()`, `updateGeometry()` / `updateGeometryFromGrid()`

**Éléments Snapables** (`/qml/meowComponent/snapable/`) :
- **`SnapableElement.qml`** : ⭐ Classe de base pour tous les éléments
  - Reçoit un `ItemSnapable snapableParameters` (C++) ; coordonnées via **`snapableParameters.displayParameter`** :
    - `gridRelativePositionX/Y` : position en unités de grille
    - `x/y` : bindés à `gridRelativePositionX/Y * gridManager.gridSize`
    - `width/height` : `gridManager.gridSize * unitSizeWidth/Height`
  - Auto-snapping à la création et après drag (`onElementReleased`)
  - Z : `zOrder + zLayer` (normal), +11 si sélectionné
  - Contient : `SnapableElementControl`, `SnapableElementResizeHandles`, gestionnaire de connexions (`connectionManager`)

- **`SnapableElementConnections.qml`** : Gestionnaire de connexions (exposé comme `connectionManager` sur l’élément)
  - Listes `previousElements[]`, `nextElements[]` ; dessin avec `ConnectionOverlay` ; bidirectionnalité

- **`SnapableElementControl.qml`** : Boutons (supprimer, plan, configurer)
- **`SnapableElementResizeHandles.qml`** : Poignées de redimensionnement (unités de grille)
- **`ResizeHandle.qml`** : Poignée individuelle
- **`SnapableElementDeleteAnimation.qml`** / **`SnapableElementCreateAnimation.qml`** : Animations
- **`SnapableCaseTile.qml`** : Case de jeu (caseData, TileContent)
- **`SnapableDecoration.qml`** : Élément décoratif
- **`SnapableExclusionZone.qml`** : Zone d'exclusion / physique
- **`ConnectionOverlay.qml`** / **`ConnectionOverlay2.qml`** : Lignes de connexion visuelles

**Aperçus** (`/qml/meowComponent/preview/`) :
- **`AssetPreviewCursor.qml`** : Aperçu sous le curseur en mode POSE
- **`PolygonPreviewCursor.qml`**, **`LinkPreviewCursor.qml`**, **`TemplatePreviewCursor.qml`**

#### **Sous-dossier `/qml/editor/panel/`** - Panneaux d'Interface

**Structure à deux niveaux** : `bottomPanel/bottomMainPanel/` (panneau principal) et `bottomPanel/bottomSidePanel/` (panneau latéral).

**Panneau principal** (`bottomPanel/bottomMainPanel/`) :
- **`SelectionPanel.qml`** : Panneau inférieur avec `MenuSelector` (onglets) et zone de redimensionnement
  - `StackLayout` avec **`AssetSelectionPanel`** (assets + types de cases intégrés)
  - Signaux : `assetSelected`, `assetCleared`, `caseSelected`, `visualEffectChanged`, `resizeStarted`/`resizeFinished`
  - Sous-dossiers : `assetSelectionPanel/`, `caseSelectionPanel/`, `menuSelectionPanel/`, `editorBottomPanel/`, `templatePanel/`, `zonePanel/`
  - **Note** : `MapSelectionPanel` existe en backup uniquement ; paramètres carte / sauvegarde-chargement passent par `MapInfoPanel` et `EditorEscMenu`.

**Panneau latéral** (`bottomPanel/bottomSidePanel/`) :
- **`BottomSidePanel.qml`** : Panneau coulissant (droite) ; expose `visualEffectsPanel`, `caseConfigurationPanel`, `connectionsConfigurationPanel`, `zoneConfigurationPanel`
- **`caseConfigPanel/`** : Configuration de case
  - `CaseConfigurationPanel.qml`, `CaseConfigurationPanelSection.qml`
  - `ConnectionsConfigurationSection.qml` : ⭐ Gestion des connexions (previous/next)
  - `ConnectionListSection.qml`, `ConnectionsPanel.qml`
  - Sections par type : `CCPS_*.qml`, `CCP_*.qml`
- **`visualEffectPanel/`** : `VisualEffectsPanel.qml`, `TransformPanel.qml`, `VEP_*.qml` (couleur, miroir, rotation, etc.)
- **`zoneConfigPanel/`** : Configuration des zones physiques (`ZCP_*.qml`, `ZoneConfigurationPanelSection.qml`)
- **`ModelSelectionPanel.qml`** : Sélection de modèles

**Autres panneaux** :
- **`mapInfoPanel/`** : `MapInfoPanel.qml`, `MapInfoDrawer.qml`, `MapNavigationBar.qml`, `MapSidePanel.qml` — infos carte et fond d’écran

#### **Sous-dossier `/qml/meowComponent/case/`** - Affichage des Cases

- **`CaseTile.qml`** : Composant d'affichage d'une case
- **`TileContent.qml`** : Contenu visuel d'une case
- **`TileDetailsPopup.qml`** : Popup de détails
- **`content/`** : Contenus spécifiques par type (KibbleDispenser, CatDoor, RestArea, etc.)
- **`details/`** : Détails spécifiques par type

---

## 2. Fonctionnement de la Grille

### 2.1 Génération de la Grille

La grille est générée par **`meowComponent/grid/GridManager.qml`** (instancié dans `Base_Board` comme `gameGrid`, exposé à l’éditeur comme `editorGrid`) :

```qml
property int croisillons: 600
property int mmSize: 12
property real defaultMmSize: 12.0
property real scaleLevel: mmSize / defaultMmSize
property int gridSize: Screen.pixelDensity * mmSize  // Pixels par cellule

property int boardSize: gridSize * croisillons  // Grille de 600×600 cellules
width: boardSize
height: boardSize
```

**Rendu de la grille** :
- Un seul `Repeater` avec `model: totalLineCount` où `totalLineCount = verticalLinesCount + horizontalLinesCount`
- `verticalLinesCount` / `horizontalLinesCount` = `croisillons + 1` si la grille est affichée
- Chaque delegate est un `Rectangle` dont la position et la taille dépendent de `isVertical` (index < verticalLinesCount)

```qml
Repeater {
    model: gridContainer.totalLineCount
    Rectangle {
        readonly property bool isVertical: index < gridContainer.verticalLinesCount
        x: isVertical ? verticalIndex * gridManager.gridSize : 0
        y: isVertical ? 0 : horizontalIndex * gridManager.gridSize
        width: isVertical ? lineWidth : parent.width
        height: isVertical ? parent.height : lineWidth
    }
}
```

### 2.2 Système de Coordonnées

**Deux systèmes coexistent** :

1. **Coordonnées de grille** (logiques) : `snapableParameters.displayParameter.gridRelativePositionX/Y`
   - Entiers : 0, 1, 2, 3, ...
   - Stockées dans le `DisplayParameter` C++ (via `ItemSnapable`)

2. **Coordonnées pixel** (visuelles) : `x/y`
   - Calculées automatiquement : `x = gridRelativePositionX * gridSize` (bindings dans `SnapableElement.qml`)

**Conversion** (dans `GridManager`) :
```javascript
// Pixel → Grille
function getGridPosition(x, y) {
    return Qt.point(
        Math.floor(x / gridSize),
        Math.floor(y / gridSize)
    )
}
// getGridPixelPosition(x, y) pour grille → pixel
```

---

## 3. Système "Snapable" (Accrochage)

### 3.1 Principes de Base

Le système snapable permet aux éléments de **s'accrocher automatiquement à la grille**.

**Composant de base** : `SnapableElement.qml`

**Mécanisme** :
1. L'élément est positionné en coordonnées grille (`gridRelativePositionX/Y`)
2. Les coordonnées pixel (`x/y`) sont **calculées automatiquement** via binding QML
3. Lors du drag, l'élément est déplacé en pixels
4. Au relâchement, `snapToGrid()` est appelé automatiquement

### 3.2 Cycle de Vie d'un Élément Snapable

```
Création → snapToGrid() [Component.onCompleted]
   ↓
Sélection → isSelected = true → z augmenté
   ↓
Drag → parent = groupeSelection → déplacement libre en pixels
   ↓
Release → updateRelativePosition() → snapToGrid()
   ↓
Désélection → parent = workArea → snap final
```

### 3.3 Fonction Snap

Dans **`SnapableElement.qml`**, les positions logiques sont dans **`snapableParameters.displayParameter`** :

```javascript
function snapToGrid() {
    if (!gridManager || !gridManager.snapToGrid) return
    
    var snappedGridX = Math.round(x / gridManager.gridSize)
    var snappedGridY = Math.round(y / gridManager.gridSize)
    
    snapableParameters.displayParameter.gridRelativePositionX = snappedGridX
    snapableParameters.displayParameter.gridRelativePositionY = snappedGridY
    
    gridManager.snapElement2(snapableElement)  // ou l'élément root
}
```

`GridManager.snapElement2(element)` lit `element.snapableParameters.displayParameter.gridRelativePositionX/Y` et met à jour `element.x/y` ; si l’élément est sélectionné, émet `selectedElementSnapped(element)` pour recréer les bindings.

### 3.4 Groupe de Sélection

Quand plusieurs éléments sont sélectionnés :
- Ils deviennent enfants d'un `Item` appelé `groupeSelection`
- Le drag déplace `groupeSelection` → tous les enfants bougent ensemble
- Au relâchement, chaque élément retourne dans `workArea` et snap individuellement

```qml
Item { 
    id: groupeSelection
    property int gridXPosition: 0
    property int gridYPosition: 0
}
```

---

## 4. Système de Zoom

### 4.1 Principe

Le zoom ne change **pas l'échelle** (scale) de la grille, mais la **taille des cellules**.

**Formule** :
```
gridSize = Screen.pixelDensity * mmSize
```

- `Screen.pixelDensity` : Constante (pixels par mm de l'écran)
- `mmSize` : Variable contrôlée par l'utilisateur (10mm par défaut)

**Effet** :
- Augmenter `mmSize` → cellules plus grandes → effet de "zoom in"
- Diminuer `mmSize` → cellules plus petites → effet de "zoom out"

### 4.2 Contrôle du Zoom

**Via la molette** (`editor/logic/ScrollLogic.qml`) :
- La fonction `scrollGrid(wheel, deltaSize)` est appelée par le wheel handler.
- Si `wheel.modifiers & Qt.ControlModifier` : mise à jour de `editorGrid.mmSize` (zoom centré sous la souris), ajustement de `editorGrid.x/y` et éventuellement de `tileLogic.currentElementWidth/Height` pour garder le ratio.

**Effet cascade** :
1. `editorGrid.mmSize` change (GridManager)
2. `gridSize` et `scaleLevel` sont recalculés (bindings)
3. Tous les éléments snapables se repositionnent et redimensionnent car leurs `x/y/width/height` sont bindés à `gridManager.gridSize`

### 4.3 Avantages de cette Approche

✅ **Pas de perte de qualité** : Les éléments sont re-rendus à la nouvelle taille, pas juste étirés  
✅ **Précision** : Les coordonnées de grille restent exactes  
✅ **Performance** : Un seul calcul pour tous les éléments (bindings QML)  
✅ **Simplicité** : Pas besoin de gérer des transformations complexes

---

## 5. Gestion des Liens entre Cases

### 5.1 Architecture

Chaque élément snapable expose un gestionnaire de connexions (**`connectionManager`**, instance de **`SnapableElementConnections.qml`**) qui gère :
- `previousElements[]` : Liste des éléments précédents (flux de jeu)
- `nextElements[]` : Liste des éléments suivants
- `parentElement` : référence vers l’élément parent

La bidirectionnalité est gérée côté C++ (`ItemSnapable::addNext` / `addPrev`) et/ou dans la couche QML selon les cas ; les overlays sont mis à jour via `nextElementsSegments.updateModel()`.

### 5.2 Affichage Visuel

Les connexions sont affichées par un `Repeater` dans **`meowComponent/snapable/SnapableElementConnections.qml`** (exposé comme `connectionManager` sur l’élément) :

```qml
ListModel { id: nextElementsSegments }  // mis à jour par updateModel() sur nextElements

Repeater {
    model: nextElementsSegments
    delegate: ConnectionOverlay {
        fromElement: parentElement
        toElement: model.toElement  // nextEl
    }
}
```

`ConnectionOverlay.qml` dessine une ligne entre les deux éléments (avec prise en compte de `groupeSelection` pour le décalage).

### 5.3 Processus de Création d'un Lien

**Mode opératoire** :

1. **Demande de connexion** :
   - Utilisateur sélectionne une case
   - Clique sur "Connect Next" ou "Connect Previous" dans le panneau
   - Signal `connectionRequested(kind)` émis

2. **Changement de mode** :
   ```javascript
   logic.mouseLogic.changeMouseMode(EditorEnum.EM_SELECTION_LINK)
   logic.mouseLogic.kind = "next"  // ou "previous"
   logic.mouseLogic.linkSourceCase = sourceElement
   ```

3. **Attente du clic** : `MouseLogic_Selection_link` est actif ; l’utilisateur clique sur la case cible.

4. **Création du lien** : appel à `logic.tileLogic.createSnapableLink(linkSourceCase, targetCase, kind)` ou équivalent (ajout via `snapableParameters.addNext` / `addPrev` côté C++).

5. **Retour au mode normal** : `changeMouseMode(EditorEnum.EM_NORMAL)` (par ex. depuis `EditorController` ou dans `MouseLogic_Selection_link`).

### 5.4 Synchronisation avec le Backend C++

Les connexions sont stockées dans l’objet `ItemSnapable`/`Case` C++ ; au chargement d’une carte, les connexions visuelles sont reconstruites à partir de ces données.

---

## 6. Fonction de Sélection par Rectangle

### 6.1 Composants Impliqués

1. **`meowComponent/SelectionRect.qml`** : Rectangle visuel (instancié dans `Editor.qml`, passé à `logic.selectionRect`)
2. **`editor/logic/MouseLogic_Selection.qml`** : Logique de détection
3. **`Editor.qml`** : Capture des mouvements de souris via `mainMa` (fourni par Base_Board)

### 6.2 Processus Détaillé

**Phase 1 : Détection du début**

```javascript
// MouseLogic_Selection.qml :: pressedLeft()
function pressedLeft(mouse, drag) {
    // Si aucun élément cliqué → mode sélection rectangle
    if (clickElement.length === 0) {
        isRectangleSelecting = true
        rectangleStart = Qt.point(mouse.x, mouse.y)
        logic.selectionRect.show()
        drag.target = null  // Empêcher le drag de la grille
    }
}
```

**Phase 2 : Mise à jour pendant le drag**

```javascript
// Editor.qml :: MouseArea
onPositionChanged: function(mouse) {
    if (logic.mouseLogic.isRectangleSelecting) {
        logic.mouseLogic.updateRectangleSelection(mouse.x, mouse.y)
    }
}

// MouseLogic_Selection.qml
function updateRectangleSelection(mouseX, mouseY) {
    rectangleCurrent = Qt.point(mouseX, mouseY)
    logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
    
    // Sélection en temps réel
    var elementsInRect = getElementsInRectangle(rectangleStart, rectangleCurrent)
    selectElementsInRectangle(elementsInRect)
}
```

**Phase 3 : Détection des éléments dans le rectangle**

```javascript
function getElementsInRectangle(start, current) {
    var elements = []
    
    // Limites du rectangle
    var rectLeft = Math.min(start.x, current.x)
    var rectRight = Math.max(start.x, current.x)
    var rectTop = Math.min(start.y, current.y)
    var rectBottom = Math.max(start.y, current.y)
    
    // Parcourir tous les éléments
    for (var i = 0; i < logic.snapableTilesList.length; i++) {
        var element = logic.snapableTilesList[i]
        
        // Limites de l'élément
        var elementLeft = element.x
        var elementRight = element.x + element.width
        var elementTop = element.y
        var elementBottom = element.y + element.height
        
        // Test d'intersection
        if (!(elementRight < rectLeft || elementLeft > rectRight || 
              elementBottom < rectTop || elementTop > rectBottom)) {
            elements.push(element)
        }
    }
    
    return elements
}
```

**Phase 4 : Finalisation**

```javascript
// MouseLogic_Selection.qml :: release()
function release(mouse, drag) {
    if (isRectangleSelecting) {
        finalizeRectangleSelection()  // Sélection finale
        isRectangleSelecting = false
        logic.selectionRect.hide()
    }
}
```

### 6.3 Particularités

- **Sélection en temps réel** : Les éléments sont sélectionnés pendant le drag, pas seulement à la fin
- **Désélection automatique** : Les éléments hors du rectangle sont désélectionnés
- **Groupement** : Tous les éléments sélectionnés deviennent enfants de `groupeSelection`
- **Configuration** : Si un seul élément au final → le panneau de configuration s'affiche

---

## 7. Flux de Données et Patterns Architecturaux

### 7.1 Pattern "State Machine" pour les Modes de Souris

```
EditorLogic.editorMouseMode (enum)
   ↓
Loader (sourceComponent: editorDynamicComponent.mouseLogic_*_comp) → charge le MouseLogic correspondant
   ↓
   ├─ EM_NORMAL → MouseLogic_Selection
   ├─ EM_POSE → MouseLogic_Pose
   ├─ EM_GAME → MouseLogic_Game
   ├─ EM_SELECTION_LINK → MouseLogic_Selection_link
   ├─ EM_DRAW_POLYGON → MouseLogic_DrawPolygon
   └─ EM_TEMPLATE → MouseLogic_Template
```

**Avantages** :
- Séparation claire des comportements
- Pas de gros `if/else` dans le code
- Extension facile (ajouter un nouveau mode = nouveau fichier + enum + Component dans EditorDynamicComponent)

### 7.2 Pattern "Factory" pour la Création d'Éléments

`EditorDynamicComponent` contient des `Component` QML instanciés à la demande par **`editor/logic/TileLogic.qml`** :

```javascript
// TileLogic.qml
var newTile = dynamicComponent.snapableCaseTileComponent.createObject(workArea, {
    "snapableParameters.displayParameter.gridRelativePositionX": gridX,
    "snapableParameters.displayParameter.gridRelativePositionY": gridY,
    // + caseData, displayParameter, etc.
})
```

Idem pour `snapableDecorationComponent` et `snapablePhysicZoneComponent` (zones d’exclusion).

### 7.3 Pattern "Observer" via Signaux QML

Les composants communiquent via signaux :

```
SnapableElement.elementDeleted
   → EditorDynamicComponent (handler)
   → TileLogic.deleteElement()
   → Liste snapableTilesList mise à jour
```

### 7.4 Binding Réactif pour la Synchronisation

Les positions et tailles sont automatiquement synchronisées :

```qml
// SnapableElement.qml (meowComponent/snapable)
x: snapableParameters.displayParameter.gridRelativePositionX * gridManager.gridSize
width: gridManager.gridSize * snapableParameters.displayParameter.unitSizeWidth
```

Changer `gridRelativePositionX` / `unitSizeWidth` ou `gridSize` met à jour `x` / `width` automatiquement.

---

## 8. Résumé des Sous-Dossiers

### `/qml/editor/` - Éditeur Principal
**Rôle** : Point d'entrée et coordination générale (hérite de `meowComponent/Base_Board`)  
**Fichiers clés** : `Editor.qml`, `EditorLogic.qml`, `EditorDynamicComponent.qml`, `EditorEscMenu.qml`, `EditorController.qml`, `Trackers.qml`, `MenuMapAtStart.qml`

### `/qml/editor/logic/` - Logique Métier
**Rôle** : Modes souris, scroll, tuiles, plans  
**Pattern** : State Machine avec Loaders  
**Fichiers clés** : `MouseLogic_Base.qml`, `MouseLogic_Selection.qml`, `MouseLogic_Pose.qml`, `MouseLogic_Selection_link.qml`, `MouseLogic_Game.qml`, `MouseLogic_DrawPolygon.qml`, `MouseLogic_Template.qml`, `TileLogic.qml`, `PlanLogic.qml`, `ScrollLogic.qml`, `ScrollLogic_POSE.qml`

### `/qml/meowComponent/` - Composants Partagés (éditeur + jeu)
**Rôle** : Grille, zone de travail, fond, rectangle de sélection, éléments snapables, cases  
**Fichiers clés** : `Base_Board.qml`, `Base_WorkArea.qml`, `Base_logic.qml`, `Background.qml`, `SelectionRect.qml`, `GlobalMa.qml`

### `/qml/meowComponent/grid/` - Grille
**Rôle** : Grille et snapping  
**Fichiers clés** : `GridManager.qml`

### `/qml/meowComponent/snapable/` - Système Snapable
**Rôle** : Classe de base et comportements des éléments accrochables  
**Fichiers clés** : `SnapableElement.qml`, `SnapableElementConnections.qml`, `SnapableCaseTile.qml`, `SnapableDecoration.qml`, `SnapableExclusionZone.qml`, `ConnectionOverlay.qml`

### `/qml/editor/panel/bottomPanel/bottomMainPanel/` - Panneau Principal (bas)
**Rôle** : Panneau inférieur avec onglets (MenuSelector) et contenu  
**Fichiers clés** : `SelectionPanel.qml`, `assetSelectionPanel/AssetSelectionPanel.qml`, `caseSelectionPanel/`, `menuSelectionPanel/`, `editorBottomPanel/`, `templatePanel/`, `zonePanel/`

### `/qml/editor/panel/bottomPanel/bottomSidePanel/` - Panneau Latéral (droite)
**Rôle** : Configuration case, connexions, effets visuels, zones  
**Fichiers clés** : `BottomSidePanel.qml`, `caseConfigPanel/CaseConfigurationPanel.qml`, `connectionConfigPanel/ConnectionsConfigurationSection.qml`, `visualEffectPanel/VisualEffectsPanel.qml`, `zoneConfigPanel/`

### `/qml/editor/panel/mapInfoPanel/` - Infos Carte
**Rôle** : Infos carte, fond d’écran, navigation (sauvegarde/chargement via EditorEscMenu / MapNavigationBar)  
**Fichiers clés** : `MapInfoPanel.qml`, `MapInfoDrawer.qml`, `MapNavigationBar.qml`

### `/qml/meowComponent/case/` - Affichage des Cases
**Rôle** : Composants visuels pour afficher les cases de jeu  
**Fichiers clés** : `CaseTile.qml`, `TileContent.qml`, `content/`, `details/`

---

## 9. Diagrammes de Flux

### 9.1 Création d'une Case

```
Utilisateur clique sur un type de case dans CaseSelectionPanel
   ↓
selectionPanel.caseTypeSelected = type
   ↓
logic.mouseLogic.changeMouseMode(EM_POSE)
   ↓
Loader charge MouseLogic_Pose
   ↓
Utilisateur clique sur la grille
   ↓
Editor.placeSelectedAsset(gridX, gridY)
   ↓
logic.tileLogic.createNewTileAtPosition(type, gridX, gridY, ItemSnapable.CaseTile)
   ↓
dynamicComponent.snapableCaseTileComponent.createObject(workArea, ...)
   ↓
Nouvel élément ajouté à snapableTilesList
   ↓
Component.onCompleted → snapToGrid()
   ↓
Case affichée sur la grille
```

### 9.2 Déplacement d'une Case

```
Utilisateur clique sur une case
   ↓
SnapableElement.dragArea.onPressed → elementPressed()
   ↓
mainMa.elementClicked(snapableElement)
   ↓
MouseLogic_Selection.elementClicked() → clickElement.push(tile)
   ↓
Utilisateur clique (sans drag)
   ↓
MouseLogic_Selection.clickedLeft()
   ↓
tile.parent = groupeSelection
   ↓
selectedElements.push(tile)
   ↓
Utilisateur drag
   ↓
mainMa.drag.target = groupeSelection
   ↓
Utilisateur relâche
   ↓
MouseLogic_Selection.release()
   ↓
tile.x += groupeSelection.x
tile.y += groupeSelection.y
   ↓
tile.parent = workArea
   ↓
tile.elementReleased() → snapToGrid()
   ↓
Case snappée à la nouvelle position
```

### 9.3 Sélection par Rectangle

```
Utilisateur clique sur zone vide
   ↓
MouseLogic_Selection.pressedLeft() (clickElement.length === 0)
   ↓
isRectangleSelecting = true
rectangleStart = mouse position
   ↓
selectionRect.show()
   ↓
Utilisateur drag
   ↓
mainMa.onPositionChanged → updateRectangleSelection()
   ↓
rectangleCurrent = mouse position
selectionRect.updateGeometry()
   ↓
getElementsInRectangle() → détecte les intersections
   ↓
selectElementsInRectangle() → sélectionne en temps réel
   ↓
Utilisateur relâche
   ↓
MouseLogic_Selection.release() → finalizeRectangleSelection()
   ↓
selectionRect.hide()
   ↓
Éléments dans le rectangle restent sélectionnés
```

### 9.4 Création d'un Lien

```
Utilisateur sélectionne une case
   ↓
updateCaseConfiguration() → connectionsConfigurationPanel.setTargetElement()
   ↓
Utilisateur clique "Connect Next" dans le panneau (BottomSidePanel / connectionConfigPanel)
   ↓
signal connectionRequested("next")
   ↓
logic.mouseLogic.changeMouseMode(EM_SELECTION_LINK)
logic.mouseLogic.kind = "next"
logic.mouseLogic.linkSourceCase = case
   ↓
Loader charge MouseLogic_Selection_link
   ↓
Utilisateur clique sur la case cible
   ↓
MouseLogic_Selection_link.clickedLeft()
   ↓
logic.tileLogic.createSnapableLink(source, target, "next")
   ↓
source.connectionManager / snapableParameters.addNext(target) (côté C++/QML)
   ↓
Connexion visuelle affichée (ConnectionOverlay via nextElementsSegments)
   ↓
Retour au mode EM_NORMAL
```

---

## 10. Points Techniques Avancés

### 10.1 Gestion du Z-Order

Chaque élément a deux composantes pour son ordre Z (dans **`snapableParameters.displayParameter`**) :
- **`zLayer`** : Couche logique, modifiable par l’utilisateur via les contrôles
- **`zOrder`** : Ordre dans la même couche
- **Bonus de sélection** : +11 quand sélectionné (et non en train d’être déplacé)

```qml
// SnapableElement.qml
z: (isSelected && !isDragging) ? snapableParameters.displayParameter.zOrder + 11 : snapableParameters.displayParameter.zOrder + snapableParameters.displayParameter.zLayer
```

### 10.2 Optimisation de la Grille

La grille utilise un seul `Repeater` pour toutes les lignes :
- **Avant** : 2 Repeater (vertical + horizontal) = double overhead
- **Après** : 1 Repeater avec logique conditionnelle = meilleure performance

```qml
Repeater {
    model: verticalLinesCount + horizontalLinesCount
    Rectangle {
        readonly property bool isVertical: index < verticalLinesCount
        // Position calculée selon le type
    }
}
```

### 10.3 Transparence des Clics

`SnapableElement` peut implémenter une logique pour ignorer les clics sur des zones transparentes (utile pour les PNG avec alpha), selon la configuration du projet.

### 10.4 Prévention du Vol de Drag

```qml
MouseArea {
    propagateComposedEvents: true
    preventStealing: true  // Empêche les parent MouseArea de voler les événements
}
```

Essentiel pour que les éléments enfants gardent le contrôle de leurs interactions.

### 10.5 Roster Joueurs (Player Config Panel)

Le **Player Config Panel** étend `MapInfo` avec la configuration des joueurs autorisés sur une carte. Plan complet : `doc/architecture/PLAYER_CONFIG_PANEL_PLAN.md`.

**Modèle de données (C++)** :

- `MapInfo` (cf. `cpp/game/map/mapinfo.{h,cpp}`) porte :
  - `int minPlayers` / `int maxPlayers` (placeholders 2/8, indicatifs — pas de check bloquant runtime).
  - `int playerConfigVersion` (courant : 1, monotone). `version > current` au load → roster wipé + warning.
  - `QQmlListProperty<PlayerProfile> playerProfiles` + helpers `addPlayerProfile`/`addPlayerProfileFromJson`/`updatePlayerProfile`/`removePlayerProfile`/`reorderPlayerProfile`/`duplicatePlayerProfile`/`playerProfileById`/`playerProfileAt`/`playerProfileCount`/`clearPlayerProfiles`.
- `PlayerProfile` (`cpp/game/map/playerprofile.{h,cpp}`) :
  - Identité : `id` (UUID stable, CONSTANT), `name`, `modelName` (dossier modèle 3D).
  - `pickMode` (`Unique` / `Shared` / `Mandatory`) + `minOccurrences` (utilisé seulement si `Mandatory`, clampé à `[1, MAX_PLAYERS_HARD_CAP]`).
  - Physique : `radius`, `mass`, `acceleration`, `maxSpeed`, `linearDamping`, `staticFriction`, `dynamicFriction`, `bounceFactor`.
  - Presets : `applyPreset("Standard"|"Léger"|"Lourd"|"Glissant"|"Adhérent")` (touche uniquement la physique, jamais `pickMode`/`minOccurrences`/`name`/`modelName`).
  - Sérialisation : `toJSON()` / `applyJson()` ; `pickMode` sérialisé en string (lisibilité human-diff), parsing tolérant string ou int.

**UI (QML)** :

- **Vue "Cartes" du `MapInfoDrawer`** : 2 SpinBox `minPlayers` / `maxPlayers` ajoutés au `GridLayout` (pattern `Game.updateMapMetadata(before, after)`).
- **5e onglet "Joueurs" du `AssetSelectionPanel`** : composants `PCP_*` dans `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/`.
  - `PCP_Content` : racine, tient `selectedProfileId`.
  - `PCP_ProfileRow` : Flickable horizontal des cards.
  - `PCP_ProfileCard` : preview 3D + nom inline-éditable (double-clic) + badge `pickMode` + overlay actions (Dupliquer / Supprimer) + boutons `←/→` pour réordonner (drag & drop reporté en v2).
  - `PCP_AddProfileCard` : "+" en queue de rangée → crée profil et le sélectionne.
  - `PCP_ProfileDetail` : panneau d'édition conditionnel (visible si une card sélectionnée).
  - `PCP_PickModeSelector`, `PCP_ModelPicker`, `PCP_PhysicsSimpleSection`, `PCP_PhysicsExpertSection`, `PCP_PresetButtons`, `PCP_Profile3DPreview`.
- **Convention de tailles** : aucun pixel fixe ; `Screen.pixelDensity * X` pour mm/cm ou proportions du parent.

**Catalogue de modèles** : `AssetManager::availablePlayerModels()` scanne `qrc:/asset/models/` + `<AppData>/models/`, filtre les dossiers contenant `<name>.qml`, dédupe par nom (priorité QRC).

**Op bus collab (ops 12-16)** : ajoutés à `EditorOpType` :

| ID | Op | Champs |
|---|---|---|
| 12 | `AddPlayerProfile` | `profile: {...}` complet |
| 13 | `RemovePlayerProfile` | `id` |
| 14 | `UpdatePlayerProfile` | `id`, `fields: {...}` partiel |
| 15 | `ReorderPlayerProfile` | `id`, `newIndex` |
| 16 | `SetMapPlayerLimits` | `minPlayers?`, `maxPlayers?` |

Helpers `EditorOpBus.make{Add,Remove,Update,Reorder}PlayerProfileOp` + `makeSetMapPlayerLimitsOp`. Apply remote dans `Editor.qml` (cases 12-16). Toutes les écritures `PCP_*` + le SpinBox du `MapInfoDrawer` passent par `EditorOpBus.submitOp(...)`. **Pas d'undo en v1** (les ops 12-16 utilisent `submitOp`, pas `submitOpWithUndo`).

> **Gotcha** : la borne `EditorProtocol::isEditorPacket` filtre par plage `EditorMessageType` (0x20+), pas par `EditorOpType`. Les ops 12-16 transitent via `EditorMessageType::Op` (0x23) déjà couvert — la borne **n'a pas** été modifiée par cette extension.

**Migration & fallback** :

- Toute `MapInfo` (default ctor ou JSON) garantit ≥ 1 profil via `ensureFallbackProfile()` (injecte un "Princess" si roster vide après chargement).
- Cas `playerConfigVersion > current` : roster wipé + Princess réinjecté + warning log.
- Cas JSON sans clé `playerProfiles` (ancienne map pré-Phase 1) : Princess auto-injecté au load, persisté au prochain save.

**Runtime (PR ultérieures, hors panel)** : choix profil par joueur en lobby pré-partie (respect `Unique`/`Shared`/`Mandatory`), peuplement `LocalPlayerSpawner.params`/`World3D.modelName` depuis le profil choisi.

---

## 11. Points d'Extension Future

### Ajouter un Nouveau Mode de Souris

1. Créer `editor/logic/MouseLogic_NewMode.qml` héritant de `MouseLogic_Base`
2. Ajouter l’enum dans `EditorEnum` (C++, ex. `cpp/tools/editorenum.h`)
3. Ajouter un `Component` dans `EditorDynamicComponent.qml` (ex. `mouseLogic_newMode_comp`) et l’alias correspondant
4. Modifier le `Loader` dans `EditorLogic.qml` :
   ```qml
   sourceComponent: (logic.editorMouseMode === EditorEnum.EM_NEW_MODE) ? editorDynamicComponent.mouseLogic_newMode_comp : ...
   ```

### Ajouter un Nouveau Type d'Élément Snapable

1. Créer `meowComponent/snapable/SnapableNewType.qml` héritant de `SnapableElement`
2. Ajouter un `Component` dans `editor/EditorDynamicComponent.qml`
3. Ajouter la logique de création dans `editor/logic/TileLogic.qml` (createObject avec le bon component)

### Ajouter une Nouvelle Catégorie dans le Panneau

1. Créer le panel dans `editor/panel/bottomPanel/bottomMainPanel/newCategoryPanel/` (ou l’intégrer dans le panneau latéral `bottomSidePanel/`)
2. Si panneau principal : ajouter dans le `StackLayout` de `SelectionPanel.qml` et un onglet dans `MenuSelector.qml`
3. Si panneau latéral : l’ajouter dans `BottomSidePanel_Content.qml` (ou équivalent)

---

## 12. Conclusion

L'éditeur de Meownopoly est un système bien architecturé qui utilise :

✅ **Modularité** : Logique séparée en fichiers distincts  
✅ **Réactivité** : Bindings QML automatiques  
✅ **Extensibilité** : Patterns Factory et State Machine  
✅ **Performance** : Grille optimisée, calculs minimaux  
✅ **Flexibilité** : Zoom sans perte, snapping configurable  

**Points forts** :
- Architecture claire avec responsabilités bien définies
- Système de coordonnées intelligent (grille + pixels)
- Gestion robuste des connexions bidirectionnelles
- Interface utilisateur riche et paramétrable

**Points d'amélioration potentiels** :
- Documentation inline pourrait être plus détaillée
- Certains calculs de connexions pourraient être optimisés pour de très grandes cartes
- Tests unitaires pour les fonctions de snapping et de sélection

---

**Auteur de l'analyse** : Assistant IA  
**Date** : 12 octobre 2025  
**Dernière révision** : 25 février 2026 — Vérification de l’architecture : chemins (`meowComponent/`, `editor/panel/bottomPanel/`), noms (`snapableParameters.displayParameter`, `ConnectionsConfigurationSection`, `BottomSidePanel`), modes souris (EM_GAME, EM_DRAW_POLYGON, EM_TEMPLATE), MapInfoPanel, EditorController, Trackers.  
**Version** : 1.1

