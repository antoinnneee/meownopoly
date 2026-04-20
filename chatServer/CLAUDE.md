# CLAUDE.md — chatServer

Sous-projet Node.js du dépôt Meownopoly. Serveur WebSocket "Blind Relay" (E2EE, le serveur ne voit jamais le cleartext) couplé à un STUN minimaliste pour le hole-punching UDP de Catway. Voir aussi le `CLAUDE.md` racine pour l'architecture globale.

## Vue d'ensemble

- **Runtime** : Node.js 18+, CommonJS.
- **Dépendances** (`package.json`) : `ws`, `better-sqlite3`, `dotenv`.
- **Processus unique** : `server.js` démarre simultanément un HTTP server (dashboard + API stats), un WebSocket server (`ws`) monté sur ce HTTP server, et un STUN UDP server (`simple_stun.js`).
- **Persistance** : SQLite (`chat.db` dans le répertoire courant). Schéma géré par `database.js` avec migrations `ALTER TABLE` idempotentes (try/catch). Pas d'ORM — tout est en `prepared statements` directs.
- **Pas de tests automatisés**. Les fichiers `test_*.js` sont des clients de vérif manuelle (`node test_client.js`, etc.).

## Lancement

```bash
npm install
node server.js
```

Variables d'env (fichier `.env`) — valeurs par défaut entre parenthèses :
- `PORT` (3000) — HTTP + WebSocket.
- `STUN_PORT` (3478) — UDP STUN.
- `MAX_PAYLOAD_SIZE` (10 MB) — rejet WebSocket au-delà.
- `MAX_DB_SIZE` (500 MB) — au-dessus, purge automatique des 50 plus vieux messages.
- `MAX_SESSIONS` (500) — plafond dur : refus de `CREATE_SESSION` / `JOIN_SESSION` si dépassé.
- `DEBUG_MODE` (false) — logs verbeux timestampés.
- `ENABLE_DASHBOARD` (false) — expose `/dashboard.html`, `/labo.html`, `/api/stats`.
- `ENABLE_TTL` (true), `TTL_INTERVAL_MS` (3600000) — nettoyage périodique via `cleanup.js` (TTL 24 h hard-codé).
- `ADMIN_TOKEN` (vide) — **fail-closed** : sans token configuré, `CLEAR_ALL_SESSIONS` est désactivé.

## Fichiers

- `server.js` — point d'entrée, routage WebSocket par `type`, état en mémoire (`rooms`, `keyRotationRequired`), HTTP + dashboard.
- `database.js` — toutes les opérations SQLite. Exporte `db` brut en plus des helpers (utilisé par `server.js` pour les stats). **Source de vérité** du schéma.
- `cleanup.js` — `setInterval` qui appelle `db.cleanupOldData(24h)`.
- `simple_stun.js` — STUN binding-request/response minimaliste (RFC 5389 partiel). Renvoie MAPPED-ADDRESS IPv4 seulement. Utilisé par Catway côté client.
- `chat_crypto.js` — miroir JS du système crypto du client C++ (SHA-256, HMAC, stream cipher custom). Chargé par `dashboard.html` et `labo.html` uniquement ; pas utilisé côté serveur (le serveur est aveugle par design).
- `dashboard.html` / `dashboard.css` / `dashboard.js` — UI de monitoring + mini-client chat E2EE (gated derrière `ENABLE_DASHBOARD`).
- `labo.html` — playground crypto (même gate que dashboard).
- `deploy.sh` + `.deployEnv` — SCP + `systemctl restart` via SSH multiplexing. `.deployEnv` contient les credentials (NE PAS commit en clair).
- `setup-domain.sh` — bootstrap nginx + Let's Encrypt + systemd sur Linux.
- `test_client.js`, `test_clear.js`, `test_dashboard.sh`, `test_get_session_list.js`, `test_participants.js` — harnais manuel.

## Schéma SQLite (géré dans `database.js`)

