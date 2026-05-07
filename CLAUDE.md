# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Meownopoly is a networked board game (Monopoly-inspired, cat-themed) built with Qt6/QML and C++20. It includes a map editor, P2P multiplayer via UDP hole punching, a WebSocket chat system, and a custom 2D physics engine. The project language (code comments, docs, conventions) is primarily French.

## Branching

- **V2** : branche principale de développement (équivalent de main pour le travail actif)
- **V2Antoine** : branche de travail d'Antoine
- **V2_Valou** : branche de travail de Valou
- Les deux développeurs mergent dans V2 une fois leur travail stabilisé

## Build Commands

```bash
# Configure (from repo root)
cd Meownopoly && cmake -B ../build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build ../build

# Run
../build/Meownopoly.exe
```

Requires: CMake 3.21+, Ninja, Qt6 (Core, Quick, Qml, Widgets, QuickControls2, Network, WebSockets, Sql, Quick3D, Concurrent).

No automated test runner is configured. Manual testing via the executable.

## Architecture

### Threading Model
- **GUI thread**: QML UI + `Catway` singleton (network orchestrator)
- **Network thread**: `CatwayWorker` handles UDP I/O, STUN, heartbeats
- Cross-thread communication uses `Qt::BlockingQueuedConnection` for socket setup and `Qt::QueuedConnection` for async events

### Networking (Catway)
- P2P via UDP hole punching with STUN server discovery
- `reliable.io` library provides ACK-based reliability over UDP (magic byte `0x01` prefix)
- Heartbeats (`HP:PING`) every 10s to maintain NAT holes
- C callbacks bridge `reliable.io` into Qt's signal/slot system
- Key classes: `Catway`, `CatwayWorker`, `PlayerNetwork`, `StunManager`

### Chat System
- Client: C++ WebSocket (`ChatClient`) in `cpp/chat/`
- Server: Node.js + SQLite in `chatServer/`
- Protocol: JSON commands (JOIN_SESSION, SEND_MSG, GET_HISTORY)
- End-to-end encrypted blind relay (server never sees plaintext)

### Map Editor
- `GridManager` renders configurable grids; `ItemSnapable` is the base class for placeable elements
- Modular panel system with prefix naming: `CCP_` (case config), `ASP_` (asset), `VEP_` (visual effects)
- Selection uses AABB rectangles with multi-select support
- Undo/redo with full state management, autosave with debouncing
- **Rendu GPU viewport-cullé** (Qt 6.11+, `cpp/editor/painter/`) : la grille et les zones d'exclusion utilisent **un seul canvas painter global** chacune, qui couvre le viewport visible et fait du viewport culling. Modèle calqué : `GridCanvasPainter` pour la grille (croisillons, lignes), `ZonesOverlayPainter` pour les zones polygonales (fill + contour + hachures). L'ancien pattern "1 item canvas par tile" était impraticable au zoom (backing texture × N items, freezes >1 s/cran). Toggle env `MEOW_GRID_RENDERER=canvas|repeater` et `MEOW_ZONES_RENDERER=overlay|per-tile` (défaut canvas/overlay). Cf. `qmlapp.cpp` pour les context properties `_gridRendererUseCanvas` et `_useZonesOverlay`.
- **Zoom multiplicatif ×1.1 par cran** : `mmSize` est `real` (pas int) pour permettre un zoom continu. `ScrollLogic.scrollGrid` multiplie au lieu d'additionner. La caméra 3D `World3D` suit via `cameraMagnification: gameGrid.scaleLevel`.
- Map files stored in `./map/` (CWD-relative = `build/<config>/map/` en dev). Défini par `#define MAP_FILE_PATH` dans `cpp/game/map/mapfilemanager.h`. Pas d'isolation par `--instance N` pour les maps (contrairement à QSettings, chat DB, assets qui passent par `AppDataLocation`). **À ré-arbitrer** dans la suite des correctifs save/map.
- **Persisted "last opened map"** : QSettings `Editor/SaveConfig/lastOpenedMap` (renommé depuis `currentMap` pour lever la confusion avec `MapFileManager.currentMap` qui est un pointeur `Map*` live, sans rapport). Migration one-shot dans `Editor.qml:stEnableAutoSave.Component.onCompleted`.
- **Save-on-modification** : politique `saveEvent==3` (QSettings `Editor/SaveConfig/saveEvent`). Le fichier cible est `<mapName>_map.json` pour CUSTOM ou `autosave_tmp.json` pour AUTOSAVE. Le type d'origine est porté par `Map::sourceType()` (pas par `MapInfo` — une propriété d'emplacement, pas de contenu).

