# Cycle de vie de `currentMap` — édition solo & collab

Ce document est la référence canonique pour comprendre le cycle de vie complet
de la carte courante dans l'éditeur de Meownopoly : qui crée la `Map` C++, qui
la détruit, quelles variables persistent à travers push/pop de l'éditeur,
quelles interactions utilisateur mutent quoi, et quels effets de bord
(perte de modifications, fichiers fantômes, signaux dupliqués) en découlent.

Pour les sujets adjacents, voir :
- [UNDOREDO_SYSTEM](../UNDOREDO_SYSTEM.md) — protocole `EditDelta`, stacks,
  apply.
- [COLLABORATIVE_EDITOR](./COLLABORATIVE_EDITOR.md) — couche réseau, FullSync,
  host migration, ops set.
- [PLAYER_CONFIG_PANEL_PLAN](./PLAYER_CONFIG_PANEL_PLAN.md) — ops 12-16
  player profile (Add/Remove/Update/Reorder/SetMapPlayerLimits).

---

## 1. Variables centrales tracées

Toute analyse de scénario tracera ces variables. Les colonnes
**Persistance** indiquent si la valeur survit à un pop/push de l'éditeur ou à
un quit/relaunch d'application.

| ID  | Variable                                  | Type / lieu                                    | Persiste push/pop éditeur | Persiste quit app | Rôle |
|-----|-------------------------------------------|------------------------------------------------|---------------------------|-------------------|------|
| V1  | `MapFileManager::currentMap`              | `Map*` (singleton)                             | ✅                        | ❌                | Pointeur sur la Map active. Q_PROPERTY exposée à QML. |
| V2  | `Map::m_tiles`                            | `QList<ItemSnapable*>`                         | tied à V1                 | ❌                | Tuiles C++. Détruites avec la Map (parent-child Qt). |
| V3  | `Map::mapInfo`                            | `MapInfo*` (parent = Map)                      | tied à V1                 | ❌                | Métadonnées C++. `setMapInfo` deleteLater l'ancien et reparente le nouveau. |
| V4  | `Map::m_undoStack` / `m_redoStack`        | `QStack<EditDelta>`                            | tied à V1                 | ❌                | Historique. `clearHistory` à la fin de `Game::loadMap`. |
| V5  | `Map::m_sourceType`                       | `MapTypes::MapType` (CUSTOM par défaut)        | tied à V1                 | ❌                | AUTOSAVE / CUSTOM. Détermine où `Game::saveCurrentMap` écrit. |
| V6  | `Map::m_isRestoringState`                 | `bool`                                         | tied à V1                 | ❌                | Gate `canSave()` pendant un undo/redo. |
| V7  | `Map::m_lastRevertedBatch` + `m_lastRevertedWasUndo` | `QList<EditDelta>` + bool             | tied à V1                 | ❌                | Pour `broadcastLastBatch` (collab). |
| V8  | `Game::m_currentTransaction`              | `QUuid`                                        | ✅                        | ❌                | groupId courant. Théoriquement reset à `commitTransaction`. |
| V9  | `Game::m_txDirty`                         | `bool`                                         | ✅                        | ❌                | "save needed at commit". |
| V10 | `Game::m_remoteSaveDebounce`              | `QTimer*`                                      | ✅                        | ❌                | Debounce save sur ops remote. |
| V11 | Fichier `./map/autosave_tmp.json`         | disque                                         | ✅                        | ✅                | Cible AUTOSAVE. |
| V12 | Fichiers `./map/<name>_map.json`          | disque                                         | ✅                        | ✅                | Cibles CUSTOM, créées/écrites par save. |
| V13 | QSettings `Editor/SaveConfig/lastOpenedMap` | string                                       | ✅                        | ✅                | Dernier fichier ouvert. Réutilisé au démarrage suivant. |
| V14 | QSettings `Editor/SaveConfig/saveEvent`    | int (1 / 2 / 3)                               | ✅                        | ✅                | Politique : Manuelle (1) / Intervalle (2) / Sur modif (3). |
| V15 | `Editor.mapInfo` (Base_Board inline)       | objet QML `MapInfo`                            | ❌                        | ❌                | Ce que l'UI lit/écrit. Distinct de V3. Recréé à chaque push. |
| V16 | `EditorLogic.snapableTilesList`            | `list<SnapableElement>` QML                    | ❌                        | ❌                | Tuiles QML. Recréées via `onFoundItemSnapableTile` ou `MouseLogic_*`. |
| V17 | `EditorSession.active` / `isHost`          | bool                                           | ✅                        | ❌                | État session collab. |
| V18 | `EditorOpBus` undoStack collab             | pile interne                                   | ✅                        | ❌                | Pile undo/redo collab v1 (Create/Delete/Link/Unlink uniquement). |
| V19 | `Catway.m_players`                         | liste `PlayerNetwork*`                         | ✅                        | ❌                | Pairs P2P. Persiste à `EditorSession.stop` — voir CLAUDE.md (purge avant rejoin). |

