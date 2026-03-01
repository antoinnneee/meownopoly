# Protocole WebSocket - Système de Chat

Ce document récapitule les différentes trames WebSocket échangées entre le client (C++/Qt) et le serveur (Node.js). Toutes les trames sont au format JSON.

---

## Modèle de Sécurité (Blind Relay)

Le serveur fonctionne comme un "relais aveugle". Il ne connaît pas le contenu des messages.
- **Lock Key** : Dérivée du mot de passe de la session. Utilisée pour chiffrer les clés de session.
- **Session Key** : Clé symétrique aléatoire utilisée pour chiffrer les messages et les commandes. Le serveur stocke ces clés sous forme chiffrée (blob).
- **Forward Secrecy** : Une nouvelle clé de session est générée à chaque fois qu'un participant rejoint ou quitte la session.

---

## Processus de Création d'une Session

La création est désormais une opération distincte du rejoindre. Elle suit les étapes suivantes :

1. **Connexion WebSocket** : Le client ouvre une connexion TCP vers le serveur.
2. **Requête `CREATE_SESSION`** : Le client envoie le `session_id` (généré localement via `AccountManager::getNewUniqueId()`), le `session_name`, et le `password_hash`.
3. **Vérification Serveur** :
   - Si une session avec cet ID existe déjà → erreur `SESSION_EXISTS`.
   - Sinon : la session est créée en base avec son nom et son hash.
4. **Confirmation (`SESSION_CREATED`)** : Le serveur répond avec les métadonnées de la session créée.
5. **Rejoindre automatiquement** : Après réception de `SESSION_CREATED`, le client envoie immédiatement `JOIN_SESSION` pour entrer dans la session qu'il vient de créer (côté C++ : `handleSessionCreated` appelle `joinSession()`).
6. **Initialisation (`INIT_SESSION`)** : Le serveur répond au `JOIN_SESSION` avec les clés et l'historique (vides pour une nouvelle session).
7. **Génération de la première clé** : Le client détecte qu'il n'y a pas de clé et publie la première via `PUBLISH_KEY`.

---

## Processus de Rejoindre une Session Existante

1. **Connexion WebSocket** : Le client ouvre une connexion TCP vers le serveur.
2. **Requête `JOIN_SESSION`** : Le client envoie ses identifiants (`player_id`, `nickname`) et la preuve du mot de passe (`password_hash`).
3. **Vérification Serveur** :
   - **Session inexistante** : Le serveur renvoie une erreur `SESSION_NOT_FOUND`. La session doit être créée explicitement via `CREATE_SESSION`.
   - **Mot de passe invalide** : Le serveur renvoie une erreur `INVALID_PASSWORD`.
   - **Succès** : Le client est ajouté à la session (participant connu ou nouveau).
4. **Initialisation (`INIT_SESSION`)** : En cas de succès, le serveur renvoie :
   - La version actuelle de la clé de session.
   - La **dernière clé de session** enregistrée (chiffrée).
   - L'historique des messages (chiffrés).
   - Un flag `new_joiner` indiquant si c'est la première fois que ce joueur rejoint.
5. **Notification des Pairs** : Le serveur diffuse un message `NEW_PARTICIPANT` aux autres clients connectés.
6. **Rotation de Clé** : Les clients existants détectent le nouvel arrivant et publient une nouvelle clé via `PUBLISH_KEY` pour assurer la Forward Secrecy.

---

## Trames Client -> Serveur (Requêtes)

Ces trames sont envoyées par le client pour interagir avec le serveur.

### `CREATE_SESSION`
Crée une nouvelle session sur le serveur. Ne rejoint pas la session — un `JOIN_SESSION` doit suivre.
- `session_id` (string) : Identifiant unique de la session, généré côté client via `AccountManager::getNewUniqueId()`.
- `session_name` (string) : Nom lisible de la session, saisi par l'utilisateur.
- `password_hash` (string) : Preuve de connaissance du mot de passe (hash dérivé de `session_id + password`).
- `max_players` (int) : Nombre maximum de joueurs (défaut : 4).
- `is_public` (bool) : Si `true`, la session apparaît dans la liste publique (défaut : `true`).

