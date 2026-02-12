# Protocole WebSocket - Système de Chat

Ce document récapitule les différentes trames WebSocket échangées entre le client (C++/Qt) et le serveur (Node.js). Toutes les trames sont au format JSON.

---

## Modèle de Sécurité (Blind Relay)

Le serveur fonctionne comme un "relais aveugle". Il ne connaît pas le contenu des messages.
- **Lock Key** : Dérivée du mot de passe de la session. Utilisée pour chiffrer les clés de session.
- **Session Key** : Clé symétrique aléatoire utilisée pour chiffrer les messages et les commandes. Le serveur stocke ces clés sous forme chiffrée (blob).
- **Forward Secrecy** : Une nouvelle clé de session est générée à chaque fois qu'un participant rejoint ou quitte la session.

---

## Processus de Connexion et Authentification

Le processus de connexion suit une logique stricte pour garantir la sécurité du "Blind Relay".

1. **Connexion WebSocket** : Le client ouvre une connexion TCP vers le serveur.
2. **Requête `JOIN_SESSION`** : Le client envoie ses identifiants (`player_id`, `nickname`) et la preuve du mot de passe (`password_hash`).
3. **Vérification Serveur** :
   - **Session inexistante** : Le serveur crée la session et enregistre le `password_hash` fourni comme référence.
   - **Session existante** : Le serveur compare le `password_hash` reçu avec celui stocké en base de données.
   - **Échec** : Si les hashs ne correspondent pas, le serveur renvoie une erreur `INVALID_PASSWORD`.
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

### `JOIN_SESSION`
Utilisée pour rejoindre une session existante ou en créer une nouvelle.
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
- `sessions` (array) : Liste des sessions actives avec détails (hôte, nombre de joueurs, date).
- `total` (int) : Nombre total sur le serveur.

### `NEW_PARTICIPANT`
Diffusé quand un nouveau joueur rejoint la session.
- `session_id` (string)
- `player_id` (string)
- `nickname` (string)

### `PARTICIPANT_LEFT` / `PARTICIPANT_KICKED`
Diffusé quand un joueur quitte ou est expulsé.
- `session_id` (string)
- `player_id` (string)

### `ERROR`
Envoyé en cas d'échec d'une opération.
- `code` (string) : Code d'erreur (ex: `UNAUTHORIZED`, `KEY_ROTATION_REQUIRED`).
- `message` (string) : Description explicative.

### `HISTORY_CLEARED` / `SESSION_ENDED` / `SERVER_RESET`
Signaux de maintenance ou de destruction de session.
