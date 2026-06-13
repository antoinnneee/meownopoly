# 📋 Résumé Architecture Éditeur Meownopoly

## 🎯 Vue d'Ensemble Rapide

L'éditeur Meownopoly est un **éditeur de cartes de jeu** avec :
- ✅ Grille dynamique et zoom fluide
- ✅ Système de "snap-to-grid" (accrochage automatique)
- ✅ Sélection multiple par rectangle
- ✅ Connexions visuelles entre cases
- ✅ Interface panneau multi-onglets

---

## 📁 Structure des Dossiers QML/Editor

```
qml/editor/
├── Editor.qml                    # 🏠 Point d'entrée principal
├── EditorLogic.qml               # 🧠 Cerveau de l'éditeur
├── EditorDynamicComponent.qml    # 🏭 Fabrique d'éléments
├── Editor_WheelHandler.qml       # 🖱️ Gestion molette
│
├── logic/                        # 📦 Logique métier
│   ├── MouseLogic_Base.qml          # Classe de base
│   ├── MouseLogic_Selection.qml     # Mode sélection/déplacement
│   ├── MouseLogic_Pose.qml          # Mode placement
│   ├── MouseLogic_Selection_link.qml # Mode création de liens
│   ├── MouseLogic_Template.qml      # Mode template
│   ├── MouseLogic_Game.qml          # Mode jeu
│   ├── MouseLogic_DrawPolygon.qml   # Mode tracé de polygone (zones)
│   ├── TileLogic.qml                # Gestion des tuiles
│   ├── ScrollLogic.qml              # Zoom et scroll
│   └── PlanLogic.qml                # Gestion Z-layers
│
└── panel/                        # 🎨 Interface utilisateur
    ├── bottomPanel/
    │   ├── bottomMainPanel/             # Panneau principal (bas)
    │   │   ├── SelectionPanel.qml          # Conteneur du panneau principal
    │   │   ├── assetSelectionPanel/        # Sélection assets/décorations + cases
    │   │   ├── caseSelectionPanel/         # Composants CSP_ de config de case
    │   │   ├── menuSelectionPanel/         # Onglets de menu
    │   │   ├── templatePanel/              # Templates
    │   │   └── zonePanel/                  # Zones
    │   └── bottomSidePanel/             # Panneaux latéraux contextuels
    │       ├── caseConfigPanel/            # Config détaillée de case
    │       ├── connectionConfigPanel/      # Config des liens Previous/Next
    │       ├── visualEffectPanel/          # Effets visuels
    │       ├── zoneConfigPanel/            # Config de zone
    │       └── sidePanel/                  # Conteneur latéral
    └── mapInfoPanel/                    # Paramètres carte
        ├── MapInfoPanel.qml
        ├── MapInfoDrawer.qml
        └── MapNavigationBar.qml

qml/meowComponent/                # 🧩 Composants partagés éditeur/plateau
├── Background.qml                   # 🖼️ Image de fond
├── SelectionRect.qml               # ⭐ Rectangle de sélection
├── grid/
│   └── GridManager.qml             # ⭐ GRILLE - Génération et snapping
├── preview/
│   └── AssetPreviewCursor.qml      # Aperçu curseur
└── snapable/                       # 📌 Système Snapable
    ├── SnapableElement.qml             # ⭐ Classe de base
    ├── SnapableElementConnections.qml  # ⭐ Gestion des liens
    ├── SnapableElementControl.qml      # Boutons de contrôle
    ├── SnapableElementResizeHandles.qml # Poignées redimensionnement
    └── ConnectionOverlay.qml           # Ligne de connexion
```

---

## 🔲 1. La Grille (`GridManager.qml`)

### Génération
```javascript
gridSize = Screen.pixelDensity × mmSize  // Taille d'une cellule en pixels
boardSize = gridSize × 600               // Grille 600×600 cellules
```

### Rendu Optimisé
- **Chemin par défaut (Qt 6.11+)** : un seul `GridCanvasPainter` GPU global (`GridCanvasLayer.qml`) qui couvre le viewport visible et fait du **viewport culling** — il ne dessine que les croisillons/lignes réellement à l'écran
- Sélectionné via la context property `_gridRendererUseCanvas` (env `MEOW_GRID_RENDERER`, défaut `canvas`)
- **Fallback legacy (Qt 6.10)** : un Repeater unique (`gridLinesRepeater`, ~1202 `Rectangle`) activé par `MEOW_GRID_RENDERER=repeater`
- Lignes calculées dynamiquement selon la taille de la vue
- Mode "resize" pour intensifier visuellement pendant redimensionnement