- `sessions(session_id PK, session_name, password_hash, key_package, key_nonce, version, max_players, is_public, host_player_id, created_at)`.
- `messages(id AUTOINCREMENT, session_id FK, sender_id, sender_nickname, payload, nonce, key_version, server_timestamp)` + index sur `session_id`.
- `participants(session_id, player_id, nickname, joined_at)` — PK composite `(session_id, player_id)`.
- `session_keys` est explicitement **droppée** à l'init (table legacy d'une ancienne version ; `getSessionKeys` lit désormais directement les colonnes de `sessions`).

Migrations additives via `ALTER TABLE` dans des try/catch — on ne drop jamais de colonne. Pour faire évoluer le schéma : ajouter un nouveau `try { db.prepare('ALTER TABLE …').run(); } catch(e){}` en bas du bloc de migration.

## Protocole WebSocket

Frames JSON : `{ type: "XXX", payload: { … } }`. Le routage est un `switch(type)` dans `handleCommand` (`server.js:175`).

**Commandes client → serveur** :
- Session lifecycle : `CREATE_SESSION`, `JOIN_SESSION`, `LEAVE_SESSION`, `DELETE_SESSION`, `LIST_SESSIONS` / `GET_SESSION_LIST`.
- Messages : `SEND_MSG` (broadcast ou unicast via `recipient_id`), `SEND_COMMAND` (meta, non persisté), `GET_HISTORY` (pagination via `before_id`), `CLEAR_HISTORY`.
- Crypto : `PUBLISH_KEY` (nouveau blob E2EE, incrémente `version`).
- Modération : `KICK`, `RENAME_SESSION`, `TRANSFER_HOST`, `CLEAR_ALL_SESSIONS` (admin).
- Participants : `GET_PARTICIPANTS`.

**Messages serveur → client** :
- `INIT_SESSION` (réponse à JOIN, inclut `new_joiner` flag), `SESSION_CREATED`, `KEY_UPDATE`, `NEW_MESSAGE`, `NEW_COMMAND`, `HISTORY_RESULT`, `PARTICIPANTS_LIST`, `SESSIONS_LIST`, `LEFT_SESSION`, `SESSION_ENDED`, `HISTORY_CLEARED`, `SERVER_RESET`, `KICKED`, `PARTICIPANT_KICKED`, `PARTICIPANT_LEFT`, `NEW_PARTICIPANT`, `SESSION_CREATED_BROADCAST`, `SESSION_RENAMED`, `HOST_CHANGED`, `SESSION_DELETED`, `ERROR`.

Codes d'erreur (`ERROR.payload.code`) : `PAYLOAD_TOO_LARGE`, `INVALID_FORMAT`, `UNKNOWN_COMMAND`, `UNAUTHORIZED`, `FORBIDDEN`, `SESSION_NOT_FOUND`, `SESSION_EXISTS`, `INVALID_PASSWORD`, `MAX_SESSIONS_REACHED`, `KEY_ROTATION_REQUIRED`, `MISSING_PARAMETER`, `NOT_PARTICIPANT`, `RENAME_FAILED`, `TRANSFER_FAILED`, `INVALID_OPERATION`.

## Invariants de sécurité

- **Le serveur est aveugle** : il ne déchiffre jamais `payload`/`nonce` ni les blobs de clé. Ne JAMAIS ajouter de code qui lit/parse le contenu chiffré côté serveur.
- **`sender_id` toujours pris de la socket** (`ws.player_id` défini par `JOIN_SESSION`), jamais du payload client — cf. `handleSendMessage` (`server.js:418`). Toute nouvelle commande "au nom de l'utilisateur" doit suivre le même pattern.
- **Gating session** : liste `sessionCommands` (`server.js:161`) — toute commande opérant sur une session vérifie `ws.session_id === payload.session_id` avant dispatch. Ajouter les nouveaux types dans ce tableau s'ils requièrent un contexte de session.
- **Host checks** : `CLEAR_HISTORY`, `DELETE_SESSION`, `KICK` reposent sur `db.isHost(sessionId, playerId)`. Depuis la migration Phase 8, `isHost` lit `sessions.host_player_id` en priorité et retombe sur `MIN(joined_at)` pour les sessions legacy. `TRANSFER_HOST` autorise aussi la **self-promotion** (le nouvel hôte élu s'auto-déclare quand l'ancien est déjà parti) — cf. `handleTransferHost` (`server.js:935`).
- **`KICK` utilise encore `participants[0]` (legacy)** au lieu de `db.isHost`. Incohérent avec les autres commandes post-Phase-8 : à migrer vers `isHost`. Gap connu.
- **`CLEAR_ALL_SESSIONS`** : fail-closed sans `ADMIN_TOKEN`. Ne pas rendre cette commande accessible par défaut.
- **Messages privés (`recipient_id` non null) ne sont jamais persistés** et sont taggés `ephemeral: true` — cf. `handleSendMessage`.

