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
- `MAX_PAYLOAD_SIZE` (10 MB) — passé à `ws` comme `maxPayload` : frames au-dessus rejetées au parser (close 1009) avant allocation RAM.
- `MAX_DB_SIZE` (500 MB) — au-dessus, purge **proportionnelle** (10 % des plus vieux messages, min 100), plus `50` fixe qui était insuffisant sur spam.
- `MAX_SESSIONS` (500) — plafond dur. Métrique unifiée sur `db.getAllSessions().length` côté `CREATE_SESSION` et `JOIN_SESSION` (avant, JOIN comptait `rooms.size` et divergeait).
- `DEBUG_MODE` (false) — logs verbeux timestampés.
- `ENABLE_DASHBOARD` (false) — expose `/dashboard.html`, `/labo.html`, `/api/stats`.
- `ENABLE_TTL` (true), `TTL_INTERVAL_MS` (3600000) — nettoyage périodique via `cleanup.js` (TTL 24 h hard-codé). Purge en cascade aussi les participants / messages orphelins.
- `ADMIN_TOKEN` (vide) — **fail-closed** : sans token configuré, `CLEAR_ALL_SESSIONS` est désactivé. Si `ENABLE_DASHBOARD=true` et token défini, `/api/stats` exige `Authorization: Bearer <token>`.
- `ALLOWED_ORIGINS` (vide, CSV) — opt-in origin check WebSocket. Si vide, tout passe (compat clients natifs C++ qui n'envoient pas `Origin`). Sinon seuls les origines listées sont acceptées.
- `RATE_LIMIT_BUCKET` (60), `RATE_LIMIT_REFILL` (10) — token bucket par IP. Chaque frame consomme 1 token ; au-dessous de 1, la frame est rejetée avec code `RATE_LIMITED`. Bucket GC après 5 min d'inactivité.
- `HEARTBEAT_INTERVAL_MS` (30000) — ping WS périodique ; les sockets qui ne pongent pas avant le tick suivant sont `terminate()`.

## Fichiers

- `server.js` — point d'entrée, routage WebSocket par `type`, état en mémoire (`rooms`, `keyRotationRequired`), HTTP + dashboard.
- `database.js` — toutes les opérations SQLite. Exporte `db` brut en plus des helpers (utilisé par `server.js` pour les stats). **Source de vérité** du schéma.
- `cleanup.js` — `setInterval` qui appelle `db.cleanupOldData(24h)`.
- `simple_stun.js` — STUN binding-request/response minimaliste (RFC 5389). Renvoie **MAPPED-ADDRESS + XOR-MAPPED-ADDRESS** (IPv4 uniquement). Valide `Magic Cookie` + longueur ; les paquets malformés sont loggés sans crasher. Utilisé par Catway côté client.
- `chat_crypto.js` — miroir JS du système crypto du client C++ (SHA-256, HMAC, stream cipher custom). Chargé par `dashboard.html` et `labo.html` uniquement ; pas utilisé côté serveur (le serveur est aveugle par design).
- `dashboard.html` / `dashboard.css` / `dashboard.js` — **dev dashboard** (gated derrière `ENABLE_DASHBOARD`). Interface d'admin dev-only : inspection/suppression de sessions, effacement d'historique, wipe DB, TTL cleanup, VACUUM. Poll REST toutes les 3 s, pas de WebSocket. N'inclut plus le mini-client chat (déplacé dans `labo.html`).
- `labo.html` — playground crypto + mini-client chat E2EE (même gate que dashboard). Utilise `chat_crypto.js`.
- `deploy.sh` + `.deployEnv` — SCP + `systemctl restart` via SSH multiplexing. `.deployEnv` contient les credentials (NE PAS commit en clair).
- `setup-domain.sh` — bootstrap nginx + Let's Encrypt + systemd sur Linux.
- `test_client.js`, `test_clear.js`, `test_dashboard.sh`, `test_get_session_list.js`, `test_participants.js` — harnais manuel.

## Schéma SQLite (géré dans `database.js`)

- `sessions(session_id PK, session_name, password_hash, key_package, key_nonce, version, max_players, is_public, host_player_id, created_at)`.
- `messages(id AUTOINCREMENT, session_id FK, sender_id, sender_nickname, payload, nonce, key_version, server_timestamp)` + index sur `session_id`.
- `participants(session_id, player_id, nickname, joined_at)` — PK composite `(session_id, player_id)`.
- `session_keys` est explicitement **droppée** à l'init (table legacy d'une ancienne version ; `getSessionKeys` lit désormais directement les colonnes de `sessions`).

