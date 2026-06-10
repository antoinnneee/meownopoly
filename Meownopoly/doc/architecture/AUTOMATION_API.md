# API d'automation / test

API de contrôle et d'automation de l'application Meownopoly, conçue pour tester
l'app de façon scriptée (notamment depuis un agent comme Claude Code). Elle se
compose de deux parties :

1. **Serveur d'automation embarqué** dans l'app (C++ / `QWebSocketServer`).
2. **Serveur MCP** (Node.js, stdio) qui expose des *tools* mappés sur le protocole.

```
Claude Code  ──(MCP stdio)──▶  automation_mcp/  ──(WebSocket 127.0.0.1)──▶  Meownopoly.exe
```

---

## 1. Serveur d'automation embarqué

- **Fichiers** : `cpp/automation/automation_server.{h,cpp}`.
- **Transport** : `QWebSocketServer` en mode non-sécurisé, à l'écoute **strictement
  sur `127.0.0.1`** (jamais `0.0.0.0`). Les connexions non-loopback sont rejetées.
- **Thread** : tout tourne sur le **GUI thread**. Le `QWebSocket` y vit, et les
  commandes manipulent directement la scène QML (qui appartient au GUI thread).
  Aucun thread dédié n'est créé.
- **Intégration** : instancié dans `main.cpp` après `QmlApp` (l'engine a alors chargé
  `main.qml`), parenté à `QGuiApplication`, via
  `AutomationServer::maybeCreate(app.arguments(), &app)`.

### Activation (opt-in)

Le serveur n'est **jamais instancié** si aucun port n'est demandé. Résolution du port
(par priorité) :

1. Argument CLI `--automation-port <N>`.
2. Variable d'environnement `MEOW_AUTOMATION_PORT`.

```bash
Meownopoly.exe --automation-port 7700
# ou
MEOW_AUTOMATION_PORT=7700 Meownopoly.exe
```

### Sécurité

- Écoute uniquement sur la loopback ; double garde sur l'adresse du pair à la connexion.
- Opt-in strict : sans port, zéro surface d'attaque (le composant n'existe pas).
- Canal de **debug local** : expose l'introspection complète de la scène QML, la
  modification de propriétés, l'appel de méthodes et la synthèse d'événements. À ne
  **jamais** exposer hors de la machine de dev.

### Deux instances (dual_test_p2p)

Le port étant explicite, deux instances coexistent naturellement. Convention :

| Instance | Lancement | Port |
|----------|-----------|------|
| 1 | `Meownopoly.exe --automation-port 7700` | 7700 |
| 2 | `Meownopoly.exe --instance 2 --automation-port 7701` | 7701 |

---

## 2. Protocole JSON

Messages **texte JSON**, requête / réponse corrélées par un champ `id`.

### Requête

```json
{ "id": 1, "cmd": "<nom>", "params": { ... } }
```

### Réponse

```json
{ "id": 1, "ok": true,  "result": <any> }
{ "id": 1, "ok": false, "error": "<message>" }
```

### Ciblage d'un objet

Les commandes `get`/`set`/`invoke`/`tree`/souris/clavier acceptent une cible via :

- `objectName` : recherche par `objectName` (égalité exacte), optionnellement filtrée par
  `className` (sous-chaîne insensible à la casse).