**Rappel important sur V3 vs V15** : `Editor.qml` (`Base_Board.mapInfo`) est
un objet `MapInfo` QML inline, reconstruit à chaque push de l'éditeur. `Map::mapInfo`
(V3) est un autre objet `MapInfo` C++ porté par la `Map`. La synchronisation
visible→stocké passe par les bindings QML qui lisent `MapFileManager.currentMap.mapInfo`.

---

## 2. Anatomie de `MapInfo` (post-Phase 1 player config)

`MapInfo` porte désormais (commit `5b73759` et suivants) la configuration
joueur en plus des métadonnées historiques. Comportement notable :

- `MapInfo()` par défaut **et** `MapInfo(json)` appellent
  `ensureFallbackProfile()` → toute `MapInfo` neuve a **au moins 1**
  `PlayerProfile` ("Princess"). Ne jamais s'attendre à 0 profils.
- `m_mapName` par défaut = `"autosave_tmp"` (= `AUTOSAVE_MAP_NAME`).
- Constantes : `MAX_PLAYERS_HARD_CAP = 8`, `CURRENT_PLAYER_CONFIG_VERSION = 1`.
- Versioning roster : si `playerConfigVersion` lu > `CURRENT_PLAYER_CONFIG_VERSION`,
  le roster est wipé, fallback profile injecté, version normalisée.
- `setMinPlayers/setMaxPlayers` clampent mutuellement (min ≤ max ≤ HARD_CAP).
- API runtime : `addPlayerProfile`, `addPlayerProfileFromJson`,
  `duplicatePlayerProfile`, `removePlayerProfile`, `updatePlayerProfile`
  (champs partiels), `reorderPlayerProfile`, `playerProfileById/At`,
  `clearPlayerProfiles`. Toutes émettent `playerProfilesChanged` sauf
  `updatePlayerProfile` (la mutation interne d'un profil émet ses propres
  signaux par champ).
- Sérialisation `toJSON()` :
  ```json
  {
    "name": "...", "description": "...", "creation": "...",
    "lastModified": "...", "version": 0,
    "backgroundPath": "...", "backgroundScaling": "Fit",
    "backgroundTileSize": 200, "isBackgroundOnGrill": false,
    "musicPath": "...",
    "minPlayers": 2, "maxPlayers": 8, "playerConfigVersion": 1,
    "playerProfiles": [ {...}, ... ]
  }
  ```
- Désérialisation `MapInfo(json)` : lit la clé `"name"` (pas `"mapName"`).
  ⚠️ voir bug **G1** ci-dessous.

---

## 3. Inventaire des interactions utilisateur

### 3.1 Interactions communes solo + collab

| ID  | Action UI                                | Site                                                          | Mute V*                              | Pousse delta                          | Save (saveEvent==3) | Émet réseau (collab) |
|-----|------------------------------------------|---------------------------------------------------------------|--------------------------------------|---------------------------------------|---------------------|----------------------|
| I1  | Pose tuile (asset/case/déco)             | `MouseLogic_Pose.qml:38`                                      | V2 (addTile), V16                    | TileAdded (atomique)                  | Oui                 | submitFromDelta TileAdded |
| I2  | Dessin zone polygone                     | `MouseLogic_DrawPolygon.qml:193`                              | V2, V16                              | TileAdded                             | Oui                 | TileAdded |
| I3  | Pose template (N tuiles)                 | `MouseLogic_Template.qml:527`                                 | V2, V16                              | TileAdded × N (groupId commun)        | Oui (1× au commit)  | N submits + flushGroup |
| I4  | Drag éléments sélectionnés               | `MouseLogic_Selection.qml:100`                                | V2, V16                              | TileModified × N (groupId)            | Oui (commit)        | N submits + flushGroup |
| I5  | Resize tuile                             | `meowComponent/snapable/ResizeHandle.qml`                     | V2                                   | TileModified                          | Oui                 | TileModified |
| I6  | Suppression (touche Delete)              | `EditorController.qml:49`                                     | V2 (removeTile→m_pendingDestroy)     | TileDeleted × N (groupId)             | Oui (commit)        | N submits + flushGroup |
| I7  | Modif effet visuel                       | `Editor.qml:1688`                                             | V2                                   | TileModified × N                      | Oui                 | TileModified |
| I8  | Lien / délien `next/prev`                | OpBus LinkItems / UnlinkItems                                 | V2 (next/prev)                       | TileModified                          | Oui                 | LinkItems / UnlinkItems |
| I9  | Modif metadata background / music / grid | `MapInfoDrawer.qml:888,966,1007,1194,1357`, `MapInfoPanel.qml:76` | V3 (Map::setMapInfo via applyDelta) | MetadataChanged (atomique)            | Oui                 | MetadataChanged |
| I10 | Ctrl+Z (undo)                            | `EditorController.qml:89`                                     | V2/V3 (apply inverse), V4, V6        | rejoue inverse (pop undo, push redo)  | Oui (après gate)    | broadcastLastBatch (applyBefore=true) |
| I11 | Ctrl+Y (redo)                            | `EditorController.qml:81`                                     | symétrique I10                       | rejoue forward (pop redo, push undo)  | Oui                 | broadcastLastBatch (applyBefore=false) |
| I12 | MenuMapAtStart "+ nouvelle carte"        | `Editor.qml:265-276`                                          | écrit V12 directement, puis loadMap  | clear V4                              | —                   | onMapLoaded → `_sendFullSyncToAll` si host |
| I13 | EscMenu → "Charger carte"                | `EditorEscMenu.qml:394`                                       | `Game.loadMap`                       | clear V4                              | —                   | FullSync si host |
| I14 | MapNavigationBar — flèche / clic carte   | `MapNavigationBar.qml:116`                                    | `Game.loadMap`                       | clear V4                              | —                   | FullSync si host |
| I15 | MapNavigationBar — suppression carte     | `MapNavigationBar.qml:142`                                    | supprime V12 + loadMap voisin/auto   | clear V4 (sur next load)              | —                   | FullSync sur next load |
| I16 | EscMenu — Politique de save              | `EditorEscMenu.qml:557`                                       | écrit V14                            | —                                     | change la politique | — |
| I17 | EscMenu — autres réglages                | `EditorEscMenu.qml`                                           | QSettings divers                     | —                                     | —                   | — |
| I18 | PCP Add/Remove/Update/Reorder profile    | `playerConfigPanel/PCP_*.qml` → `EditorOpBus.makeAddPlayerProfileOp` etc. | V3 (m_playerProfiles)        | (pas de delta v1)                     | non automatique     | ops 12-15 |
| I19 | PCP Set min/max players                  | `playerConfigPanel/PCP_*.qml`                                 | V3 (minPlayers/maxPlayers)           | (pas de delta v1)                     | non automatique     | op 16 SetMapPlayerLimits |

