# 📊 Diagrammes Architecture Éditeur Meownopoly

## 🏗️ Architecture Globale

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                  Editor.qml                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                            Base_Board (Base)                            │  │
│  │  ┌──────────────────────────────────┐  ┌─────────────────────────────┐  │  │
│  │  │       GridManager (Grille)       │  │      GlobalMa (Souris)      │  │  │
│  │  └──────────────────────────────────┘  └─────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌───────────────────────────────┐        ┌────────────────────────────────┐  │
│  │  Base_WorkArea (Zone Travail) │        │       Panneaux Latéraux        │  │
│  │  ┌─────────────────────────┐  │        │  ┌────────────┐┌────────────┐  │  │
│  │  │     World3D (Phase 4)   │  │        │  │MapInfoPanel││BottomSidePanel│ │  │
│  │  │  ┌───────────────────┐  │  │        │  │ (Informations)│(Configuration) │  │
│  │  │  │  Moteur 3D (3D)   │  │  │        │  └────────────┘└────────────┘  │  │
│  │  │  └───────────────────┘  │  │        └────────────────────────────────┘  │
│  │  │                         │  │                                            │
│  │  │  ┌───────────────────┐  │  │        ┌────────────────────────────────┐  │
│  │  │  │ SnapableElements  │  │  │        │       EditorLogic (Logic)      │  │
│  │  │  │ (Cases, Déco...)  │  │  │        │  ┌────────────┐┌────────────┐  │  │
│  │  │  └───────────────────┘  │  │        │  │ MouseLogic ││ TileLogic   │  │  │
│  │  └─────────────────────────┘  │        │  │ (Loader)   ││ PlanLogic   │  │  │
│  └───────────────────────────────┘        │  └────────────┘└────────────┘  │  │
│                                           └────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                       SelectionPanel (Panneau Bas)                      │  │
│  │  ┌─────────────────┐                                                     │  │
│  │  │ AssetSelection  │  ← unique enfant du StackLayout                    │  │
│  │  └─────────────────┘                                                     │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔲 Système de Grille

### Génération et Rendu

```
GridManager
    │
    ├─ gridSize = Screen.pixelDensity × mmSize
    │       │
    │       ├─ mmSize = 12.0 (défaut, real)
    │       └─ Ctrl+Molette → mmSize ×1.1 / ÷1.1 (ZOOM multiplicatif centré sous curseur)
    │
    ├─ boardSize = gridSize × 600
    │
    └─ Repeater (lignes verticales + horizontales)
           │
           ├─ 0 ... verticalLinesCount     → lignes verticales
           └─ verticalLinesCount ... total → lignes horizontales

┌─────┬─────┬─────┬─────┐
│     │     │     │     │
│  0  │  1  │  2  │  3  │  ← Coordonnées grille
├─────┼─────┼─────┼─────┤
│     │     │     │     │
│  0  │gridSize   │     │  ← gridSize = taille cellule en pixels
└─────┴─────┴─────┴─────┘
  ↑
  gridSize
```

### Conversion Coordonnées

```
PIXEL → GRILLE
    getGridPosition(150px, 200px)
    → (Math.floor(150/gridSize), Math.floor(200/gridSize))
    → (3, 4)

GRILLE → PIXEL
    x = gridRelativePositionX × gridSize
    y = gridRelativePositionY × gridSize
    3 × 50px = 150px
    4 × 50px = 200px

SNAP
    snapToGridCoord(147px)
    → Math.round(147/50) × 50
    → 3 × 50 = 150px
```

---

## 📌 Système Snapable

### Hiérarchie de Classes