### Fonctions Clés
```javascript
getGridPosition(x, y)         // Pixel → Coordonnées grille entières (0,1,2...)
getGridRealPosition(x, y)     // Pixel → Coordonnées grille fractionnaires
getGridPixelPosition(x, y)    // Coordonnées grille → Pixel
snapElement2(element)         // Positionne un élément sur la grille
```

---

## 📌 2. Système Snapable (Accrochage)

### Principe
Les éléments se **positionnent automatiquement sur la grille** après chaque manipulation.

### Deux Systèmes de Coordonnées
1. **Coordonnées grille** (logiques) : `gridRelativePositionX/Y` = 0, 1, 2, 3...
2. **Coordonnées pixel** (visuelles) : `x/y` = calculées automatiquement

```qml
// Dans SnapableElement.qml - Binding automatique
x: snapableParameters.displayParameter.gridRelativePositionX × gridManager.gridSize
y: snapableParameters.displayParameter.gridRelativePositionY × gridManager.gridSize
width: snapableParameters.displayParameter.unitSizeWidth × gridManager.gridSize
height: snapableParameters.displayParameter.unitSizeHeight × gridManager.gridSize
```

### Cycle de Vie
```
Création
  → snapToGrid() automatique
  ↓
Sélection (hors drag)
  → z = zOrder + 11 (le zLayer est remplacé, pas additionné)
  ↓
Drag
  → parent = groupeSelection
  → déplacement libre en pixels
  ↓
Release
  → updateRelativePosition()
  → snapToGrid() automatique
  → parent = workArea
```

### Groupe de Sélection Multi-Éléments
```qml
Item { id: groupeSelection }
```
- Tous les éléments sélectionnés deviennent enfants
- Déplacer le groupe = déplacer tous les enfants ensemble
- Au relâchement, chaque élément retourne à `workArea` et snap individuellement

---

## 🔍 3. Zoom

### Principe Unique : Taille Variable des Cellules
❌ **Pas de transformation scale**  
✅ **Change la taille physique des cellules de grille**

```javascript
gridSize = Screen.pixelDensity × mmSize
```

### Contrôle
- **Ctrl + Molette Haut** : `mmSize ×= 1.1` → Zoom In
- **Ctrl + Molette Bas** : `mmSize ÷= 1.1` → Zoom Out
- Facteur **multiplicatif** `ScrollLogic.zoomFactor = 1.1` (zoom continu, pas additif)
- `mmSize` est un `real` (défaut `12.0`) borné en bas par `minMmSize = 0.5`

### Effet Cascade
```
mmSize change
  ↓
gridSize recalculé (binding auto)
  ↓
Tous les éléments repositionnent (x/y bindés à gridSize)
  ↓
Tous les éléments redimensionnent (width/height bindés à gridSize)
```

### Avantages
✅ Pas de perte de qualité (re-rendu, pas étirage)  
✅ Précision des coordonnées grille conservée  
✅ Performance (bindings QML automatiques)  
✅ Simplicité (pas de transformations matricielles)

---

## 🔗 4. Liens entre Cases

### Architecture
Chaque élément contient un **`SnapableElementConnections`** :
```javascript
previousElements[]  // Cases précédentes dans le flux de jeu
nextElements[]      // Cases suivantes
```

### Bidirectionnalité Automatique
```javascript
source.addNextElement(target)
  → target.previousElements.push(source)  // Lien inverse automatique
```

### Affichage Visuel
```qml
Repeater {
    model: nextElementsSegments  // Liste des connexions
    delegate: ConnectionOverlay  // Dessine une ligne
}
```

### Processus de Création

```
1. Utilisateur sélectionne case source
   ↓
2. Clic sur "Connect Next" dans panneau
   ↓
3. Mode change → EM_SELECTION_LINK
   MouseLogic_Selection_link activé
   ↓
4. Utilisateur clique case cible
   ↓
5. createSnapableLink(source, target, "next")
   ↓
6. Connexion créée (bidirectionnelle)
   Ligne visuelle affichée
   ↓
7. Retour mode EM_NORMAL
```

---

## 📐 5. Sélection par Rectangle

### Composants
- **`SelectionRect.qml`** : Rectangle visuel bleu semi-transparent
- **`MouseLogic_Selection.qml`** : Logique de détection
- **`Editor.qml`** : Capture événements souris

### Flux Complet

