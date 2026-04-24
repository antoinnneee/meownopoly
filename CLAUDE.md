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
- Map files stored in `./map/` (CWD-relative = `build/<config>/map/` en dev). Défini par `#define MAP_FILE_PATH` dans `cpp/game/map/mapfilemanager.h`. Pas d'isolation par `--instance N` pour les maps (contrairement à QSettings, chat DB, assets qui passent par `AppDataLocation`). **À ré-arbitrer** dans la suite des correctifs save/map.
- **Persisted "last opened map"** : QSettings `Editor/SaveConfig/lastOpenedMap` (renommé depuis `currentMap` pour lever la confusion avec `MapFileManager.currentMap` qui est un pointeur `Map*` live, sans rapport). Migration one-shot dans `Editor.qml:stEnableAutoSave.Component.onCompleted`.
- **Save-on-modification** : politique `saveEvent==3` (QSettings `Editor/SaveConfig/saveEvent`). Le fichier cible est `<mapName>_map.json` pour CUSTOM ou `autosave_tmp.json` pour AUTOSAVE. Le type d'origine est porté par `Map::sourceType()` (pas par `MapInfo` — une propriété d'emplacement, pas de contenu).

### Collaborative Editor (Phases 1-8)
- `EditorSession` (`cpp/editor/network/`) mirrors `GameSession` pattern on top of Catway. Host-authoritative: clients send ops, host validates/rebroadcasts.
- `EditorOpBus` (`cpp/editor/ops/`) is the QML-singleton chokepoint for **all** editor mutations. `submitOp(op)` logs + sends via `EditorSession` if active ; `submitOpWithUndo(op, inverseOp)` additionally pushes to the per-client undo stack.
- Frame format: `[1 byte EditorMessageType][JSON UTF-8]`, types start at `0x20` to coexist on Catway with `GameMessageType` (0x01–0x11). See `editor_message_type.h` / `editor_op_type.h`.
- Op set v1: `CreateItem`, `DeleteItem`, `MoveItem`, `ResizeItem`, `SetDisplayParameter`, `SetCaseData/DecorationParameter/ZoneParameter`, `LinkItems`, `UnlinkItems`.
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

### Physics
- Custom 2D engine ("PattounX") in `cpp/game/physics/`
- `PhysicsZone2D` + `ZoneParameter` define interaction volumes
- Circle collision with continuous collision detection (CCD)

## Key Patterns

- **Singletons**: `Catway`, `AssetManager`, `MapFileManager`, `LauncherManager`, `GameSession`, `EditorSession`, `EditorOpBus` — registered as QML singletons
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
  - `cpp/game/network/` — GameSession, GameProtocol, GameMessageType
  - `cpp/editor/network/` — EditorSession, EditorProtocol, EditorMessageType (frame `0x20+`)
  - `cpp/editor/ops/` — EditorOpBus (chokepoint mutations + undo stacks), EditorOpType
- `Meownopoly/qml/` — QML UI (editor, board, chat, menu, launcher, account, components)
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