```
SnapableElement.qml (BASE)
    │
    ├─ snapableParameters: ItemSnapable
    │   └─ displayParameter (accès via snapableParameters.displayParameter.*)
    │       ├─ gridRelativePositionX
    │       ├─ gridRelativePositionY
    │       ├─ unitSizeWidth
    │       ├─ unitSizeHeight
    │       ├─ zLayer
    │       └─ zOrder
    │
    ├─ connectionManager: SnapableElementConnections
    │   ├─ previousElements[]
    │   ├─ nextElements[]
    │   └─ ConnectionOverlay (lignes visuelles)
    │
    ├─ SnapableElementControl (LayerVisualizer unique)
    │   └─ Contrôle de plan / z-layer
    │       └─ signal layerChanged(int)
    │
    └─ SnapableElementResizeHandles (poignées)
        ├─ TopLeft, Top, TopRight
        ├─ Left, Right
        └─ BottomLeft, Bottom, BottomRight

        ↓ Hérite de ↓

┌─────────────────────┬─────────────────────┐
│  SnapableCaseTile   │  SnapableDecoration │
│  (Cases de jeu)     │  (Décorations)      │
│                     │                     │
│  + caseData (C++)   │  + decorationParameter│
│  + TileContent.qml  │  (résolution asset  │
│                     │   via AssetManager) │
│                     │  + AnimatedImage    │
└─────────────────────┴─────────────────────┘
```

### Bindings Automatiques

```
┌────────────────────────────────────────────┐
│         SnapableElement.qml                │
├────────────────────────────────────────────┤
│  x: gridRelativePositionX × gridSize       │ ← Binding auto
│  y: gridRelativePositionY × gridSize       │ ← Binding auto
│  width: unitSizeWidth × gridSize           │ ← Binding auto
│  height: unitSizeHeight × gridSize         │ ← Binding auto
│  z: (isSelected && !isDragging)            │ ← Binding auto
│       ? zOrder + 11 : zOrder + zLayer      │
└────────────────────────────────────────────┘

Changer gridRelativePositionX ou gridSize
    ↓
x est AUTOMATIQUEMENT recalculé par QML
    ↓
Élément se déplace visuellement
```

---

## 🖱️ Modes de Souris (State Machine)

```
EditorLogic.editorMouseMode
         │
         ├─────────────┬──────────────┬─────────────────┐
         │             │              │                 │
         ▼             ▼              ▼                 ▼
     EM_NORMAL     EM_POSE      EM_SELECTION_LINK      EM_GAME
          │             │              │                 EM_DRAW_POLYGON
          │             │              │                 EM_TEMPLATE
          ▼             ▼              ▼                         ▼
  Loader dynamique charge le bon MouseLogic
         │             │              │
         ▼             ▼              ▼
┌────────────────┐ ┌───────────┐ ┌─────────────────┐ ┌─────────────────┐
│ MouseLogic_    │ │MouseLogic_│ │ MouseLogic_     │ │ MouseLogic_     │
│ Selection      │ │  Pose     │ │ Selection_link  │ │ Game/Zone/Temp  │
├────────────────┤ ├───────────┤ ├─────────────────┤ ├─────────────────┤
│• Sélection     │ │• Place    │ │• Attend clic    │ │• Test gameplay  │
│• Déplacement   │ │  assets   │ │  sur cible      │ │• Dessin Polygone│
│• Rectangle     │ │• Aperçu   │ │• Crée connexion │ │• Multi-zones    │
│• Multi-sél     │ │  curseur  │ │• Retour NORMAL  │ │• Templates      │
└────────────────┘ └───────────┘ └─────────────────┘ └─────────────────┘

Changer de mode :
    logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
         ↓
    Loader détruit ancien MouseLogic
         ↓
    Loader crée nouveau MouseLogic
         ↓
    Comportements changent automatiquement
```

---

## 🔍 Zoom (Redimensionnement Grille)

### Mécanisme

