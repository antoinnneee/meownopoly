# Système Undo/Redo de l'éditeur de carte

L’éditeur utilise un undo/redo **par deltas** : chaque action enregistre un avant/après (JSON) au lieu de snapshots complets. L’historique est porté par la `Map` courante ; les tiles sont mises à jour **en place** (même objet C++, pas de recréation).

---

## 1. Modèle de données

### EditDelta (`editdelta.h`)

```cpp
struct EditDelta {
    EditDeltaType::Type type;  // TileModified, TileAdded, TileDeleted, MetadataChanged
    QUuid tileId;              // identifiant de la tile (vide pour MetadataChanged)
    QUuid groupId;             // null = action atomique ; même ID = une seule étape undo
    QJsonObject before;        // état avant (vide si TileAdded)
    QJsonObject after;         // état après (vide si TileDeleted)
};
```

- **TileModified** : déplacement, redimensionnement, liens — `before` = dernier état connu, `after` = état actuel.
- **TileAdded** : `before` vide, `after` = JSON de la nouvelle tile.
- **TileDeleted** : `before` = dernier état connu, `after` vide.
- **MetadataChanged** : `before` / `after` = JSON du `MapInfo` (nom, description, fond d’écran, etc.).

### Shadow copy (ItemSnapable)

Chaque `ItemSnapable` garde une copie JSON de son dernier état « validé » :

- `lastKnownJson()` : lecture.
- `commitCurrentState()` : `m_lastKnownJson = toJSON()`.

Utilisée comme `before` pour **TileModified** et **TileDeleted**. Après chaque `updateMap`, le C++ appelle `commitCurrentState()` sur la tile concernée.

---

## 2. Côté C++

### Map (`map.h` / `map.cpp`)

- **Stocks** : `m_undoStack`, `m_redoStack`, `m_isRestoringState`.
- **API** : `pushDelta(delta)`, `undo()`, `redo()`, `canSave()` (= `!m_isRestoringState`).
- **Tiles** : `tileById(id)`, `addTile(tile)`, `removeTile(id)`. Les `ItemSnapable` sont en **CppOwnership** ; le destructeur de `Map` les détruit.
- **applyDelta(delta, applyBefore, touchedOut)** :
  - **TileModified** : `tileById` → `applyJson(jsonState)` (depuis `before` ou `after`) → `rewireLinks(tile, jsonState, touchedOut)` → `commitCurrentState()`.
  - **TileAdded** (undo) / **TileDeleted** (redo) : `unwireLinks` → `removeTile` (stash dans `m_pendingDestroy`, sans `deleteLater`) → `tileRemovedFromHistory(tileId)` → `finalizeTile` (`deleteLater`).
  - **TileAdded** (redo) / **TileDeleted** (undo) : création d’un nouvel `ItemSnapable` depuis le JSON, `addTile`, `tileRestoredFromHistory(tile)`.
  - **MetadataChanged** : `new MapInfo(jsonState)` puis `setMapInfo(mi)` (remplace le `MapInfo` C++ de la carte).

Ordre dans `undo()` / `redo()` : d’abord `emit forceUnselectAll()`, puis boucle `applyDelta`, pour que la déselection QML (et la restauration des bindings) ait lieu avant la mise à jour des données.

### Game (`game.h` / `game_loader.cpp`)

- **updateMap(type, tile, groupId)** : construit un `EditDelta` (`before` = `tile->lastKnownJson()`, `after` = `tile->toJSON()`), appelle `tile->commitCurrentState()` puis `map->pushDelta(delta)`. Ignoré si `!map->canSave()` ou `!tile`.
- **updateMapMetadata(beforeJson, afterJson)** : push un delta `MetadataChanged` avec les deux JSON (ex. `mapInfo.toJSON()` avant/après).
- **beginTransaction()** : pose `m_currentTransaction = QUuid::createUuid()` ; renvoyé pour être passé à `updateMap` si besoin.
- **commitTransaction()** : remet `m_currentTransaction` à null. Tous les deltas partagant le même `groupId` sont annulés/refaits en une seule étape.
- **finalizeDeletedTile(tileId)** : libère l’`ItemSnapable` C++ stashé par `map->removeTile` (appelle `map->finalizeTile`, qui fait le `deleteLater()`). Invoqué à la fin de l’animation de suppression.

Signaux relayés vers QML : `tileRemoved(QUuid)`, `forceUnselectAll()` (depuis les signaux homonymes de `Map`).

---

## 3. Côté QML — Enregistrement des actions

### Tiles

- **Déplacement (drag)** : dans `MouseLogic_Selection.release()`, après `updateRelativePosition()` sur les éléments sélectionnés, `beginTransaction()` puis pour chaque élément `updateMap(EditDelta.TileModified, snapableParameters, txId)` puis `commitTransaction()`.
- **Suppression (touche Delete)** : enregistré dans `EditorController.qml` (handler `Qt.Key_Delete`). `beginTransaction()`, pour chaque élément `Game.updateMap(EditDelta.TileDeleted, element.snapableParameters, txId)` puis `element.deleteRequest(false)`, puis `commitTransaction()`. Le `deleteRequest(false)` lance l’animation de suppression qui se termine par `Game.finalizeDeletedTile(uuid)`.
- **Création** (pose, zone, lien, template) : après création, `updateMap(EditDelta.TileAdded, snapableParameters)` (ou avec transaction si plusieurs tiles).
- **Redimensionnement** : dans `ResizeHandle.qml` `onReleased`, `updateRelativePosition()` puis `Game.updateMap(EditDelta.TileModified, targetElement.snapableParameters)`.
- **Effets visuels** : timer 200 ms sur `onEffectChanged` ; au déclenchement, transaction + `updateMap(TileModified)` pour chaque élément sélectionné.

