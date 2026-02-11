# Meownopoly Secure Chat Server (Blind Relay)

Ce serveur est un relais "aveugle" (Blind Relay) conçu pour faciliter la communication sécurisée entre les joueurs de Meownopoly. Il assure la persistance et la diffusion de messages chiffrés de bout en bout (E2EE) sans jamais avoir accès au contenu clair des échanges.

## Architecture & Concept

- **Blind Relay** : Le serveur ne stocke que des données chiffrées (payloads) et des métadonnées publiques nécessaires au routage.
- **E2EE (End-to-End Encryption)** : Le chiffrement et le déchiffrement sont effectués exclusivement par les clients.
- **Persistence Asynchrone** : Les messages sont sauvegardés en base de données pour permettre aux joueurs de récupérer l'historique même s'ils se connectent après l'envoi d'un message ("mode seul au monde").
- **Persistence des Participants** : Contrairement aux WebSockets classiques, une déconnexion (internet perdu, fermeture app) ne retire pas l'utilisateur de la session. Il est marqué "offline" mais reste membre. Seule une action explicite (`LEAVE_SESSION` ou `DELETE_SESSION`) le supprime.

## Spécifications Techniques

- **Runtime** : Node.js (v18+)
- **Communication** : WebSockets via `ws`.
- **Base de Données** : SQLite (`better-sqlite3`) pour une performance optimale et une gestion simplifiée.
- **Sécurité & Gestion des Ressources** : 
  - Validation de la taille des messages (max **10 Mo**).
  - Atomicité du Key Package (le premier arrivé définit la clé de session).
  - **Gestion de la Taille DB** : Si la base de données dépasse **500 Mo**, les 50 messages les plus anciens sont automatiquement supprimés.
  - **Nettoyage Temporel (TTL)** : Suppression automatique des messages et sessions inactives après 24 heures (désactivable via `ENABLE_TTL=false`).

## Protocoles WebSocket

### Client -> Serveur
- `JOIN_SESSION` : Rejoint une session de jeu. Renvoie le package de clé et l'historique récent.
- `PUBLISH_KEY` : Publie la clé de session chiffrée (une seule fois par session).
- `SEND_MSG` : Envoie un message chiffré. Il est stocké et diffusé aux autres clients.
- `GET_HISTORY` : Récupère les messages plus anciens (pagination).
- `GET_PARTICIPANTS` : Récupère la liste des membres (avec statut online/offline).
- `LEAVE_SESSION` : Quitte explicitement la session (suppression de la liste + notification aux autres).
- `DELETE_SESSION` : Supprime définitivement la session et déconnecte tous les participants.

### Serveur -> Client
- `INIT_SESSION` : Données initiales reçues après une jointure réussie.
- `NEW_MESSAGE` : Notification en temps réel d'un nouveau message.
- `HISTORY_RESULT` : Liste des messages historiques demandés.
- `PARTICIPANTS_LIST` : Liste des membres avec leur statut.
- `PARTICIPANT_LEFT` : Un membre a quitté explicitement la session (pas lors d'une simple déconnexion).
- `SESSION_ENDED` : La session a été supprimée par un utilisateur.
- `ERROR` : Signalement d'une erreur. Codes possibles : `PAYLOAD_TOO_LARGE`, `INVALID_FORMAT`, `UNKNOWN_COMMAND`, `MAX_SESSIONS_REACHED`, `FORBIDDEN`, **`KEY_ROTATION_REQUIRED`** (envoyé en réponse à `SEND_MSG` lorsqu'un nouveau participant a rejoint ou qu'un participant a quitté la session ; un client doit publier une nouvelle clé via `PUBLISH_KEY` avant d'envoyer des messages).

## Installation et Lancement

1. **Installation des dépendances** :
   ```bash
   npm install
   ```

2. **Lancer le serveur** :
   ```bash
   node server.js
   ```

3. **Lancer le test de vérification** :
   ```bash
   node test_client.js
   ```

4. **Dashboard de visualisation (optionnel)** :
   Pour activer l'interface web de monitoring, définissez la variable d'environnement `ENABLE_DASHBOARD=true` dans votre fichier `.env` :
   ```env
   ENABLE_DASHBOARD=true
   ```
   Le dashboard sera alors accessible sur `http://localhost:3000/dashboard.html`
   
   **Fonctionnalités du dashboard** :
   - Visualisation en temps réel des connexions actives
   - Monitoring des salons de chat
   - Journal d'activité détaillé
   - Statistiques du serveur (uptime, messages, etc.)

## Déploiement (Linux / Nginx)

Un script de configuration automatique est disponible pour déployer le serveur sur Linux avec Nginx en tant que proxy inverse et SSL (Let's Encrypt).

1. **Rendre le script exécutable** :
   ```bash
   chmod +x setup-domain.sh
   ```

2. **Lancer la configuration** :
   ```bash
   sudo ./setup-domain.sh votre-domaine.com
   ```

Le script s'occupera d'installer Nginx, Certbot, de configurer les règles de redirection WebSocket et de créer un service systemd pour que le serveur redémarre automatiquement.

## Structure des Fichiers

- `server.js` : Point d'entrée, gestion des WebSockets et de la logique métier (Sessions, Messages, Participants).
- `database.js` : Abstraction de la base de données SQLite (Gestion des sessions, messages et participants persistants).
- `cleanup.js` : Script de nettoyage automatique (TTL).
- `chat.db` : Fichier de base de données (généré automatiquement).
- `dashboard.html` : Interface web de monitoring (optionnelle).
- `dashboard.css` : Styles du dashboard.
- `dashboard.js` : Logique client du dashboard.

## Variables d'Environnement

Créez un fichier `.env` à la racine du projet pour configurer le serveur :

```env
# Port du serveur
PORT=3000

# Taille maximale des messages (en octets)
MAX_PAYLOAD_SIZE=10485760

# Taille maximale de la base de données (en octets)
MAX_DB_SIZE=524288000

# Mode debug (true/false)
DEBUG_MODE=false

# Activer le nettoyage TTL (true/false)
ENABLE_TTL=true

# Intervalle de nettoyage TTL (en millisecondes)
TTL_INTERVAL_MS=3600000

# Activer le dashboard de monitoring (true/false)
ENABLE_DASHBOARD=false
```