```
Utilisateur : Ctrl + Molette Haut
         ↓
ScrollLogic.scrollUp(wheel) → scrollGrid(wheel, 1)
         ↓
newMmSize = oldMmSize × 1.1  (zoomFactor)
   (zoom arrière = oldMmSize ÷ 1.1)
         ↓
mmSize est un real (défaut 12.0)
         ↓
gridSize recalculé (binding)
         ↓
gridSize = Screen.pixelDensity × mmSize
         ↓
Tous les éléments repositionnés/redimensionnés (bindings)
ScrollLogic ajuste x/y pour maintenir le point sous la souris

AVANT (mmSize=12.0, gridSize=60px) :
┌──────┬──────┬──────┐
│      │      │      │
│  60px│      │      │
│      │      │      │
└──────┴──────┴──────┘

APRÈS un cran (mmSize=13.2 = 12.0×1.1, gridSize=66px) :
┌───────┬───────┬───────┐
│       │       │       │
│  66px │       │       │
│       │       │       │
└───────┴───────┴───────┘
```

### Effet Cascade

```
         mmSize change
              ↓
      gridSize recalculé
              ↓
     ┌────────┴────────┐
     ▼                 ▼
  Grille           Éléments
  redraw           repositionnés
     │                 │
     ├─ Lignes         ├─ x recalculé
     │  repositionnées │ 
     │                 ├─ y recalculé
     └─ Espacement     │
        changé         ├─ width recalculé
                       │
                       └─ height recalculé
```

---

## 📐 Sélection par Rectangle

### Phase 1 : Début

```
Clic sur zone vide (pas d'élément)
    ↓
MouseLogic_Selection.pressedLeft()
    │
    ├─ clickElement.length === 0 ?  OUI
    │       ↓
    │   isRectangleSelecting = true
    │   rectangleStart = (mouseX, mouseY)
    │   selectionRect.show()
    │   drag.target = null  (empêche drag de la grille)
    │
    └─ clickElement.length > 0 ?  NON
            (si élément cliqué, mode déplacement normal)
```

### Phase 2 : Drag

```
Utilisateur déplace la souris
    ↓
Editor.mainMa.onPositionChanged()
    ↓
logic.mouseLogic.updateRectangleSelection(x, y)
    ↓
┌────────────────────────────────────────┐
│ 1. rectangleCurrent = (x, y)           │
│ 2. selectionRect.updateGeometry()      │
│      → Redessine rectangle visuel      │
│ 3. getElementsInRectangle()            │
│      → Test AABB pour chaque élément   │
│ 4. selectElementsInRectangle()         │
│      → Sélectionne en TEMPS RÉEL       │
└────────────────────────────────────────┘

Visuel :
┌─────────────────────────────┐
│         Grille               │
│                              │
│   ┏━━━━━━━━━━━━━━━┓         │
│   ┃   [Case1]     ┃ ← Rectangle sélection
│   ┃       [Case2] ┃         │
│   ┗━━━━━━━━━━━━━━━┛         │
│                              │
└─────────────────────────────┘
        ↑
    Bleu semi-transparent
```

### Phase 3 : Test d'Intersection AABB

```
Pour chaque élément de snapableTilesList :

    ┌─────────────────────────────┐
    │        Rectangle             │
    │  rectLeft     rectRight      │
    │     ↓           ↓            │
    │     ┏━━━━━━━━━━┓ ← rectTop   │
    │     ┃          ┃             │
    │     ┗━━━━━━━━━━┛ ← rectBottom│
    └─────────────────────────────┘

    ┌─────────────────────────────┐
    │        Élément               │
    │  elementLeft   elementRight  │
    │     ↓           ↓            │
    │     ┌──────────┐ ← elementTop│
    │     │ [Case]   │             │
    │     └──────────┘ ← elementBottom
    └─────────────────────────────┘

    Intersection = !(
        elementRight < rectLeft    ||  // Complètement à gauche
        elementLeft > rectRight    ||  // Complètement à droite
        elementBottom < rectTop    ||  // Complètement au-dessus
        elementTop > rectBottom        // Complètement en-dessous
    )

    Si intersection → elements.push(élément)
```

### Phase 4 : Finalisation