### Collaborative Editor (Phases 1-8)
- `EditorSession` (`cpp/editor/network/`) mirrors `GameSession` pattern on top of Catway. Host-authoritative: clients send ops, host validates/rebroadcasts.
- `EditorOpBus` (`cpp/editor/ops/`) is the QML-singleton chokepoint for **all** editor mutations. `submitOp(op)` logs + sends via `EditorSession` if active ; `submitOpWithUndo(op, inverseOp)` additionally pushes to the per-client undo stack.
- Frame format: `[1 byte EditorMessageType][JSON UTF-8]`, types start at `0x20` to coexist on Catway with `GameMessageType` (0x01–0x11). See `editor_message_type.h` / `editor_op_type.h`.
- Op set v1: `CreateItem`, `DeleteItem`, `MoveItem`, `ResizeItem`, `SetDisplayParameter`, `SetCaseData/DecorationParameter/ZoneParameter`, `LinkItems`, `UnlinkItems`.
- Op set Player Config (12-16) : `AddPlayerProfile`, `RemovePlayerProfile`, `UpdatePlayerProfile` (champs partiels, LWW grossier sur conflits), `ReorderPlayerProfile`, `SetMapPlayerLimits` (min/max). Helpers `EditorOpBus.make{Add,Remove,Update,Reorder}PlayerProfileOp` + `makeSetMapPlayerLimitsOp`. Apply remote dans `Editor.qml` (cases 12-16). Ces ops transitent via `EditorMessageType::Op` (0x23) déjà couvert par `isEditorPacket` — la borne `>= Hello && <= <dernier type>` ne filtre que les `EditorMessageType` (0x20+), pas les `EditorOpType`. **Gap connu : pas d'undo sur les profils en v1** (utilisent `submitOp`, pas `submitOpWithUndo`). Voir `doc/architecture/PLAYER_CONFIG_PANEL_PLAN.md`.
- Remote apply (QML `Connections` on `EditorOpBus.remoteOpReceived` in `Editor.qml`) : dispatch par op, wrap par `beginApplyRemote/endApplyRemote` pour empêcher la boucle de re-soumission.
- Phase 4 full-sync : client envoie `Hello` → host envoie map chunks (< 28 KB) en reliable ordonné → client wipe + rebuild via `ItemSnapableFactory.createItemSnapableFromJson`.
- Phase 5 présence : curseurs via `Catway.broadcastRaw("EC:<pid>;<x>;<y>")` (lossy, 20 Hz) rendus dans un `HoverHandler` enfant de `workArea` ; sélections via `EditorSession.remoteSelections` (`QVariantMap` exposée en Q_PROPERTY).
- Phase 6 undo v1 : `submitOpWithUndo` pour Create/Delete/Link/Unlink seulement (inverses triviaux). Move/Resize/Set* reportés (capture de pré-image non faite). Ctrl+Z/Y interceptés dans `EditorController` quand `EditorSession.active`.
- Phase 7 entrée lobby : mode éditeur encodé par prefix `[EDIT:<hostId>]` dans le nom de session (évite toute modif du serveur chat). `MultiplayerLobby` émet `launchNewSession/launchExistingSession(isEdition, hostId)` ; `main.qml` pilote la state machine P2P : `setupNewPort → STUN → sendRequestConnectionInfo → initiateHolePunch → p2pConnected → startAsClient + push editor`. Le lobby reste dans la stack sous l'éditeur pour préserver `lobbyChatClient` (Catway en dépend pour les REQUEST_CONNECTION_INFO).
- Phase 8 host migration (volontaire + timeout) :
  - Annonce volontaire : `EditorMessageType::HostLeaving` (`0x2A`) broadcasté en reliable par l'hôte sortant avec `{ roster: [...] }` (roster autoritaire embarqué pour éviter split-brain d'élection). Appelé depuis `escMenu.onReturnToMainMenu` AVANT `EditorSession.stop()`, et depuis `ApplicationWindow.onClosing` avec `close.accepted=false` + `Timer(300ms) → Qt.quit()` pour laisser le paquet UDP partir.
  - Timeout fallback : `onPlayerTimedOut` côté client déclenche le même flow via `emit hostLost`.
  - Élection : `electNewHost()` déterministe (min lexico du roster excluant ancien hôte), tous les clients convergent. Le client élu `promoteToHost()` (= `stop()` + `startAsHost()` en préservant tuiles/undo), puis émet `promotedToHost` → `main.qml.onPromotedToHost` → `chatClient.renameSession("[EDIT:<newHostId>]…")` + `chatClient.transferHost(newHostId)` (commande serveur `TRANSFER_HOST`).
  - Côté clients non-élus : `onHostLost` purge la carte (wipe `snapableTilesList` + `Game.initEmptyCollabMap()`) puis émet `reconnectRequested(sid, electedHostId)` → `onReconnectRequested` relance `p2pStateMachine` avec `skipPush=true` vers le nouvel hôte.
  - Serveur chat : nouvelle colonne `sessions.host_player_id` + commande `TRANSFER_HOST` + broadcast `HOST_CHANGED`. `isHost`/`getHost` utilisent `host_player_id` en priorité (fallback legacy sur premier `joined_at`). Sans ça, l'ancien hôte qui rejoint récupérerait les droits admin (CLEAR_HISTORY, DELETE_SESSION) car il avait le `joined_at` le plus ancien. Serveur-side : `handleJoinSession` initialise `host_player_id` au premier joiner si null.
  - Client C++ : `ChatClient::transferHost(newHostId)` + signal `hostChanged(sessionId, hostPlayerId)`. `availableSessions[i]` expose `hostId` (en plus de `hostNickname`), mis à jour in-place par `handleHostChanged`.
  - Re-entrée dans sa propre session : `ChatClient::setSessionId` guard l'émission si id inchangé → `MultiplayerLobby.onSessionIdChanged` ne fire pas. Fix : dans `onSessionSelected`, si `lobbyChatClient.sessionId === sessionData.sessionId && connected`, appeler `launchExistingSession` directement sans passer par `connectToSessionDirect`.
