# Réseau Meownopoly — patterns, décisions, pièges

Cette doc consolide les patterns réseau du projet et **les raisons des choix de techno**. Pour le détail d'implémentation Catway / hole punching, voir [`CATWAY_ARCHITECTURE.md`](./CATWAY_ARCHITECTURE.md) et [`P2P_NETWORK_ARCHITECTURE.md`](./P2P_NETWORK_ARCHITECTURE.md). Pour la collab éditeur : [`COLLABORATIVE_EDITOR.md`](./COLLABORATIVE_EDITOR.md) et [`COLLAB_SESSION_PATTERN.md`](./COLLAB_SESSION_PATTERN.md). Pour la physique : [`PHYSICS_ENGINE_V2.md`](./PHYSICS_ENGINE_V2.md).

---

## 1. Vue d'ensemble — couches et stacks

| Stack | Transport | Fiabilité | Usage |
|---|---|---|---|
| **Catway** | UDP P2P (hole punch) | `reliable.io` (ACK/retransmit) ou raw | Game state, editor ops, physics snapshots |
| **ChatClient** | WebSocket TCP | TCP natif | Lobby, signaling P2P, chat texte chiffré |
| **STUN** | UDP | Best effort | Découverte IP/port publics |
| **Asset / launcher** | HTTP(S) | TCP natif | Téléchargement assets, auth |

### Threading

- **Thread GUI** : QML, `Catway` singleton, `ChatClient`, `PlayerNetwork`, `UdpSocketInfo`.
- **Thread réseau** (`Catway::m_networkThread`) : `CatwayWorker`, `StunManager`, timers reliable 60 Hz, heartbeat 10 s, `QUdpSocket`.
- **Thread physique** (`PhysicsWorld::m_thread`) : moteur Pattounx v2, simulation 60 Hz. Le `QThread` est détenu par la façade `PhysicsWorld` ; `PhysicsWorker` y est déplacé via `moveToThread`.
- **Cross-thread** : `Qt::BlockingQueuedConnection` pour le setup socket, `Qt::QueuedConnection` pour l'asynchrone (datagrammes reçus, signaux GUI).

### Pourquoi cette répartition
- **GUI ne fait jamais d'I/O réseau directe** : un `recv` bloquant ou un `sendStunRequest` bloquerait l'UI.
- **Worker thread isolé** : un crash UDP ou un blocage timer ne fige pas l'UI.
- **Physique isolée** : tick déterministe 60 Hz indépendant du framerate écran (60-144 Hz).

---

## 2. UDP P2P — pourquoi pas TCP ?

### Choix
UDP avec hole punching (STUN-discovered ports) + `reliable.io` au-dessus pour le critique.

### Pourquoi UDP
- **NAT traversal** : TCP hole punching marginal et fragile, UDP standard et robuste avec STUN.
- **Latence** : pas de retransmission obligatoire pour les snapshots physique/cursor (lossy OK).
- **Contrôle fin** : on choisit par message ce qui est ack/retry vs lossy.

### Pourquoi `reliable.io` (lib C tierce) plutôt que QtNetwork
- ACKs sliding window + retransmission temporisée.
- Magic byte `0x01` prefix → coexiste avec UDP raw sur le même socket (cursors lossy = pas de prefix).
- C callbacks bridgés en Qt signal/slot via `CatwayReliableContext`.
- QtNetwork ne fournit pas de couche reliable UDP ; tout faire à la main aurait été buggué.

### Heartbeats `HP:PING` toutes les 10 s
Maintient les NAT holes ouverts. Sans ça les routeurs ferment les mappings UDP en 30-180 s selon le constructeur. Côté ChatClient un signaling channel séparé (WebSocket persistant) permet aussi de re-déclencher le hole punch si nécessaire.

---

## 3. Hole punching — séquence et pièges

### Séquence (orchestrée par QML)
```
setupNewPort()                    // STUN sur un nouveau socket
  → externalAddressReceived(ip, port)
  → takeStunSocket() (cache UdpSocketInfo)
chatClient.sendRequestConnectionInfo(peerId, ip, port, localPort)
                                  // signaling via WebSocket
initiateHolePunch(player)         // envoie premier paquet UDP vers peer
  → datagramReceived(...)         // peer répond, hole établi
  → p2pConnected
```

### Piège n°1 : ordre obligatoire des 3 étapes
Les 2 premières sont implicites si on attend le heartbeat (10 s cycle), mais `initiateHolePunch` doit être appelé **explicitement** depuis QML pour un lien rapide.

