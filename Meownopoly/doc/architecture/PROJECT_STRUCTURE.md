# 🐾 Structure du Projet Meownopoly

## Vue d'ensemble

Meownopoly est organisé selon une architecture modulaire qui sépare la logique de jeu (C++) et l'interface utilisateur (QML). Ce document explique la structure du code, les conventions et l'organisation des fichiers pour faciliter la compréhension du projet.

## Hiérarchie des dossiers

```
Meownopoly/
├── cpp/                     # Code source C++
│   ├── communication/       # Communication réseaux (Catway, UDP)
│   ├── chat/                # Client Chat WebSocket
│   ├── game/                # Logique de jeu principale
│   │   ├── case/            # Classes des différents types de cases
│   │   ├── item_snapable/   # Éléments plaçables dans l'éditeur
│   │   ├── map/             # Gestion et chargement des cartes
│   │   └── physics/         # Moteur physique et zones
│   ├── launcher/            # Logique du lanceur
│   └── tools/               # Outil globaux (MouseEventFilter, Logger, etc.)
├── qml/                     # Interface utilisateur QML
│   ├── case/            # Représentation visuelle des cases
│   ├── chat/            # Interface du chat et des participants
│   ├── editor/          # Éditeur de cartes complet
│   ├── launcher/        # Interface du lanceur
│   ├── menu/            # Menu principal
│   └── meowComponent/   # Composants réutilisables (Base_Board, Grid, etc.)
└── config/              # Fichiers de configuration
```

## Modules Principaux

### 1. Système de Cases (dossier `cpp/game/case/`)

Ce module définit tous les types de cases du jeu avec une hiérarchie d'héritage claire :

```
Case (classe de base abstraite)
├── CaseCatPerks
│   ├── CaseRestArea
│   └── ...
├── CaseCatDevice
├── CaseCatDoor
├── ...
```

**Fichiers importants :**
- `Case.h/cpp` : Classe de base abstraite pour toutes les cases
- `CaseX.h/cpp` : Implémentations spécifiques (où X est le type de case)

### 2. Éléments "Snapable" (dossier `cpp/game/item_snapable/`)

Ces classes représentent les éléments qui peuvent être placés sur la grille de l'éditeur.

**Classes principales :**
- `ItemSnapable` : Classe de base pour tous les éléments plaçables
- `SnapableCase` : Élément représentant une case sur la grille
- `SnapableDeco` : Élément représentant une décoration

### 3. Système de Maps (dossier `cpp/game/map/`)

Gère le chargement, la sauvegarde et la structure des cartes de jeu.

**Composants importants :**
- `map.h/cpp` : Définit la structure d'une carte
- `mapinfo.h/cpp` : Métadonnées d'une carte (nom, auteur, etc.)
- `maploader.h/cpp` : Chargement/sauvegarde des cartes depuis/vers JSON

### 4. Interface QML (dossier `qml/`)

L'interface utilisateur est organisée en plusieurs sections :

#### Interface de Jeu & État global
- `Editor.qml` : Interface principale de l'éditeur intégré
- `meowComponent/` : ⭐ Cœur visuel (Base_Board, Base_WorkArea, GridManager)

#### Éditeur de Cartes (`qml/editor/`)
- `Editor.qml` : Point d'entrée
- `panel/` : Panneaux de configuration (`SelectionPanel`, `SidePanel`)
- `logic/` : Logiques modulaires (`MouseLogic`, `TileLogic`, `ScrollLogic`)

### 4. Communication & Réseau (dossier `cpp/communication/`)

Ce module gère toute la couche réseau P2P entre les joueurs.

**Composants clés :**
- `Catway.h/cpp` : ⭐ Cœur du système réseau. Gère les sockets UDP, les requêtes STUN et orchestre le **Hole Punching**.
- `StunManager.h/cpp` : Gère l'interaction avec les serveurs STUN pour récupérer l'IP publique.
- `PlayerNetwork.h/cpp` : Représente un joueur distant avec ses informations de connexion UDP. Expose aussi `stats()` pour les compteurs reliable.io (RTT, loss, bandwidth).
- `chat/chat_client.h/cpp` : Client WebSocket pour les messages de chat et le signalement P2P. Gère aussi `RENAME_SESSION` et le handler de `SESSION_DELETED` pour la migration d'hôte.

**Flux de connexion (Hole Punching) :**
1. Signalement via le serveur de Chat (WebSocket).
2. Récupération des IPs publiques via STUN.
3. Échange de requêtes de "Punch" UDP pour ouvrir les pare-feu.
4. Passage en communication UDP directe une fois le lien établi.

### 4b. Session de jeu et d'édition (dossiers `cpp/game/network/`, `cpp/editor/network/`, `cpp/editor/ops/`)

Couche au-dessus de Catway qui formalise le protocole applicatif.

**Composants clés :**
- `cpp/game/network/` : `GameSession`, `GameProtocol`, `GameMessageType` (frame `0x01–0x11`).
- `cpp/editor/network/` : `EditorSession`, `EditorProtocol`, `EditorMessageType` (frame `0x20+`). Coexiste avec GameSession sur le même canal Catway (filtrage par plage de type-byte). Implémente le rate-limit par sender, le chunking d'ops > 20 KB, la détection de timeout d'hôte (élection déterministe, `promoteToHost`), le roster broadcast.
- `cpp/editor/ops/` : `EditorOpBus` (chokepoint unique des mutations, pile d'undo, rate-limit local), `EditorOpType` (enum des ops : Create/Delete/Move/Resize/Set*/Link/Unlink).

Voir [COLLABORATIVE_EDITOR.md](./COLLABORATIVE_EDITOR.md) pour le détail complet.

### 5. interface QML (dossier `qml/`)

### Communication C++/QML

L'architecture utilise plusieurs mécanismes pour exposer les fonctionnalités C++ à QML :

1. **Enregistrement de types :** Classes C++ exposées à QML via `qmlRegisterType` (ex: `Game`, `MapFileManager`)
2. **Propriétés :** Utilisation intensive de `Q_PROPERTY` pour l'exposition bidirectionnelle des données
3. **Invokables :** Méthodes C++ appelables depuis QML avec `Q_INVOKABLE`
4. **Singletons QML :** Plusieurs modules sont exposés comme des singletons accessibles partout (ex: `UiStyle`, `MapInfo`)

## Système de Construction

### CMake
Le projet utilise **CMake** comme système de construction principal pour gérer les dépendances Qt, les fichiers QML et les ressources.

## Conventions de Codage

### Nommage
- **Classes :** PascalCase (`ItemSnapable`, `CaseCatDoor`)
- **Méthodes :** camelCase (`getAssetPath()`, `loadMap()`)
- **Fichiers QML :** PascalCase.qml (`Editor.qml`, `LauncherHeader.qml`)

## Conclusion

Cette structure de projet modulaire permet une évolution et une maintenance efficaces, notamment grâce à la séparation stricte entre la logique métier riche en C++ et la flexibilité visuelle de QML.

---

**Date** : 25 février 2026  
**Version** : 1.3