- Test harness : `qml/test/CatwayTest/EditorNetworkTestTab.qml` avec `EditorSessionPanel` + `EditorOpsCard` (log live des ops locales/distantes).
- Gaps connus : live-edits CCPS_* ne passent pas par l'op bus (uuid inaccessible depuis les sections) ; LWW naïf sur conflits ; pendant la fenêtre de migration (~100-300 ms), warnings `[SÉCURITÉ] Paquet UDP spoofé` noisy (résiduels de l'ancien socket), non-bloquant (seuls les paquets UDP non-fiables sont concernés, pas reliable.io).

### Game Logic
- `Case` hierarchy: `CasePerks`, `CaseRestArea`, `CaseCatDoor`, `CaseJail`, `CaseCardBoardBox`
- `CaseFactory` creates instances by type
- 4-phase turn system: action pre-move, move, action post-move, wait
- Coproperty system (shared ownership), anonymous auctions (blind bidding)
- Maps stored as JSON
- **Roster joueurs** (`MapInfo` + `PlayerProfile`, cf. `doc/architecture/PLAYER_CONFIG_PANEL_PLAN.md`) : la map embarque `minPlayers`/`maxPlayers` (indicatifs, pas de check bloquant) + une liste de `PlayerProfile` configurables dans l'éditeur (5e onglet "Joueurs" du `AssetSelectionPanel`). Chaque profil porte `name`, `modelName`, `pickMode` (`Unique`/`Shared`/`Mandatory`) + `minOccurrences`, et tous les paramètres physiques (radius, mass, accel, maxSpeed, dampings, frictions, bounce). `playerConfigVersion` versionne le schéma (courant : 1) ; `version > current` → roster wipé + Princess réinjecté avec warning. **Fallback Princess** : tout `MapInfo` (default ctor ou JSON sans/avec roster vide) reçoit automatiquement un profil "Princess" via `ensureFallbackProfile()` — couvre les anciennes maps pré-Phase 1.

