# Meownopoly Secure Chat Server (Blind Relay)

Ce serveur est un relais "aveugle" (Blind Relay) conçu pour faciliter la communication sécurisée entre les joueurs de Meownopoly. Il assure la persistance et la diffusion de messages chiffrés de bout en bout (E2EE) sans jamais avoir accès au contenu clair des échanges.

## Architecture & Concept

- **Blind Relay** : Le serveur ne stocke que des données chiffrées (payloads) et des métadonnées publiques nécessaires au routage.
- **E2EE (End-to-End Encryption)** : Le chiffrement et le déchiffrement sont effectués exclusivement par les clients.
- **Persistence Asynchrone** : Les messages sont sauvegardés en base de données pour permettre aux joueurs de récupérer l'historique même s'ils se connectent après l'envoi d'un message ("mode seul au monde").

## Spécifications Techniques

- **Runtime** : Node.js (v18+)
- **Communication** : WebSockets via `ws`.
- **Base de Données** : SQLite (`better-sqlite3`) pour une performance optimale et une gestion simplifiée.
- **Sécurité** : 
  - Validation de la taille des messages (max 128 Ko).
  - Atomicité du Key Package (le premier arrivé définit la clé de session).
  - TTL (Time To Live) : Suppression automatique des messages et sessions après 24 heures.

## Protocoles WebSocket

### Client -> Serveur
- `JOIN_SESSION` : Rejoint une session de jeu. Renvoie le package de clé et l'historique récent.
- `PUBLISH_KEY` : Publie la clé de session chiffrée (une seule fois par session).
- `SEND_MSG` : Envoie un message chiffré. Il est stocké et diffusé aux autres clients.
- `GET_HISTORY` : Récupère les messages plus anciens (pagination).

### Serveur -> Client
- `INIT_SESSION` : Données initiales reçues après une jointure réussie.
- `NEW_MESSAGE` : Notification en temps réel d'un nouveau message.
- `HISTORY_RESULT` : Liste des messages historiques demandés.
- `ERROR` : Signalement d'une erreur (ex: payload trop gros).

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

## Structure des Fichiers

- `server.js` : Point d'entrée, gestion des WebSockets et de la logique métier.
- `database.js` : Abstraction de la base de données SQLite.
- `cleanup.js` : Script de nettoyage automatique (TTL).
- `chat.db` : Fichier de base de données (généré automatiquement).