### `JOIN_SESSION`
Rejoint une session existante. Renvoie `SESSION_NOT_FOUND` si la session n'existe pas encore.
- `session_id` (string) : Identifiant unique de la session.
- `player_id` (string) : Identifiant unique du joueur.
- `player_nickname` (string) : Pseudonyme du joueur.
- `password_hash` (string) : Preuve de connaissance du mot de passe (hash).

### `PUBLISH_KEY`
Publie une nouvelle clé de session (chiffrée avec la Lock Key).
- `session_id` (string) : Identifiant de la session.
- `blob` (string, base64) : Clé de session chiffrée.
- `nonce` (string, base64) : Nonce utilisé pour le chiffrement du blob.

### `SEND_MSG`
Envoie un message de chat. Par défaut diffusé à tous les participants et enregistré dans l'historique.
- `session_id` (string) : Identifiant de la session.
- `sender_id` (string) : Identifiant de l'expéditeur.
- `sender_nickname` (string) : Pseudonyme de l'expéditeur.
- `payload` (string, base64) : Contenu du message chiffré.
- `nonce` (string, base64) : Nonce utilisé pour le chiffrement du payload.
- `key_v` (int) : Version de la clé de session utilisée.
- `recipient_id` (string, optionnel) : Si présent, le message est envoyé **uniquement** à ce participant (unicast) et **n'est pas enregistré** dans l'historique de la session.

### `SEND_COMMAND`
Envoie une commande interne chiffrée (ex: PING/PONG, signaux de jeu).
- `session_id` (string) : Identifiant de la session.
- `recipient_id` (string, optionnel) : ID du destinataire (Unicast). Si vide, diffusé à tous sauf l'expéditeur.
- `payload` (string, base64) : Commande chiffrée.
- `nonce` (string, base64) : Nonce utilisé.
- `key_v` (int) : Version de la clé utilisée.

### `GET_PARTICIPANTS`
Demande la liste des participants de la session.
- `session_id` (string) : Identifiant de la session.

### `GET_HISTORY`
Récupère l'historique des messages.
- `session_id` (string) : Identifiant de la session.
- `before_id` (int, optionnel) : ID du message pour la pagination (récupère les messages plus anciens).

### `LEAVE_SESSION`
Se retire de la session de manière explicite.
- `session_id` (string) : Identifiant de la session.
- `player_id` (string) : Identifiant du joueur quittant.