```
Utilisateur relâche souris
    ↓
MouseLogic_Selection.release()
    ↓
finalizeRectangleSelection()
    │
    ├─ Récupère éléments dans rectangle
    ├─ Désélectionne anciens
    ├─ Sélectionne nouveaux
    │   ├─ element.parent = groupeSelection
    │   └─ selectedElements.push(element)
    │
    ├─ updateCaseConfiguration()
    │   └─ Si 1 seul élément → affiche panneau config
    │
    ├─ isRectangleSelecting = false
    └─ selectionRect.hide()
```

---

## 🔗 Connexions entre Cases

### Structure de Données

```
SnapableElementConnections
    │
    ├─ previousElements: []
    │       ↓
    │   [Case A, Case B, ...]  ← Cases qui mènent à cet élément
    │
    └─ nextElements: []
            ↓
        [Case X, Case Y, ...]  ← Cases accessibles depuis cet élément

Exemple :
    Case Start
        ↓ next
    Case Middle  ← previous (Start)
        ↓ next
    Case End     ← previous (Middle)
```

### Bidirectionnalité Automatique

```
Appel :
    caseA.addNextElement(caseB)

Effet automatique :
    caseA.nextElements.push(caseB)
          ↓
    caseB.previousElements.push(caseA)

┌──────────┐              ┌──────────┐
│  Case A  │─────next────→│  Case B  │
│          │←──previous───│          │
└──────────┘              └──────────┘
```

### Affichage Visuel

```
nextElementsSegments (ListModel)
    │
    ├─ Segment 1: { fromElement: caseA, toElement: caseB }
    ├─ Segment 2: { fromElement: caseA, toElement: caseC }
    └─ ...
         ↓
    Repeater
         ↓
    ConnectionOverlay (pour chaque segment)
         ↓
    Shape avec ligne SVG

Visuel :
    [Case A] ───────→ [Case B]
        │
        └───────────→ [Case C]
```

### Flux de Création d'un Lien

```
1. Utilisateur sélectionne Case A
        ↓
2. Panneau ConnectionsConfigurationSection
        ↓
   [Connect Next ▶]  ← Utilisateur clique
        ↓
3. signal connectionRequested("next")
        ↓
4. logic.mouseLogic.changeMouseMode(EM_SELECTION_LINK)
   logic.mouseLogic.kind = "next"
   logic.mouseLogic.linkSourceCase = Case A
        ↓
5. Loader charge MouseLogic_Selection_link
        ↓
6. Utilisateur clique sur Case B
        ↓
7. MouseLogic_Selection_link.clickedLeft()
        ↓
8. logic.tileLogic.createSnapableLink(Case A, Case B, "next")
        ↓
9. Case A.connectionManager.addNextElement(Case B)
   Case B.connectionManager.addPreviousElement(Case A) [auto]
        ↓
10. ConnectionOverlay créé (ligne visuelle)
        ↓
11. Retour mode EM_NORMAL

Résultat :
    [Case A] ───────→ [Case B]
```

---

## 🎭 Cycle de Vie d'un Élément

### Création

```
1. Utilisateur clique type de case "Kibble Dispenser"
        ↓
2. caseTypeSelected = CS_KibbleDispenser
        ↓
3. Mode change → EM_POSE
        ↓
4. Aperçu sous curseur (AssetPreviewCursor)
        ↓
5. Utilisateur clique sur grille (x=200px, y=300px)
        ↓
6. getGridPosition(200, 300) → (gridX=4, gridY=6)
        ↓
7. TileLogic.placeSelectedAsset(gridX, gridY)
        ↓
8. snapableParameters = ItemSnapableFactory.createItemSnapable(caseType)
        ↓
   On renseigne sur snapableParameters :
        displayParameter.gridRelativePositionX = 4
        displayParameter.gridRelativePositionY = 6
        displayParameter.unitSizeWidth  = 3
        displayParameter.unitSizeHeight = 4
        displayParameter.zLayer = 5
        displayParameter.zOrder = Game.tickLamport()
        + decorationParameter
        ↓
   createItemSnapableTile(snapableParameters)
        → instancie via snapableCaseTileComponent
        ↓
9. Nouvel élément ajouté à snapableTilesList
        ↓
10. Component.onCompleted
        ↓
    snapToGrid()
        ↓
    createAnimation.start()
        ↓
11. Case visible sur la grille ✅
```