### Piège n°2 : `currentSocketInfo()` vide après `takeStunSocket`
Après `takeStunSocket`, le cache est consommé → lire `Catway.lastLocalPort()` à la place. `currentSocketInfo()` retournerait vide.

### Piège n°3 : `m_players` persiste à travers `EditorSession.stop/start`
`EditorSession.stop()` ne déconnecte que les handlers de signaux, pas les `PlayerNetwork`. Conséquence : après migration hôte, l'ancien hôte qui rejoint a encore en cache `PlayerNetwork(<newHost>, oldIP, oldPort, p2pConnected=true)`. `p2pStateMachine` croit être connecté instantanément (300 ms) → Hello envoyé sur un port mort → pas de FullSync.

**Fix** : `main.qml.onLaunchExistingSession` appelle `Catway.removePlayer(Catway.playerById(hostId))` avant de démarrer le state machine. Idem dans `EditorSession::onReliableReceived` case `HostLeaving`. `Catway::removePlayer` libère aussi le socket local si plus aucun pair ne l'utilise → `setupNewPort` kick au prochain tick.

### Piège n°4 : `Catway.chatClient` est shared (un seul à la fois)
`Catway::setChatClient` ne stocke qu'un pointeur. En mode collab éditeur, **préserver le `ChatClient` du lobby** (la session collab) — ne pas le laisser être écrasé par le `ChatClient` d'in-game de `ChatDrawer`. Gate sur `!EditorSession.active` dans `Editor.qml`.

---

## 4. Sessions host-authoritative — pattern réutilisable

Trois sessions suivent le même pattern : `GameSession`, `EditorSession`, `PhysicsSession`.

### Principe
- **Host** : valide les ops/inputs reçus, applique localement, rebroadcast aux autres clients.
- **Client** : envoie ses ops/inputs au host en reliable, reçoit l'état autoritaire en retour, applique avec une fenêtre `beginApplyRemote/endApplyRemote` qui empêche la boucle de re-soumission.

### Pourquoi host-authoritative et pas mesh consensus
- **Simplicité** : pas de résolution de conflits distribués.
- **Cohérence** : un seul producteur d'état → pas de divergence.
- **Coût** : 1 hop supplémentaire pour les non-hôtes, mais latence locale UDP (< 50 ms typique).

### Frame format
| Stack | Type byte | Plage | Coexistence |
|---|---|---|---|
| Game | `GameMessageType` | `0x01–0x11` | Catway |
| Editor | `EditorMessageType` | `0x20–0x2A` | Catway |
| Physics | `PhysicsMessageType` | `0x40+` | Catway |

Préfixe `[1 byte type][JSON UTF-8]` (sauf physics qui passe en binaire compact pour les snapshots).

### Piège : ajout d'un `EditorMessageType`
`EditorProtocol::isEditorPacket` filtre par plage `>= Hello && <= <dernier type>`. Toute nouvelle valeur doit être la **plus haute**, sinon les paquets entrants sont silencieusement droppés par `unpack`. Cf. commentaire dans `editor_protocol.cpp`.

### Op bus QML (collab editor)
`EditorOpBus` (singleton QML) est le **chokepoint pour TOUTES les mutations**.
- `submitOp(op)` : log + envoie via `EditorSession` si active.
- `submitOpWithUndo(op, inverseOp)` : push aussi sur la stack undo locale (par-client).

Sans ce chokepoint, des mutations directes du modèle bypasseraient la sync collab. Gap connu v1 : live-edits CCPS_* ne passent pas par l'op bus (uuid inaccessible depuis les sections).

### Full-sync au join (Phase 4)
Client envoie `Hello` → host répond avec map chunks (< 20 KB, seuil `k_chunkThresholdBytes`) en reliable ordonné → client wipe + rebuild via `ItemSnapableFactory.createItemSnapableFromJson`.

### Piège : `Game`/`MapFileManager` singletons persistants
La `Map` C++ survit à la destruction du QML `Editor` (quit + re-push). Sur rejoin collab, `Game.m_tiles` garde les uuids de la session précédente → `applyRemoteDelta(TileAdded)` du FullSync no-ope → carte QML vide alors que C++ a les données. Fix : `Game::initEmptyCollabMap()` recrée toujours une `Map` neuve. En reconnect post-migration (`skipPush=true`), l'appel doit être fait **explicitement** — cf. `Editor.onHostLost` qui wipe `snapableTilesList` + `Game.initEmptyCollabMap()` avant `reconnectRequested`.

