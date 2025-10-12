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
├── Background.qml                # 🖼️ Image de fond
│
├── logic/                        # 📦 Logique métier
│   ├── MouseLogic_Base.qml          # Classe de base
│   ├── MouseLogic_Selection.qml     # Mode sélection/déplacement
│   ├── MouseLogic_Pose.qml          # Mode placement
│   ├── MouseLogic_Selection_link.qml # Mode création de liens
│   ├── TileLogic.qml                # Gestion des tuiles
│   ├── ScrollLogic.qml              # Zoom et scroll
│   └── PlanLogic.qml                # Gestion Z-layers
│
├── tools/                        # 🔧 Outils
│   ├── GridManager.qml              # ⭐ GRILLE - Génération et snapping
│   ├── SelectionRect.qml            # ⭐ Rectangle de sélection
│   ├── AssetPreviewCursor.qml       # Aperçu curseur
│   ├── ConnectionOverlay.qml        # Ligne de connexion
│   │
│   └── snapable/                    # 📌 Système Snapable
│       ├── SnapableElement.qml           # ⭐ Classe de base
│       ├── SnapableElementConnections.qml # ⭐ Gestion des liens
│       ├── SnapableElementControl.qml    # Boutons de contrôle
│       └── SnapableElementResizeHandles.qml # Poignées redimensionnement
│
└── panel/                        # 🎨 Interface utilisateur
    ├── SelectionPanel.qml           # Panneau principal (bas)
    ├── assetSelectionPanel/         # Sélection décorations
    ├── caseSelectionPanel/          # Sélection cases + config
    └── mapSelectionPanel/           # Paramètres carte
```

---

## 🔲 1. La Grille (`GridManager.qml`)

### Génération
```javascript
gridSize = Screen.pixelDensity × mmSize  // Taille d'une cellule en pixels
boardSize = gridSize × 600               // Grille 600×600 cellules
```

### Rendu Optimisé
- **1 seul Repeater** pour toutes les lignes (vertical + horizontal)
- Lignes calculées dynamiquement selon la taille de la vue
- Mode "resize" pour intensifier visuellement pendant redimensionnement

### Fonctions Clés
```javascript
snapToGridCoord(value)        // Pixel → Position snappée
getGridPosition(x, y)         // Pixel → Coordonnées grille (0,1,2...)
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
x: displaySettings.gridRelativePositionX × gridManager.gridSize
y: displaySettings.gridRelativePositionY × gridManager.gridSize
width: displaySettings.unitSizeWidth × gridManager.gridSize
height: displaySettings.unitSizeHeight × gridManager.gridSize
```

### Cycle de Vie
```
Création
  → snapToGrid() automatique
  ↓
Sélection
  → z augmenté (+11)
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
- **Ctrl + Molette Haut** : `mmSize++` → Zoom In
- **Ctrl + Molette Bas** : `mmSize--` → Zoom Out

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
   └─ EM_SELECTION_LINK → MouseLogic_Selection_link
       • Création de connexions
       • Attend clic sur case cible
```

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
│   ├─ [Assets] → AssetSelectionPanel
│   ├─ [Cases] → CaseSelectionPanel
│   └─ [Map] → MapSelectionPanel
│
├── StackLayout (Affiche le panneau actif)
│
└── ResizeHandle (Zone de redimensionnement)
```

### AssetSelectionPanel
- Sélection de décorations (arbres, objets 3D, etc.)
- **VisualEffectsPanel** : Rotation, miroir, couleur, opacité, etc.
- Lock des effets pour appliquer aux prochains éléments

### CaseSelectionPanel ⭐
- Sélecteur de type de case (Kibble Dispenser, Cat Door, etc.)
- **CaseConfigurationPanelSection** : Config détaillée (nom, prix, loyers, etc.)
- **ConnectionsConfigurationSection** : Gestion des liens Previous/Next

### MapSelectionPanel
- Sélection d'image de fond
- Paramètres de scaling (Stretch, Fit, Tile)
- Sauvegarde/Chargement de cartes

---

## ⚙️ 8. Concepts Avancés

### Z-Order (Ordre d'Affichage)
```javascript
z = zOrder + zLayer + (isSelected ? 11 : 0)
```
- **zLayer** : Couche logique (0-10), modifiable par utilisateur
- **zOrder** : Micro-ordre (0.00001 incréments), ordre de création
- **+11** : Bonus si sélectionné (passe au premier plan)

### Éviter les Conflits de Drag
```qml
MouseArea {
    propagateComposedEvents: true
    preventStealing: true  // ✅ Important !
}
```

### Performance Grille
- **1 Repeater** au lieu de 2 → 2× plus rapide
- Lignes calculées à la demande
- Visible uniquement si `showGrid: true`

---

## 📊 Diagramme Simplifié : Création d'une Case

```
Utilisateur clique sur type de case (Kibble Dispenser)
   ↓
CaseSelectionPanel.caseTypeSelected = CS_KibbleDispenser
   ↓
Mode change → EM_POSE
   ↓
Utilisateur clique sur la grille (200px, 300px)
   ↓
Conversion : getGridPosition(200, 300) → (2, 3)
   ↓
TileLogic.createNewTileAtPosition(CS_KibbleDispenser, 2, 3, CaseTile)
   ↓
EditorDynamicComponent.snapableCaseTileComponent.createObject(workArea)
   ↓
Nouvel élément créé :
   - displaySettings.gridRelativePositionX = 2
   - displaySettings.gridRelativePositionY = 3
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

1. **Grille** : Cellules de taille dynamique (pas de scale), zoom = changer `mmSize`
2. **Snapable** : Coordonnées grille (0,1,2...) → pixel calculé automatiquement
3. **Sélection rectangle** : Détection AABB en temps réel pendant le drag
4. **Liens** : Connexions bidirectionnelles automatiques avec affichage visuel
5. **Modes** : State Machine avec Loaders pour changer le comportement

**Le secret** : **Bindings QML** partout → changez une variable, tout se met à jour ! 🎉

---

**Date** : 12 octobre 2025  
**Version** : 1.0