### Déplacement

```
1. Utilisateur clique sur case
        ↓
2. SnapableElement.dragArea.onPressed
        ↓
3. mainMa.elementClicked(element)
   clickElement.push(element)
        ↓
4. Utilisateur clique (sans drag)
        ↓
5. MouseLogic_Selection.clickedLeft()
        ↓
6. element.parent = groupeSelection
   selectedElements.push(element)
   element.isSelected = true
   element.z += 11  (premier plan)
        ↓
7. Utilisateur drag
        ↓
8. mainMa.drag.target = groupeSelection
   groupeSelection se déplace → element suit
        ↓
9. Utilisateur relâche
        ↓
10. MouseLogic_Selection.release()
        ↓
11. element.x += groupeSelection.x  (coordonnées absolues)
    element.y += groupeSelection.y
        ↓
12. element.parent = workArea
        ↓
13. element.elementReleased()
        ↓
14. updateRelativePosition()
    gridRelativePositionX = Math.round(x / gridSize)
    gridRelativePositionY = Math.round(y / gridSize)
        ↓
15. snapToGrid()
    x = gridRelativePositionX × gridSize  (snap !)
    y = gridRelativePositionY × gridSize
        ↓
16. Case snappée à la grille ✅
```

### Suppression

```
1. Utilisateur sélectionne case
        ↓
2. Appui sur Delete
        ↓
3. element.deleteRequest()
        ↓
4. deleteAnimation.start()
   (animation de disparition)
        ↓
5. Animation terminée → onFinished
        ↓
6. element.elementDeleted(element)
        ↓
7. EditorDynamicComponent.onElementDeleted → _handleElementDeleted(element)
        ↓
8. logic.tileLogic.deleteElementsConnections(element)
   Supprime les connexions vers/depuis cet élément
        ↓
9. element.connectionManager.deleteLinkedConnection()
   Nettoie previousElements/nextElements
        ↓
10. logic.tileLogic.deleteElement(element)
    Retire de snapableTilesList
        ↓
11. element.destroy()
    Destruction de l'objet QML
        ↓
12. Case supprimée ✅
```

---

## 🎨 Panneau SelectionPanel

### Structure

```
SelectionPanel.qml
    │
    ├─ ResizeHandle (zone drag en haut)
    │   └─ MouseArea → customHeight ajustable
    │
    ├─ MenuSelector (Barre d'onglets)
    │   └─ [🎨 Assets]
    │
    └─ StackLayout
        │
        └─ Index 0: AssetSelectionPanel  ← unique enfant
            ├─ ASP_CategoryGrid (Catégories)
            ├─ ASP_Grid (Assets dans catégorie)
            └─ VisualEffectsPanel
                ├─ Rotation, Miroir
                ├─ Opacité, Saturation
                └─ Lock effets
```

> **Note** : la configuration des cases (`CaseConfigurationPanelSection`), des
> connexions (`ConnectionsConfigurationSection`), des zones et des effets visuels
> n'est plus dans le `SelectionPanel`. Elle est déplacée dans le
> `BottomSidePanel` (le `sidePanel`), sous
> `caseConfigPanel/` / `connectionConfigPanel/` / `zoneConfigPanel/` /
> `visualEffectPanel/`. Les infos de map (nom, fond, sauvegarde/chargement) sont
> portées par `MapInfoPanel.qml` (`qml/editor/panel/mapInfoPanel/`).

### Flux de Redimensionnement

```
Utilisateur drag ResizeHandle vers le haut
    ↓
MouseArea.onPositionChanged
    │
    ├─ deltaY = mouse.y - startY
    ├─ newHeight = startHeight - (deltaY × sensitivity)
    ├─ Applique limites : minHeight < newHeight < maxHeight
    └─ customHeight = newHeight
        ↓
SelectionPanel.height = customHeight (binding)
    ↓
StackLayout ajusté automatiquement
    ↓
Contenu visible change
```

