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

Utilisée comme `before` pour **TileModified** et **TileDeleted**. Après chaque `updateEditState`, le C++ appelle `commitCurrentState()` sur la tile concernée.

---

## 2. Côté C++

### Map (`map.h` / `map.cpp`)

- **Stocks** : `m_undoStack`, `m_redoStack`, `m_isRestoringState`.
- **API** : `pushDelta(delta)`, `undo()`, `redo()`, `canSave()` (= `!m_isRestoringState`).
- **Tiles** : `tileById(id)`, `addTile(tile)`, `removeTile(id)`. Les `ItemSnapable` sont en **CppOwnership** ; le destructeur de `Map` les détruit.
- **applyDelta(delta, applyBefore)** :
  - **TileModified** : `tileById` → `copyFrom(tmp)` depuis `before` ou `after` → `commitCurrentState()`.
  - **TileAdded** (undo) / **TileDeleted** (redo) : retrait de la tile, `removeTile` puis `deleteLater()` sur l’objet C++, puis `tileRemovedFromHistory(tileId)`.
  - **TileAdded** (redo) / **TileDeleted** (undo) : création d’un nouvel `ItemSnapable` depuis le JSON, `addTile`, `tileRestoredFromHistory(tile)`.
  - **MetadataChanged** : `new MapInfo(jsonState)` puis `setMapInfo(mi)` (remplace le `MapInfo` C++ de la carte).

Ordre dans `undo()` / `redo()` : d’abord `emit forceUnselectAll()`, puis boucle `applyDelta`, pour que la déselection QML (et la restauration des bindings) ait lieu avant la mise à jour des données.

### Game (`game.h` / `game_loader.cpp`)

- **updateEditState(type, tile, groupId)** : construit un `EditDelta` (`before` = `tile->lastKnownJson()`, `after` = `tile->toJSON()`), appelle `tile->commitCurrentState()` puis `map->pushDelta(delta)`. Ignoré si `!map->canSave()` ou `!tile`.
- **updateEditMetadata(beforeJson, afterJson)** : push un delta `MetadataChanged` avec les deux JSON (ex. `mapInfo.toJSON()` avant/après).
- **beginTransaction()** : pose `m_currentTransaction = QUuid::createUuid()` ; renvoyé pour être passé à `updateEditState` si besoin.
- **commitTransaction()** : remet `m_currentTransaction` à null. Tous les deltas partagant le même `groupId` sont annulés/refaits en une seule étape.
- **removeMapTile(tileId)** : retire la tile de `m_tiles` et appelle `tile->deleteLater()`. Sûr même si la tile a déjà été retirée (ex. par undo).

Signaux relayés vers QML : `tileRemoved(QUuid)`, `forceUnselectAll()` (depuis les signaux homonymes de `Map`).

---

## 3. Côté QML — Enregistrement des actions

### Tiles

- **Déplacement (drag)** : dans `MouseLogic_Selection.release()`, après `updateRelativePosition()` sur les éléments sélectionnés, `beginTransaction()` puis pour chaque élément `updateEditState(EditDelta.TileModified, snapableParameters, txId)` puis `commitTransaction()`.
- **Suppression (touche Delete)** : `beginTransaction()`, pour chaque élément `updateEditState(EditDelta.TileDeleted, snapableParameters, txId)` puis `deleteRequest(false)` (qui mène à `Game.removeMapTile(uuid)`), puis `commitTransaction()`.
- **Création** (pose, zone, lien, template) : après création, `updateEditState(EditDelta.TileAdded, snapableParameters)` (ou avec transaction si plusieurs tiles).
- **Redimensionnement** : dans `ResizeHandle.qml` `onReleased`, `updateRelativePosition()` puis `Game.updateEditState(EditDelta.TileModified, targetElement.snapableParameters)`.
- **Effets visuels** : timer 200 ms sur `onEffectChanged` ; au déclenchement, transaction + `updateEditState(TileModified)` pour chaque élément sélectionné.