- `id` : identifiant stable `"0x..."` retourné par `find`/`tree` (pointeur encodé, validé
  contre l'arbre courant pour éviter un use-after-free).
- `target` : alias acceptant soit un `objectName`, soit un `id`.

---

## 3. Commandes

### `ping`
Infos app. Aucun paramètre.
```json
→ { "cmd": "ping" }
← { "ok": true, "result": { "app": "Meownopoly", "version": "", "instance": 1,
     "pid": 12345, "windowTitle": "Meownopoly", "windowWidth": 1280,
     "windowHeight": 720, "currentScene": "titleScreen", "windowCount": 1 } }
```

### `tree`
Arbre des objets QML. `params` : `depth` (défaut 3), `filter` (sous-chaîne sur
className/objectName), cible optionnelle (sinon part des fenêtres top-level).
```json
→ { "cmd": "tree", "params": { "depth": 2, "filter": "Button" } }
← { "ok": true, "result": [ { "className": "QQuickWindow", "children": [ ... ] } ] }
```
Chaque nœud : `objectName`, `className`, `id`, `geometry` (x/y/width/height + `scene`
{x,y,centerX,centerY}), `visible`, `enabled`, `children`.

### `find`
Trouve par `objectName` et/ou `className`. Retourne une liste de
`{ objectName, className, id, geometry, visible, enabled }`.
```json
→ { "cmd": "find", "params": { "objectName": "editorButton" } }
```

### `get` / `set`
`get` lit `params.property`. `set` écrit `params.property` = `params.value`.
```json
→ { "cmd": "get", "params": { "objectName": "mainStackView", "property": "depth" } }
→ { "cmd": "set", "params": { "id": "0x...", "property": "visible", "value": true } }
```
> Note : écraser un binding QML déclenche les avertissements `qt.qml.binding.removal`.
> Préférer `invoke` d'une méthode dédiée quand elle existe.

### `invoke`
Appelle une méthode `Q_INVOKABLE` / slot / fonction QML. Surcharges résolues par **arité**
(premier match). `params` : `method`, `args` (tableau JSON). Retourne `result` si la
méthode a une valeur de retour.
```json
→ { "cmd": "invoke", "params": { "objectName": "mainStackView", "method": "pop" } }
```

### `click` / `doubleClick` / `move` / `press` / `release`
Synthèse souris (bouton gauche) via `QMouseEvent` envoyés à la fenêtre aux coordonnées
scène. Cible : un item (centre par défaut, ou `offsetX`/`offsetY`) **ou** `x`/`y` en scène.
```json
→ { "cmd": "click", "params": { "objectName": "editorButton" } }
→ { "cmd": "click", "params": { "x": 640, "y": 360 } }
```

### `wheel`
Événement molette (test du zoom éditeur). `params` : cible ou `x`/`y`, `delta` (angleDelta
vertical, défaut 120 = 1 cran).
```json
→ { "cmd": "wheel", "params": { "objectName": "gameGrid", "delta": 240 } }
```

### `keys`
Synthèse clavier. Deux modes :
- `text` : tape la chaîne caractère par caractère.
- `key` : valeur numérique `Qt::Key` (ex. 16777220 = Enter) + `modifiers`
  (`["ctrl","shift","alt","meta"]`).
Si une cible est fournie, elle reçoit le focus d'abord.
```json
→ { "cmd": "keys", "params": { "objectName": "nameField", "text": "Ma carte" } }
→ { "cmd": "keys", "params": { "key": 90, "modifiers": ["ctrl"] } }
```

### `screenshot`
`QQuickWindow::grabWindow()` → PNG. `params.path` optionnel (sinon dossier temp).
Retourne le chemin **absolu** (+ width/height). Les PNG sont lisibles directement.
```json
→ { "cmd": "screenshot", "params": {} }
← { "ok": true, "result": { "path": "C:/.../meow_screenshot_...png", "width": 1280, "height": 720 } }
```

### `waitFor`
Attend (polling 100 ms côté app, **réponse différée**) qu'un item existe / soit visible /
qu'une propriété atteigne une valeur. `params` : `objectName`, `property`+`value`,
`visible`, `timeout` (ms, défaut 5000).
```json
→ { "cmd": "waitFor", "params": { "objectName": "gameGrid", "visible": true, "timeout": 8000 } }
```

### `quit`
Ferme l'app proprement (la réponse part avant la fermeture).
```json
→ { "cmd": "quit" }
← { "ok": true, "result": { "quitting": true } }
```

---

## 4. Serveur MCP (Node.js)

- **Dossier** : `automation_mcp/` (à la racine du repo). `npm install` puis enregistrement
  via `.mcp.json`.
- **Transport** : stdio (`@modelcontextprotocol/sdk`). Connexion WebSocket **lazy** à
  l'app (`ws`), reconnexion auto, erreur claire si l'app n'est pas lancée.
- **Port** : `MEOW_AUTOMATION_PORT` (défaut 7700), surchargeable par paramètre `port` sur
  chaque tool (pour piloter 2 instances).

### Tools exposés

| Tool MCP | Commande | Notes |
|----------|----------|-------|
| `app_ping` | `ping` | À appeler en premier. |
| `qml_tree` | `tree` | `depth`, `filter`, cible optionnelle. |
| `qml_find` | `find` | `objectName` / `className`. |
| `qml_get` / `qml_set` | `get` / `set` | |
| `qml_invoke` | `invoke` | `method`, `args`. |
| `mouse_click` / `mouse_double_click` / `mouse_press` / `mouse_release` / `mouse_move` | `click`/… | cible ou `x`/`y`, `offsetX`/`offsetY`. |
| `mouse_wheel` | `wheel` | `delta`. |
| `send_keys` | `keys` | `text` ou `key`+`modifiers`. |
| `screenshot` | `screenshot` | `path` optionnel. |
| `wait_for` | `waitFor` | timeout côté app + marge côté MCP. |
| `app_quit` | `quit` | |

---

## 4 bis. Commandes haut niveau éditeur

Ces tools pilotent l'éditeur de map sans connaître la géométrie écran (pas de
clics sur la grille à calculer). Ils ne fonctionnent que lorsque **l'éditeur est
ouvert**.