Pragmas au boot : `journal_mode = WAL` (lectures concurrentes + robustesse crash), `synchronous = NORMAL`, `foreign_keys = ON`. Les fichiers `chat.db-wal` / `chat.db-shm` apparaissent à côté de `chat.db` — gitignorés.

Migrations additives via `ALTER TABLE` dans des try/catch — on ne drop jamais de colonne. Pour faire évoluer le schéma : ajouter un nouveau `try { db.prepare('ALTER TABLE …').run(); } catch(e){}` en bas du bloc de migration.

`addParticipant` est un **UPSERT** (`ON CONFLICT DO UPDATE SET nickname`) : un joueur qui rejoint avec un nouveau pseudo voit son nickname rafraîchi, mais `joined_at` est préservé (indispensable pour le fallback legacy `getHost`).

## REST admin API (dashboard, dev-only)

Exposée quand `ENABLE_DASHBOARD=true`. Toutes les routes sont gatées par `ADMIN_TOKEN` si défini (header `Authorization: Bearer <token>`), sinon ouvertes (mode dev). Le serveur log un warning au boot si dashboard activé sans token.

- `GET /api/stats` — stats globales (connexions, rooms, DB size, uptime, mémoire, résumé des sessions).
- `GET /api/sessions` — liste détaillée des sessions (via `getDetailedSessionList` + `getSessionMessageCount`).
- `GET /api/sessions/:id` — détail d'une session : métadonnées + participants (online/offline selon `rooms`) + flag `key_rotation_required`.
- `GET /api/sessions/:id/messages?limit=N` — métadonnées des messages seulement (id, sender_id, nickname, key_version, timestamp, `payload_len`). Pas le ciphertext lui-même — inutile pour le debug et peut être lourd. **Le serveur reste aveugle.**
- `DELETE /api/sessions/:id` — supprime la session (broadcast `SESSION_ENDED` aux membres, `deleteSession` cascade, broadcast `SESSION_DELETED` global).
- `DELETE /api/sessions/:id/messages` — clear history (`clearMessages` + broadcast `HISTORY_CLEARED`).
- `POST /api/db/cleanup` — trigger manuel `cleanupOldData(24h)` (TTL normalement périodique).
- `POST /api/db/vacuum` — `VACUUM` SQLite.
- `DELETE /api/db` — **wipe total** (`clearAllData` + broadcast `SERVER_RESET`, kick toutes les sockets). Équivalent REST de `CLEAR_ALL_SESSIONS`.

Toutes les réponses sont JSON. Erreurs : `{ error, ...context }` avec status HTTP approprié (401, 404, 500). CORS permissif (`*`) — usage dev uniquement.

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

Codes d'erreur (`ERROR.payload.code`) : `PAYLOAD_TOO_LARGE`, `INVALID_FORMAT`, `UNKNOWN_COMMAND`, `UNAUTHORIZED`, `FORBIDDEN`, `SESSION_NOT_FOUND`, `SESSION_EXISTS`, `INVALID_PASSWORD`, `MAX_SESSIONS_REACHED`, `KEY_ROTATION_REQUIRED`, `MISSING_PARAMETER`, `NOT_PARTICIPANT`, `RENAME_FAILED`, `TRANSFER_FAILED`, `INVALID_OPERATION`, `RATE_LIMITED`, `PLAYER_ID_IN_USE`, `INTERNAL_ERROR`.

