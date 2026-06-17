# Placer un élément dans la carte par code (sans interaction souris)

Cette note documente le **pattern de placement programmatique** d'un élément
(`ItemSnapable`) dans l'éditeur. Il a été extrait du `CrateTestPanel` (badge de
test « Spawn crate », retiré avec la feature caisses) mais reste valable pour
**tout type de tile** : case, décoration, zone d'exclusion, etc.

L'intérêt : poser un élément en passant par **le même pipeline que la pose
souris**, donc compatible **collab (op bus)** et **undo/redo**, sans dupliquer
de logique.

## Recette

```js
// 1. Créer le jeu de paramètres via la factory (singleton ItemSnapableFactory).
//    Un helper par type de tile :
//      - createItemSnapable()                → tile vide (décoration par défaut)
//      - createItemSnapable(Case.CaseType…)  → case
//      - createPhysicZone()                  → zone polygonale
//    (la factory fixe le tileType et l'ownership JS ; cf. itemsnapablefactory.cpp)
const params = ItemSnapableFactory.createPhysicZone()

// 2. Configurer position + taille en coordonnées GRILLE (pas pixels).
params.displayParameter.gridRelativePositionX = gx
params.displayParameter.gridRelativePositionY = gy
params.displayParameter.unitSizeWidth  = w
params.displayParameter.unitSizeHeight = h
params.displayParameter.zLayer = z
// …et tout paramètre spécifique au type (zoneParameter.polygonPoints,
//   decorationParameter.assetId, caseData…).

// 3. Instancier la tile via la logique éditeur → crée le présentateur QML
//    (SnapableXxx) branché sur la grille.
const tile = logic.tileLogic.createItemSnapableTile(params)

// 4. Pousser dans le modèle de carte via le pipeline standard.
//    → émet tileAddedToMap → ItemSnapableEvents (C++) → bridges abonnés
//      (physique des zones, rendu…) ; transite par l'op bus si collab actif ;
//      empilé dans l'undo.
if (tile && tile.snapableParameters)
    Game.updateMap(EditDelta.TileAdded, tile.snapableParameters)
```

## Points clés

- **Coordonnées grille**, pas pixels. La conversion pixels↔grille est gérée
  ailleurs (cf. `GridManager`). Ici tout est en unités de cases.
- **Toujours passer par `Game.updateMap(EditDelta.TileAdded, …)`** : c'est ce
  qui déclenche la propagation (events C++, collab, undo). Instancier la tile
  sans cet appel la laisse orpheline du modèle.
- **Suppression programmatique symétrique** : récupérer les tiles via
  `logic.snapableTilesList`, filtrer par `snapableParameters.tileType`, puis
  `logic.tileLogic.deleteElement(tile)`.

## Voie « automation » (déjà câblée)

Les hooks d'automation de l'éditeur exposent ce pattern clé en main, utilisé
par le serveur MCP (cf. `doc/architecture/AUTOMATION_API.md`) :

- `editorAutomationHooks.placeAsset(id, cat, type, gx, gy)`
- `editorAutomationHooks.placeCase(caseType, gx, gy)`
- `editorAutomationHooks.placeZone(points, options)`

Ces fonctions encapsulent exactement la recette ci-dessus (factory →
displayParameter → `Game.updateMap`), donc compatibles collab/undo.
