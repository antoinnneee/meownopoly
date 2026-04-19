# Pattern — Session collaborative host-authoritative

Ce document extrait, du code de l'éditeur collaboratif (`EditorSession` + `EditorOpBus`), le **pattern générique** pour bâtir une nouvelle session multi-joueurs au-dessus de `Catway` — que ce soit pour un mode de jeu, un outil de dessin, une salle d'édition d'avatars, etc.

Il est complémentaire de [`COLLABORATIVE_EDITOR.md`](COLLABORATIVE_EDITOR.md) (cas concret éditeur) et [`CATWAY_ARCHITECTURE.md`](CATWAY_ARCHITECTURE.md) (transport P2P). **Lire d'abord ces deux-là si le contexte manque.**

---

## 1. Quand réutiliser ce pattern

Le pattern convient pour :

- Un ensemble de clients qui modifient un **état partagé** commun (tuiles, figurines, curseurs de chat, tableau blanc…).
- Une **autorité unique** (host) raisonnable, c'est-à-dire où un client peut faire rejouer ses actions par le host sans dégrader l'expérience (latence LAN/WAN sur un tick, acceptable quand le retour visuel est <150 ms).
- Des ops **petites et fréquentes** (quelques KB, < 30 Hz par client), avec un chemin de fallback pour les rares ops volumineuses.
- Un état global **pas trop gros** (snapshot < quelques MB) pour supporter un full-sync à chaud à chaque join.

Il ne convient **pas** pour :

- Simulations en temps réel à 60 Hz où chaque ms compte (FPS, physique tight-loop) → il faut du client-side prediction + rollback, hors scope.
- Jeux où il existe plusieurs autorités distribuées (CRDT-only, blockchain, etc.).
- Persistance serveur durable (ici le host est éphémère, la source de vérité disparaît avec lui sauf autosave client).

---

## 2. Architecture cible (3 couches)

```
┌─────────────────────────────────────────────────────────────────────┐
│  QML (UI)                                                            │
│   - lit/écrit l'état via un chokepoint unique côté QML               │
│   - applique les ops distantes (signal remoteOpReceived)             │
└─────────────────────────────────────────────────────────────────────┘
                               │     ▲
                      submitOp │     │ remoteOpReceived
                               ▼     │
┌─────────────────────────────────────────────────────────────────────┐
│  <Mode>OpBus  (singleton QML)                                        │
│   - chokepoint unique pour TOUTES les mutations                      │
│   - rate-limit local, logs, undo stacks                              │
│   - garde "isApplyingRemote" pour empêcher la boucle réseau          │
└─────────────────────────────────────────────────────────────────────┘
                               │     ▲
                       sendOp  │     │ opReceived
                               ▼     │
┌─────────────────────────────────────────────────────────────────────┐
│  <Mode>Session  (singleton QML)                                      │
│   - host-authoritative : validate + rebroadcast                      │
│   - frame [1B type][JSON UTF-8], plage de types réservée             │
│   - rate-limit par sender, chunking fallback, _seq/_by, roster       │
│   - full-sync à la connexion, élection, présence                     │
└─────────────────────────────────────────────────────────────────────┘
                               │     ▲
              reliable / UDP   │     │
                               ▼     │
┌─────────────────────────────────────────────────────────────────────┐
│  Catway  (transport P2P, partagé)                                    │
│   - reliable.io : ordre + ACK + fragmentation automatique            │
│   - UDP brut : lossy, curseurs/présence                              │
│   - heartbeats, détection de timeout (playerTimedOut)                │
└─────────────────────────────────────────────────────────────────────┘
```

Les deux singletons (`<Mode>Session`, `<Mode>OpBus`) sont **toujours vivants** même hors session. Un simple flag `active` gate la logique réseau. Le mode monoposte reste la branche par défaut — le réseau n'est qu'une surimpression.

---

## 3. Checklist de réimplémentation

### 3.1 Fichiers à créer

| Fichier | Rôle |
|---|---|
| `cpp/<mode>/network/<mode>_session.{h,cpp}` | Session host-authoritative |
| `cpp/<mode>/network/<mode>_message_type.h` | Enum des types de message |
| `cpp/<mode>/network/<mode>_protocol.{h,cpp}` | Pack/unpack `[1B type][JSON]` |
| `cpp/<mode>/ops/<mode>_op_bus.{h,cpp}` | Chokepoint QML + undo |
| `cpp/<mode>/ops/<mode>_op_type.h` | Enum des ops logiques |