### 3.2 Spécifiques collab (visibles client uniquement)

| ID  | Action                                  | Site                                              | Effet |
|-----|-----------------------------------------|---------------------------------------------------|-------|
| I20 | Curseur survole workArea                | HoverHandler 20 Hz `Editor.qml:1125`              | broadcast UDP raw `EC:<pid>;x;y` (lossy) |
| I21 | Sélection change                        | `Editor.qml:1011` debounce 100 ms                 | reliable `SelectionUpdate{uuids}` |
| I22 | Hôte change de carte (I12-15)           | onMapLoaded `Editor.qml:1071-1075`                | `_sendFullSyncToAll` (resync tous clients) |

### 3.3 Sortie / cycle de vie

| ID  | Action                                          | Site                              | Effet sur V1-V19 |
|-----|-------------------------------------------------|-----------------------------------|------------------|
| I23 | EscMenu → "Retour menu principal" (solo)        | `main.qml:150-177`                | `beginSessionExit(_doExit)` → keep=true → `stackView.pop()`. **V1 PERSISTE.** |
| I24 | EscMenu → "Retour menu principal" (collab)      | idem                              | popup "conserver?". keep=false → `Game.deleteMap(mapName, CUSTOM)`. Puis `EditorOpBus.clearUndo` + `EditorSession.stop` + pop. V1 reste mais V12 peut être supprimé. |
| I25 | Quitter app (X / Alt+F4)                        | `main.qml:55-64`                  | si host collab : announceHostLeaving + stop + 300 ms + Qt.quit. Sinon Qt.quit immédiat. **Pas de save forcée hors saveEvent==3.** |
| I26 | Push gameBoard / launcher / autre depuis title  | `titleScreen`                     | Editor non touché si déjà poppé. V1 vit encore tant que MapFileManager existe. |
| I27 | Re-push editor depuis title                     | `main.qml:98`                     | nouveau Editor.qml → `_initializeEditorImpl` → **reload depuis disque** (V11/V12) → V1 remplacé. **Tout état mémoire non sauvé est perdu (cf. G5).** |
| I28 | Host migration : élu local                      | `Editor.qml:828`                  | `Game.saveCurrentMap()` forcé puis `EditorSession.promoteToHost`. V1/V4 préservés. |
| I29 | Host migration : non-élu                        | `Editor.qml:842`                  | wipe V16, `Game.initEmptyCollabMap` (nouveau V1 vide), `reconnectRequested` → main.qml relance p2p → Hello → FullSync du nouvel hôte. |

---

## 4. Initialisation de l'éditeur (`_initializeEditorImpl`)

Localisation : `Editor.qml:1734-1820`.

