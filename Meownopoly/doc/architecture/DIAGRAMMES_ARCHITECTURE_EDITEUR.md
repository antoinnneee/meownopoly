# 📊 Diagrammes Architecture Éditeur Meownopoly

## 🏗️ Architecture Globale

```
┌─────────────────────────────────────────────────────────────┐
│                        Editor.qml                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  EditorLogic.qml                      │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │MouseLogic  │  │ScrollLogic │  │TileLogic   │     │   │
│  │  │  (Loader)  │  │  (Loader)  │  │            │     │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               GridManager (Grille)                    │   │
│  │  ┌─────────────────────────────────────────────┐     │   │
│  │  │          WorkArea (Zone de travail)          │     │   │
│  │  │  ┌─────────────┐  ┌─────────────┐           │     │   │
│  │  │  │SnapableCase │  │SnapableDeco │  ...      │     │   │
│  │  │  └─────────────┘  └─────────────┘           │     │   │
│  │  └─────────────────────────────────────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            SelectionPanel (Panneau Bas)               │   │
│  │  ┌───────┐  ┌───────┐  ┌──────┐                      │   │
│  │  │Assets │  │Cases  │  │ Map  │  ← Onglets           │   │
│  │  └───────┘  └───────┘  └──────┘                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔲 Système de Grille

### Génération et Rendu

```
GridManager
    │
    ├─ gridSize = Screen.pixelDensity × mmSize
    │       │
    │       ├─ mmSize = 10 (défaut)
    │       └─ Ctrl+Molette → mmSize ± 1 (ZOOM)
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
    ├─ displaySettings: DisplayParameter
    │   ├─ gridRelativePositionX
    │   ├─ gridRelativePositionY
    │   ├─ unitSizeWidth
    │   ├─ unitSizeHeight
    │   ├─ zLayer
    │   └─ zOrder
    │
    ├─ connectionManager: SnapableElementConnections
    │   ├─ previousElements[]
    │   ├─ nextElements[]
    │   └─ ConnectionOverlay (lignes visuelles)
    │
    ├─ SnapableElementControl (boutons)
    │   ├─ Bouton Supprimer
    │   ├─ Bouton Plan (z-layer)
    │   └─ Bouton Configurer
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
│  + caseData (C++)   │  + decorationSettings│
│  + TileContent.qml  │  + Image            │
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
│  z: zOrder + zLayer + (isSelected?11:0)    │ ← Binding auto
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
    EM_NORMAL     EM_POSE      EM_SELECTION_LINK    ...
         │             │              │
         ▼             ▼              ▼
  Loader dynamique charge le bon MouseLogic
         │             │              │
         ▼             ▼              ▼
┌────────────────┐ ┌───────────┐ ┌─────────────────┐
│ MouseLogic_    │ │MouseLogic_│ │ MouseLogic_     │
│ Selection      │ │  Pose     │ │ Selection_link  │
├────────────────┤ ├───────────┤ ├─────────────────┤
│• Sélection     │ │• Place    │ │• Attend clic    │
│• Déplacement   │ │  assets   │ │  sur cible      │
│• Rectangle     │ │• Aperçu   │ │• Crée connexion │
│• Multi-sél     │ │  curseur  │ │• Retour NORMAL  │
└────────────────┘ └───────────┘ └─────────────────┘

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
ScrollLogic.scrollUp()
         ↓
logic.updateSize(mmSize + 1)
         ↓
mmSize = 11  (était 10)
         ↓
gridSize recalculé (binding)
         ↓
gridSize = Screen.pixelDensity × 11
         ↓
Tous les éléments repositionnés/redimensionnés (bindings)

AVANT (mmSize=10, gridSize=50px) :
┌──────┬──────┬──────┐
│      │      │      │
│  50px│      │      │
│      │      │      │
└──────┴──────┴──────┘

APRÈS (mmSize=11, gridSize=55px) :
┌───────┬───────┬───────┐
│       │       │       │
│  55px │       │       │
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
7. TileLogic.createNewTileAtPosition(CS_KibbleDispenser, 4, 6, CaseTile)
        ↓
8. editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
        gridRelativePositionX: 4,
        gridRelativePositionY: 6,
        unitSizeWidth: 3,
        unitSizeHeight: 4,
        caseData: Game.getNewCaseType(CS_KibbleDispenser)
   })
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
2. Appui sur Delete OU clic bouton supprimer
        ↓
3. element.deleteRequest()
        ↓
4. SnapableElementControl.deleteRequested()
        ↓
5. deleteAnimation.start()
   (animation de disparition)
        ↓
6. Animation terminée → signal finished
        ↓
7. element.elementDeleted(element)
        ↓
8. EditorDynamicComponent.onElementDeleted handler
        ↓
9. logic.tileLogic.deleteElementsConnections(element)
   Supprime les connexions vers/depuis cet élément
        ↓
10. element.connectionManager.deleteLinkedConnection()
    Nettoie previousElements/nextElements
        ↓
11. logic.tileLogic.deleteElement(element)
    Retire de snapableTilesList
        ↓
12. element.destroy()
    Destruction de l'objet QML
        ↓
13. Case supprimée ✅
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
    │   ├─ [🎨 Assets]
    │   ├─ [🏠 Cases]
    │   └─ [🗺️ Map]
    │
    └─ StackLayout
        │
        ├─ Index 0: AssetSelectionPanel
        │   ├─ ASP_CategoryGrid (Catégories)
        │   ├─ ASP_Grid (Assets dans catégorie)
        │   └─ VisualEffectsPanel
        │       ├─ Rotation, Miroir
        │       ├─ Opacité, Saturation
        │       └─ Lock effets
        │
        ├─ Index 1: CaseSelectionPanel
        │   ├─ CSP_CaseTypeSelector (Sélection type)
        │   └─ CSP_ContentArea (Onglets)
        │       ├─ Tab 0: CaseConfigurationPanelSection
        │       │   ├─ Nom, Description
        │       │   ├─ Prix, Loyers
        │       │   └─ Config spécifique par type
        │       │
        │       └─ Tab 1: ConnectionsConfigurationSection
        │           ├─ [Connect Previous ◀]
        │           ├─ [Connect Next ▶]
        │           └─ Liste connexions existantes
        │
        └─ Index 2: MapSelectionPanel
            ├─ MSP_SP_Background (Image de fond)
            ├─ MSP_SP_General (Nom, description)
            └─ MSP_SP_SaveLoad (Sauvegarde/Chargement)
```

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
z = zOrder + zLayer + (isSelected ? 11 : 0)
    │        │         │
    │        │         └─ Bonus sélection (premier plan)
    │        │
    │        └─ Couche logique (0-10)
    │           Modifiable via boutons "Plan"
    │
    └─ Ordre microscopique (0.00001 incréments)
       Ordre de création (plus récent = plus haut)

Exemple :
    Case A : zOrder=0.00001, zLayer=5, selected=false
    → z = 5.00001

    Case B : zOrder=0.00002, zLayer=5, selected=true
    → z = 5.00002 + 11 = 16.00002
    → Case B au premier plan

Visuel (z croissant de bas en haut) :
    ┌─────────────────┐
    │   Case B (16)   │  ← Sélectionnée, devant tout
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

APRÈS (1 Repeater) :
    Repeater (vertical + horizontal)
    → Overhead × 1
    → Performance × 2 ✅

model: verticalLinesCount + horizontalLinesCount
    │
    ├─ Index < verticalLinesCount ?  Ligne verticale
    └─ Index >= verticalLinesCount ?  Ligne horizontale
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

**Date** : 12 octobre 2025  
**Version** : 1.0