## Invariants de sécurité

- **Le serveur est aveugle** : il ne déchiffre jamais `payload`/`nonce` ni les blobs de clé. Ne JAMAIS ajouter de code qui lit/parse le contenu chiffré côté serveur.
- **`sender_id` et `sender_nickname` toujours pris de la socket** (`ws.player_id` / `ws.player_nickname` définis par `JOIN_SESSION`), jamais du payload client — cf. `handleSendMessage`. Toute nouvelle commande "au nom de l'utilisateur" doit suivre ce pattern.
- **Gating session** : liste `sessionCommands` dans `handleCommand` — toute commande opérant sur une session vérifie `ws.session_id === payload.session_id` avant dispatch. Ajouter les nouveaux types dans ce tableau s'ils requièrent un contexte de session.
- **Host checks** : `CLEAR_HISTORY`, `DELETE_SESSION`, **et `KICK`** reposent sur `db.isHost(sessionId, playerId)`. `isHost` lit `sessions.host_player_id` en priorité et retombe sur `MIN(joined_at)` pour les sessions legacy pré-Phase-8. `TRANSFER_HOST` autorise la **self-promotion** (le nouvel hôte élu s'auto-déclare quand l'ancien est parti), bornée au seul check `db.isParticipant(session_id, new_host_id)` — pas de vérif "ancien hôte encore connecté" (cf. gotcha Phase 8).
- **`CLEAR_ALL_SESSIONS`** : fail-closed sans `ADMIN_TOKEN`. `/api/stats` est derrière le même token si défini.
- **Anti-usurpation `player_id`** : `JOIN_SESSION` refuse (`PLAYER_ID_IN_USE`) si une autre socket OPEN dans la même session revendique déjà ce `player_id`. Mitige (sans authentifier) l'impersonation d'un membre actif.
- **Validation d'entrée** : `ID_REGEX` (`^[A-Za-z0-9_.:\-]{1,64}$`) pour tous les IDs, hash SHA-256 accepté en **64-char hex OU 44-char base64 avec `=`** (le client Qt envoie hex via `derivePasswordProof().toHex()` + `QString::fromLatin1`), `max_players ∈ [1, 16]`, noms bornés (128 / 64 chars). Toute commande qui accepte de nouveaux champs doit les valider.
- **Rate-limit** : token bucket par IP (`getClientIp` honore `X-Forwarded-For` si présent — OK derrière nginx). Pas de disconnect auto, juste drop + erreur `RATE_LIMITED`.
- **Messages privés (`recipient_id` non null) ne sont jamais persistés** et sont taggés `ephemeral: true` — cf. `handleSendMessage`.

## Key rotation (E2EE)

- À chaque `JOIN_SESSION` d'un **nouveau** participant (`isNewParticipant`), le serveur ajoute `session_id` à `keyRotationRequired`. `SEND_MSG` et `SEND_COMMAND` renvoient alors `KEY_ROTATION_REQUIRED` jusqu'à ce qu'un client republie via `PUBLISH_KEY`.
- Idem sur `LEAVE_SESSION` et `KICK` (rotation requise pour sécuriser les messages futurs contre le partant).
- La rotation effective est **clear** par `handlePublishKey` → `keyRotationRequired.delete(session_id)`. Ne pas oublier ce delete si on ajoute une commande qui publie une clé.

## État mémoire vs DB