---

## 5. Présence collab (Phase 5) — cursors lossy + sélections fiables

### Cursors temps-réel (20 Hz lossy)
`Catway.broadcastRaw("EC:<pid>;<x>;<y>")` — **pas de prefix reliable**, paquet UDP nu. Si perdu, le suivant remplace. Rendu côté QML via `HoverHandler` enfant de `workArea`.

### Sélections (fiable)
`EditorSession.remoteSelections` (`QVariantMap` exposée en `Q_PROPERTY`). Update via op `EditorMessageType::SelectionUpdate` reliable.

### Pourquoi cette dichotomie
- Cursors changent 20× par seconde × N peers → 20×N pkts/s. Si reliable → file de retransmission saturée. Lossy OK : une frame sautée invisible.
- Sélections changent rarement et doivent persister pour les UI distantes. Reliable obligatoire.

---

## 6. Host migration (Phase 8) — volontaire + timeout

### Annonce volontaire
`EditorMessageType::HostLeaving` (`0x2A`) broadcasté en reliable par l'hôte sortant avec `{ roster: [...] }`. **Roster autoritaire embarqué** pour éviter split-brain d'élection (sans ça, deux clients peuvent élire deux hôtes différents si leurs vues du roster divergent au moment de la déconnexion).

### Timer 300 ms avant `Qt.quit()`
`Catway::broadcastReliable` utilise `Qt::QueuedConnection` vers le worker thread. Si `Qt.quit()` est appelé directement dans `onClosing`, le paquet n'a pas le temps de sortir. Pattern :
```qml
ApplicationWindow.onClosing: {
    if (closeDelayTimer.running) return  // garde anti-récursion
    close.accepted = false
    Catway.broadcastReliable(...)
    closeDelayTimer.start()
}
Timer { id: closeDelayTimer; interval: 300; onTriggered: Qt.quit() }
```

### Timeout fallback
`onPlayerTimedOut` côté client déclenche le même flow via `emit hostLost`.

### Élection déterministe
`electNewHost()` = min lexicographique du roster excluant l'ancien hôte. Tous les clients convergent. Le client élu `promoteToHost()` (= `stop()` + `startAsHost()` en préservant tuiles/undo).

### Pourquoi `min lexico` et pas un autre critère
- Déterministe sans coordination.
- Pas besoin de mesurer latence/charge (info pas dispo localement).
- Stable : même résultat sur tous les peers à partir du même roster autoritaire.

### Re-routage du chat lobby
Le client élu émet `promotedToHost` → `main.qml.onPromotedToHost` → `chatClient.renameSession("[EDIT:<newHostId>]…")` + `chatClient.transferHost(newHostId)` (commande serveur `TRANSFER_HOST`). Sans ça l'ancien hôte qui rejoint récupérerait les droits admin (CLEAR_HISTORY, DELETE_SESSION) car il avait le `joined_at` le plus ancien.

### Schema SQL
Colonne `sessions.host_player_id` + commande `TRANSFER_HOST` + broadcast `HOST_CHANGED`. `isHost`/`getHost` priorisent `host_player_id`, fallback legacy sur premier `joined_at`. Côté serveur : `handleJoinSession` initialise `host_player_id` au premier joiner si null.

### Pourquoi pas de garde "ancien hôte encore connecté"
Quand l'hôte ferme via `HostLeaving` (Timer 300 ms avant `Qt.quit()`), les pairs élisent et envoient `TRANSFER_HOST` **avant** que la WS chat lobby de l'hôte ne soit close côté serveur. Un garde naïf "refuse si rooms contient encore le `host_player_id`" casserait la migration. Le serveur fait confiance au client élu (élection déterministe min-lexico côté pairs) ; seule garde restante : `db.isParticipant(session_id, new_host_id)`.

