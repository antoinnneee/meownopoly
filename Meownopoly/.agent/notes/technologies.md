# Technologies Utilisées - Meownopoly

## 🛠 Stack Technique
- **Langages** : C++ (Standard C++20), QML (Qt Quick).
- **Framework** : Qt 6 (Modules : `core`, `quick`, `qml`, `widgets`, `network`, `quick3d`, `quickcontrols2`).
- **Système de Build** : QMake (`Meownopoly.pro`).
- **Plateformes Cibles** : Windows (principal), Android, Unix (QNX).

## 🏗 Architecture
- **Séparation C++/QML** : Utilisation de `Q_PROPERTY`, `Q_INVOKABLE`, et `qmlRegisterType`.
- **Managers (Singletons)** : 
    - `LauncherManager` : Gestion du lancement.
    - `AssetManager` : Chargement et gestion des ressources.
    - `CursorManager` : Acces aux fonction de QCursor depuis QML.
    - `UndoRedoManager` : Gestion de l'historique des actions.
- **Système de Cases** : Architecture hiérarchique pour les cases du plateau (`Case` -> `CaseCatPerks`, `CaseCatDevice`, etc.).

## 🚀 Moteur de Physique (PattounX)
- **Anciennement** : Physics2D.
- **Composants** :
    - `PattounX_engine` : Noyau du moteur.
    - `PattounX_body` : Représentation physique des objets.
    - `PattounX_zone` : Zones d'influence physique (gravité, friction, etc.).
    - `Collision2D` : Gestionnaire de détection de collisions (incluant le balayage/swept collision).

## 🎨 Interface & Assets
- **Style** : Thème personnalisé "MeowStyle".
- **Asset System** : 
    - Format personnalisé `.meow` (archives compressées).
    - Utilisation de `FolderCompressor` pour la gestion des archives.
    - Système de métadonnées pour les assets graphiques.
- **Éditeur de Cartes** : UI complexe en QML pour la création de niveaux.

## 💾 Données & Persistance
- **Formats** : JSON et CSV pour les configurations et les cartes.
- **Ressources** : Intégrées via `.qrc` (Qt Resource System).

## 🛠 Outils & Debug
- **Logger** : Système de log personnalisé (`tools/logger.h`).
- **Debug Info** : Macros et outils de visualisation pour le développement.
- **Tests** : Dossier `qml/test/` contenant des scènes de test pour chaque composant.