Cloner `cpp/editor/network/*` + `cpp/editor/ops/*` et substituer `Editor` → `<Mode>`. L'éditeur est **la référence canonique** ; si vous divergez, documentez-le ici.

### 3.2 Plage de types-bytes (CRITIQUE)

Tous les modes partagent le même `Catway::reliableMessageReceived` : **aucun overlap de plage de type-byte** n'est permis sans dispatch explicite.

Conventions actuelles :

| Plage | Réservé |
|---|---|
| `0x01–0x1F` | `GameMessageType` (partie en cours) |
| `0x20–0x2F` | `EditorMessageType` |
| `0x30–0x3F` | *libre* — nouveau mode A |
| `0x40–0x4F` | *libre* — nouveau mode B |

Règle : chaque session **filtre** sur sa plage dans `unpack()`. Un paquet hors plage est ignoré silencieusement — pas d'erreur. C'est ce qui permet la coexistence pacifique sur un même canal Catway.

**Règle d'exclusivité** : deux sessions du même mode ne peuvent pas tourner simultanément (singleton). Deux sessions de modes différents peuvent coexister uniquement si leurs plages sont disjointes ET si leur logique n'interfère pas au niveau état (rare — par prudence, on refuse via `if (OtherSession::instance()->active()) return false` dans `startAsHost/Client`).

### 3.3 API publique minimale de `<Mode>Session`

```cpp
// Cycle de vie
Q_INVOKABLE bool startAsHost(QString localPlayerId, QString sessionId = {});
Q_INVOKABLE bool startAsClient(QString localPlayerId, QString hostId, QString sessionId = {});
Q_INVOKABLE void stop();

// Envoi
Q_INVOKABLE void sendOp(QJsonObject op);                    // client→host ou host→self
Q_INVOKABLE void broadcastOp(QJsonObject op);               // host uniquement
Q_INVOKABLE void sendEvent(int type, QJsonObject payload);  // autres events
Q_INVOKABLE void sendEventTo(QString pid, int type, QJsonObject payload);
Q_INVOKABLE void sendCursor(qreal x, qreal y);              // UDP brut si présence

// Migration
Q_INVOKABLE QString electNewHost() const;                   // déterministe
Q_INVOKABLE bool    promoteToHost();                        // stop+startAsHost

// Signaux
void opReceived(QString senderId, QJsonObject op);
void opRejected(QJsonObject reject);
void editorEventReceived(int type, QString senderId, QJsonObject payload);
void cursorReceived(QString senderId, qreal x, qreal y);
void selectionReceived(QString senderId, QJsonObject payload);
void hostLost(QString electedHostId);
void promotedToHost();
void peerLeft(QString playerId);
void opRateLimited(QString senderId, int dropped);

// Q_PROPERTY
bool        active;
bool        isHost;
QString     localPlayerId, hostPlayerId, sessionId;
QVariantMap remoteSelections;   // pid → [uuid,...]  si applicable
QStringList knownRoster;        // clients connus (hors hôte)
```

### 3.4 API publique minimale de `<Mode>OpBus`

```cpp
// Submit
Q_INVOKABLE void submitOp(QJsonObject op);                         // local + réseau
Q_INVOKABLE void submitOpWithUndo(QJsonObject op, QJsonObject inv);

// Undo/redo
Q_INVOKABLE void undo();
Q_INVOKABLE void redo();
Q_INVOKABLE void clearUndo();

// Remote apply
Q_INVOKABLE void beginApplyRemote();  // refcount interne
Q_INVOKABLE void endApplyRemote();
Q_PROPERTY bool isApplyingRemote;     // pour QML gates

// Signaux
void opRecorded(QJsonObject op);       // local, après submitOp
void remoteOpReceived(QJsonObject op); // après réception, avant apply QML
void localThrottled(QJsonObject op);   // rate-limit local

// Helpers de construction (selon les ops du mode)
Q_INVOKABLE QString newUuid() const;
Q_INVOKABLE QJsonObject makeXxxOp(...) const;
```

---

## 4. Patterns critiques

### 4.1 Chokepoint unique (OpBus)

**Règle d'or** : **toutes** les mutations de l'état partagé passent par `<Mode>OpBus::submitOp`. Une mutation directe qui bypasse le bus est un bug — elle ne sera pas propagée et cassera la convergence.

Cela implique en QML :

