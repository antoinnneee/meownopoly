# Éditeur collaboratif — architecture

L'éditeur de cartes de Meownopoly supporte l'édition simultanée à plusieurs joueurs via une couche réseau construite au-dessus de `Catway` (P2P UDP + reliable.io). Ce document couvre la stack réseau, le bus d'opérations, l'élection d'hôte, la reconnexion automatique, et les stats de transmission.

---

## 1. Vue d'ensemble

Modèle **host-authoritative** : un pair est l'hôte ; les autres sont clients. Les clients ne mutent jamais la carte directement — ils envoient des **ops** (opérations logiques) à l'hôte, qui les valide, les applique, puis les rediffuse à tout le monde (auteur inclus). Chaque client attend le rebroadcast avant d'appliquer.

```
CLIENT                             HOST                           OTHER CLIENTS
  │                                  │                                  │
  │  submit(op)  ── reliable ──▶    │                                  │
  │                                  │  validate + apply local          │
  │  ◀── rebroadcast (with _seq)   rebroadcast  ─────reliable────▶     │
  │  apply remote op                 │                          apply remote op
```

- Séparation stricte : le monoposte reste le code par défaut, `EditorSession.active` gate tout ce qui va sur le réseau.
- Exclusivité avec `GameSession` : les deux sessions ne peuvent pas tourner en même temps sur le même canal Catway.
- Frame wire : `[1 octet type][JSON UTF-8]`. Types éditeur en `0x20+` pour coexister avec les types jeu en `0x01–0x11`.

---

## 2. Composants

### 2.1 `EditorSession` (`cpp/editor/network/editor_session.{h,cpp}`)

Singleton QML (`import EditorSession 1.0`). Même patron que `GameSession`. Rôles :

- `startAsHost(playerId, sessionId?)` / `startAsClient(playerId, hostPlayerId, sessionId?)` / `stop()`.
- Ecoute `Catway::reliableMessageReceived` et filtre les paquets dont le premier octet est dans la plage `EditorMessageType`.
- Dispatch : `Op` → signal `opReceived(senderId, op)` ; autres → `editorEventReceived(type, …)`.
- **Host-seul** : rate-limit par sender (token bucket 30 ops/s, burst 60), ajout d'un `_seq` monotone à chaque op rebroadcastée, ajout de `_by` (sender id), relay aux autres pairs.
- **Cursor** UDP brut via `Catway::broadcastRaw("EC:<pid>;<x>;<y>")` (lossy, 20 Hz).

Q_PROPERTY exposés : `active`, `isHost`, `localPlayerId`, `hostPlayerId`, `sessionId`, `remoteSelections` (QVariantMap), `knownRoster` (QStringList, élection).

### 2.2 `EditorOpBus` (`cpp/editor/ops/editor_op_bus.{h,cpp}`)

Singleton QML (`import EditorOpBus 1.0`). Chokepoint **unique** par lequel passent toutes les mutations utilisateur. Responsabilités :

- `submitOp(op)` — loggue, rate-limit local (token bucket, évite de noyer la file réseau), envoie à `EditorSession` si collaboratif.
- `submitOpWithUndo(op, inverseOp)` — en plus, pousse l'entrée `{op, inverseOp}` sur une pile d'undo locale.
- `undo()` / `redo()` — resoumet l'inverse (ou l'op) sans re-push, avec pivot sur la pile opposée.
- `beginApplyRemote()` / `endApplyRemote()` — garde qui fait droper tous les `submitOp` déclenchés par l'application d'ops distantes (empêche la boucle réseau).
- `onSessionOpReceived(senderId, op)` — émet `remoteOpReceived(op)` pour que QML applique, entouré de begin/endApplyRemote. Log structuré `[EditorOpBus] apply seq=X by=Y type=Z`.

Helpers de construction : `makeCreateOp`, `makeDeleteOp`, `makeMoveOp`, `makeLinkOp`, `makeUnlinkOp`, `newUuid` ; côté player-config : `makeAddPlayerProfileOp`, `makeRemovePlayerProfileOp`, `makeUpdatePlayerProfileOp`, `makeReorderPlayerProfileOp`, `makeSetMapPlayerLimitsOp` ; et `submitFromDelta` / `flushGroup` pour le transport `ApplyState` (liste non exhaustive).

### 2.3 Types de messages (`editor_message_type.h`)