### Physics (Pattounx v2)
- Moteur 2D maison **Pattounx v2**, dédié à Meownopoly. V1 (`PattounX_engine`/`PattounX_body`/`PattounX_zone` QObject) supprimée (commit `328e263`).
- Cœur Qt-free `pattounx::PattounX_engine` dans `cpp/game/physics/pattounx_engine_v2.{h,cpp}` ; types POD partagés (`BodySpec`, `ZoneSpec`, `BodySnapshot`, `WorldSnapshot`, enums `BodyType`/`ShapeType`) dans `pattounx_types.h`.
- **Thread physique dédié** : `PhysicsWorker` (`physics_worker.{h,cpp}`) tourne dans son `QThread` à 60 Hz. Façade GUI `PhysicsWorld` (`physics_world.{h,cpp}`) expose API QML, fait le triple buffer Fraser-Harris lock-free pour les snapshots, et code/décode pour le réseau. Toutes les commandes GUI → worker passent par signaux `Qt::QueuedConnection`. Aucune mutation directe du moteur depuis le GUI.
- **Bodies multi-types** : `Static` (figé), `Kinematic` (input-driven, `invMass==0`, pousse les Dynamic mais ne reçoit pas de réponse), `Dynamic` (forces, masse, body-body). Plusieurs actors instantiables (player principal + P2 toggleable, caisses).
- **Collisions** : cercle-polygone (zones d'exclusion/effet) avec CCD analytique sweep cercle-segment + cercle-vertex, body-body cercle-cercle avec sweep + résolution d'impulsion (caisses). Friction Coulomb (statique + dynamique), `linearDamping` exponentiel framerate-indep, "sleep system".
- **Bridge éditeur** : `ItemSnapableEvents` (singleton agrégateur de signaux tile-by-tile) + `EditorPhysicsBridge.qml` ; sync live des zones (`upsertZone`/`removeZone` debounce 30 Hz). Caisses (`SnapablePhysicalObject`) paramétrables via `PhysicalObjectParameter` (`mass`/`bounceFactor`/`frictionStrength`/`linearDamping`) — porté par `ItemSnapable`, exposé en QML, sérialisé dans le JSON de map (commit `56195cb`).
- **Réseau** : `PhysicsSession` (`physics_session.{h,cpp}`, singleton QML module `Pattounx`) host-authoritative, broadcast snapshot 30 Hz reliable (plage `physics_message_type.h` 0x40+ : `Snapshot`, `BodiesAnnounce`, `InputUpdate`, `Hello`/`Welcome`). Clients route leurs inputs reliable vers l'hôte qui simule pour tout le monde.
- **Présentation 3D** : `qml/world3d/World3D.qml` (View3D + helpers grid↔world), `PhysicsActor.qml` (présentateur 3D, pull `bodyState(id)` chaque tick FrameAnimation, lissage, **Y visuel 2.5D** via `visualY` + `jump()`/`wave()`), `PhysicsObjectSpawner.qml` (spawn auto sur tiles `PhysicalObjectTile`), `LocalPlayerSpawner.qml`, `EditorPhysicsBridge.qml`, `InputController.qml` (clavier → `pushInput(actorId, vec)`), `CameraRig.qml` (modes `Follow`/`Free`/`FixedTopDown`).
- `PhysicsObject` a été absorbé dans `PhysicsActor` (commit `750d4f8`) — un seul présentateur 3D pour joueurs et caisses.
- Doc complète : `doc/architecture/PHYSICS_ENGINE_V2.md` (post-Phase 9). `PHYSICS_ENGINE.md` est l'archive V1 legacy (à ignorer pour le code actuel). `PHYSICS_REFACTOR_PLAN.md` garde l'historique des décisions et phases.

## Key Patterns

- **Singletons**: `Catway`, `AssetManager`, `MapFileManager`, `LauncherManager`, `GameSession`, `EditorSession`, `EditorOpBus`, `PhysicsSession`, `ItemSnapableEvents` — registered as QML singletons. `PhysicsWorld` est exposé via `contextProperty("pattounxWorld")` (pas singleton QML, mais instance globale unique survivant aux navigations).
- **C++/QML bridge**: `Q_PROPERTY` for data binding, `Q_INVOKABLE` for method calls
- **Resource files**: `qml.qrc`, `asset.qrc`, `base_comp.qrc`, `chat.qrc`, `launcher.qrc`, `other.qrc`

## QML / Qt gotchas learned in this repo

- **Q_PROPERTY name, pas getter name** : QML lit le nom de la *propriété*, pas celui de la méthode C++. Exemple : `Q_PROPERTY(bool p2pConnected READ isP2pConnected …)` → côté QML, `player.p2pConnected` (pas `player.isP2pConnected` qui renvoie `undefined`).
- **Hover sans clic** : `MouseArea { hoverEnabled: true }` est masqué si un enfant capte l'événement. Pour tracker la souris sans que les enfants ne consomment, utiliser `HoverHandler` (Qt6 pointer handler), qui coexiste avec les MouseAreas.
- **Binding sur `var` map** : muter un champ en place (`map[key] = v`) ne déclenche pas la ré-évaluation des bindings QML. Réassigner la map entière : `map = Object.assign({}, map, { [key]: v })` — ou un pattern équivalent qui crée un nouvel objet.
- **`sessionIdChanged` pas émis** : si un setter C++ assigne directement `m_foo = …` sans passer par son `setFoo` qui `emit fooChanged()`, les handlers QML `onFooChanged` restent muets. Leçon apprise sur `ChatClient::connectToSessionDirect` — toujours passer par le setter.
- **QQmlListProperty n'est pas une JS array** : pas d'accès par index direct depuis JS. Exposer des helpers `Q_INVOKABLE QObject *fooAt(int)` / `int fooCount()` / `QObject *lastFoo()` si besoin (voir `Catway::localPortAt/localPortCount/lastLocalPort`).
- **Catway.chatClient est shared** : un seul `ChatClient` peut être enregistré à la fois via `Catway::setChatClient`. En mode collab éditeur, préserver le ChatClient du lobby (la session collab) — ne pas le laisser être écrasé par le ChatClient d'in-game de `ChatDrawer` (gate sur `!EditorSession.active` dans `Editor.qml`).
- **Hole-punch client** nécessite 3 étapes explicites dans l'ordre : `setupNewPort()` → `chatClient.sendRequestConnectionInfo(peerId, ip, port, localPort)` → `initiateHolePunch(player)`. Les 2 premières sont implicites si on attend le heartbeat (10 s cycle), mais `initiateHolePunch` doit être appelé explicitement depuis QML pour un lien rapide. Après `takeStunSocket`, c'est `Catway.lastLocalPort()` qu'il faut lire (pas `currentSocketInfo()` qui est alors vide).
- **Catway.m_players persiste à travers EditorSession.stop/start** : `EditorSession.stop()` ne déconnecte que les handlers de signaux, pas les `PlayerNetwork`. Conséquence : après migration hôte, l'ancien hôte qui rejoint a encore en cache `PlayerNetwork(<newHost>, oldIP, oldPort, p2pConnected=true)`. `p2pStateMachine` croit être connecté instantanément (300 ms) → Hello envoyé sur un port mort → pas de FullSync. Fix : `main.qml.onLaunchExistingSession` appelle `Catway.removePlayer(Catway.playerById(hostId))` avant de démarrer le state machine. Idem dans `EditorSession::onReliableReceived` case `HostLeaving` qui purge l'ancien hôte. `Catway::removePlayer` libère aussi le socket local si plus aucun pair ne l'utilise → `setupNewPort` kick naturellement au prochain tick.
- **`ChatClient::setSessionId` no-op si id inchangé** : le setter guard `if (m_sessionId != id)` avant `emit sessionIdChanged()`. Conséquence : se reconnecter à la session courante (ex: quitter l'éditeur collab puis re-cliquer la même session) ne fait pas re-fire `onSessionIdChanged` → handler de nav pas déclenché. Fix dans `MultiplayerLobby.onSessionSelected` : si `lobbyChatClient.sessionId === target && connected`, appeler `launchExistingSession` directement.
- **`Game`/`MapFileManager` sont singletons persistants** : la `Map` C++ survit à la destruction du QML `Editor` (quit + re-push). Sur rejoin collab, `Game.m_tiles` garde les uuids de la session précédente → `applyRemoteDelta(TileAdded)` du FullSync no-ope → carte QML vide alors que le C++ a les données. Fix : `Game::initEmptyCollabMap()` recrée toujours une `Map` neuve (`setCurrentMap(newMap)` delete-later l'ancienne). En reconnect post-migration (`skipPush=true`, pas de nouveau `Editor.Component.onCompleted`), l'appel doit être fait explicitement — cf. `Editor.onHostLost` qui wipe `snapableTilesList` + `Game.initEmptyCollabMap()` avant `reconnectRequested`.
- **Ajout d'un `EditorMessageType`** : `EditorProtocol::isEditorPacket` filtre par plage `>= Hello && <= <dernier type>`. Toute nouvelle valeur doit être la plus haute, sinon les paquets entrants sont silencieusement droppés par `unpack`. Cf. commentaire dans `editor_protocol.cpp`.
- **`ApplicationWindow.onClosing` + broadcast Catway** : `Catway::broadcastReliable` utilise `Qt::QueuedConnection` vers le worker thread. Si `Qt.quit()` est appelé directement dans `onClosing`, le paquet n'a pas le temps de sortir. Pattern : `close.accepted=false` + `Timer(interval:300, onTriggered: Qt.quit())`, avec un garde `if (closeDelayTimer.running) return` pour éviter la récursion sur le 2e `onClosing` déclenché par `Qt.quit()`.
- **`ChatClient::password_hash` format** : `ChatCrypto::derivePasswordProof` retourne déjà du SHA-256 **hex** via `.toHex()` (64 chars). L'envoi serveur doit passer par `QString::fromLatin1(m_passwordHash)` — **ne pas** ré-appliquer `.toBase64()` (produisait 88 chars "b64 of hex", rejeté par la validation stricte du serveur). Le serveur accepte `^[0-9a-fA-F]{64}$` ou `^[A-Za-z0-9+/]{43}=$` (base64 canonique pour le dashboard JS). Les deux sites à garder cohérents : `ChatClient::createSession` et `ChatClient::joinSession`.
- **Phase 8 `TRANSFER_HOST` : pas de garde serveur "ancien hôte encore connecté"** : quand l'hôte ferme son éditeur via `HostLeaving` (Timer 300 ms avant `Qt.quit()`), les pairs élisent et envoient `TRANSFER_HOST` avant que la WS chat lobby de l'hôte ne soit close côté serveur. Un garde naïf "refuse si rooms contient encore le host_player_id" casserait la migration. Le serveur fait confiance au client élu (élection déterministe min-lexico côté pairs) ; seule garde restante : `db.isParticipant(session_id, new_host_id)`.
- **`QQuickRhiItem` (= `QCanvasPainterItem`) backing texture explose au zoom si 1 item / tile** : la texture suit `width × height × dpr`. Pour un canvas painter par tile dimensionné via `* gridSize` (ex: zone d'exclusion 10×10 cellules à mmSize=200 = 2000×2000 px = 16 MB), Qt ré-alloue à chaque cran de zoom → freezes ponctuels >1 s. Pattern : un seul canvas global qui couvre le viewport visible et fait du viewport culling. Voir `GridCanvasPainter` (1 canvas pour toute la grille) et `ZonesOverlayPainter` (1 canvas pour toutes les zones), instanciés dans `Editor.qml`. Le canvas reçoit la liste des items à dessiner via Q_PROPERTY (binding QML qui itère snapableTilesList et capture les deps fines), itère, compute bbox écran, viewport-cull, dessine. `setFixedColorBufferWidth/Height` (cap dur) n'est PAS une bonne solution alternative : Qt étire le texture sur tout l'item → flou inacceptable.
- **`visible: false` ne libère PAS le backing texture d'un `QCanvasPainterItem`** : un item invisible mais instancié continue de réagir aux changes `width`/`height` et de réallouer son backing GPU. Pour vraiment l'éliminer (ex: en cas de toggle vers un overlay global), passer par `Loader { active: ... ; sourceComponent: ... }` côté QML — l'item n'est pas créé. Cf. `SnapableExclusionZone.qml` qui passe son `ZoneCanvasPainter` legacy sous Loader pour ne pas ré-allouer le backing au zoom quand l'overlay global prend le relais.
- **Position pendant un drag : pixels (`x/y`), pas grille (`gridRelativePosition`)** : le drag manipule directement `element.x` / `element.y` (pixels) via la `MouseLogic`, et la conversion vers `gridRelativePositionX/Y` (coords grille) ne se fait qu'au snap (`onReleased`). Pour un binding qui doit être visuellement à jour pendant un drag (ex: overlay externe au SnapableElement), lire `t.x / gridSize`, pas `t.snapableParameters.displayParameter.gridRelativePositionX`. Le ZoneCanvasPainter individuel ne souffrait pas car `anchors.fill: parent` du SnapableElement faisait suivre `x`/`y` automatiquement.
- **`Loader.source = "qrc:/..."` peut fail silencieusement** (status=Error sans message clair). Si le module C++ utilisé par le QML chargé est déjà importé ailleurs dans la scène (linker OK), préférer instancier directement le composant via `import` + Component inline plutôt qu'un `Loader { source: "qrc:/..." }`. `ZonesOverlayPainter` est instancié directement dans `Editor.qml` après échec du Loader/qrc.
- **`FrameAnimation.onTriggered` ne reçoit PAS `frameTime` en argument** en Qt 6 — c'est une property du FrameAnimation (en SECONDES depuis la frame précédente) qu'il faut lire dans le scope. Pattern : `FrameAnimation { id: anim; onTriggered: { const dtMs = anim.frameTime * 1000; ... } }`.
- **Zoom multiplicatif nécessite `mmSize` en `real`** (pas `int`) — sinon `mmSize * 1.1` se ré-arrondit à chaque cran et le zoom progresse par ±1 mmSize seulement. `GridManager.mmSize` est passé en `real` (cf. commit `c0205b3`) ; `gridSize` aussi pour préserver la précision (les downstream usages `* gridSize` / `Math.round(... / gridSize)` sont déjà compatibles).

## QML Conventions

- Root `id`: `root` by default, or a semantic role name
- Files: `PascalCase.qml`; editor panels prefixed (`CCP_`, `ASP_`, `VEP_`)
- Internal properties prefixed with `_`
- Signals: `camelCase`, often suffixed `Requested`. Avoid `Changed` suffix for custom signals — QML auto-generates `<property>Changed` for every property/alias, causing "Duplicate signal name" errors
- Prefer declarative bindings over imperative assignments in signal handlers — imperative `prop = value` overwrites bindings and triggers `qt.qml.binding.removal` warnings
- Use `root.` prefix in children to avoid binding ambiguity
- Use `const`/`let` (not `var`) in JS functions
- Reusable components in `ui_item/`, board elements in `meowComponent/`, logic in `board/logic/` or `editor/logic/`
- Base types prefixed `Base_` (e.g., `Base_Board`, `Base_logic`)

## Directory Layout

- `Meownopoly/cpp/` — C++ source (game logic, networking, chat, assets, physics, editor)
  - `cpp/communication/` — Catway, PlayerNetwork, StunManager, UdpSocketInfo
  - `cpp/game/network/` — GameSession, GameProtocol, GameMessageType, MinigameSync
  - `cpp/game/physics/` — Pattounx v2 (engine_v2, types, worker, world, session, protocol, message_type, item_snapable_events, collision2d)
  - `cpp/editor/network/` — EditorSession, EditorProtocol, EditorMessageType (frame `0x20+`)
  - `cpp/editor/ops/` — EditorOpBus (chokepoint mutations + undo stacks), EditorOpType
  - `cpp/editor/painter/` — Composants GPU 2D pour l'éditeur (Qt 6.11+) : `grid_canvas_painter*` (1 canvas pour la grille entière, viewport culling), `zones_overlay_painter*` (1 canvas pour toutes les zones d'exclusion, viewport culling), `zone_canvas_painter*` (legacy 1 canvas / zone, fallback `MEOW_ZONES_RENDERER=per-tile`), `zone_hatch_compute*` (scanline hachures factorisé, modes baseline/qtc/precompute(-async))
- `Meownopoly/qml/` — QML UI (editor, board, chat, menu, launcher, account, components)
  - `qml/world3d/` — Présentation 3D physique (World3D, PhysicsActor, PhysicsObjectSpawner, LocalPlayerSpawner, EditorPhysicsBridge, InputController, CameraRig)
  - `qml/test/CatwayTest/` — dev harness incl. `EditorSessionPanel`, `EditorOpsCard`, `EditorNetworkTestTab`
  - `qml/multiplayer/` — lobby (MultiplayerLobby, SessionList, SessionCard, SessionCreation, SessionDetails)
- `Meownopoly/doc/` — Comprehensive project documentation (40+ files)
- `Meownopoly/config/` — Configuration files
- `chatServer/` — Node.js WebSocket chat server with SQLite (deploy via `deploy.sh` + `.deployEnv`)
- `asset_server/` — Node.js HTTP asset distribution server (deploy via `deploy.sh` + `.deployEnv`)
- `image_tools/` — Image processing utilities

## Dev test harness

- **Cible CMake `dual_test_p2p`** (Windows) lance 2 instances : Instance 1 et Instance 2 (avec `--instance 2`). `main.cpp` ajuste `applicationName` en conséquence → `QStandardPaths::AppDataLocation` renvoie des dossiers distincts (`Meownopoly/` vs `Meownopoly_2/`).
- **CatwayTest scene** : tabs Catway / UDP Tests / Game Network / Editor Network. L'onglet Editor Network permet de démarrer manuellement une EditorSession pour tests sans passer par le lobby.

## External Documentation

Extensive docs exist in `Meownopoly/doc/` — check `doc/INDEX.md` for the full index and `doc/QUICK_START.md` for navigation. Key architecture docs:
- `doc/architecture/P2P_NETWORK_ARCHITECTURE.md` — Catway/networking details
- `doc/architecture/ANALYSE_ARCHITECTURE_EDITEUR.md` — Editor architecture (detailed)
- `doc/architecture/CATWAY_ARCHITECTURE.md` — P2P/UDP communication
- `doc/architecture/PROJECT_STRUCTURE.md` — Code organization
- `doc/architecture/PHYSICS_ENGINE_V2.md` — Moteur physique Pattounx v2 (post-refactor) ; **ne pas se fier** à `PHYSICS_ENGINE.md` (V1 archivée, contient des erreurs)
- `doc/architecture/PHYSICS_REFACTOR_PLAN.md` — Décisions, phases et roadmap du refactor physique