### Warnings résiduels
Pendant la fenêtre de migration (~ 100-300 ms), warnings `[SÉCURITÉ] Paquet UDP spoofé` noisy (résiduels de l'ancien socket). **Non-bloquant** : seuls les paquets UDP non-fiables sont concernés, pas reliable.io.

---

## 7. Chat — WebSocket + chiffrement bout-en-bout

### Architecture
- **Client** : C++ `ChatClient` (`cpp/chat/`) sur thread GUI.
- **Serveur** : Node.js + SQLite (`chatServer/`). Deploy via `deploy.sh` + `.deployEnv`.
- **Protocole** : JSON commandes (`JOIN_SESSION`, `SEND_MSG`, `GET_HISTORY`, `TRANSFER_HOST`, `CLEAR_HISTORY`, `DELETE_SESSION`, …).

### Blind relay E2E
Le serveur ne voit JAMAIS le plaintext. Les clients dérivent une clé à partir d'un secret partagé (mot de passe de session) via `ChatCrypto`. Le serveur ne stocke que des ciphertexts. Conséquence : la recherche full-text est impossible côté serveur, l'historique se déchiffre côté client.

### Format `password_hash`
`ChatCrypto::derivePasswordProof` retourne du SHA-256 **hex** via `.toHex()` (64 chars). L'envoi serveur passe par `QString::fromLatin1(m_passwordHash)` — **ne pas** ré-appliquer `.toBase64()` (88 chars "b64 of hex", rejeté par la validation stricte du serveur). Le serveur accepte `^[0-9a-fA-F]{64}$` ou `^[A-Za-z0-9+/]{43}=$` (base64 canonique pour le dashboard JS). Sites à garder cohérents : `ChatClient::createSession` et `ChatClient::joinSession`.

### Mode éditeur encodé dans le nom de session
Prefix `[EDIT:<hostId>]` → évite toute modif du serveur chat. `MultiplayerLobby` émet `launchNewSession/launchExistingSession(isEdition, hostId)`. Le lobby reste dans la stack sous l'éditeur pour préserver `lobbyChatClient` (Catway en dépend pour les `REQUEST_CONNECTION_INFO`).

### Piège : `ChatClient::setSessionId` no-op si id inchangé
Le setter guard `if (m_sessionId != id)` avant `emit sessionIdChanged()`. Conséquence : se reconnecter à la session courante (ex: quitter l'éditeur collab puis re-cliquer la même session) ne fait pas re-fire `onSessionIdChanged` → handler de nav pas déclenché. Fix dans `MultiplayerLobby.onSessionSelected` : si `lobbyChatClient.sessionId === target && connected`, appeler `launchExistingSession` directement.

### Piège : setter direct C++ ne déclenche pas `*Changed`
Si un setter C++ assigne directement `m_foo = …` sans passer par son `setFoo` qui `emit fooChanged()`, les handlers QML `onFooChanged` restent muets. Leçon apprise sur `ChatClient::connectToSessionDirect` — toujours passer par le setter.

---

## 8. Physique réseau — host-authoritative 30 Hz

`PhysicsSession` (`cpp/game/physics/physics_session.{h,cpp}`, singleton QML module `Pattounx`) :

### Plage 0x40+ pour les types de message
| Type | Sens | Fréquence |
|---|---|---|
| `Hello/Welcome` | client → host / host → client | 1× |
| `BodiesAnnounce` | host → clients | au join + au spawn |
| `Snapshot` | host → clients | 30 Hz reliable |
| `InputUpdate` | clients → host | au change input |

### Pourquoi reliable pour les snapshots et pas lossy
- 30 Hz, ≈ 200 octets/snapshot/joueur → bande passante minime.
- Un snapshot perdu produirait un saut visuel (les positions ne sont pas interpolées de force).
- L'overhead reliable.io est marginal vs un saut de 33 ms.

### Inputs reliable aussi
Une input perdue = une saccade contrôle. Reliable garantit l'ordre + l'arrivée. Coût : latence input → host ≤ 1 RTT (≈ 30-100 ms typique LAN/internet).

### Triple buffer GUI (Fraser-Harris)
Le `PhysicsWorld` triple-buffer les snapshots du worker physique (60 Hz) vers la GUI (60-144 Hz). Lock-free avec peek+swap pour éviter la régression à haute cadence. Voir [`RENDERING_PERF.md` §4](./RENDERING_PERF.md#4-triple-buffer-physique-fraser-harris--physics_worldcpp).

---

## 9. Patterns Q_PROPERTY / signaux — pièges récurrents

### `Q_PROPERTY` name vs getter name
QML lit le nom de la **property**, pas celui de la méthode C++.
```cpp
Q_PROPERTY(bool p2pConnected READ isP2pConnected NOTIFY p2pConnectedChanged)
```
```qml
player.p2pConnected   // ✓
player.isP2pConnected // ✗ undefined
```

### `QQmlListProperty` n'est pas une JS array
Pas d'accès par index direct depuis JS. Exposer des helpers :
```cpp
Q_INVOKABLE QObject *fooAt(int)
Q_INVOKABLE int fooCount()
Q_INVOKABLE QObject *lastFoo()
```
Voir `Catway::localPortAt/localPortCount/lastLocalPort`.

### Setter doit passer par `setFoo`
Pas de mutation directe `m_foo = ...` qui bypasse le setter — `*Changed` ne fire pas.

### `*Changed` réservé pour les properties
QML auto-génère `<property>Changed`. Un signal custom `fooChanged` provoque "Duplicate signal name". Préférer `fooRequested` ou un autre suffixe.

---

## 10. Test harness

### `dual_test_p2p` (CMake target Windows)
Lance 2 instances : `Instance 1` et `Instance 2` (`--instance 2`). `main.cpp` ajuste `applicationName` → `QStandardPaths::AppDataLocation` renvoie des dossiers distincts (`Meownopoly/` vs `Meownopoly_2/`). QSettings, chat DB, assets isolés. **Pas** d'isolation pour les maps (CWD-relative `./map/` — à arbitrer).

### `qml/test/CatwayTest/`
Tabs : Catway / UDP Tests / Game Network / Editor Network / Physics / Painter. L'onglet Editor Network permet de démarrer manuellement une `EditorSession` pour tests sans passer par le lobby.

### `EditorOpsCard`
Log live des ops locales/distantes — visible dans `EditorNetworkTestTab.qml`.

---

## 11. Récap "quoi sert à quoi"

| Techno | Pourquoi choisie |
|---|---|
| UDP + STUN + hole punch | NAT traversal robuste, latence faible, contrôle fin reliable vs lossy. |
| `reliable.io` (lib C tierce) | ACK/retransmit + sliding window que QtNetwork ne fournit pas ; magic byte permet coexistence raw/reliable sur même socket. |
| `Qt::QueuedConnection` cross-thread | Évite blocage GUI pendant I/O réseau ; sérialise les events sur la queue de chaque thread. |
| `Qt::BlockingQueuedConnection` (setup socket) | Quand le caller a vraiment besoin du résultat avant de continuer (ex: `setupNewPort` qui doit retourner un port valide). |
| WebSocket TCP pour chat/signaling | TCP suffit pour des messages rares ordonnés, persistant, support browser pour le dashboard JS, pas de NAT issue. |
| Host-authoritative | Cohérence simple, 1 producteur d'état, pas de résolution de conflits distribués. |
| Élection min-lexico | Déterministe sans coordination, stable même sous perte de paquets, ne nécessite pas d'info externe (latence/charge). |
| `[EDIT:<hostId>]` prefix nom session | Encode le contexte sans toucher au serveur chat. |
| Triple buffer Fraser-Harris (peek+swap) | GUI 144 Hz peut tirer plus vite que worker 60 Hz sans rejouer son propre dépôt. Lock-free. |
| Plage `EditorMessageType` 0x20+, `PhysicsMessageType` 0x40+ | Coexistence sur Catway sans collision avec `GameMessageType` 0x01-0x11. |
| Cursor 20 Hz lossy + sélection reliable | Bande passante : transient = lossy (la suivante remplace), persistant = reliable. |
| Heartbeat 10 s | Maintient les NAT mappings UDP ouverts (timeout typique 30-180 s). |
| E2E blind relay chat | Serveur ne voit jamais le plaintext, mot de passe de session dérive la clé client-side. |

---

## 12. Pour aller plus loin

- [`CATWAY_ARCHITECTURE.md`](./CATWAY_ARCHITECTURE.md) — détail thread-by-thread, fichiers `catway_*.cpp`.
- [`P2P_NETWORK_ARCHITECTURE.md`](./P2P_NETWORK_ARCHITECTURE.md) — diagrammes hole punch + reliable.
- [`COLLABORATIVE_EDITOR.md`](./COLLABORATIVE_EDITOR.md) — phases 1-8 collab editor, op bus, host migration.
- [`COLLAB_SESSION_PATTERN.md`](./COLLAB_SESSION_PATTERN.md) — pattern générique réutilisable.
- [`PHYSICS_ENGINE_V2.md`](./PHYSICS_ENGINE_V2.md) — `PhysicsSession` host-authoritative + 3D presentation.
- [`websocket_protocol.md`](./websocket_protocol.md) — détail protocole chat.