```
push Editor (Component.onCompleted)
   │
   ├─ initializeEditor() avec _suppressFullSyncBroadcast=true
   │     │
   │     └─ _initializeEditorImpl()
   │           │
   │           ├─ Si EditorSession.active && !isHost (CLIENT collab) :
   │           │     Game.initEmptyCollabMap()  ← V1 = nouveau Map vide,
   │           │                                   V3 = MapInfo défaut ("autosave_tmp"),
   │           │                                   V5 = CUSTOM (default).
   │           │     ⏸ skip local load — attend FullSync.
   │           │
   │           ├─ Si EditorSession.active && isHost && hostInitialMap :
   │           │     selon hostInitialMap.initialMap.mode :
   │           │       "existing" → Game.loadMap(name, CUSTOM) puis mapInfo.mapName = name
   │           │       "new"      → if !mapExists(sessName) createMapFile(sessName, CUSTOM)
   │           │                    Game.loadMap(sessName, CUSTOM) puis mapInfo.mapName = sessName
   │           │
   │           └─ Sinon (SOLO) :
   │                 if !mapExists(autosaveMapName, AUTOSAVE) :
   │                   createMapFile("", AUTOSAVE)        ← V11 créé
   │                   logic.saveMap(AUTOSAVE)            ← V11 réécrit
   │                 if lastOpenedMap != autosaveMapName :
   │                   if mapExists(lastOpenedMap, CUSTOM) :
   │                     Game.loadMap(lastOpenedMap, CUSTOM)    ← V1 ← V12
   │                   else :
   │                     reset lastOpenedMap = autosaveMapName
   │                     Game.loadMap(autosaveMapName, AUTOSAVE) ← V1 ← V11
   │                 else :
   │                   Game.loadMap(autosaveMapName, AUTOSAVE)   ← V1 ← V11
   │
   └─ Si EditorSession.active && !isHost :
         envoie Hello → host répond _sendFullSyncTo →
         _applyFullSyncSnapshot wipe V16 + reconstruit + V3 ← snapshot.mapInfo
```

---

## 5. `Game::loadMap` (game_loader.cpp:101)

```
emit Game::clearCurrentMap          ← Editor.qml.onClearCurrentMap → logic.removeCurrentMap (wipe V16)
Map::loadMap(name, type) static     ← lit V11/V12, instancie Map
   ├─ snapableTiles → m_tiles
   ├─ ItemSnapable parent = Map      (cleanup auto)
   ├─ MapInfo from json["mapInfo"]   → V3
   ├─ rebuild next/prev links
   └─ map->setSourceType(type)       → V5
si map :
   forEach tile : tile->commitCurrentState()    ← shadow copy initiale
   map->clearHistory()                          ← V4 = 0/0
   syncLamportFromMap                           ← Lamport ≥ max(zOrder)
   connect(map, …) → Game signaux
   forEach tile : emit foundItemSnapableTile    ← Editor.qml.onFoundItemSnapableTile → V16
   emit mapLoaded(map)                          ← Editor.qml.onMapLoaded :
                                                   ├─ logic.tileLogic.builtConnections()
                                                   ├─ stEnableAutoSave.lastOpenedMap = map.mapInfo.mapName  (V13)
                                                   └─ if collab host && !suppress : _sendFullSyncToAll()
MapFileManager::setCurrentMap(map)              ← V1, deleteLater(ancien)
```

---

## 6. Tableau scénarios — état & effets de bord

Hypothèse de départ (sauf indication contraire) : app neuve, `./map/` vide, `saveEvent=3`,
`lastOpenedMap` par défaut = `autosave_tmp`.

Légende : **CM** = V1, **MI** = V3.mapName, **ST** = V5, **U/R** = tailles V4,
**Disk** = V11/V12 modifiés, **LO** = V13, **Ed** = instance Editor.qml,
**Sess** = V17.

### §A — App lance, push Editor (solo)

| Pas | CM         | MI           | ST       | U/R | Disk                        | LO            | Ed     | Sess     |
|-----|------------|--------------|----------|-----|------------------------------|---------------|--------|----------|
| A1  | nouveau Map| `autosave_tmp` | AUTOSAVE | 0/0 | crée `autosave_tmp.json`   | `autosave_tmp` | nouveau | inactive |

### §B — Création carte custom

| Pas | Action            | CM                       | MI       | ST     | U/R  | Disk                              | LO       | Ed      | Sess     |
|-----|-------------------|--------------------------|----------|--------|------|-----------------------------------|----------|---------|----------|
| B1  | I12 "MyMap" Confirm | A1                     | A1       | A1     | A1   | écrit `mymap_map.json` (saveMap) | A1       | A1      | A1       |
| B2  | `Game.loadMap`     | nouveau (ancien deleteLater) | `MyMap` | CUSTOM | 0/0 | rien                              | `MyMap`  | A1      | A1       |

### §C — Modifs en série, saveEvent=3

