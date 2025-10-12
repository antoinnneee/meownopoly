# Analyse Complète de l'Architecture de l'Éditeur Meownopoly

## Vue d'Ensemble

L'éditeur de Meownopoly est un éditeur de cartes sophistiqué construit en QML/Qt qui permet de créer et modifier des plateaux de jeu avec un système de grille, de snapable elements (accrochage), de zoom, de connexions entre cases, et de sélection par rectangle.

---

## 1. Structure des Dossiers QML

### `/qml/editor/` - Dossier Principal de l'Éditeur

#### **Fichiers Racine**
- **`Editor.qml`** : Point d'entrée principal de l'éditeur
  - Gère le layout global (grille, zone de travail, panneaux)
  - Contient le `MouseArea` principal (`mainMa`) qui capture tous les événements souris
  - Coordonne tous les sous-composants
  - Gère les raccourcis clavier (Delete, Escape)

- **`EditorLogic.qml`** : Cerveau de l'éditeur
  - Centralise toute la logique métier
  - Charge dynamiquement les différents modes de souris via `Loader`
  - Contient les références aux listes d'éléments snapables
  - Gère la sélection par rectangle

- **`EditorDynamicComponent.qml`** : Fabrique d'éléments
  - Contient les `Component` pour créer dynamiquement :
    - `SnapableCaseTile` (cases de jeu)
    - `SnapableDecoration` (décorations)
  - Gère les événements de suppression et configuration

- **`Editor_WheelHandler.qml`** : Gestionnaire de molette
  - Capture les événements de la molette de la souris
  - Délègue au `ScrollLogic` approprié

- **`Background.qml`** : Image de fond
  - Affiche l'image de fond de la carte
  - Gère différents modes d'affichage (Stretch, Fit, Tile)

- **`MenuMapAtStart.qml`** : Menu de démarrage
  - Permet de créer/charger une carte au lancement

#### **Sous-dossier `/qml/editor/logic/`** - Logique Métier

**Architecture Modulaire basée sur des États**

Le système utilise un pattern "State Machine" où la logique de la souris et du scroll change selon le mode actif :

**Logique de la Souris** (3 modes) :
- **`MouseLogic_Base.qml`** : Classe de base abstraite
  - Définit l'interface commune pour tous les modes
  - Gère la sélection d'éléments (`selectedElements`)
  - Méthodes : `pressedLeft()`, `clickedLeft()`, `release()`, etc.
  - Gère la configuration des cases dans le panneau

- **`MouseLogic_Selection.qml`** : Mode NORMAL (sélection/déplacement)
  - Gestion de la sélection d'éléments
  - Déplacement d'éléments par drag & drop
  - **Sélection par rectangle** (voir section dédiée)
  - Support de la multi-sélection avec Ctrl
  - Utilise un `groupeSelection` pour déplacer plusieurs éléments ensemble