### Métadonnées (MapInfo)

Avant toute modification du `mapInfo` (nom, description, fond d’écran, scaling, etc.) :

```qml
var before = logic.mapInfo.toJSON()   // ou mapInfo.toJSON() selon le contexte
logic.mapInfo.backgroundPath = nouvelleValeur
Game.updateMapMetadata(before, logic.mapInfo.toJSON())
```

Pour les sliders (ex. taille de tuile) : capturer `before` dans `onPressedChanged` quand `pressed === true`, et appeler `updateMapMetadata(_beforeJson, logic.mapInfo.toJSON())` quand `pressed === false`.

`MapInfo.toJSON()` doit être exposé en QML (`Q_INVOKABLE` dans `mapinfo.h`).

---

## 4. Lecture undo/redo et synchronisation QML

- **Ctrl+Z** : `Game.askPreview()` → `Map::undo()`.
- **Ctrl+Y** : `Game.askNext()` → `Map::redo()`.

Lors d’un undo/redo :

1. **forceUnselectAll** est émis avant les `applyDelta`, pour que QML détruise les bindings de drag et restaure les bindings « données » (voir ci‑dessous).
2. **applyDelta** met à jour les objets C++ (tiles via `applyJson`, ou `MapInfo` via `setMapInfo`).
3. Pour les tiles, le visuel suit si les bindings QML `x`/`y` sont bien recalculés à partir de `displayParameter.gridRelativePositionX/Y` après déselection (sinon l’élément reste figé).

### Bindings après déselection

Quand on désélectionne des éléments (y compris après undo), `destroyBindingsForElement` ne doit **pas** figer `element.x`/`element.y` en valeur scalaire. Il faut rétablir un binding vers les données C++ :

```qml
element.x = Qt.binding(function() {
    return element.snapableParameters.displayParameter.gridRelativePositionX * element.gridManager.gridSize
})
element.y = Qt.binding(function() { ... })
```

Sinon, après un undo, `applyJson` met à jour les données mais aucun binding ne réagit → l’affichage ne bouge pas.

### Métadonnées et fond d’écran

Le `mapInfo` affiché dans l’UI (`Base_Board.mapInfo`) est désormais un **binding direct** sur `MapFileManager.currentMap.mapInfo`. Quand `applyDelta` fait `setMapInfo(mi)` sur la carte, le fond d’écran (et le reste des métadonnées) se resynchronise donc **automatiquement** après un undo/redo métadonnées. L’ancien `Connections` sur `MapFileManager.currentMap` avec `onMapInfoChanged` (qui recopiait `Map.mapInfo` dans l’objet QML inline) a été **supprimé** : la synchro est portée par le binding.

---

## 5. Suppression d’une tile (côté utilisateur ou undo)

- **Côté utilisateur** : la suppression est en deux temps. `Game.updateMap(EditDelta.TileDeleted, …)` appelle `map->removeTile`, qui retire la tile de `m_tiles` et la **stash** dans `m_pendingDestroy` (sans `deleteLater`). L’animation de suppression (`deleteRequest`) se termine par `Game.finalizeDeletedTile(uuid)` → `map->finalizeTile`, qui fait alors le `deleteLater()` sur l’`ItemSnapable`.
- **Undo d’un ajout** / **redo d’une suppression** : dans `applyDelta`, la Map fait `unwireLinks` → `removeTile` (stash dans `m_pendingDestroy`) → émet `tileRemovedFromHistory(tileId)` → `finalizeTile` (`deleteLater`). Le slot QML `onTileRemoved` appelle `logic.tileLogic.deleteElement(...)` pour retirer l’élément visuel.

Aucun `ItemSnapable` ne doit être détruit par le QML (`destroy`) : la durée de vie est gérée par la Map via `removeTile` (stash) puis `finalizeTile` (`deleteLater()`).

---

## 6. Fichiers principaux

| Rôle | Fichiers |
|------|----------|
| Définition delta | `cpp/game/map/editdelta.h` |
| Stack + apply | `cpp/game/map/map.h`, `map.cpp` |
| API Game | `cpp/game/game.h`, `cpp/game/game_loader.cpp` |
| Shadow copy | `cpp/game/item_snapable/ItemSnapable.h` |
| Enregistrement drag/delete/pose | `qml/editor/logic/MouseLogic_Selection.qml`, `EditorController.qml`, `MouseLogic_Pose.qml`, etc. |
| Resize | `qml/meowComponent/snapable/ResizeHandle.qml` |
| Métadonnées | `qml/editor/panel/mapInfoPanel/MapInfoPanel.qml`, `MapNavigationBar.qml`, `MapInfoDrawer.qml` |
| Bindings après déselection | `qml/editor/logic/MouseLogic_Base.qml` (`destroyBindingsForElement`) |
| Sync mapInfo undo | `qml/editor/Editor.qml` (binding direct sur `MapFileManager.currentMap.mapInfo`, plus de Connections) |