| Code | Nom | Direction | Payload |
|------|-----|-----------|---------|
| `0x20` | `Hello` | Client → Host | `{nickname, assetPackHash}` |
| `0x21` | `Welcome` | Host → Client | réservé (non utilisé en v1) |
| `0x22` | `FullSync` | Host → Client | `{chunkIndex, chunkCount, payload}` — snapshot map |
| `0x23` | `Op` | Client ↔ Host | op JSON + `_seq`/`_by` côté host |
| `0x24` | `OpAck` | Host → Client | réservé |
| `0x25` | `OpReject` | Host → Client | `{op, reason}` (rate-limit, schéma invalide) |
| `0x26` | `CursorUpdate` | UDP brut | `EC:<pid>;<x>;<y>` (non-reliable) |
| `0x27` | `SelectionUpdate` | Broadcast reliable | `{uuids}` |
| `0x28` | `PlayerRoster` | Host → Tous | `{players: [pid, …]}` |
| `0x29` | `OpChunk` | Reliable | `{opId, chunkIndex, chunkCount, origType, payloadB64}` pour ops > 20 KB |
| `0x2A` | `HostLeaving` | Host → Tous | `{ roster: [...] }` — annonce de départ volontaire de l'hôte ; déclenche l'élection immédiate côté clients (sans attendre le timeout Catway) |

### 2.4 Op set v1 — ops items de base

Chaque op est un `QJsonObject` avec au moins `{op: <EditorOpType>, …}`.

| Op | Payload | Cible |
|----|---------|-------|
| `CreateItem` | `{item: <JSON complet ItemSnapable, UUID pré-mintée>}` | — |
| `DeleteItem` | `{target: <uuid>}` | item |
| `MoveItem` | `{target, gridX, gridY, zOrder?}` | item |
| `ResizeItem` | `{target, w, h}` | item |
| `SetDisplayParameter` | `{target, fields: {field: value, …}}` | `displayParameter` (brightness, contrast, saturation, `colorization`, `colorizationColor`, blur, shadow, rotation, miroirs, zLayer…) |
| `SetCaseData` / `SetDecorationParameter` / `SetZoneParameter` | `{target, fields: {…}}` | sous-objet typé |
| `LinkItems` / `UnlinkItems` | `{source, target, kind}` | lien inter-items |