```
1. DÉBUT : Clic sur zone vide (aucun élément cliqué)
   ↓
   MouseLogic_Selection.pressedLeft()
   → clickElement.length === 0
   → isRectangleSelecting = true
   → rectangleStart = position souris
   → selectionRect.show()
   ↓
2. DRAG : Utilisateur déplace la souris
   ↓
   Editor.mainMa.onPositionChanged()
   → updateRectangleSelection(x, y)
   ↓
   rectangleCurrent = position souris
   selectionRect.updateGeometry()  // Redessine le rectangle
   ↓
   getElementsInRectangle()  // Détecte intersections
   → Pour chaque snapableTilesList[i]
      → Test AABB (Axis-Aligned Bounding Box)
      → if (intersection) → elements.push(i)
   ↓
   selectElementsInRectangle()  // Sélection en TEMPS RÉEL
   → unselectAllElements()
   → Pour chaque élément détecté
      → element.parent = groupeSelection
      → selectedElements.push(element)
   ↓
3. RELEASE : Utilisateur relâche
   ↓
   MouseLogic_Selection.release()
   → finalizeRectangleSelection()  // Sélection finale
   → isRectangleSelecting = false
   → selectionRect.hide()
   ↓
4. Éléments restent sélectionnés
   Si 1 seul élément → affiche panneau configuration
```

### Test d'Intersection AABB

```javascript
// Limites rectangle
rectLeft, rectRight, rectTop, rectBottom

// Limites élément
elementLeft = element.x
elementRight = element.x + element.width
elementTop = element.y
elementBottom = element.y + element.height

// Intersection si PAS (complètement à gauche OU à droite OU au-dessus OU en-dessous)
intersection = !(elementRight < rectLeft || 
                 elementLeft > rectRight || 
                 elementBottom < rectTop || 
                 elementTop > rectBottom)
```

---

## 🎛️ 6. Modes de Souris (State Machine)

### Architecture
```
EditorLogic.editorMouseMode (enum)
   ↓
Loader charge dynamiquement le MouseLogic correspondant
   ↓
   ├─ EM_NORMAL → MouseLogic_Selection
   │   • Sélection/déplacement
   │   • Sélection par rectangle
   │   • Multi-sélection avec Ctrl
   │
   ├─ EM_POSE → MouseLogic_Pose
   │   • Placement d'assets/cases
   │   • Aperçu sous curseur
   │
   ├─ EM_SELECTION_LINK → MouseLogic_Selection_link
   │   • Création de connexions
   │   • Attend clic sur case cible
   │
   ├─ EM_TEMPLATE → MouseLogic_Template
   │   • Pose/manipulation de templates
   │
   ├─ EM_GAME → MouseLogic_Game
   │   • Interaction en mode jeu
   │
   └─ EM_DRAW_POLYGON → MouseLogic_DrawPolygon
       • Tracé de polygones (zones)
```

Les six valeurs de `EditorEnum::EditorMouseMode` (`EM_NORMAL`, `EM_POSE`, `EM_SELECTION_LINK`, `EM_TEMPLATE`, `EM_GAME`, `EM_DRAW_POLYGON`) ont chacune leur `MouseLogic` chargé dynamiquement dans `EditorLogic.qml`.

### Changement de Mode
```javascript
logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
  → Loader recharge le bon MouseLogic
  → Comportements souris changent automatiquement
```

---

## 🎨 7. Panneaux d'Interface

### SelectionPanel (Panneau Principal Bas)
```
SelectionPanel.qml
├── MenuSelector (Onglets en haut)
│
├── StackLayout (Affiche le panneau actif)
│   └─ AssetSelectionPanel (unique enfant)
│
└── ResizeHandle (Zone de redimensionnement)
```
- Le `StackLayout` ne contient qu'un seul enfant : `AssetSelectionPanel` (id `assetPanel`).
- La sélection du **type de case** n'est pas un panneau séparé : elle est intégrée à `AssetSelectionPanel` et exposée via `property alias caseTypeSelected: assetPanel.selectedCaseType`.
- Les **paramètres de carte** vivent dans `panel/mapInfoPanel/` (`MapInfoPanel`, `MapInfoDrawer`, `MapNavigationBar`), pas dans un `MapSelectionPanel`.

### AssetSelectionPanel
- Sélection de décorations (arbres, objets 3D, etc.)
- Sélection du type de case (Kibble Dispenser, Cat Door, etc.) via `selectedCaseType`
- **VisualEffectsPanel** : Rotation, miroir, couleur, opacité, etc.
- Lock des effets pour appliquer aux prochains éléments