## Key rotation (E2EE)

- À chaque `JOIN_SESSION` d'un **nouveau** participant (`isNewParticipant`), le serveur ajoute `session_id` à `keyRotationRequired`. `SEND_MSG` et `SEND_COMMAND` renvoient alors `KEY_ROTATION_REQUIRED` jusqu'à ce qu'un client republie via `PUBLISH_KEY`.
- Idem sur `LEAVE_SESSION` et `KICK` (rotation requise pour sécuriser les messages futurs contre le partant).
- La rotation effective est **clear** par `handlePublishKey` → `keyRotationRequired.delete(session_id)`. Ne pas oublier ce delete si on ajoute une commande qui publie une clé.

## État mémoire vs DB

- `rooms: Map<sessionId, Set<WebSocket>>` — sockets actives par session. Rebuild from scratch au démarrage (pas persisté).
- `keyRotationRequired: Set<sessionId>` — idem, éphémère.
- **Les participants sont persistés**. Une déconnexion réseau ne retire pas de `participants`. Seuls `LEAVE_SESSION`, `KICK`, `DELETE_SESSION`, ou la déconnexion (via `removeFromRooms`, Phase 8) retirent la ligne.
- **Session vide = purge totale** (Phase 8) : `removeFromRooms` supprime la session entière (`deleteSession`) quand la dernière socket se déconnecte, et broadcast `SESSION_DELETED`. Conséquence : une session créée puis quittée avant qu'un autre pair ne join disparaît — pensez-y en testant `CREATE_SESSION` en isolé.

## Gotchas

- `handleCreateSession` ne désigne **pas** d'hôte (`host_player_id=null`). L'hôte est fixé au premier `JOIN_SESSION` (`server.js:271`). Le flow client typique est `CREATE` → `JOIN` enchaînés.
- `updateSession` (= `PUBLISH_KEY`) **refuse** si la session n'existe pas : pas de `createSession` fallback. La session doit avoir été créée explicitement.
- `db.db` est exposé volontairement pour les queries stats dans `server.js` (`getTotalMessages`, `getSessionMessageCount`). Ne pas étendre cet usage sans raison — préférer ajouter un helper dans `database.js`.
- Dashboard HTTP sert une **allowlist stricte** de fichiers (`/dashboard.html`, `/dashboard.css`, `/dashboard.js`, `/chat_crypto.js`, `/labo.html`). Tout nouveau fichier servi doit être ajouté à `allowedFiles` (`server.js:81`) — pas de path traversal possible via ce contrôle.
- `simple_stun.js` ne gère **que** IPv4 et ne supporte pas XOR-MAPPED-ADDRESS. Suffisant pour Catway actuel mais à garder en tête si on évolue vers RFC 5780 (NAT behavior discovery).
- `better-sqlite3` est **synchrone** : toutes les ops DB bloquent l'event loop. OK tant que les transactions restent courtes ; éviter les gros batchs sans `db.transaction(…)`.

## Déploiement

- `deploy.sh` lit `.deployEnv` (gitignored), copie la liste `FILES` via SCP, puis `npm install --production && systemctl restart $SERVICE_NAME`. `node_modules/` et `chat.db` ne sont **pas** copiés : la DB de prod est préservée.
- Ajouter un nouveau fichier source ? Penser à l'ajouter au tableau `FILES` (`deploy.sh:55`) sinon il ne sera pas déployé.
- `setup-domain.sh votre-domaine.com` (sudo) bootstrap nginx reverse-proxy + Let's Encrypt + systemd. One-shot, à relancer seulement si on change de domaine.