- **`MouseLogic_Pose.qml`** : Mode POSE (placement d'éléments)
  - Permet de placer des assets/cases sur la grille
  - Désactive certaines interactions de sélection

- **`MouseLogic_Selection_link.qml`** : Mode SELECTION_LINK (création de connexions)
  - Mode spécial pour créer des liens entre cases
  - Attend un clic sur la case cible pour créer la connexion
  - Utilise `linkSourceCase` et `kind` (previous/next)

**Logique de Scroll** (2 modes) :
- **`ScrollLogic.qml`** : Scroll normal
  - Ctrl + Molette = Zoom (change `mmSize`)

- **`ScrollLogic_POSE.qml`** : Scroll en mode pose
  - Comportement adapté au placement d'éléments

**Logique des Tuiles** :
- **`TileLogic.qml`** : Gestion centralisée des éléments
  - Création de nouveaux éléments (`createNewTileAtPosition()`)
  - Suppression d'éléments (`deleteElement()`)
  - Gestion des connexions entre cases
  - Désélection globale
  - Maintient l'ordre Z (`currentZOrder`)

**Logique de Plan** :
- **`PlanLogic.qml`** : Gestion des plans/calques Z
  - Gère les niveaux de profondeur (z-layers)

#### **Sous-dossier `/qml/editor/tools/`** - Outils de l'Éditeur

**Grille et Snapping** :
- **`GridManager.qml`** : ⭐ Composant central de la grille
  - Dessine la grille avec un `Repeater` optimisé
  - Calcule les positions de snap
  - Fonctions clés :
    - `snapToGridCoord(value)` : Arrondit une coordonnée à la grille
    - `getGridPosition(x, y)` : Convertit pixels → coordonnées grille
    - `snapElement2(element)` : Positionne un élément sur la grille
  - Propriétés dynamiques :
    - `gridSize` = `Screen.pixelDensity * mmSize` (taille d'une cellule en pixels)
    - `boardSize` = `gridSize * 600` (grille de 600×600)
  - Mode redimensionnement visuel (`resizeMode`)

- **`SelectionRect.qml`** : Rectangle de sélection
  - Rectangle visuel bleu semi-transparent
  - Fonctions :
    - `show()/hide()` : Afficher/masquer
    - `updateGeometry()` : Mise à jour des dimensions
    - `updateGeometryFromGrid()` : Version avec coordonnées grille

**Éléments Snapables** (sous-dossier `tools/snapable/`) :
- **`SnapableElement.qml`** : ⭐ Classe de base pour tous les éléments
  - Rectangle qui se positionne automatiquement sur la grille
  - **Système de coordonnées** :
    - `displaySettings.gridRelativePositionX/Y` : Position en unités de grille (0, 1, 2, ...)
    - `x/y` : Position en pixels (calculée automatiquement = gridPos × gridSize)
    - `width/height` : Taille en pixels (= unitSize × gridSize)
  - **Auto-snapping** :
    - À la création (`Component.onCompleted`)
    - Après un drag (`onElementReleased`)
  - **Gestion du Z** :
    - `z = zOrder + zLayer` (normal)
    - `z = zOrder + zLayer + 11` (si sélectionné)
  - Contient :
    - `SnapableElementControl` : Boutons de contrôle
    - `SnapableElementResizeHandles` : Poignées de redimensionnement
    - `SnapableElementConnections` : Gestionnaire de connexions

- **`SnapableElementConnections.qml`** : Gestionnaire de connexions entre éléments
  - Maintient deux listes : `previousElements[]` et `nextElements[]`
  - Dessine les connexions visuelles avec `ConnectionOverlay`
  - Fonctions bidirectionnelles (ajouter un lien met à jour les deux éléments)

- **`SnapableElementControl.qml`** : Boutons de contrôle d'un élément
  - Boutons pour : supprimer, changer de plan, configurer

- **`SnapableElementResizeHandles.qml`** : Poignées de redimensionnement
  - 8 poignées aux coins et bords
  - Redimensionnement en unités de grille

- **`SnapableElementDeleteAnimation.qml`** : Animation de suppression
- **`SnapableElementCreateAnimation.qml`** : Animation de création

**Éléments Concrets** (héritent de SnapableElement) :
- **`SnapableCaseTile.qml`** : Case de jeu (Kibble Dispenser, Cat Door, etc.)
  - Contient un `caseData` (logique C++)
  - Affiche le contenu de la case avec `TileContent.qml`

- **`SnapableDecoration.qml`** : Élément décoratif
  - Contient un `decorationSettings`
  - Affiche une image de décoration

**Autres Outils** :
- **`AssetPreviewCursor.qml`** : Aperçu de l'asset sous le curseur en mode POSE
- **`ConnectionOverlay.qml`** : Ligne de connexion visuelle entre deux éléments
- **`LoadMapButton.qml`** : Bouton pour charger une carte

#### **Sous-dossier `/qml/editor/panel/`** - Panneaux d'Interface

**Panneau Principal** :
- **`SelectionPanel.qml`** : Panneau inférieur multi-onglets
  - Contient un `StackLayout` avec 3 panneaux :
    1. `AssetSelectionPanel` : Sélection d'assets (décorations)
    2. `CaseSelectionPanel` : Sélection de cases
    3. `MapSelectionPanel` : Paramètres de la carte
  - **Redimensionnable** : Zone de drag en haut pour ajuster la hauteur
  - Propage les signaux : `assetSelected`, `connectionRequested`, `effectChanged`

**Panneaux Enfants** :
- **`assetSelectionPanel/`** : Sélection d'assets avec effets visuels
  - `AssetSelectionPanel.qml` : Gestionnaire principal
  - `ASP_CategoryGrid.qml` : Grille de catégories
  - `ASP_ContentArea.qml` : Zone de contenu
  - `VisualEffectsPanel.qml` : Effets visuels (rotation, miroir, couleur, etc.)

- **`caseSelectionPanel/`** : Sélection et configuration des cases
  - `CaseSelectionPanel.qml` : Gestionnaire principal
  - `CSP_CaseTypeSelector.qml` : Sélecteur de type de case
  - `CaseConfigurationPanelSection.qml` : Configuration détaillée d'une case
  - `ConnectionsConfigurationSection.qml` : ⭐ Gestion des connexions
  - Configuration spécifique par type de case (CCPS_*.qml)

- **`mapSelectionPanel/`** : Paramètres de la carte
  - Background, sauvegarde/chargement, paramètres généraux

- **`InfoPanel.qml`** : Panneau d'informations (coins supérieur)

#### **Sous-dossier `/qml/case/`** - Affichage des Cases

- **`CaseTile.qml`** : Composant d'affichage d'une case
- **`TileContent.qml`** : Contenu visuel d'une case
- **`TileDetailsPopup.qml`** : Popup de détails
- **`content/`** : Contenus spécifiques par type de case
- **`details/`** : Détails spécifiques par type de case

---

## 2. Fonctionnement de la Grille

### 2.1 Génération de la Grille

La grille est générée par **`GridManager.qml`** :

```qml
// Taille dynamique basée sur la densité de pixels de l'écran
property int mmSize: logic.mmSize  // Taille en millimètres (défaut: 10mm)
property int gridSize: Screen.pixelDensity * mmSize  // Pixels par cellule

property int boardSize: gridSize * 600  // Grille de 600×600 cellules
width: boardSize
height: boardSize
```

**Rendu de la grille** :
- Utilise un seul `Repeater` optimisé qui crée des lignes verticales et horizontales
- Nombre de lignes calculé dynamiquement : `Math.ceil(width / gridSize) + 1`
- Lignes verticales et horizontales dans le même modèle pour optimisation

```qml
Repeater {
    model: verticalLinesCount + horizontalLinesCount
    Rectangle {
        readonly property bool isVertical: index < verticalLinesCount
        x: isVertical ? index * gridSize : 0
        y: isVertical ? 0 : (index - verticalLinesCount) * gridSize
        width: isVertical ? lineWidth : parent.width
        height: isVertical ? parent.height : lineWidth
    }
}
```

### 2.2 Système de Coordonnées

**Deux systèmes coexistent** :

1. **Coordonnées de grille** (logiques) : `gridRelativePositionX/Y`
   - Entiers : 0, 1, 2, 3, ...
   - Stockées dans `DisplayParameter`

2. **Coordonnées pixel** (visuelles) : `x/y`
   - Calculées automatiquement : `x = gridRelativePositionX * gridSize`
   - Bindées dans `SnapableElement.qml`

**Conversion** :
```javascript
// Pixel → Grille
function getGridPosition(x, y) {
    return Qt.point(
        Math.floor(x / gridSize),
        Math.floor(y / gridSize)
    )
}

// Snap à la grille
function snapToGridCoord(value) {
    return Math.round(value / gridSize) * gridSize
}
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

```javascript
function snapToGrid() {
    if (!gridManager || !gridManager.snapToGrid) return
    
    // Calculer les positions snappées
    var snappedGridX = Math.round(x / gridManager.gridSize)
    var snappedGridY = Math.round(y / gridManager.gridSize)
    
    // Mettre à jour les positions relatives (qui vont automatiquement mettre à jour x et y)
    displaySettings.gridRelativePositionX = snappedGridX
    displaySettings.gridRelativePositionY = snappedGridY
    
    gridManager.snapElement2(snapableElement)
}
```

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

**Via la molette** (`ScrollLogic.qml`) :
```javascript
function scrollUp(wheel) {
    if (wheel.modifiers & Qt.ControlModifier) {
        logic.updateSize(logic.mmSize + 1)  // Zoom in
    }
}

function scrollDown(wheel) {
    if (wheel.modifiers & Qt.ControlModifier) {
        logic.updateSize(logic.mmSize - 1)  // Zoom out
    }
}
```

**Effet cascade** :
1. `mmSize` change
2. `gridSize` est recalculé (binding automatique)
3. Tous les éléments snapables repositionnent et redimensionnent automatiquement car leurs `x/y/width/height` sont bindés à `gridSize`

### 4.3 Avantages de cette Approche

✅ **Pas de perte de qualité** : Les éléments sont re-rendus à la nouvelle taille, pas juste étirés  
✅ **Précision** : Les coordonnées de grille restent exactes  
✅ **Performance** : Un seul calcul pour tous les éléments (bindings QML)  
✅ **Simplicité** : Pas besoin de gérer des transformations complexes

---

## 5. Gestion des Liens entre Cases

### 5.1 Architecture

Chaque élément snapable contient un **`SnapableElementConnections`** qui gère :
- `previousElements[]` : Liste des éléments précédents (flux de jeu)
- `nextElements[]` : Liste des éléments suivants

**Bidirectionnalité automatique** :
```javascript
function addNextElement(element) {
    nextElements.push(element)
    // Ajoute automatiquement le lien inverse
    if (!element.previousElements.includes(parentElement)) {
        element.previousElements.push(parentElement)
    }
}
```

### 5.2 Affichage Visuel

Les connexions sont affichées par un `Repeater` dans `SnapableElementConnections.qml` :

```qml
ListModel { id: nextElementsSegments }

Repeater {
    model: nextElementsSegments
    delegate: ConnectionOverlay {
        fromElement: model.fromElement
        toElement: model.toElement
    }
}
```

`ConnectionOverlay.qml` dessine une ligne entre les centres des deux éléments.

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

3. **Attente du clic** :
   - `MouseLogic_Selection_link` est actif
   - Utilisateur clique sur la case cible

4. **Création du lien** :
   ```javascript
   logic.tileLogic.createSnapableLink(linkSourceCase, targetCase, kind)
   ```

5. **Retour au mode normal** :
   ```javascript
   changeMouseMode(EditorEnum.EM_NORMAL)
   ```

### 5.4 Synchronisation avec le Backend C++

Les connexions sont également stockées dans l'objet `Case` C++ :
- `Case::getNextList()` : Retourne la liste des cases suivantes
- Lors du chargement d'une carte : `TileLogic::builtConnections()` reconstruit les connexions visuelles

---

## 6. Fonction de Sélection par Rectangle

### 6.1 Composants Impliqués

1. **`SelectionRect.qml`** : Rectangle visuel bleu
2. **`MouseLogic_Selection.qml`** : Logique de détection
3. **`Editor.qml`** : Capture des mouvements de souris

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
Loader → charge le MouseLogic correspondant
   ↓
   ├─ EM_NORMAL → MouseLogic_Selection
   ├─ EM_POSE → MouseLogic_Pose
   └─ EM_SELECTION_LINK → MouseLogic_Selection_link
```

**Avantages** :
- Séparation claire des comportements
- Pas de gros `if/else` dans le code
- Extension facile (ajouter un nouveau mode = nouveau fichier)

### 7.2 Pattern "Factory" pour la Création d'Éléments

`EditorDynamicComponent` contient des `Component` QML qui sont instanciés à la demande :

```javascript
// TileLogic.qml
var newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
    "displaySettings.gridRelativePositionX": gridX,
    "displaySettings.gridRelativePositionY": gridY,
    // ...
})
```

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
// SnapableElement.qml
x: displaySettings.gridRelativePositionX * gridManager.gridSize
width: gridManager.gridSize * displaySettings.unitSizeWidth
```

Changer `gridRelativePositionX` ou `gridSize` met à jour `x` automatiquement.

---

## 8. Résumé des Sous-Dossiers

### `/qml/editor/` - Éditeur Principal
**Rôle** : Point d'entrée et coordination générale  
**Fichiers clés** : `Editor.qml`, `EditorLogic.qml`

### `/qml/editor/logic/` - Logique Métier
**Rôle** : Gestion des modes, souris, scroll, tuiles  
**Pattern** : State Machine avec Loaders  
**Fichiers clés** : `MouseLogic_*.qml`, `TileLogic.qml`, `ScrollLogic.qml`

### `/qml/editor/tools/` - Outils et Composants Réutilisables
**Rôle** : Grille, rectangle de sélection, éléments snapables  
**Fichiers clés** : `GridManager.qml`, `SelectionRect.qml`

### `/qml/editor/tools/snapable/` - Système Snapable
**Rôle** : Classe de base et comportements des éléments accrochables  
**Fichiers clés** : `SnapableElement.qml`, `SnapableElementConnections.qml`

### `/qml/editor/panel/` - Interface Utilisateur
**Rôle** : Panneaux de sélection et configuration  
**Fichiers clés** : `SelectionPanel.qml`

### `/qml/editor/panel/assetSelectionPanel/` - Sélection d'Assets
**Rôle** : Choisir des décorations, appliquer des effets visuels  
**Fichiers clés** : `AssetSelectionPanel.qml`, `VisualEffectsPanel.qml`

### `/qml/editor/panel/caseSelectionPanel/` - Sélection de Cases
**Rôle** : Choisir des types de cases, configurer les propriétés, gérer les connexions  
**Fichiers clés** : `CaseSelectionPanel.qml`, `CaseConfigurationPanelSection.qml`, `ConnectionsConfigurationSection.qml`

### `/qml/editor/panel/mapSelectionPanel/` - Paramètres de Carte
**Rôle** : Background, sauvegarde/chargement  
**Fichiers clés** : `MapSelectionPanel.qml`

### `/qml/case/` - Affichage des Cases
**Rôle** : Composants visuels pour afficher les cases de jeu  
**Fichiers clés** : `CaseTile.qml`, `TileContent.qml`

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
editorDynamicComponent.snapableCaseTileComponent.createObject(...)
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
updateCaseConfiguration() → connectionsPanel.setTargetElement()
   ↓
Utilisateur clique "Connect Next" dans le panneau
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
source.connectionManager.addNextElement(target)
   ↓
Connexion visuelle affichée (ConnectionOverlay)
   ↓
Retour au mode EM_NORMAL
```

---

## 10. Points Techniques Avancés

### 10.1 Gestion du Z-Order

Chaque élément a deux composantes pour son ordre Z :
- **`zLayer`** : Couche logique (0-10), modifiable par l'utilisateur via les contrôles
- **`zOrder`** : Ordre microscopique (0.00001 incréments), détermine l'ordre dans la même couche
- **Bonus de sélection** : +11 quand sélectionné

```qml
z: (isSelected) ? displaySettings.zOrder + 11 : displaySettings.zOrder + displaySettings.zLayer
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

`SnapableElement` peut implémenter `isTransparent(mouse)` pour ignorer les clics sur des zones transparentes (utile pour les PNG avec alpha).

### 10.4 Prévention du Vol de Drag

```qml
MouseArea {
    propagateComposedEvents: true
    preventStealing: true  // Empêche les parent MouseArea de voler les événements
}
```

Essentiel pour que les éléments enfants gardent le contrôle de leurs interactions.

---

## 11. Points d'Extension Future

### Ajouter un Nouveau Mode de Souris

1. Créer `MouseLogic_NewMode.qml` héritant de `MouseLogic_Base`
2. Ajouter l'enum dans `EditorEnum` (fichier C++)
3. Modifier le `Loader` dans `EditorLogic.qml` :
   ```qml
   sourceComponent: (logic.editorMouseMode == EditorEnum.EM_NEW_MODE) ? newModeComponent : ...
   ```

### Ajouter un Nouveau Type d'Élément Snapable

1. Créer `SnapableNewType.qml` héritant de `SnapableElement`
2. Ajouter un `Component` dans `EditorDynamicComponent.qml`
3. Ajouter la logique de création dans `TileLogic.qml`

### Ajouter une Nouvelle Catégorie dans le Panneau

1. Créer le panel dans `/panel/newCategoryPanel/`
2. Ajouter dans le `StackLayout` de `SelectionPanel.qml`
3. Ajouter un bouton dans `MenuSelector.qml`

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
**Version** : 1.0