### Métadonnées (MapInfo)

Avant toute modification du `mapInfo` (nom, description, fond d’écran, scaling, etc.) :

```qml
var before = logic.mapInfo.toJSON()   // ou mapInfo.toJSON() selon le contexte
logic.mapInfo.backgroundPath = nouvelleValeur
Game.updateEditMetadata(before, logic.mapInfo.toJSON())
```

Pour les sliders (ex. taille de tuile) : capturer `before` dans `onPressedChanged` quand `pressed === true`, et appeler `updateEditMetadata(_beforeJson, logic.mapInfo.toJSON())` quand `pressed === false`.

`MapInfo.toJSON()` doit être exposé en QML (`Q_INVOKABLE` dans `mapinfo.h`).

---

## 4. Lecture undo/redo et synchronisation QML

- **Ctrl+Z** : `Game.askPreview()` → `Map::undo()`.
- **Ctrl+Y** : `Game.askNext()` → `Map::redo()`.

Lors d’un undo/redo :

1. **forceUnselectAll** est émis avant les `applyDelta`, pour que QML détruise les bindings de drag et restaure les bindings « données » (voir ci‑dessous).
2. **applyDelta** met à jour les objets C++ (tiles via `copyFrom`, ou `MapInfo` via `setMapInfo`).
3. Pour les tiles, le visuel suit si les bindings QML `x`/`y` sont bien recalculés à partir de `displayParameter.gridRelativePositionX/Y` après déselection (sinon l’élément reste figé).

### Bindings après déselection

Quand on désélectionne des éléments (y compris après undo), `destroyBindingsForElement` ne doit **pas** figer `element.x`/`element.y` en valeur scalaire. Il faut rétablir un binding vers les données C++ :

```qml
element.x = Qt.binding(function() {
    return element.snapableParameters.displayParameter.gridRelativePositionX * element.gridManager.gridSize
})
element.y = Qt.binding(function() { ... })
```

Sinon, après un undo, `copyFrom` met à jour les données mais aucun binding ne réagit → l’affichage ne bouge pas.

### Métadonnées et fond d’écran

Le `mapInfo` affiché dans l’UI est un objet QML (`Base_Board.mapInfo`) distinct du `MapInfo*` C++ de la `Map`. Quand `applyDelta` fait `setMapInfo(mi)` sur la carte, il faut que le QML se synchronise. Dans `Editor.qml`, un `Connections` sur `MapFileManager.currentMap` avec `onMapInfoChanged` qui appelle `mapInfo.setMapInfo(MapFileManager.currentMap.mapInfo)` assure que le fond d’écran (et le reste des métadonnées) se met à jour après un undo/redo métadonnées.

---

## 5. Suppression d’une tile (côté utilisateur ou undo)

- **Côté utilisateur** : le QML retire l’élément visuel et appelle `Game.removeMapTile(uuid)`. La Map retire la tile de `m_tiles` et fait `deleteLater()` sur l’`ItemSnapable`.
- **Undo d’un ajout** / **redo d’une suppression** : dans `applyDelta`, la Map retire la tile et fait `deleteLater()`, puis émet `tileRemovedFromHistory(tileId)`. Le slot QML `onTileRemoved` peut appeler `removeMapTile` ; c’est un no‑op car la tile est déjà retirée.

Aucun `ItemSnapable` ne doit être détruit par le QML (`destroy`) : la durée de vie est gérée par la Map / `removeMapTile` et `deleteLater()`.

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
| Métadonnées | `qml/editor/panel/mapInfoPanel/MapInfoPanel.qml`, `MapSidePanel.qml`, `MapInfoDrawer.qml` |
| Bindings après déselection | `qml/editor/logic/MouseLogic_Base.qml` (`destroyBindingsForElement`) |
| Sync mapInfo undo | `qml/editor/Editor.qml` (Connections `onMapInfoChanged`) |