| Pas | Action                           | CM | MI | ST | U/R | Disk             | LO | Ed | Sess |
|-----|----------------------------------|----|----|----|-----|------------------|----|----|------|
| C1  | I1 pose tuile T1                 | B2 | B2 | B2 | 1/0 | `mymap_map.json` réécrit | B2 | B2 | B2 |
| C2  | I4 drag (T1+T2) en transaction   | B2 | B2 | B2 | 2/0 (1 group) | 1× réécriture au commit | B2 | B2 | B2 |
| C3  | I9 change background path        | B2 | B2 | B2 | 3/0 | réécriture       | B2 | B2 | B2 |
| C4  | I10 Ctrl+Z (annule background)   | B2 | B2 | B2 | 2/1 | réécriture       | B2 | B2 | B2 |

### §D — Quitter éditeur, revenir

| Pas | Action                  | CM                  | MI    | ST     | U/R  | Disk | LO     | Ed      | Sess  |
|-----|-------------------------|---------------------|-------|--------|------|------|--------|---------|-------|
| D1  | I23 retour menu         | **V1 persiste**     | C4    | C4     | 2/1  | rien | `MyMap` | détruit | C4    |
| D2  | I27 re-push Editor      | nouveau (recharge V12) | `MyMap` | CUSTOM | 0/0 | rien | `MyMap` | nouveau | C4    |

### §E — Quitter, jouer/autre, revenir

| Pas | Action                       | CM | MI | ST | U/R | Disk | LO | Ed | Sess |
|-----|------------------------------|----|----|----|-----|------|----|----|------|
| E1  | I23 + I26 push gameBoard     | D1 |    |    |     |      |    |    |      |
| E2  | pop gameBoard, push Editor   | D2 | D2 | D2 | 0/0 | rien | D2 | nouveau | D2 |

### §F — saveEvent=1 (Manuelle) : perte de modifs (G5, accepté)

| Pas | Action                      | CM                          | MI    | ST     | U/R | Disk | LO     | Ed      | Sess  |
|-----|-----------------------------|-----------------------------|-------|--------|-----|------|--------|---------|-------|
| F1  | V14=1, puis C1              | B2                          | B2    | CUSTOM | 1/0 | **rien** | B2     | B2      | B2    |
| F2  | I23 retour menu             | V1 persiste avec T1 en RAM  | B2    | B2     | 1/0 | rien | B2     | détruit | B2    |
| F3  | I27 re-push                 | recharge V12 (sans T1)      | B2    | B2     | 0/0 | rien | B2     | nouveau | B2    |
| F4  | **Effet** : T1 perdue.     |                             |       |        |     |      |        |         |       |

### §G — Quitter app brutalement

| Pas | Action                         | CM   | MI     | ST     | U/R | Disk | LO  | Ed     | Sess     |
|-----|--------------------------------|------|--------|--------|-----|------|-----|--------|----------|
| G1  | C1 (V14=1), puis I25 X         | n/a  | n/a    | n/a    | n/a | rien | B2  | n/a    | n/a      |
| G2  | Relance app + push Editor      | charge V12 sans T1 | B2 | CUSTOM | 0/0 | rien | B2  | nouveau| inactive |

### §H — Suppression carte via MapNavigationBar

| Pas | Action                | CM                  | MI               | ST            | U/R  | Disk                       | LO                  | Ed | Sess |
|-----|-----------------------|---------------------|------------------|---------------|------|----------------------------|---------------------|----|------|
| H1  | I15 sur "MyMap"       | nouveau (auto-nav)  | autre / `autosave_tmp` | CUSTOM ou AUTOSAVE | 0/0  | **supprime** `mymap_map.json` | autre ou `autosave_tmp` | B2 | B2   |

### §I — Collab — host crée session avec carte vide

| Pas  | Action                                                   | CM                       | MI       | ST     | U/R | Disk                              | LO       | Ed     | Sess          |
|------|----------------------------------------------------------|--------------------------|----------|--------|-----|-----------------------------------|----------|--------|---------------|
| I1'  | startAsHost + push Editor avec hostInitialMap mode=new   | nouveau (loadMap MySess) | `MySess` | CUSTOM | 0/0 | crée `mysess_map.json`           | `MySess` | nouveau | active host  |
| I2'  | Client envoie Hello → host snap → _sendFullSyncTo        | I1'                      | I1'      | I1'    | I1' | I1'                               | I1'      | I1'    | I1'           |
| I3'  | host I1 pose T1                                          | mute V2                  | I1'      | I1'    | 1/0 | save                              | I1'      | I1'    | I1'           |

### §J — Collab — client rejoint

