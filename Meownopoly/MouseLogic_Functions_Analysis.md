# 📊 TABLEAU RÉCAPITULATIF DES FONCTIONS MOUSELOGIC

## 📋 LÉGENDE

- ✅ **[CONFORME]** = Présente et conforme aux critères de cette catégorie (fonctionnalité native)
- ⚠️ **[MODIFIÉE]** = Présente mais différente (redéfinie avec logique spécifique)
- ❌ **[ABSENTE]** = Absente (n'existe pas dans ce fichier, non applicable)
- 🔄 **[HÉRITÉE]** = Héritée sans redéfinition (utilise l'implémentation du parent)

---

## 📊 TABLEAU EXHAUSTIF : TOUTES LES FONCTIONS

### 🛠️ FONCTIONS DE GESTION UTILITAIRE (Bindings, Configuration, Sélection)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `unselectSelectedElements()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `clearCaseConfiguration()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `updateCaseConfiguration()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `updateVisualEffectPanel()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `setSelectedElementList()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `elementClicked()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `createBindingsForElement()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `destroyBindingsForElement()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `moveMouseToWindowCenter()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `changeMouseMode()` | ✅ | 🔄 | ⚠️ | 🔄 | ❌ | ❌ |

### 🖱️ FONCTIONS D'ÉVÉNEMENTS SOURIS (Clics, Drag, Mouvements)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `dragChanged()` | ✅ | ⚠️ | ❌ | 🔄 | ❌ | ⚠️ |
| `positionChanged()` | ✅ | 🔄 | ❌ | 🔄 | ⚠️ | ❌ |
| `pressedLeft()` | ✅ | ⚠️ | ⚠️ | 🔄 | ⚠️ | ⚠️ |
| `pressedRight()` | ✅ | ⚠️ | ⚠️ | 🔄 | ❌ | ⚠️ |
| `pressedMiddle()` | ✅ | 🔄 | ❌ | 🔄 | ❌ | ❌ |
| `release()` | ✅ | ⚠️ | ⚠️ | 🔄 | ❌ | ⚠️ |
| `pressedAndHold()` | ✅ | ⚠️ | ⚠️ | 🔄 | ❌ | ⚠️ |
| `clickedLeft()` | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | ⚠️ |
| `clickedRight()` | ✅ | ✅ | ✅ | 🔄 | ❌ | ✅ |
| `clickedMiddle()` | ✅ | 🔄 | ❌ | 🔄 | ❌ | ❌ |
| `clicked()` | ✅ | 🔄 | ❌ | 🔄 | ❌ | ❌ |

### 🔲 FONCTIONS DE SÉLECTION RECTANGLE (Multi-sélection par zone)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `updateRectangleSelection()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `getElementsInRectangle()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `selectElementsInRectangle()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `finalizeRectangleSelection()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |

### 🔗 FONCTIONS SPÉCIFIQUES AUX LIENS (Création et prévisualisation)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `updateMousePosition()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `getElementAtPosition()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `showLinkPreview()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `hideLinkPreview()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |

### 📦 FONCTIONS SPÉCIFIQUES (Unique à Template)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `addToList()` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 📊 COMPTAGE PAR SYMBOLE ET COMPLEXITÉ

| Fichier | ✅ Conforme | ⚠️ Modifiée | ❌ Absente | 🔄 Héritée | Total | Taux de Redéfinition |
|---------|------------|-------------|-----------|-----------|-------|---------------------|
| **Base** | 20 🟢 | 0 | 9 | 0 | 29 | 0% (Base) |
| **Selection** | 4 | 7 🟡 | 5 | 13 🔵 | 29 | 38% (Complexe) |
| **Pose** | 1 | 6 🟡 | 15 🔴 | 7 | 29 | 24% (Spécialisé) |
| **Selection_link** | 4 | 1 | 5 | 19 🔵 | 29 | 17% (Extension) |
| **Game** | 0 | 2 | 18 🔴 | 9 | 29 | 18% (Minimal) |
| **Template** | 5 | 6 🟡 | 11 | 7 | 29 | 38% (Complexe) |

**Légende taux de redéfinition** : % de fonctions modifiées (⚠️) par rapport au total disponible
- 🟢 Base de référence
- 🔵 Principalement héritées (légères modifications)
- 🟡 Nombreuses redéfinitions (comportement adapté)
- 🔴 Beaucoup de fonctions non utilisées (contexte très spécifique)

---

## 🌳 HIÉRARCHIE D'HÉRITAGE

```
MouseLogic_Base
    │
    ├── MouseLogic_Selection
    │       │
    │       └── MouseLogic_Selection_link
    │
    ├── MouseLogic_Pose
    │
    ├── MouseLogic_Game
    │
    └── MouseLogic_Template
```

---

## 📋 CATÉGORIE 1 : FONCTIONS IDENTIQUES 🟢
### (Héritées sans modification, ou avec logs supplémentaires uniquement)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `unselectSelectedElements()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `clearCaseConfiguration()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `updateCaseConfiguration()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `updateVisualEffectPanel()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `setSelectedElementList()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `elementClicked()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `createBindingsForElement()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `destroyBindingsForElement()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `moveMouseToWindowCenter()` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `pressedMiddle()` | ✅ | 🔄 | ❌ | 🔄 | ❌ | ❌ |
| `clickedMiddle()` | ✅ | 🔄 | ❌ | 🔄 | ❌ | ❌ |
| `clicked()` | ✅ | 🔄 | ❌ | 🔄 | ❌ | ❌ |
| `clickedRight()` | ✅ | ✅ | ✅ | 🔄 | ❌ | ✅ |
| `updateRectangleSelection()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `getElementsInRectangle()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `selectElementsInRectangle()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `finalizeRectangleSelection()` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |

---

## 📋 CATÉGORIE 2 : FONCTIONS AVEC DIFFÉRENCES 🟡
### (Structure similaire, logique adaptée au contexte spécifique)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `dragChanged()` | ✅ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `pressedLeft()` | ✅ | ✅ | ✅ | 🔄 | ✅ | ✅ |
| `pressedRight()` | ✅ | ✅ | ✅ | 🔄 | ❌ | ✅ |
| `release()` | ✅ | ✅ | ✅ | 🔄 | ❌ | ✅ |
| `pressedAndHold()` | ✅ | ✅ | ✅ | 🔄 | ❌ | ✅ |
| `changeMouseMode()` | ✅ | 🔄 | ✅ | 🔄 | ❌ | ❌ |
| `positionChanged()` | ✅ | 🔄 | ❌ | 🔄 | ✅ | ❌ |

---

## 📋 CATÉGORIE 3 : FONCTIONS UNIQUES 🔴
### (Logique spécifique et unique à un contexte particulier)

| Fonction | Base | Selection | Pose | Selection_link | Game | Template |
|----------|------|-----------|------|----------------|------|----------|
| `clickedLeft()` | ⚠️ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `updateMousePosition()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `getElementAtPosition()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `showLinkPreview()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `hideLinkPreview()` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `addToList()` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 🎯 PROPRIÉTÉS SPÉCIFIQUES PAR FICHIER
### (État interne et données de contexte)

| Propriété | Base | Selection | Pose | Selection_link | Game | Template |
|-----------|------|-----------|------|----------------|------|----------|
| `isDragging` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `clickElement` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `selectedElements` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `elementBindings` | ✅ | 🔄 | 🔄 | 🔄 | 🔄 | 🔄 |
| `isRectangleSelecting` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `rectangleStart` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `rectangleCurrent` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `pressPosition` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `hadPressWithoutElement` | ❌ | ✅ | ❌ | 🔄 | ❌ | ✅ |
| `kind` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `linkSourceCase` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `currentMouseX` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `currentMouseY` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `linkPreviewCursor` | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `targetEntity` | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `snapableTemplateTileList` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