- `rooms: Map<sessionId, Set<WebSocket>>` — sockets actives par session. Rebuild from scratch au démarrage (pas persisté).
- `keyRotationRequired: Set<sessionId>` — idem, éphémère.
- `rateBuckets: Map<ip, { tokens, last }>` — rate-limiter, GC automatique à 5 min d'inactivité.
- **Les participants sont persistés**. Une déconnexion réseau ne retire pas de `participants`. Seuls `LEAVE_SESSION`, `KICK`, `DELETE_SESSION`, ou la déconnexion (via `removeFromRooms`, Phase 8) retirent la ligne.
- **Session vide = purge totale** : à la fois `removeFromRooms` (disconnect brut) **et** `handleLeaveSession` (LEAVE propre) suppriment la session entière (`deleteSession`) + broadcast `SESSION_DELETED` quand la dernière socket part. Avant, un LEAVE laissait la session orpheline en DB jusqu'au TTL 24 h, alors qu'un disconnect la purgeait immédiatement — asymétrie corrigée.
- **Host reassignment** : quand un participant part (LEAVE, disconnect), si c'était l'hôte désigné, `db.clearHostIfMatches` libère `host_player_id`. Le fallback legacy (`MIN(joined_at)` sur les participants restants) prend le relais jusqu'au prochain `TRANSFER_HOST` (élection Phase 8 côté client). Sans ça, le retour de l'ex-hôte lui rendait les droits admin.

## Gotchas

- `handleCreateSession` ne désigne **pas** d'hôte (`host_player_id=null`). L'hôte est fixé au premier `JOIN_SESSION`. Le flow client typique est `CREATE` → `JOIN` enchaînés.
- `updateSession` (= `PUBLISH_KEY`) **refuse** si la session n'existe pas : pas de `createSession` fallback. La session doit avoir été créée explicitement.
- `db.db` est exposé volontairement pour les queries stats dans `server.js` (`getTotalMessages`, `getSessionMessageCount`). Ne pas étendre cet usage sans raison — préférer ajouter un helper dans `database.js`.
- Dashboard HTTP sert une **allowlist stricte** de fichiers (`/dashboard.html`, `/dashboard.css`, `/dashboard.js`, `/chat_crypto.js`, `/labo.html`). Tout nouveau fichier servi doit être ajouté à `allowedFiles` — pas de path traversal possible via ce contrôle.
- `better-sqlite3` est **synchrone** : toutes les ops DB bloquent l'event loop. OK tant que les transactions restent courtes ; éviter les gros batchs sans `db.transaction(…)`.
- **Format `password_hash`** : le client Qt envoie le hash **en hex pur** (64 chars) via `QString::fromLatin1(derivePasswordProof(...))`. `derivePasswordProof` fait déjà `.toHex()` en interne. Ne **pas** ré-appliquer `.toBase64()` au-dessus — c'était un bug (88 chars "b64 of hex") que la validation stricte du serveur rejetait. Le serveur accepte aussi la forme base64 canonique (44 chars avec `=`) pour compat dashboard JS.
- **Phase 8 `TRANSFER_HOST` self-promotion : pas de guard "ancien hôte connecté"**. La WS chat du lobby peut rester ouverte après que le client a quitté l'éditeur P2P (timeout / `HostLeaving`) — le serveur ne peut pas distinguer "WS ouverte" de "hôte vivant". On fait confiance au caller (élection Phase 8 déterministe côté client, tous les pairs convergent). Seule garde : le caller doit être participant.
- **Ne pas confondre socket WS et liveness P2P** : un participant "online" côté lobby peut être totalement offline côté éditeur. Les broadcasts `PARTICIPANT_LEFT` émis sur disconnect WS ne reflètent pas l'état P2P Catway.

## Déploiement

- `deploy.sh` lit `.deployEnv` (gitignored), copie la liste `FILES` via SCP, puis `npm install --production && systemctl restart $SERVICE_NAME`. `node_modules/` et `chat.db` ne sont **pas** copiés : la DB de prod est préservée.
- Ajouter un nouveau fichier source ? Penser à l'ajouter au tableau `FILES` (`deploy.sh:55`) sinon il ne sera pas déployé.
- `setup-domain.sh votre-domaine.com` (sudo) bootstrap nginx reverse-proxy + Let's Encrypt + systemd. One-shot, à relancer seulement si on change de domaine.
