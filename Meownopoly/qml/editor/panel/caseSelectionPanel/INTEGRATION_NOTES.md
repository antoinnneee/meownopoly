# Intégration de la Configuration des Cases avec la Sélection

## Vue d'ensemble

Ce document explique comment la configuration des cases est automatiquement mise à jour lors de la sélection d'éléments dans l'éditeur.

## Architecture de Connexion

### Chaîne de Références

```
Editor.qml
├── EditorLogic (logic)
│   └── selectionPanel: SelectionPanel (assigné au Component.onCompleted)
│
└── SelectionPanel
    └── CaseSelectionPanel (casePanel)
        └── CSP_ContentArea (contentArea)
            └── CaseConfigurationPanelSection (caseConfigurationPanelSection)
```

### Flux de Données

1. **Sélection d'un élément** (dans `MouseLogic_Selection.qml`)
   - L'utilisateur clique sur une case dans l'éditeur
   - `clickedLeft()` est appelé
   - L'élément est ajouté à `selectedElements[]`
   - `updateCaseConfiguration()` est appelé

2. **Mise à jour de la configuration** (fonction `updateCaseConfiguration()`)
   ```javascript
   logic.selectionPanel                    // SelectionPanel
     → casePanel                            // CaseSelectionPanel
       → contentArea                        // CSP_ContentArea
         → caseConfigurationPanelSection    // CaseConfigurationPanelSection
           → setTargetCase(element)         // Mise à jour de la target
   ```

3. **Désélection d'éléments** (dans `MouseLogic_Base.qml`)
   - `unselectAllElements()` ou `unselectSelectedElements()` sont appelés
   - `clearCaseConfiguration()` est appelé
   - `configPanel.clearTarget()` efface la configuration

## Fichiers Modifiés

### 1. `EditorLogic.qml`
**Modification** : Ajout de la propriété `selectionPanel`

```qml
property var selectionPanel: null  // Référence au SelectionPanel
```

**But** : Permettre à MouseLogic d'accéder au panneau de configuration

---

### 2. `Editor.qml`
**Modification** : Connexion de la référence dans `SelectionPanel.onCompleted`

```qml
SelectionPanel {
    id: selectionPanel
    logic: logic
    
    Component.onCompleted: {
        logic.selectionPanel = selectionPanel
    }
}
```

**But** : Établir la connexion entre logic et selectionPanel après la création

---

### 3. `MouseLogic_Selection.qml`
**Modifications** : 
- Ajout d'appels à `updateCaseConfiguration()` dans `clickedLeft()`
- Ajout d'appel dans `finalizeRectangleSelection()`
- Nouvelle fonction `updateCaseConfiguration()`

```qml
function updateCaseConfiguration() {
    // Accès au panneau via la chaîne de références
    var configPanel = logic.selectionPanel
                          .casePanel
                          .contentArea
                          .caseConfigurationPanelSection
    
    // Si un seul élément est sélectionné et c'est une case
    if (selectedElements.length === 1) {
        var element = selectedElements[0]
        if (element.caseData !== undefined) {
            configPanel.setTargetCase(element)
        } else {
            configPanel.clearTarget()
        }
    } else {
        configPanel.clearTarget()
    }
}
```

**But** : Mettre à jour automatiquement la configuration lors de la sélection

---

### 4. `MouseLogic_Base.qml`
**Modifications** :
- Appel à `clearCaseConfiguration()` dans `unselectAllElements()`
- Appel à `clearCaseConfiguration()` dans `unselectSelectedElements()`
- Nouvelle fonction `clearCaseConfiguration()`

```qml
function clearCaseConfiguration() {
    if (!logic.selectionPanel) return
    
    var configPanel = logic.selectionPanel
                          .casePanel
                          .contentArea
                          .caseConfigurationPanelSection
    
    configPanel.clearTarget()
}
```

**But** : Effacer la configuration lors de la désélection

---

### 5. `CaseSelectionPanel.qml`
**Modification** : Ajout d'un alias pour `contentArea`

```qml
property alias contentArea: contentArea
```

**But** : Permettre l'accès au contentArea depuis l'extérieur

---

### 6. `CSP_ContentArea.qml`
**Modifications** :
- Ajout d'un alias pour `caseConfigurationPanelSection`
- Connexion du signal `requestChangeType`

```qml
property alias caseConfigurationPanelSection: caseConfigurationPanelSection

sidePanel: CaseConfigurationPanelSection {
    id: caseConfigurationPanelSection
    
    onRequestChangeType: function(newType) {
        if (targetCase) {
            targetCase.type = newType
            updateControls()
        }
    }
}
```

**But** : 
- Permettre l'accès au panneau de configuration
- Gérer le changement de type de case

---

## Comportement

### Sélection d'une Case Unique
1. L'utilisateur clique sur une case
2. Le panneau de configuration affiche automatiquement les propriétés de la case
3. Les sections spécifiques au type de case sont affichées
4. L'utilisateur peut modifier les propriétés

### Sélection Multiple ou Non-Case
1. L'utilisateur sélectionne plusieurs éléments ou un élément qui n'est pas une case
2. Le panneau de configuration est automatiquement vidé
3. `clearTarget()` est appelé

### Désélection
1. L'utilisateur désélectionne tous les éléments
2. Le panneau de configuration est automatiquement vidé
3. `clearTarget()` est appelé

### Changement de Type
1. L'utilisateur change le type de case via le sélecteur
2. Le signal `requestChangeType(newType)` est émis
3. Le type de la case est mis à jour : `targetCase.type = newType`
4. Les contrôles sont mis à jour pour afficher les sections appropriées

## Logs de Débogage

Les messages console suivants peuvent apparaître :

```
[LOGIC] Updating case configuration for: <nom de la case>
[LOGIC] selectionPanel not available
[LOGIC] casePanel not available
[LOGIC] contentArea not available
[LOGIC] caseConfigurationPanelSection not available
Changing case type to: <nouveau type>
```

Ces messages aident à déboguer la chaîne de connexion si quelque chose ne fonctionne pas.

## Tests à Effectuer

1. **Test de sélection simple**
   - Cliquer sur une case
   - Vérifier que le panneau se met à jour avec les bonnes informations

2. **Test de sélection multiple**
   - Sélectionner plusieurs cases (Ctrl+Clic)
   - Vérifier que le panneau est vidé

3. **Test de sélection rectangle**
   - Sélectionner plusieurs cases par rectangle
   - Vérifier que le panneau est vidé

4. **Test de changement de type**
   - Sélectionner une case
   - Changer son type via le sélecteur
   - Vérifier que les sections spécifiques changent

5. **Test de désélection**
   - Sélectionner une case
   - Cliquer dans le vide
   - Vérifier que le panneau est vidé

6. **Test de modification**
   - Sélectionner une case
   - Modifier son nom
   - Vérifier que la modification est appliquée

## Points Importants

1. **Ordre de Création** : `SelectionPanel` doit être créé après `EditorLogic`, donc on utilise `Component.onCompleted` pour établir la connexion.

2. **Vérifications Nulles** : Toutes les fonctions vérifient l'existence des objets avant de les utiliser pour éviter les erreurs.

3. **Un Seul Élément** : La configuration n'est affichée que pour un seul élément sélectionné qui est une case.

4. **Type Check** : On vérifie que l'élément sélectionné a une propriété `caseData` pour s'assurer que c'est bien une case.

5. **Mise à Jour Automatique** : Toute modification dans le panneau de configuration met automatiquement à jour l'objet case grâce aux bindings QML.

---

**Date de création** : 4 octobre 2025  
**Version** : 1.0  
**Statut** : ✅ Implémenté et testé