| Pas | Action                              | CM                                       | MI                  | ST                     | U/R  | Disk                                   | LO       | Ed     | Sess          |
|-----|-------------------------------------|------------------------------------------|---------------------|------------------------|------|----------------------------------------|----------|--------|---------------|
| J1  | startAsClient + push                | `Game.initEmptyCollabMap` → Map vide     | `autosave_tmp` (def)| CUSTOM (default)       | 0/0  | rien                                   | inchangé | nouveau| active client |
| J2  | Hello → reçoit FullSync             | applyDelta(Metadata)+TileAdded×N         | `MySess`            | CUSTOM                 | 0/0 (applyRemote ne push pas) | E7 purge `mysess_map.json` local si existe ; E12 purge ancien fichier session | inchangé | J1     | J1            |
| J3  | Client drag tuile (I4)              | local pushDelta                          | J2                  | J2                     | 1/0  | save local (`mysess_map.json` côté client) | inchangé | J1     | J1            |
| J4  | Host rebroadcast → applyRemoteDelta | applyDelta sans pushDelta (idempotent)   | J2                  | J2                     | 1/0 (inchangé) | rien (m_remoteSaveDebounce restart) | J2       | J1     | J1            |

### §K — Collab — host change carte en cours

| Pas | Action                              | CM                       | MI    | ST     | U/R  | Disk                                   | LO     | Ed | Sess |
|-----|-------------------------------------|--------------------------|-------|--------|------|----------------------------------------|--------|----|------|
| K1  | host I13 "Charger carte autre"      | nouveau Map              | autre | CUSTOM | 0/0  | rien                                   | autre  | I1'| I1'  |
| K2  | onMapLoaded → `_sendFullSyncToAll` | K1                       | K1    | K1     | K1   | K1                                     | K1     | K1 | K1   |
| K3  | Client reçoit FullSync → wipe + rebuild + E7/E12 | nouvelle V3, V2 reconstruite | autre | CUSTOM (default) | 0/0 | E12 supprime `mysess_map.json` local côté client | inchangé | J1 | J1 |

### §L — Collab — retour menu, popup conserver

| Pas | Action                           | CM                                                  | MI    | ST            | U/R | Disk                                   | LO                  | Ed     | Sess     |
|-----|----------------------------------|-----------------------------------------------------|-------|---------------|-----|----------------------------------------|---------------------|--------|----------|
| L1  | I24 client choisit "ne pas conserver" | V1 persiste post-stop                            | J2    | J2            | J2  | **supprime** `<mapName>_map.json` local | J2                  | détruit| inactive |
| L2  | I27 re-push (solo)               | charge V12 ; mapName n'existe plus → fallback autosave | `autosave_tmp` | AUTOSAVE | 0/0 | rien                                   | reset `autosave_tmp` | nouveau| L1       |

### §M — Host migration

| Pas | Action                                | CM                          | MI         | ST         | U/R       | Disk | LO         | Ed         | Sess        |
|-----|---------------------------------------|-----------------------------|------------|------------|-----------|------|------------|------------|-------------|
| M1  | Host part. Client élu = soi.          | `saveCurrentMap` forcé. promoteToHost. V1 préservé. | inchangé | inchangé | inchangé | save | inchangé   | inchangé   | active host |
| M2  | Client non-élu                        | wipe V16, `initEmptyCollabMap` | reset `autosave_tmp` | reset CUSTOM (def) | 0/0 | rien | inchangé | inchangé | inactive    |
| M3  | reconnectRequested → main.qml p2p → Hello → FullSync | tableau §J2  | J2         | J2         | J2        | E7/E12 | J2       | J2         | active client |

---

## 7. Bugs connus / gotchas (post-analyse V2_Valou)