- Créer une op dans chaque handler user-facing (bouton, drag release, panneau d'édition…).
- Si le même champ est édité par plusieurs panneaux, tous doivent router par le bus.
- Debouncer les interactions continues (sliders, drag) — ne soumettre qu'au **release** pour éviter la flood.

### 4.2 Anti-boucle `beginApplyRemote / endApplyRemote`

Le signal `remoteOpReceived` déclenche des mutations QML — qui doivent modifier l'état **sans re-soumettre au réseau**. D'où ce pattern (refcount pour supporter la recursion) :

```cpp
void OpBus::onSessionOpReceived(QString senderId, QJsonObject op) {
    beginApplyRemote();      // m_applyDepth++
    emit remoteOpReceived(op);
    endApplyRemote();        // m_applyDepth--
}
void OpBus::submitOp(QJsonObject op) {
    if (m_isApplyingRemote) return;   // drop silencieusement
    ...
}
```

**Pourquoi refcount et pas bool** : un handler QML peut appliquer une op qui elle-même déclenche en cascade d'autres mutations (ex: création de tuile → création d'un lien automatique). Tant qu'on est encore dans le premier `apply`, les cascades doivent être droppées.

### 4.3 `_seq` et `_by` (tagging host)

Quand le host reçoit une op d'un client puis la rebroadcast, **il doit** :

1. Insérer `op["_seq"] = ++m_serverSeq` (ordonnancement global).
2. Insérer `op["_by"] = senderId` (auteur original).

Les clients lisent ces champs pour :

- Ignorer les ops `_seq <= baseSeq` reçues juste après un FullSync.
- Corréler un toast/notification à l'auteur réel (**pas** au `senderId` Catway, qui côté client reçu est l'hôte, pas l'auteur — voir §4.6).

### 4.4 Validation + relay côté host

Le host applique lui-même ses ops (chemin symétrique avec les clients) en plus de les rebroadcaster. Pseudocode :

```cpp
void Session::onReliableReceived(senderId, data) {
    if (unpack(data, type, payload) fails) return;
    switch (type) {
    case Op:
        if (isHost) {
            if (!consumeOpToken(senderId)) { send OpReject; break; }
            payload["_seq"] = ++m_serverSeq;
            payload["_by"]  = senderId;
        }
        emit opReceived(senderId, payload);    // s'applique localement
        if (isHost) relayToOthers(senderId, pack(type, payload));
        break;
    ...
    }
}
```

Côté client, `senderId` du paramètre est **toujours** l'hôte (puisque le packet vient de l'hôte). L'auteur original est `payload["_by"]`.

### 4.5 Rate-limit par sender (token bucket)

Deux niveaux :

- **Local** (OpBus, côté émetteur) : évite de noyer sa propre file reliable.io. Capacité typique : 60 tokens, refill 30/s.
- **Host** (Session, côté réception) : défense contre un client bavard ou buggy. Mêmes constantes, par `senderId`.

Implémentation standard (token bucket) :

```cpp
bool consumeOpToken(QString senderId) {
    qint64 now = m_clock.elapsed();
    TokenBucket &b = m_buckets[senderId];
    double dt = (now - b.lastMs) / 1000.0;
    b.tokens = qMin(k_burst, b.tokens + dt * k_ratePerSec);
    b.lastMs = now;
    if (b.tokens >= 1.0) { b.tokens -= 1.0; return true; }
    return false;
}
```

Drop à chaud = `OpReject{reason: "rate_limited"}` au seul émetteur (il doit ralentir, pas diffuser).

### 4.6 Bug récurrent : `senderId` écrasé par l'hôte au relay

Quand le host relaie une op/selection/event reliable aux autres clients, le paquet arrive chez le receiver avec `senderId = hostId` (puisque Catway identifie toujours l'expéditeur direct, pas l'auteur original).

**Toujours** embarquer l'auteur dans le payload :

- Pour les ops : `_by` inséré par le host avant relay.
- Pour les événements de présence (sélections) : idem.
- Pour les curseurs UDP : l'auteur est encodé **dans le message** (`EC:<pid>;x;y`) — c'est cette chaîne qui fait foi côté receiver, pas le `senderId` paramètre.

### 4.7 Relay UDP brut côté host (multi-client)

En P2P, les clients ne sont connectés qu'au host. `Catway::broadcastRaw` d'un client envoie donc seulement à l'hôte. Pour que le client B voie les curseurs du client A, **l'hôte doit relayer** :

```cpp
void Session::onUdpReceived(senderId, message) {
    ...extraire auteur depuis message...
    emit cursorReceived(author, x, y);

    if (m_isHost) {
        // Forward brut aux autres pairs, sauf l'auteur.
        for (int i = 0; i < catway->playersCount(); ++i) {
            PlayerNetwork *p = catway->playerAt(i);
            if (p && p->isP2pConnected() && p->playerId() != senderId)
                catway->sendUdpMessageToPlayer(p, message);
        }
    }
}
```