### Hooks QML (`objectName: "editorAutomationHooks"`)

Un `Item` léger, **strictement passif** (`width/height: 0`, `visible/enabled:
false`), instancié dans `Editor.qml`. Il expose des fonctions JS appelées via la
commande générique `invoke` (résolution `find` par `objectName`, puis `invoke`
par `id`). Chemin de pose identique à l'UI (`TileLogic.placeSelectedAsset` +
`Game.updateMap`) → **compatible mode collab / undo**.

> NB : c'est un `Item` et non un `QtObject`, car `find`/`tree` parcourent l'arbre
> **visuel** (`childItems()`) — un `QtObject` (enfant *data*) serait invisible.

| Fonction QML | Args | Retour |
|--------------|------|--------|
| `listAssetCategories()` | — | `{ ok, categories: [{ category, types: [...] }] }` |
| `listAssets(category, type)` | 2 str | `{ ok, count, assets: [{ id, filename, path, width, height, ratioWidth, ratioHeight, description }] }` |
| `placeAsset(assetId, category, type, gridX, gridY)` | str×3 + int×2 | `{ ok, tile: { uuid, gridX, gridY, width, height } }` |
| `placeCase(caseType, gridX, gridY)` | int×3 | `{ ok, tile: { uuid, gridX, gridY, width, height } }` |
| `getCamera()` | — | `{ ok, centerGridX, centerGridY, scaleLevel, mmSize, gridSize, gridOffsetX/Y, viewportWidth/Height }` |
| `setCamera(gridX, gridY)` | 2 num | `getCamera()` (pan absolu, centre la vue sur la cellule) |
| `panCamera(dGridX, dGridY)` | 2 num | `getCamera()` (pan relatif) |
| `zoomCamera(steps)` | int | `getCamera()` (±N crans ×1.1, centré viewport) |

Propriété lecture seule : `_tileCount` (nombre de tiles dans la carte courante,
pratique pour vérifier une pose via `get`).

Notes de design :
- L'état « asset sélectionné » vit dans `assetPanel` (`AssetSelectionPanel`,
  via `SelectionPanel`). `placeAsset` arme la sélection par
  `selectionPanel.assetPanel.updateSelectedAsset(...)` (qui passe en `EM_POSE`),
  pose, puis restaure `EM_NORMAL` — l'éditeur ne reste jamais armé.
- `placeCase` arme `selectionPanel.caseTypeSelected` (= `EM_POSE` aussi), pose,
  puis remet `-1` → `EM_NORMAL`.
- `placeSelectedAsset(gridX, gridY)` **centre** l'élément : la tile résultante a
  pour origine `(gridX − floor(w/2), gridY − floor(h/2))` (comportement UI).