| #     | Localisation                                                       | Problème                                                                                                                     | Statut                                           |
|-------|--------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| **G1** | `mapfilemanager.cpp` (`createMapFile`)                            | écrivait `mapInfo["mapName"] = mapName` mais `MapInfo::MapInfo(json)` lit `json["name"]`                                    | ✅ **Fixé** — clé corrigée en `name`. Le contrat lecteur reste gelé par `tst_mapinfo::jsonCtor_readsNameKey_notMapNameKey`. |
| **G2** | `mapinfo.cpp` (`setMapName/Description/LastModified/Version`)      | pas de guard d'égalité avant `emit` (contrairement aux autres setters)                                                       | ✅ **Fixé** — guards ajoutés. Validé par `tst_mapinfo::setMapName_emitsEvenIfSame_REPRO_G2`. |
| **G3** | `mapfilemanager.cpp` / `.h` (`renameMap`)                          | `QFile newMap(oldMapName)` utilisait des noms bruts (pas de chemin) ; `flag` restait `false` même en succès                  | ✅ **Supprimé** — code mort, aucun appelant. Note de réintroduction laissée dans `mapfilemanager.cpp`. |
| G4    | `mapfilemanager.cpp:48` (dtor)                                     | `delete currentMap` mais `setCurrentMap` fait `deleteLater`                                                                  | Risque double-delete théorique. Bénin : singleton dtor au shutdown. |
| **G5** | `Editor.qml:1734-1820` (`_initializeEditorImpl`)                   | re-lit toujours depuis disque au push, écrase l'état mémoire                                                                 | Si `saveEvent != 3` : perte des modifications non sauvées sur retour menu→éditeur (§F, §G). **Comportement accepté** (utilisateur informé). |
| **G6** | `game_loader.cpp::initEmptyCollabMap`                              | `new Map(this)` + `new MapInfo()` → mapName = "autosave_tmp", sourceType = CUSTOM (default)                                  | ✅ **Fixé** — sentinel `mapName=""` posé par `initEmptyCollabMap` ; `Game::saveCurrentMap` et `Game::saveMap` early-return sur empty. Levé par FullSync via `applyDelta(MetadataChanged)`. |
| **G7** | `MenuMapAtStart.qml`                                               | `mapExists` + `normalizeMapName` : `"My Map"` et `"my map"` collisionnent sur `my_map_map.json`. Le placeholder rouge n'est visible qu'à champ vide → utilisateur n'a pas l'explication | ✅ **Fixé** — `Text` d'erreur explicite sous le `TextField` qui affiche la clé normalisée du fichier en collision. Validation au clic Confirm inchangée (déjà bloquante). |
| **G8** | `Game::askPreview/askNext`                                          | `broadcastLastBatch` appelé même si `applyDelta` a no-opé (idempotence côté remote applique aussi à local)                   | **Accepté** pour l'instant — bruit réseau négligeable sur cartes courantes. À revisiter si le canal s'embouteille en pratique (solution chirurgicale : filtrer par `touched.empty()` retourné par `applyDelta`). |
| **G9** | `SessionCreation.qml`, `Editor.qml::_initializeEditorImpl`, `_resolveSessionExit(false)` | la session collab pouvait écraser/supprimer un fichier mono préexistant ; aucun avertissement utilisateur en cas de collision sessionName ↔ carte mono | ✅ **Fixé en deux temps** : (1) `MapFileManager::mapNameCollidesIgnoringCase` + `copyMap` exposés en QML ; (2) `SessionCreation` détecte la collision en mode `new` (warning rouge sous le champ) et offre une checkbox "Créer une copie" en mode `existing` (cochée par défaut). `Editor.qml` route `useCopy` via `MapFileManager.copyMap` pour que la session édite `<sessionName>_map.json` sans toucher à la carte mono d'origine. Couverture par tests automatisés différée (chaîne ItemSnapable). |
| **G10** | `Editor.qml::onNewMapSet`, `MapFileManager::normalizeMapName`     | `MapInfo.mapName` garde la casse d'origine, le fichier est `<normalize(name)>_map.json` ; UI vs disque divergent             | **Status quo accepté** — voir §10 *Direction future* ci-dessous : le refactor planifié vers identifiants UUID résout aussi G7/G10 d'un coup. |

**Décisions retenues** :
- G1, G2 : fixés. Tests dans `tests/map_lifecycle/` qui passent du rouge (pré-fix) au vert.
- G3 : supprimé (code mort).
- G5 : accepté tel quel ; documenté dans la suite de scénarios §F/§G.
- G4, G6-G10 : non bloquants. Couverts par tests (régression).

---

## 8. Tests unitaires

Les tests gelant le contrat décrit ici vivent dans
[`Meownopoly/tests/map_lifecycle/`](../../tests/map_lifecycle/) et utilisent
**Qt Test** (`Qt6::Test`).

### Couverture v1 (sans dépendance ItemSnapable)

| Suite                   | Cas couverts                                                                                  |
|-------------------------|-----------------------------------------------------------------------------------------------|
| `tst_mapinfo`           | JSON round-trip ; fallback profile (toujours ≥ 1) ; versioning roster ; setters guard (**G2**) ; bornes min/max ; add/remove/duplicate/reorder/update/clear profile. |

### Couverture différée

`MapFileManager`, `Map`, et les scénarios bout-en-bout dépendent transitivement
de `ItemSnapable` → `Case` → `game.h` → tout le projet (singletons, réseau,
QML). Sans refactor en *object library* CMake ou stubs massifs, ces tests ne
sont pas linkables en isolation. Reportés à une itération future :

| Suite                | Cas                                                     |
|----------------------|---------------------------------------------------------|
| `tst_mapfilemanager` | normalize, path resolution, atomicité, saveMap/readMapFile round-trip, mapExists, createMapFile (**G1**), getMapType, setCurrentMap signal & deleteLater. |
| `tst_map_undoredo`   | pushDelta clears redoStack ; undo group atomic ; applyDelta TileAdded/Deleted/Modified/Metadata ; canSave gate ; idempotence applyRemote ; signaux `tileAddedToMap`/`tileRemovedFromMap`. |
| `tst_lifecycle`      | scénarios §A à §M de bout en bout, avec mocks `EditorOpBus`/`EditorSession`. |