Ops additionnelles courantes (non listées ci-dessus) : `ApplyState` (11, transport générique d'un EditDelta — `Game::updateMap` / `askPreview` / `askNext`), et les ops player-config `AddPlayerProfile` (12), `RemovePlayerProfile` (13), `UpdatePlayerProfile` (14), `ReorderPlayerProfile` (15), `SetMapPlayerLimits` (16). Cf. `editor_op_type.h` et `PLAYER_CONFIG_PANEL_PLAN.md`.

Undo supporté v1 : `CreateItem`, `DeleteItem`, `LinkItems`, `UnlinkItems` seulement. `MoveItem` / `ResizeItem` / `Set*` sont reportés (demandent une capture pré-image au submit).

### 2.5 Apply remote (QML)

Dans `Editor.qml`, `Connections { target: EditorOpBus; function onRemoteOpReceived(op) { … } }` dispatche par `op.op` et mute directement l'état local. Wrap automatique `beginApplyRemote/endApplyRemote` autour du signal évite la re-soumission.

---

## 3. Flux

### 3.1 Entrée via le lobby

Encodage du mode éditeur dans le nom de session : prefix `[EDIT:<hostPlayerId>] <nom user>`. Évite toute modif du serveur chat.

- `MultiplayerLobby` détecte le prefix dans `onSessionCreated` (hôte) et `onSessionIdChanged` (client) → émet `launchNewSession(isEdition, hostId, rawSessionName, initialMap)` / `launchExistingSession(isEdition, hostId)`.
- `main.qml` pilote la state machine P2P côté client : `setupNewPort → STUN → sendRequestConnectionInfo → initiateHolePunch → p2pConnected → startAsClient + push editor`.
- Le lobby reste dans la `StackView` sous l'éditeur pour garder `lobbyChatClient` vivant (Catway en dépend pour le signaling chat).

### 3.2 Full-sync à la connexion

1. Client devient actif → envoie `Hello` via `EditorSession.sendEvent(Hello, {nickname, assetPackHash})`.
2. Host reçoit `Hello` → ajoute le sender au roster (`m_knownRoster`) + diffuse `PlayerRoster` à tous + appelle `_sendFullSyncTo(senderId)`.
3. `_sendFullSyncTo` sérialise toutes les tuiles (`itemSnapable.toJSON()`), splitte en chunks < 20 KB, envoie point-à-point `FullSync{chunkIndex, chunkCount, payload}`.
4. Client accumule les chunks (`fullSyncBuffer.chunks`), quand `count` atteint : parse JSON, wrap `beginApplyRemote`, **wipe local** des tuiles existantes (sécurité), recrée via `ItemSnapableFactory.createItemSnapableFromJson` + `logic.tileLogic.createItemSnapableTile`.

**Important** : quand un client rejoint une session collab, `initializeEditor()` **skippe** le chargement de la map locale (`Game.loadMap`) — sinon `Game.onFoundItemSnapableTile` émettrait des `CreateItem` ops qui seraient rebroadcastées, polluant la map de l'hôte. Le client démarre vide et attend le FullSync. Filet de sécurité additionnel : le handler `Game.onFoundItemSnapableTile` enveloppe `createItemSnapableTile` dans `begin/endApplyRemote`.

### 3.3 Fallback chunké pour ops > 20 KB

`EditorSession::sendReliableOrChunked` : si le packet sérialisé dépasse `k_chunkThresholdBytes` (20 KB), il est split en paquets `OpChunk` identifiés par un `opId` UUID. Le receiver accumule par `(senderId, opId)` dans `m_chunkBuffers` ; une fois tous les fragments reçus, il reconstruit le packet original et le réinjecte dans `onReliableReceived` — donc même chemin que les ops non-chunkées (rate-limit, seq, etc.).

### 3.4 Présence

- **Curseurs** (`Editor.qml`) : `HoverHandler` sur workArea + `Connections { target: mainMa }` (pour capter pendant un drag) alimentent `_hoverX/_hoverY` en **coords workArea**. Un timer 20 Hz convertit en **unités de grille** (division par `gameGrid.gridSize`) avant `EditorSession.sendCursor(x, y)`. Invariant par zoom et résolution.
- Rendu : Repeater dans `workArea`, position `x: _entry.x * gameGrid.gridSize` — ré-évalue au zoom local. Interpolation 60 ms `OutQuad` entre ticks pour un rendu fluide.
- Prune : timer 500 ms purge les curseurs sans update depuis 2 s.
- **Sélections** : `SelectionUpdate{uuids}` en reliable, debounced 100 ms côté émetteur. `EditorSession.remoteSelections` (QVariantMap) exposée. `SnapableElement` trace un liseré coloré via `foreignSelectors`.

### 3.5 Host migration (détection + élection + reconnexion)

Détection (2 chemins) :

1. **Chemin rapide volontaire** — l'hôte appelle `EditorSession.announceHostLeaving()` qui broadcaste `HostLeaving` (0x2A) en reliable avec le roster autoritaire embarqué (`main.qml` l'appelle à la fermeture de la fenêtre et lorsque l'hôte quitte). À la réception, les clients purgent le `PlayerNetwork` de l'ancien hôte (via `Catway::removePlayer`) et élisent immédiatement, sans attendre le timeout.
2. **Fallback** — `Catway::playerTimedOut(playerId)` (~30 s sans paquet, signal relayé depuis `CatwayWorker`) déclenche le même flow via `onPlayerTimedOut`.

`EditorSession::onPlayerTimedOut` branche selon le rôle :

- **Client** + pid == hostPlayerId :
  1. `electNewHost()` : candidats = `m_knownRoster ∪ {localPlayerId}` moins `m_hostPlayerId`. Gagnant = plus petit id lexicographique. Tous les survivants qui ont la même snapshot roster élisent le même.
  2. Émet `hostLost(electedHostId)`.
  3. Le handler QML (`Editor.qml`) décide :
     - Si `electedId == localPlayerId` → appelle `promoteToHost()` (stop+startAsHost, préserve l'état local). Signal `promotedToHost()` → `main.qml` appelle `Catway.chatClient.renameSession("[EDIT:<newHostId>] …")` pour rafraîchir le lobby **sans changer le sessionId** (même canal chat, mêmes participants, même historique). En plus de `renameSession` (rafraîchissement de l'affichage lobby), `main.qml` appelle `Catway.chatClient.transferHost(newHostId)` → commande serveur `TRANSFER_HOST` → broadcast `HOST_CHANGED`, qui met à jour `sessions.host_player_id` côté serveur pour que l'ancien hôte perde ses droits admin (`CLEAR_HISTORY` / `DELETE_SESSION`).
     - Sinon → `EditorSession.stop()` + émission `reconnectRequested(sessionId, electedHostId)`. `main.qml` relance le `p2pStateMachine` avec `skipPush=true` (l'éditeur est déjà empilé). Au retour de `p2pConnected`, `startAsClient(newHostId)` → `Hello` → `FullSync` du nouvel hôte.

- **Host** + pid == (un client) :
  1. Purge `m_remoteSelections[pid]`, les buckets de rate-limit et les chunk buffers du sender.
  2. Retire du `m_knownRoster` + rediffuse `PlayerRoster`.
  3. Émet `peerLeft(pid)` → UI purge curseur/sélection.

Le chat server supporte `RENAME_SESSION` (broadcast `SESSION_RENAMED`) ajouté spécifiquement pour ce flux. `ChatClient::handleSessionRenamed` met à jour `availableSessions` in-place pour que le lobby d'autres utilisateurs reflète le nouvel hôte sans re-list.

Limitations connues :
- Si tous les survivants ont des snapshots roster divergentes (rare timing window), l'élection peut élire plusieurs hôtes simultanés. Pas de résolution v1.
- Migration en chaîne (hôte meurt, élu meurt à son tour pendant la reconnexion) non testée.

---

## 4. Stats de transmission (reliable.io)

`PlayerNetwork::stats()` (`Q_INVOKABLE`, retourne `QVariantMap`) expose les compteurs de `reliable_endpoint_t` :

- `rtt`, `rttMin`, `rttMax`, `rttAvg` (ms, moyenne exponentielle glissante)
- `packetLoss` (0..1)
- `sentBwKbps`, `recvBwKbps`, `ackedBwKbps`
- `packetsSent`, `packetsReceived`, `packetsAcked`, `packetsStale`, `packetsInvalid`
- `fragmentsSent`, `fragmentsReceived`, `fragmentsInvalid`

**Thread safety** : les getters lisent sans verrou pendant que le worker thread écrit via `reliable_endpoint_update`. OK pour un affichage UI à ~2 Hz (lectures de floats/uint64 sont atomiques sur x86/ARM pour un polling d'affichage — on n'utilise pas ces valeurs pour du contrôle).

**UI** : panneau overlay dans l'éditeur (coin haut-droit, sous le badge Collab). Toggle via clic sur le badge. Poll 500 ms. Affiche une section par pair P2P connecté avec RTT (rouge si loss > 5 %), bande passante et compteurs de paquets/fragments.

---

## 5. Persistance & isolation

- Chemin des cartes : CWD-relatif `./map/` via `#define MAP_FILE_PATH` dans `cpp/game/map/mapfilemanager.h` (= `build/<config>/map/` en dev). Ce dossier n'est **pas** sous `AppDataLocation` et n'est **pas** isolé par `--instance N` (contrairement à QSettings / DB chat / assets, qui passent par `AppDataLocation`). L'isolation inter-instances des maps repose uniquement sur des répertoires de travail distincts.
- En mode collab, l'autosave locale d'un client écrit dans son propre répertoire de travail `./map/` (pas dans `AppDataLocation`). Tant que l'hôte et le client tournent dans des répertoires de travail distincts, le client ne peut **pas** écraser la map réelle de l'hôte.

---

## 6. Ce qui n'est PAS fait (gaps connus)

- Live-edits via sections CCPS_* (panel case config) ne passent pas par le bus — le uuid n'est pas accessible depuis les sections indépendantes.
- Pas d'undo pour `MoveItem` / `ResizeItem` / `Set*` (pré-image non capturée au submit).
- Conflits simultanés : last-writer-wins naïf par champ (le rebroadcast du host fait foi).
- Divergence des asset packs (mismatch `assetPackHash`) non détectée — les clients avec des packs différents verront des placeholders.
- Migration en chaîne : non testée ; un timeout pendant la reconnexion arrêtera la session.

---

## 7. Fichiers critiques

| Chemin | Rôle |
|--------|------|
| `cpp/editor/network/editor_session.{h,cpp}` | Session host-authoritative, rate-limit, chunking, host migration |
| `cpp/editor/network/editor_protocol.{h,cpp}` | Pack/unpack `[type][JSON]` |
| `cpp/editor/network/editor_message_type.h` | Enum `0x20+` |
| `cpp/editor/ops/editor_op_bus.{h,cpp}` | Chokepoint mutations + undo stacks |
| `cpp/editor/ops/editor_op_type.h` | Enum ops |
| `cpp/communication/catway.{h,cpp}` | Signaux `playerTimedOut`, `reliableMessageReceived` |
| `cpp/communication/player_network.{h,cpp}` | `stats()` getter reliable.io |
| `cpp/chat/chat_client.{h,cpp}` | `renameSession`, `handleSessionRenamed`, `handleSessionDeleted` |
| `../chatServer/server.js` (racine du dépôt) | Handlers `RENAME_SESSION` / `SESSION_RENAMED`, `TRANSFER_HOST` / `HOST_CHANGED`, purge session vide |
| `qml/editor/Editor.qml` | Apply remote, FullSync, curseurs, sélections, stats overlay |
| `qml/main.qml` | p2pStateMachine, promotion → renameSession, reconnexion |
| `qml/multiplayer/MultiplayerLobby.qml` | Encodage `[EDIT:...]`, signaux `launchNewSession`/`launchExistingSession` |
| `qml/test/CatwayTest/EditorNetworkTestTab.qml` | Harness de test dev |
