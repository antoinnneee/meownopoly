---
name: editor-feature
description: Méthode pour ajouter une feature à l'éditeur de map Meownopoly (nouveau type d'élément, panneau, op collab, runtime 3D). Utiliser quand l'utilisateur demande d'ajouter/étendre un élément posable, un panneau d'éditeur, une donnée sérialisée dans la map, ou une feature éditeur en général.
user_invocable: true
argument_hint: [description de la feature éditeur]
---

# Ajouter une feature dans l'éditeur Meownopoly

Méthode éprouvée (feature PNJ, commit `c3f252f7` — s'en servir comme exemple
de référence pour chaque étape). Adapter les phases à la feature : tout
n'est pas toujours nécessaire, mais l'ORDRE et les pièges le sont.

## Phase 0 — Lecture préalable (obligatoire)

1. Lire le CLAUDE.md du repo (sections Architecture, QML gotchas, Dev test harness).
2. S'il existe un plan dans `Meownopoly/doc/architecture/*_PLAN.md`, le lire ET
   **vérifier ses affirmations contre le code réel** avant d'implémenter
   (numéros de ligne, noms de classes, bornes d'enum — les plans dérivent).
3. Identifier les **fichiers modèles à calquer** (le repo fonctionne par
   décalque de patterns existants) :
   - Paramètre sérialisé : `cpp/game/item_snapable/ZoneParameter.{h,cpp}` ou
     `npcparameter.{h,cpp}` (préférer ce dernier : sérialisation propre).
   - Élément posable QML : `qml/meowComponent/snapable/SnapableDecoration.qml`.
   - Module d'éditeur (panneau bas) : `qml/editor/moduleManager/zonePanel/` ou
     `npcSelectionPanel/`.
   - Section de config de sélection : `qml/editor/configPanel/zoneConfigPanel/`
     ou `npcConfigPanel/` (sections préfixées `XCP_`).
   - Contrôleur runtime piloté par la physique :
     `qml/world3d/ScreenEffectController.qml` (pattern pile LIFO + Connections).

## Phase 1 — Backend C++ (données + sérialisation)

Si la feature porte un nouveau type de tile ou de paramètre :

- **Nouvelle classe paramètre** `cpp/game/item_snapable/<x>parameter.{h,cpp}` :
  `Q_PROPERTY` + setters avec garde `if (m_x == v) return; emit`.
  - **toJSON() via `QJsonObject`/`QJsonDocument::toJson(Compact)`**, PAS la
    concat manuelle des vieux `toJSON()` — obligatoire dès qu'un champ contient
    du texte libre (guillemets, retours à la ligne).
  - Listes éditables : exposer des `Q_INVOKABLE add/set/remove/move/clear`
    qui émettent le NOTIFY — la mutation en place d'une liste Q_PROPERTY
    n'est pas observée par QML.
  - `applyJson()` **Q_INVOKABLE** si le remote-apply collab doit l'appeler.
  - Champ de version de schéma (`<x>Version`) : version > courante → reset
    aux défauts + warning (pattern `playerConfigVersion`).
- **Nouveau `TileType`** dans `ItemSnapable.h` : TOUJOURS en **dernière
  position** de l'enum, puis étendre la borne du ctor JSON
  (`ItemSnapable.cpp` : `rawTileType > <DernierType>`) — sinon les tiles
  chargées retombent silencieusement en `DecorationTile`.
- **ItemSnapable** : `Q_PROPERTY` + membre + delete au dtor, parse dans le
  ctor JSON, sérialisation dans `toJSON()` (gated par le tileType), apply
  dans `applyJson()`, cas dans `operator==`, `qmlRegisterType` dans
  `registerQml()`.
- **Factory** : `ItemSnapableFactory::create<X>()` (new + setTileType +
  `QQmlEngine::setObjectOwnership(JavaScriptOwnership)`).
- **Auditer tous les sites `tileType`** après ajout d'une valeur :
  `grep -rn "PhysicZoneTile" cpp/` et `grep -rn "tileType ===" qml/`
  (operator==, `Map::updateTileCounts`, `TileLogic.createItemSnapableTile`,
  `EditorPhysicsBridge`, `TemplatePreviewCursor`…).
- **CMake GLOB_RECURSE est figé au configure** : reconfigurer AVANT de
  builder après tout ajout de `.cpp` (cf. commandes dans CLAUDE.md).

## Phase 2 — Protocole collab (ops)

- Pose/suppression/déplacement/liens : **réutiliser** `CreateItem`/`DeleteItem`/
  `MoveItem` + le canal `ApplyState` (transporté par `Game.updateMap`) —
  ne créer une op fine que pour l'édition de champs typés.
- Nouvelle op : valeur suivante dans `cpp/editor/ops/editor_op_type.h`,
  helper `make<X>Op` dans `editor_op_bus.{h,cpp}`, case de remote-apply dans
  la `Connections { target: EditorOpBus }` d'`Editor.qml` (~l.430).
- Les ops transitent par `EditorMessageType::Op` (0x23) déjà couvert par
  `isEditorPacket` → **pas** de nouveau `EditorMessageType`. Si un jour il en
  faut un : valeur la plus haute obligatoire (borne de `isEditorPacket`).
- Pattern d'édition côté panneau : mutation directe du paramètre C++ →
  `EditorOpBus.recordOp(make<X>Op(uuid, fields))` +
  `Game.updateMap(EditDelta.TileModified, sp)` **débouncé** (Timer ~200 ms).

## Phase 3 — UI éditeur

- **Composant posable** : `qml/meowComponent/snapable/Snapable<X>.qml`
  (hérite `SnapableElement`), + entrée dans `qml/meowComponent/qmldir` ET
  `base_comp.qrc`.
- **Routage de pose** :
  - `EditorLogic.qml` : état d'armement (`<x>PoseArmed` + config), fonction
    `arm<X>Pose()` ; désarmer dans `clearAssetSelection`/`updateSelectedAsset`/
    `setCaseType` (sélections mutuellement exclusives).
  - `TileLogic.placeSelectedAsset` : brancher la nouvelle branche EN PREMIER.
  - `TileLogic.createItemSnapableTile` : router le `TileType` vers le
    composant, déclaré dans `EditorDynamicComponent.qml` (Component + alias).
- **Module d'éditeur** (panneau bas) : entrée dans le catalogue
  `ModuleManager.qml` (`availableModules`), dossier
  `moduleManager/<x>Panel/` (`<X>Panel.qml` chrome + `<X>_Content.qml` en
  `EBP_Content`), instanciation dans `Editor.qml` (binding
  `visible: moduleManager.selectedModuleId === "<id>"`) + id ajouté à la
  liste `_bottomModuleActive`.
- **Config de l'élément sélectionné** : dossier `configPanel/<x>ConfigPanel/`
  avec `<X>ConfigurationPanelSection.qml` (`CollapsableGroupBox`) + sections
  `XCP_*`, branché dans `BottomSidePanel_Content.qml` (+ alias dans
  `BottomSidePanel.qml`) et alimenté par `BottomSidePanel.updateSidePanel`
  (appelé à la sélection simple par `MouseLogic_Selection`).
- **Style** : tout via le singleton `Theme` + composants `Meow*` de
  `ui_item/` (`MeowTextField`, `MeowComboBox`, `MeowButton`,
  `MeowPropertyRow`, `MeowInfoBox`, `CollapsableGroupBox`). `pixelSize`
  uniquement, jamais `pointSize`.

## Phase 4 — Enregistrement QML (le plus oublié)

Chaque nouveau fichier/dossier QML exige **trois** choses :
1. Entrée `<file>` dans le `.qrc` concerné (`qml.qrc` pour editor/world3d,
   `base_comp.qrc` pour meowComponent/ui_item) — y compris le `qmldir`.
2. Ligne dans le `qmldir` du module (nouveau dossier = nouveau `qmldir`
   avec `module <nom>`).
3. Chemin d'import couvert par un `addImportPath` de `qmlapp.cpp`
   (~l.203-210) — les dossiers sous `moduleManager/` et `configPanel/` sont
   déjà couverts ; un dossier à un niveau inédit exige un nouveau
   `addImportPath`.

## Phase 5 — Runtime (world3d) si la feature vit en jeu

- Logique événementielle : décalquer `ScreenEffectController.qml`
  (Connections sur `pattounxWorld.actorEnteredZone/ExitedZone`, pile LIFO,
  copie de la pile avant mutation, `onlyActorId: "player"`).
- Zone de trigger : `PhysicZoneTile` standard **`exclusion=false`** (une
  zone exclusion est un mur, elle n'émet PAS enter/exit) ; lien élément↔zone
  par `connectionManager.addNextElement` + `Game.updateMap(TileModified)`
  (persisté + broadcast, la zone reste éditable avec l'outil existant) ;
  résolution runtime `zoneId → tile → getPrevList()`.
- Overlays 2D (bulles, badges) : enfant de `workArea` ancré sur
  `tile.x/tile.y` (pixels) — suit pan/zoom sans projection 3D. Pendant un
  drag, lire `t.x/gridSize`, PAS `gridRelativePositionX`.
- Nodes 3D multiples : `Instantiator` de `Node { parent: world3D.scene }`
  + `SkinnedModel` ; position via `gridToWorldStable(gx, gy)` avec
  dépendance explicite à `world3D._gridBasis` dans le binding.
- `snapableTilesList` est mutée par `push()` (non observé) : exposer un
  compteur de révision incrémenté sur `logic.snapableTilesListUpdated()` et
  le référencer dans les bindings de filtrage.

## Phase 6 — Automation + vérification

- Ajouter des hooks dans `editorAutomationHooks` (`Editor.qml`, ~l.2260) :
  `place<X>(...)` passant par le chemin UI exact (`arm<X>Pose` +
  `placeSelectedAsset` + `Game.updateMap(TileAdded)` puis restaurer
  `EM_NORMAL`), retour `{ ok, tile: _tileInfo(placed) }`. Un hook
  `saveMap(custom)` existe déjà pour forcer une sauvegarde.
- **Build** : reconfigure CMake (si .cpp ajoutés) → build Release →
  `Copy-Item build\Release\Meownopoly.exe build\` (l'exe racine est la copie
  déployée). Fermer l'app avant la copie (fichier verrouillé).
- **Vérification runtime** (pas de test runner) : lancer
  `build\Meownopoly.exe --automation-port 7700` (CWD `build/` → maps dans
  `build/map/`), piloter en WebSocket JSON `{id, cmd, params}` avec le
  `WebSocket` global de Node ≥ 21 (pas de dépendance) :
  `click objectName=editorButton` → attendre ~6 s → `invoke` sur
  `objectName=editorAutomationHooks` → `get _tileCount` → `screenshot`
  (résultat = chemin PNG, à ouvrir avec Read).
- **Round-trip obligatoire** : poser via hook (avec données piégées :
  guillemets, `\n`) → `saveMap` → inspecter le JSON de `build/map/` →
  quitter (`quit`) → relancer → re-entrer l'éditeur → vérifier
  `_tileCount` + screenshot.
- `qmllint` (Qt 6.11) sur les nouveaux QML pour la syntaxe (ignorer les
  erreurs d'import non résolus).

## Phase 7 — Documentation

- Mettre à jour le plan `doc/architecture/*_PLAN.md` : statut « implémenté »
  + section « État d'implémentation » listant fichiers livrés et **écarts
  assumés** par rapport au plan.
- Reporter les gotchas nouveaux dans CLAUDE.md seulement s'ils sont
  transverses (pas spécifiques à la feature).
- Commit local uniquement (pas de push sans demande explicite).