### `KICK`
Expulse un joueur (réservé à l'hôte).
- `session_id` (string) : Identifiant de la session.
- `target_player_id` (string) : Identifiant du joueur à expulser.

### `LIST_SESSIONS`
Demande la liste de toutes les sessions actives sur le serveur.

### `DELETE_SESSION`
Supprime complètement une session (réservé aux participants).
- `session_id` (string) : Identifiant de la session.

### `CLEAR_HISTORY`
Efface tous les messages d'une session.
- `session_id` (string) : Identifiant de la session.

---

## Trames Serveur -> Client (Réponses / Événements)

### `SESSION_CREATED`
Confirmation de création de session, envoyée après un `CREATE_SESSION` réussi. Le client doit ensuite envoyer un `JOIN_SESSION` pour entrer dans la session.
- `session_id` (string) : Identifiant de la session créée.
- `session_name` (string) : Nom de la session.
- `max_players` (int) : Capacité maximale.
- `is_public` (bool) : Visibilité dans la liste publique.
- `created_at` (string) : Date ISO de création.

### `INIT_SESSION`
Envoyée après un `JOIN_SESSION` réussi.
- `current_version` (int) : Version actuelle de la clé.
- `keys` (array) : Liste des clés de session (`version`, `key_package`, `nonce`). (uniquement dernière clé)
- `history` (array) : Historique des messages chiffrés.
- `new_joiner` (bool) : `true` si le joueur vient de s'inscrire pour la première fois dans cette session.

### `NEW_MESSAGE`
Diffusé quand un nouveau message est reçu.
- `msg_id` (int, optionnel) : ID unique du message en base de données. Absent ou 0 pour les messages éphémères (envoyés avec `recipient_id`).
- `ephemeral` (bool, optionnel) : Si `true`, le message ne doit pas être enregistré dans l'historique local (message privé / unicast).
- `sender_id` (string) : ID de l'expéditeur.
- `sender_nickname` (string) : Pseudonyme de l'expéditeur.
- `payload` (string, base64) : Message chiffré.
- `nonce` (string, base64) : Nonce utilisé.
- `key_version` (int) : Version de la clé à utiliser pour déchiffrer.
- `timestamp` (string) : Date ISO de réception par le serveur.

### `NEW_COMMAND`
Diffusé quand une commande (`SEND_COMMAND`) est reçue.
- `sender_id` (string) : ID de l'expéditeur.
- `payload` (string, base64) : Commande chiffrée.
- `nonce` (string, base64) : Nonce utilisé.
- `key_version` (int) : Version de la clé.
- `timestamp` (string) : Date ISO.

### `KEY_UPDATE`
Diffusé quand une nouvelle clé de session est publiée.
- `version` (int) : Nouvelle version de la clé.
- `key_package` (string, base64) : Clé chiffrée.
- `nonce` (string, base64) : Nonce de la clé.

### `PARTICIPANTS_LIST`
Réponse à `GET_PARTICIPANTS`.
- `session_id` (string)
- `count` (int) : Nombre total.
- `participants` (array) : Objets contenant `player_id`, `player_nickname`, `status` (online/offline).

### `SESSIONS_LIST`
Réponse à `LIST_SESSIONS`.
- `sessions` (array) : Liste des sessions. Chaque entrée contient :
  - `session_id` (string)
  - `session_name` (string) : Nom lisible de la session.
  - `host_id` (string) : ID du premier participant (hôte).
  - `host_nickname` (string) : Pseudonyme de l'hôte.
  - `player_count` (int) : Nombre de participants enregistrés.
  - `max_players` (int) : Capacité maximale.
  - `online_count` (int) : Nombre de joueurs actuellement connectés.
  - `is_public` (bool)
  - `status` (string) : `"waiting"`, `"available"` ou `"full"`.
  - `created_at` (string) : Date ISO de création.
- `total` (int) : Nombre total sur le serveur.
- `limit` (int) : Limite appliquée.
- `limited` (bool) : `true` si la liste a été tronquée.

### `NEW_PARTICIPANT`
Diffusé quand un nouveau joueur rejoint la session.
- `session_id` (string)
- `player_id` (string)
- `player_nickname` (string)

### `PARTICIPANT_LEFT` / `PARTICIPANT_KICKED`
Diffusé quand un joueur quitte ou est expulsé.
- `session_id` (string)
- `player_id` (string)

### `ERROR`
Envoyé en cas d'échec d'une opération.
- `code` (string) : Code d'erreur. Codes possibles :

| Code | Déclencheur | Comportement client |
|------|-------------|---------------------|
| `UNAUTHORIZED` | Commande de session sans avoir rejoint | — |
| `INVALID_PASSWORD` | `JOIN_SESSION` avec mauvais hash | `emit errorOccurred` |
| `SESSION_NOT_FOUND` | `JOIN_SESSION` sur session inexistante | `emit errorOccurred("La session demandée n'existe pas.")` |
| `SESSION_EXISTS` | `CREATE_SESSION` sur ID déjà pris | `emit errorOccurred` |
| `KEY_ROTATION_REQUIRED` | `SEND_MSG` / `SEND_COMMAND` bloqué | Publie une nouvelle clé et relance le message en attente |
| `MAX_SESSIONS_REACHED` | Limite serveur atteinte | `emit errorOccurred` |
| `MISSING_PARAMETER` | Paramètre obligatoire absent | `emit errorOccurred` |
| `PAYLOAD_TOO_LARGE` | Message dépassant la limite (10 MB) | `emit errorOccurred` |

- `message` (string) : Description explicative.

### `HISTORY_CLEARED` / `SESSION_ENDED` / `SERVER_RESET`
Signaux de maintenance ou de destruction de session.

---

## Contenu et structure de la session (côté serveur)

Le serveur (`chatServer/server.js`) et la base de données (`chatServer/database.js`) maintiennent les sessions selon la structure suivante.

### Données persistantes (base SQLite)

**Table `sessions`**
| Champ           | Type      | Description |
|-----------------|-----------|-------------|
| `session_id`    | TEXT (PK) | Identifiant unique de la session. |
| `session_name`  | TEXT      | Nom lisible de la session, saisi par le créateur. |
| `password_hash` | TEXT      | Preuve du mot de passe (hash) utilisée pour vérifier les rejoins. |
| `key_package`   | TEXT      | Dernière clé de session chiffrée (blob). |
| `key_nonce`     | TEXT      | Nonce utilisé pour le chiffrement du blob. |
| `version`       | INTEGER   | Version courante de la clé (incrémentée à chaque rotation). |
| `created_at`    | TIMESTAMP | Date de création de la session. |

**Table `participants`**
| Champ        | Type      | Description |
|--------------|-----------|-------------|
| `session_id` | TEXT      | Référence vers la session. |
| `player_id`  | TEXT      | Identifiant du joueur. |
| `nickname`   | TEXT      | Pseudonyme du joueur. |
| `joined_at`  | TIMESTAMP | Date d'inscription dans la session. |
| *(PK)*       |           | `(session_id, player_id)`. |

L'ordre d'insertion définit l'**hôte** : le premier participant (`ORDER BY joined_at ASC`) est considéré comme hôte (pour le KICK, etc.).

**Table `messages`**
| Champ             | Type      | Description |
|-------------------|-----------|-------------|
| `id`              | INTEGER   | Identifiant unique du message (auto). |
| `session_id`      | TEXT      | Session concernée. |
| `sender_id`       | TEXT      | ID de l'expéditeur. |
| `sender_nickname` | TEXT      | Pseudonyme au moment de l'envoi. |
| `payload`         | TEXT      | Message chiffré (base64). |
| `nonce`           | TEXT      | Nonce du chiffrement. |
| `key_version`     | INTEGER   | Version de la clé utilisée. |
| `server_timestamp`| TIMESTAMP | Date d'enregistrement côté serveur. |

### État en mémoire (serveur Node.js)

- **`rooms`** : `Map<session_id, Set<WebSocket>>` — Connexions WebSocket actuellement dans chaque session. Une session peut exister en base sans entrée dans `rooms` si personne n'est connecté.
- **`keyRotationRequired`** : `Set<session_id>` — Sessions pour lesquelles un nouveau participant vient d'arriver ou quelqu'un vient de partir ; aucun message/commande n'est accepté tant qu'un client n'a pas publié une nouvelle clé via `PUBLISH_KEY`.
- **État attaché à chaque socket (`ws`)** : `session_id`, `player_id`, `player_nickname`.

### Clés de session exposées au client

`db.getSessionKeys(session_id)` retourne une liste (en pratique une seule entrée) d'objets avec :
- `version` : version de la clé
- `key_package` : blob chiffré (envoyé tel quel dans les trames)
- `key_nonce` : nonce (envoyé sous le champ `nonce` dans INIT_SESSION / KEY_UPDATE)

Les entrées avec `key_package === null` sont filtrées avant envoi au client (session sans clé encore publiée).

---

## Génération des identifiants de session

Les `session_id` sont générés **exclusivement côté client** via `AccountManager::getNewUniqueId()` (méthode statique C++). En QML, l'ID est généré automatiquement en ne passant pas le troisième argument à `chatClient.createSession(name, password)` — le paramètre par défaut C++ se charge de l'appel à `getNewUniqueId()`.

Le `session_name` (nom lisible) est un champ distinct, saisi par l'utilisateur dans l'interface de création.