Ne PAS utiliser `Catway::broadcastRaw` ici — il enverrait aussi au sender et causerait une boucle locale visible.

### 4.8 Chunking fallback pour ops > 20 KB

`reliable.io` plafonne ~32 KB par paquet. Pour les ops rares mais volumineuses (sérialisation d'un item complexe, payload FullSync), on split :

- Seuil : `k_chunkThresholdBytes = 20000` (marge vs 32 K, overhead base64 +33 %).
- Chaque chunk est un paquet `OpChunk{opId, chunkIndex, chunkCount, origType, payloadB64}`.
- Receiver accumule par `(senderId, opId)` dans `m_chunkBuffers`, puis **réinjecte** dans `onReliableReceived` — même chemin que les ops non-chunkées (rate-limit, `_seq`, etc.).

**Attention** : la ré-injection se fait via `onReliableReceived(senderId, rebuilt)` — ne pas dupliquer la logique du switch.

### 4.9 Full-sync à la connexion

Pattern pour amener un nouveau client à l'état courant :

```
client                           host
  │  Hello{nickname, assetHash}   │
  │ ────────────────────────────▶ │
  │                                │   (optionnel) ajout au roster,
  │                                │   broadcast PlayerRoster à tous
  │  FullSync{chunk 0/N, payload} │
  │ ◀──────────────────────────── │   (point-à-point, splitté en chunks)
  │  FullSync{chunk 1/N, ...}     │
  │ ◀──────────────────────────── │
  │  ...                          │
  │  [baseSeq implicite = _seq du dernier Op envoyé avant FullSync]
  │                                │
  │  Op{_seq=K}                   │
  │ ◀──────────────────────────── │   (les ops concurrentes sont bufférisées
  │                                    client side, appliquées après le full-sync)
```

Côté client qui vient de rejoindre :

1. **Ne PAS charger l'état local** (sinon il sera rebroadcasté comme des `CreateItem`). Démarrer vide.
2. Envoyer `Hello` dès `EditorSession.active === true`.
3. Accumuler les chunks FullSync, wrapper l'apply dans `beginApplyRemote`.
4. **Safety net** : tout signal de création de l'état local (ex : `Game::foundItemSnapableTile`) doit aussi wrapper `begin/endApplyRemote` avant de créer des ops.

### 4.10 Élection déterministe d'un nouvel hôte

Le host broadcast périodiquement `PlayerRoster{players:[...]}` (mise à jour à chaque join/leave). Tous les clients cachent cette liste. Quand le host tombe (`Catway::playerTimedOut`), chacun calcule :

```
candidats = roster_cache ∪ {self} − {ancien_hôte}
gagnant   = plus petit id lexicographique
```

Si tous les survivants ont la même snapshot roster, ils élisent le même gagnant — pas de négociation. Le gagnant appelle `promoteToHost()` ; les autres `stop()` puis tentent une reconnexion vers le nouvel hôte.

**Piège** : `stop()` après `emit hostLost()` annule la promotion synchronement faite par le handler QML. Ne jamais stopper en C++ — laisser le handler QML décider et appeler `stop()` explicitement dans la branche "je ne suis pas élu".

### 4.11 Reconnexion via rename chat

Le canal de signaling chat a une session identifiée par `sessionId`. Pour que les clients suivent l'ancien host-devenu-nouveau-host sans re-join manuel, on **renomme** la session côté chat server (commande `RENAME_SESSION`) plutôt que d'en créer une nouvelle. Les bénéfices :

- Même sessionId → historique conservé, pas de broadcast `SESSION_CREATED` parasite.
- Les autres lobbies voient juste un `SESSION_RENAMED{newName}` et mettent à jour `availableSessions` in place.
- Le préfixe `[EDIT:<newHostId>]` (ou autre encodage de mode) dans le nom reflète le nouveau host sans changer la clé.

Le `ChatClient::renameSession()` et les handlers `SESSION_RENAMED`/`SESSION_DELETED` existent déjà côté chat — réutiliser.

---

## 5. Gotchas QML à relire avant

- **Q_PROPERTY nom, pas getter name** : `Q_PROPERTY(bool p2pConnected READ isP2pConnected)` → en QML c'est `player.p2pConnected`, pas `player.isP2pConnected` qui renvoie undefined.
- **Binding sur `var` map** : muter `map[key] = v` ne re-déclenche pas les bindings. Toujours **réassigner** : `map = Object.assign({}, map, {[key]: v})`.
- **Hover sans clic** : `MouseArea { hoverEnabled: true }` est mangé par les enfants. Utiliser `HoverHandler` (pointer handler Qt6).
- **Catway.chatClient est partagé** : un seul `ChatClient` à la fois via `setChatClient`. En mode collab, préserver le ChatClient du lobby (ne pas le laisser écraser par un chat in-game).
- **`element.x = Qt.binding(...)` casse les bindings précédents** : si `MouseLogic_Base` ou un resize handle a remplacé `element.x` par un binding de groupe, les NOTIFY de `gridRelativePositionX` ne seront plus ré-évalués. Rebind manuellement après chaque apply distant (voir `_rebindTileIfSelected` dans `Editor.qml`).
- **QQmlListProperty ≠ JS array** : pas d'index direct depuis QML. Exposer des helpers `Q_INVOKABLE QObject *fooAt(int)` / `int fooCount()`.

---

## 6. Ordre de réimplémentation recommandé

Pour ne pas casser le mode monoposte, développer **par phases** derrière un flag `<Mode>Session.active === false` :

1. **Squelette session** : singletons vides, enums, frame pack/unpack. `active` toujours false. Build passe, comportement monoposte inchangé.
2. **Chokepoint OpBus** : tout router par `submitOp` **sans** appel réseau. Vérifier que chaque action utilisateur passe par le bus en mode monoposte.
3. **Broadcast host-auth** : brancher `sendOp → session.sendEvent(Op) → relayToOthers`. Tester host + 1 client local. Convergence sur create/move/delete.
4. **Full-sync à la connexion** : `Hello` / `FullSync` chunké. Tester un join en cours de session.
5. **Présence** : curseurs UDP (avec relay host §4.7), sélections reliable.
6. **Undo par op inverse** : pour les ops triviales (Create↔Delete, Link↔Unlink). Reporter Move/Resize/Set si pas de capture pré-image au submit.
7. **Entrée par le lobby** : encodage du mode dans le nom de session (`[EDIT:...]` pour l'éditeur, `[GAME:...]` pour une partie collab, etc.) + state machine P2P dans `main.qml`.
8. **Durcissement** : rate-limit, chunking fallback, élection + migration host via rename chat.

Chaque phase a une scène de test dédiée dans `qml/test/CatwayTest/` (voir `EditorNetworkTestTab.qml` / `EditorSessionPanel.qml` comme référence). Développer la scène en parallèle de la phase simplifie les itérations.

---

## 7. Non-objectifs (mêmes que l'éditeur sauf justification contraire)

- Migration de host en chaîne (host A meurt, élu B meurt pendant la reconnexion) non garantie.
- Pas de serveur persistant — le host tient l'état, autosave locale par participant.
- Conflits concurrents : **last-writer-wins par champ** (le rebroadcast du host fait foi). Pas de CRDT.
- Divergence d'asset packs / d'état initial : mismatch `assetPackHash` non détecté ; les clients verront des placeholders.
- Replay offline / reconnexion différée : non.

---

## 8. Référence rapide

| Besoin | Endroit du code éditeur à cloner |
|---|---|
| Singleton QML + cycle de vie | `EditorSession::startAsHost/Client/stop` |
| Rate-limit token bucket | `EditorSession::consumeOpToken` |
| Chunking fallback | `EditorSession::sendReliableOrChunked` + `handleOpChunk` |
| Dispatch par type | `EditorSession::onReliableReceived` switch |
| Relay ops host | `EditorSession::relayReliableToOthers` |
| Relay UDP host (curseurs) | `EditorSession::onUdpReceived` branche `m_isHost` |
| Full-sync chunké | `Editor.qml::_sendFullSyncTo` + `_receiveFullSyncChunk` |
| Élection + promotion | `EditorSession::electNewHost` + `promoteToHost` |
| Rename chat à la promotion | `ChatClient::renameSession` + handlers `SESSION_RENAMED` |
| Chokepoint mutations | `EditorOpBus::submitOp` + `isApplyingRemote` |
| Undo par op inverse | `EditorOpBus::submitOpWithUndo` + `undo/redo` |
| Encodage mode dans lobby | `MultiplayerLobby.qml` prefix `[EDIT:...]` |

Quand en doute, **lire le code de `EditorSession` / `EditorOpBus` est la source canonique**. Ce document ne fait qu'expliquer *pourquoi* il ressemble à ça.