---

## ⚙️ Z-Order (Ordre d'Affichage)

```
z = (isSelected && !isDragging) ? zOrder + 11 : zOrder + zLayer
         │                          │              │       │
         │                          │              │       └─ Couche logique (0-10)
         │                          │              │          Modifiable via le contrôle "Plan"
         │                          │              │
         │                          │              └─ Ordre microscopique (0.00001 incréments)
         │                          │                 Ordre de création (plus récent = plus haut)
         │                          │
         │                          └─ Quand sélectionné (et pas en cours de drag) :
         │                             bonus +11 (premier plan), zLayer ignoré
         │
         └─ Sinon : zOrder + zLayer

Exemple :
    Case A : zOrder=0.00001, zLayer=5, selected=false
    → z = 0.00001 + 5 = 5.00001

    Case B : zOrder=0.00002, zLayer=5, selected=true, !isDragging
    → z = 0.00002 + 11 = 11.00002  (zLayer ignoré quand sélectionné)
    → Case B au premier plan

Visuel (z croissant de bas en haut) :
    ┌─────────────────┐
    │   Case B (11)   │  ← Sélectionnée, devant tout
    ├─────────────────┤
    │   Case A (5)    │
    ├─────────────────┤
    │   Grille (0)    │
    └─────────────────┘
```

---

## 🚀 Performance et Optimisations

### Grille Optimisée

```
AVANT (2 Repeater) :
    Repeater 1 (lignes verticales)
    Repeater 2 (lignes horizontales)
    → Overhead × 2

ÉTAPE INTERMÉDIAIRE (1 Repeater) :
    Repeater (vertical + horizontal)
    → model: verticalLinesCount + horizontalLinesCount
        ├─ Index < verticalLinesCount ?  Ligne verticale
        └─ Index >= verticalLinesCount ?  Ligne horizontale
    → Overhead × 1

APRÈS (défaut Qt 6.11+) :
    Un seul GridCanvasPainter GPU + viewport culling
    → O(1) items dans le scene graph ✅

Le path 1-Repeater (verticalLinesCount + horizontalLinesCount) n'est plus
que le fallback legacy, activé par MEOW_GRID_RENDERER=repeater (ou Qt < 6.11).
```

### Bindings vs Calculs Manuels

```
❌ MAUVAIS (calcul manuel à chaque frame) :
    onPositionChanged: {
        x = gridRelativePositionX * gridSize
    }

✅ BON (binding automatique) :
    x: gridRelativePositionX * gridSize
    
    → QML optimise automatiquement
    → Recalcul uniquement si une dépendance change
```

### Loaders pour Modes

```
Loader {
    sourceComponent: (mode == EM_NORMAL) ? mouseLogic_selection_comp
                                        : mouseLogic_pose_comp
}

✅ Avantages :
    • Seul le MouseLogic actif est chargé en mémoire
    • Changement de mode = destruction ancien + création nouveau
    • Pas de code mort en mémoire
```

---

## 🔑 Concepts Clés à Retenir

### 1. Système de Coordonnées Dual
```
Grille (logique)  ←→  Pixel (visuel)
    0, 1, 2...       0px, 50px, 100px...
```

### 2. Bindings QML Partout
```
Changer une variable
    ↓
QML recalcule AUTOMATIQUEMENT toutes les dépendances
    ↓
Interface se met à jour
```

### 3. State Machine pour Modes
```
Mode change
    ↓
Loader charge le bon composant
    ↓
Comportements changent automatiquement
```

### 4. Connexions Bidirectionnelles
```
addNextElement(B)
    ↓
A.next.push(B) ET B.previous.push(A)
```

### 5. Zoom sans Scale
```
Pas de transformation scale !
Mais changement de taille de cellule
    → Pas de perte de qualité
```

---

**Date** : 25 février 2026  
**Version** : 1.1