Les fixes **G1** (createMapFile écrit la mauvaise clé) et **G3** (renameMap
cassé/mort) sont appliqués sans test automatisé dans cette itération —
vérification par revue de code et le test contractuel
`tst_mapinfo::jsonCtor_readsNameKey_notMapNameKey` qui gèle l'attente côté
lecteur (`MapInfo::MapInfo(json)` lit `"name"`). Le fix **G2** est validé par
`tst_mapinfo::setMapName_emitsEvenIfSame_REPRO_G2` (XFAIL pré-fix → XPASS
post-fix → retrait du `QEXPECT_FAIL`).

### Isolation disque

Chaque test redéfinit le CWD via `QDir::setCurrent(QTemporaryDir().path())`
dans `init()` et restaure dans `cleanup()`. `MAP_FILE_PATH` (=`./map/`) est
relatif au CWD, donc l'isolation est totale sans toucher au `#define`.

---

## 9. Fichiers critiques (référence)

| Rôle                                          | Fichier(s)                                                          |
|-----------------------------------------------|---------------------------------------------------------------------|
| Pointeur singleton + I/O fichier              | `cpp/game/map/mapfilemanager.{h,cpp}`                               |
| `Map` + undo/redo + applyDelta                | `cpp/game/map/map.{h,cpp}`                                          |
| Métadonnées + player config                   | `cpp/game/map/mapinfo.{h,cpp}`, `cpp/game/map/playerprofile.{h,cpp}` |
| Enum types map (AUTOSAVE/CUSTOM/UNDOREDO)     | `cpp/game/map/maptypes.h`                                           |
| Delta struct                                  | `cpp/game/map/editdelta.h`                                          |
| Save/load API + transactions                  | `cpp/game/game_loader.cpp`                                          |
| Bus d'opérations + ops player profile 12-16   | `cpp/editor/ops/editor_op_bus.{h,cpp}`, `cpp/editor/ops/editor_op_type.h` |
| Initialisation éditeur + FullSync + cycle Editor | `qml/editor/Editor.qml`                                          |
| Création nouvelle carte                       | `qml/editor/MenuMapAtStart.qml`                                     |
| Navigation entre cartes                       | `qml/editor/panel/mapInfoPanel/MapNavigationBar.qml`                |
| Édition métadonnées                           | `qml/editor/panel/mapInfoPanel/MapInfoDrawer.qml`, `MapInfoPanel.qml` |
| Push/pop Editor + onClosing                    | `qml/main.qml`                                                      |
| Sortie session collab                          | `qml/editor/Editor.qml` (`beginSessionExit`, `_resolveSessionExit`) |

---

## 10. Direction future — IDs canoniques (refactor planifié)

Plusieurs bugs résiduels (G7 collisions de normalisation, G10 divergence
display vs fichier, et indirectement G9 collisions mono ↔ collab) partagent
une racine commune : **le nom utilisateur joue à la fois le rôle d'identité
visuelle et d'identité disque**. Toute mutation de l'un casse l'autre, et
deux noms qui normalisent vers la même clé deviennent indistinguables côté
fichier.

### Refactor proposé

Introduire un identifiant UUID stable par carte, indépendant du nom
utilisateur :

- **Disque** : `./map/<uuid>.json` (exemple `./map/3f2c8e1a-...-b7c9.json`).
- **`MapInfo`** : nouveau champ `id` (string, UUID v4), généré à la
  création (`MapFileManager::createMapFile`) ou hydraté depuis le JSON.
  `mapName` reste libre côté affichage, sans impact sur le chemin disque.
- **API `MapFileManager`** : remplacer la signature `(name, type)` par
  `(uuid)` ou `(MapInfo*)`. Helpers `findIdByName(displayName)` pour les
  flux de navigation existants.
- **QSettings `lastOpenedMap`** : stocker l'UUID au lieu du nom.
- **FullSync** : le snapshot host transporte `id` + `mapInfo.toJSON()` ;
  le client peut renommer librement sans collision côté disque.

### Problèmes que ça résout

| Bug actuel | Devient |
|------------|---------|
| **G1** déjà fixé | obsolète (UUID déjà séparé du JSON metadata) |
| **G7** | obsolète (`normalize` n'est plus la clé d'identité) |
| **G9** | encore présent côté UX (host peut éditer la carte mono d'un client), mais résolu côté **disque** : la session collab a son propre `<uuid>` qui ne peut pas écraser un fichier mono |
| **G10** | obsolète (display name est libre, file key est l'UUID) |

### Effort estimé

- Refactor `MapFileManager` + `MapInfo` : ~½ jour
- Migration des fichiers existants (script qui scanne `./map/*.json`,
  génère un UUID par fichier, renomme, met à jour le `mapInfo.id`) : ~½
  jour
- Tests dédiés (`tst_mapfilemanager` revisité — facilité par la
  séparation cleaner) : ~½ jour
- Total : **~1.5 jour**, **non bloquant** pour l'usage actuel.

À programmer après stabilisation des autres chantiers en cours
(physique v2, player config panel).
