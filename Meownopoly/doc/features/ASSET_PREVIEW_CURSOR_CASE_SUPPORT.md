# Support des SnapableCaseTile dans AssetPreviewCursor

## Vue d'ensemble

Le composant `AssetPreviewCursor` a été étendu pour supporter la prévisualisation des `SnapableCaseTile` en plus des décorations existantes. Cette fonctionnalité permet aux utilisateurs de voir un aperçu des cases avant de les placer sur la grille de l'éditeur.

## Nouvelles propriétés

### Propriétés ajoutées

- `caseType: int` - Le type de case à prévisualiser (correspond aux valeurs de `Case::CaseType`)
- `isCasePreview: bool` - Indique si la prévisualisation est pour une case (true) ou une décoration (false)

### Propriétés existantes modifiées

- `visible` - Maintenant visible si soit les propriétés de décoration sont définies, soit `isCasePreview` est true et `caseType` est valide

## Utilisation

### Prévisualisation de décorations (comportement existant)

```qml
AssetPreviewCursor {
    assetCategory: "decoration"
    assetType: "grass"
    assetId: "1"
    isCasePreview: false  // ou omis (défaut)
    // ... autres propriétés
}
```

### Prévisualisation de cases (nouvelle fonctionnalité)

```qml
AssetPreviewCursor {
    caseType: 1  // Case::CS_RestArea
    isCasePreview: true
    // ... autres propriétés
}
```

## Types de cases supportés

Les types de cases suivants sont supportés avec leurs icônes correspondantes :

| Type | Valeur | Nom | Icône |
|------|--------|-----|-------|
| CS_KibbleDispenser | 0 | Départ | kibble_dispenser.png |
| CS_RestArea | 1 | Propriétés | rest_area.png |
| CS_CardBoardBox | 2 | Caisse de Communauté | cardboard_box.png |
| CS_CatNip | 3 | Chance | cat_nip.png |
| CS_Jail | 4 | Prison (Visite) | jail.png |
| CS_ToJail | 5 | Allez en Prison | to_jail.png |
| CS_CatDoor | 6 | Gare | cat_door.png |
| CS_FreeNap | 7 | Free Parking | free_nap.png |
| CS_Device | 8 | Service | device.png |
| CS_Taxe | 9 | Taxe | taxe.png |

## Intégration dans l'éditeur

L'éditeur utilise automatiquement cette fonctionnalité quand un type de case est sélectionné :

```qml
AssetPreviewCursor {
    id: assetPreview
    parent: workArea
    assetCategory: root.selectedAssetCategory
    assetType: root.selectedAssetType
    assetId: root.selectedAssetId
    caseType: selectionPanel.caseTypeSelected
    isCasePreview: selectionPanel.caseTypeSelected !== -1
    unitSizeWidth: logic.tileLogic.currentElementWidth
    unitSizeHeight: logic.tileLogic.currentElementHeight
    gridManager: editorGrid
    selectionPanel: selectionPanel
}
```

## Fonctionnement interne

1. Le composant charge automatiquement le bon type de prévisualisation selon la valeur de `isCasePreview`
2. Pour les cases, il utilise `Game.getNewCaseType(caseType)` pour créer une instance temporaire
4. Les effets visuels sont appliqués de la même manière que pour les décorations

## Avantages

- **Cohérence** : Même interface utilisateur pour les décorations et les cases
- **Prévisualisation** : Les utilisateurs peuvent voir exactement ce qu'ils vont placer
- **Feedback visuel** : Le curseur montre l'icône appropriée selon le type de case
- **Effets visuels** : Support complet des effets visuels pour les cases aussi

## Notes techniques

- Les cases créées pour la prévisualisation sont temporaires et ne sont pas ajoutées au jeu
- Le composant gère automatiquement le basculement entre les deux modes de prévisualisation