### Panneaux latéraux contextuels (`panel/bottomPanel/bottomSidePanel/`)
- **caseConfigPanel** : Config détaillée d'une case (nom, prix, loyers, etc.)
- **connectionConfigPanel** : Gestion des liens Previous/Next
- **zoneConfigPanel** : Config de zone
- **visualEffectPanel** : Effets visuels

### mapInfoPanel
- Informations et paramètres de carte (image de fond, scaling, etc.)
- Sauvegarde/Chargement de cartes

---

## ⚙️ 8. Concepts Avancés

### Z-Order (Ordre d'Affichage)
```javascript
z = (isSelected && !isDragging) ? zOrder + 11 : zOrder + zLayer
```
- **zLayer** : Couche logique (0-10), modifiable par utilisateur
- **zOrder** : Micro-ordre (0.00001 incréments), ordre de création
- **+11** : Bonus si sélectionné (passe au premier plan). En sélection, le `zLayer` est **remplacé** par le bonus, pas additionné — et ce bonus ne s'applique **pas pendant un drag**.

### Éviter les Conflits de Drag
```qml
MouseArea {
    propagateComposedEvents: true
    preventStealing: true  // ✅ Important !
}
```

### Performance Grille
- **Canvas GPU unique global** (`GridCanvasPainter`, chemin par défaut Qt 6.11+) avec **viewport culling** : ne dessine que ce qui est à l'écran
- Le **Repeater unique** (`gridLinesRepeater`, ~1202 `Rectangle`) est désormais le **fallback legacy** (Qt 6.10), activable via `MEOW_GRID_RENDERER=repeater`
- Lignes calculées à la demande
- Visible uniquement si `showGrid: true`

---

## 📊 Diagramme Simplifié : Création d'une Case

```
Utilisateur clique sur type de case (Kibble Dispenser)
   ↓
AssetSelectionPanel.selectedCaseType = CS_KibbleDispenser
(exposé via SelectionPanel.caseTypeSelected)
   ↓
Mode change → EM_POSE
   ↓
Utilisateur clique sur la grille (200px, 300px)
   ↓
Conversion : getGridPosition(200, 300) → (2, 3)
   ↓
TileLogic.placeSelectedAsset(gridX, gridY)
   → ItemSnapableFactory.createItemSnapable(caseType)  // construit le ItemSnapable
   → createItemSnapableTile(itemSnapableData)
   ↓
EditorDynamicComponent.snapableCaseTileComponent.createObject(workArea)
   ↓
Nouvel élément créé :
   - snapableParameters.displayParameter.gridRelativePositionX = 2
   - snapableParameters.displayParameter.gridRelativePositionY = 3
   - x = 2 × gridSize (binding auto)
   - y = 3 × gridSize (binding auto)
   ↓
Component.onCompleted → snapToGrid()
   ↓
Case affichée sur la grille ✅
```

---

## 🚀 Points Forts de l'Architecture

✅ **Modularité** : Chaque fichier a une responsabilité claire  
✅ **Réactivité** : Bindings QML automatiques partout  
✅ **Extensibilité** : Ajouter un mode = créer un fichier  
✅ **Performance** : Grille optimisée, calculs minimaux  
✅ **Robustesse** : Connexions bidirectionnelles automatiques  
✅ **UX** : Sélection temps réel, aperçu curseur, animations  

---

## 🔑 Fichiers Clés à Connaître

| Fichier | Rôle |
|---------|------|
| **`GridManager.qml`** | ⭐ Grille, snapping, zoom |
| **`SnapableElement.qml`** | ⭐ Base de tous les éléments accrochables |
| **`EditorLogic.qml`** | 🧠 Orchestration générale |
| **`MouseLogic_Selection.qml`** | 📐 Sélection par rectangle |
| **`TileLogic.qml`** | 🏭 Création/Suppression d'éléments |
| **`SnapableElementConnections.qml`** | 🔗 Gestion des liens |
| **`SelectionPanel.qml`** | 🎨 Interface principale |

---

## 📝 Résumé Ultra-Rapide

**Comment ça marche ?**

1. **Grille** : Cellules de taille dynamique (pas de scale), zoom = `mmSize` multiplié/divisé par 1.1 par cran
2. **Snapable** : Coordonnées grille (0,1,2...) → pixel calculé automatiquement
3. **Sélection rectangle** : Détection AABB en temps réel pendant le drag
4. **Liens** : Connexions bidirectionnelles automatiques avec affichage visuel
5. **Modes** : State Machine avec Loaders pour changer le comportement

**Le secret** : **Bindings QML** partout → changez une variable, tout se met à jour ! 🎉

---

**Date** : 12 octobre 2025  
**Version** : 1.0

