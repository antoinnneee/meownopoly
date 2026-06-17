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

Les types de cases suivants sont supportés :

| Type | Valeur | Nom |
|------|--------|-----|
| CS_KibbleDispenser | 0 | Départ |
| CS_RestArea | 1 | Propriétés |
| CS_CardBoardBox | 2 | Caisse de Communauté |
| CS_CatNip | 3 | Chance |
| CS_Jail | 4 | Prison (Visite) |
| CS_ToJail | 5 | Allez en Prison |
| CS_CatDoor | 6 | Gare |
| CS_FreeNap | 7 | Free Parking |
| CS_Device | 8 | Service |
| CS_Taxe | 9 | Taxe |

La prévisualisation ne s'appuie pas sur une icône statique par type : elle instancie un vrai `SnapableCaseTile`, rendu par son propre contenu.

## Intégration dans l'éditeur

L'éditeur utilise automatiquement cette fonctionnalité quand un type de case est sélectionné :

```qml
AssetPreviewCursor {
    id: assetPreview
    parent: workArea
    assetCategory: selectionPanel.currentSelectedAssetCategory
    assetType: selectionPanel.currentSelectedAssetType
    assetId: selectionPanel.currentSelectedAssetId
    caseType: selectionPanel.caseTypeSelected
    isCasePreview: selectionPanel.caseTypeSelected !== -1
    unitSizeWidth: logic.tileLogic.currentElementWidth
    unitSizeHeight: logic.tileLogic.currentElementHeight
    gridManager: gameGrid
    sidePanel: sidePanel
}
```

## Fonctionnement interne

1. Le composant charge automatiquement le bon type de prévisualisation selon la valeur de `isCasePreview`
2. Pour les cases, il utilise `ItemSnapableFactory.createItemSnapable(caseType)` pour créer le `snapableParameters` (un `SnapableCaseTile` est instancié via `casePreviewComponent`)
3. Les effets visuels sont appliqués de la même manière que pour les décorations

## Avantages

- **Cohérence** : Même interface utilisateur pour les décorations et les cases
- **Prévisualisation** : Les utilisateurs peuvent voir exactement ce qu'ils vont placer
- **Feedback visuel** : Le curseur montre un vrai `SnapableCaseTile` correspondant au type de case sélectionné
- **Effets visuels** : Support complet des effets visuels pour les cases aussi

## Notes techniques

- Les cases créées pour la prévisualisation sont temporaires et ne sont pas ajoutées au jeu
- Le composant gère automatiquement le basculement entre les deux modes de prévisualisation