- Le pan modifie `gameGrid.x/y` (pixels) puis resynchronise la caméra 3D via
  `logic.mouseLogic.updateCameraPosition()`. Le zoom réplique la math de
  `ScrollLogic.scrollGrid` (zoom multiplicatif + point fixe au centre +
  `prepareZoom`/`applyZoom` pour la 3D).

### Tools MCP éditeur

| Tool MCP | Hook invoqué | Notes |
|----------|--------------|-------|
| `editor_list_assets` | `listAssetCategories` / `listAssets` | sans `category`/`type` : catégories ; avec les deux : assets. |
| `editor_place_item` | `placeAsset` | `category`, `type`, `assetId`, `gridX`, `gridY`. |
| `editor_place_case` | `placeCase` | `caseType` (Case::CaseType), `gridX`, `gridY`. |
| `editor_camera_get` | `getCamera` | |
| `editor_camera_center` | `setCamera` | `gridX`, `gridY` (pan absolu). |
| `editor_camera_pan` | `panCamera` | `dx`, `dy` (cellules). |
| `editor_camera_zoom` | `zoomCamera` | `steps` (± crans). |

Chaque tool localise les hooks (`find objectName=editorAutomationHooks`) puis
`invoke`. Si l'éditeur n'est pas ouvert, le tool renvoie une erreur explicite.

Exemple end-to-end :

```
editor_list_assets {}                                   # catégories + types
editor_list_assets { category: "decoration", type: "grass" }
editor_place_item { category: "decoration", type: "grass", assetId: "0", gridX: 12, gridY: 8 }
editor_camera_center { gridX: 12, gridY: 8 }
editor_camera_zoom   { steps: -2 }
screenshot {}
```

---

## 5. Scénarios

### Entrer dans l'éditeur de map

```
app_ping                                  # confirmer la connexion + scène titleScreen
qml_find  { objectName: "editorButton" }  # localiser le bouton EDITOR
mouse_click { objectName: "editorButton" }
wait_for  { objectName: "gameGrid", visible: true, timeout: 8000 }
screenshot {}
```

### Déposer un item dans l'éditeur

```
qml_find  { className: "AssetSelectionPanel" }      # découvrir le panneau d'assets
mouse_click { id: "<id d'un asset>" }               # sélectionner un asset
mouse_click { objectName: "gameGrid", offsetX: 200, offsetY: 200 }  # poser sur la grille
qml_get   { objectName: "gameGrid", property: "..." }              # vérifier l'état
screenshot {}
```

### Tester le zoom de l'éditeur

```
mouse_wheel { objectName: "gameGrid", delta: 240 }  # 2 crans vers le haut
qml_get     { objectName: "gameGrid", property: "scaleLevel" }
```

### Piloter deux instances P2P

```
# Instance 1 : Meownopoly.exe --automation-port 7700
# Instance 2 : Meownopoly.exe --instance 2 --automation-port 7701
app_ping { }                 # instance 1 (port défaut)
app_ping { port: 7701 }      # instance 2
```

---

## 6. Limitations connues

- **Qt 6.11 requis pour la scène complète** : `Editor.qml` importe `MeowPainter`
  (CanvasPainter, Tech Preview Qt 6.11+). Sur Qt 6.10, `main.qml` échoue à charger et
  aucune scène n'est créée — le serveur d'automation démarre néanmoins mais n'a rien à
  introspecter (seule la `QQuickWindow` sonde de `main.cpp` est visible). `primaryWindow()`
  privilégie la fenêtre peuplée pour ignorer cette sonde dès qu'une scène existe.
- **Environnement headless** : `grabWindow()` renvoie une image vide sans surface
  d'affichage.
- **`invoke`** : résolution des surcharges par arité seulement (premier match) ;
  conversion des arguments best-effort selon la signature meta-object. Les
  **fonctions JS QML** (paramètres et retour de meta-type `QVariant`) sont gérées
  par une voie dédiée : args/retour passés en `QVariant` avec le nom de type
  exact, et déballage `QJSValue` → `QVariant` → JSON dans `variantToJson`. Sans
  ça, le retour des fonctions QML revenait `null`.
