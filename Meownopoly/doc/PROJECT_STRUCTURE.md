# 🐾 Structure du Projet Meownopoly

## Vue d'ensemble

Meownopoly est organisé selon une architecture modulaire qui sépare la logique de jeu (C++) et l'interface utilisateur (QML). Ce document explique la structure du code, les conventions et l'organisation des fichiers pour faciliter la compréhension du projet.

## Hiérarchie des dossiers

```
Meownopoly/
├── asset_manager.cpp/h   # Système de gestion des ressources
├── case/                # Classes représentant les différents types de cases
├── config/              # Fichiers de configuration (JSON, CSV)
├── doc/                 # Documentation du projet
├── item_snapable/       # Éléments plaçables dans l'éditeur
├── map/                 # Gestion et chargement des cartes de jeu
├── qml/                 # Interface utilisateur QML
│   ├── case/            # Représentation visuelle des cases
│   ├── editor/          # Éditeur de cartes
│   ├── launcher/        # Interface du lanceur
│   ├── menu/            # Menu principal et navigation
│   ├── test/            # Tests QML et exemples
│   └── titleScreen/     # Écran titre du jeu
├── QtFolderCompressor/  # Bibliothèque de compression/décompression
└── tools/               # Outils et utilitaires
```

## Modules Principaux

### 1. Système de Cases (dossier `case/`)

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

### 2. Éléments "Snapable" (dossier `item_snapable/`)

Ces classes représentent les éléments qui peuvent être placés sur la grille de l'éditeur.

**Classes principales :**
- `ItemSnapable` : Classe de base pour tous les éléments plaçables
- `SnapableCase` : Élément représentant une case sur la grille
- `SnapableDeco` : Élément représentant une décoration

### 3. Système de Maps (dossier `map/`)

Gère le chargement, la sauvegarde et la structure des cartes de jeu.

**Composants importants :**
- `map.h/cpp` : Définit la structure d'une carte
- `mapinfo.h/cpp` : Métadonnées d'une carte (nom, auteur, etc.)
- `maploader.h/cpp` : Chargement/sauvegarde des cartes depuis/vers JSON

### 4. Interface QML (dossier `qml/`)

L'interface utilisateur est organisée en plusieurs sections :

#### Interface de Jeu
- `main.qml` : Point d'entrée principal de l'application QML
- `titleScreen/` : Écran titre et menu de démarrage

#### Éditeur de Cartes
- `editor/Editor.qml` : Interface principale de l'éditeur
- `editor/panel/` : Panneaux et contrôles de l'éditeur
- `editor/tools/` : Outils de l'éditeur (placement, sélection, etc.)

#### Représentation des Cases
- `case/CaseTile.qml` : Représentation visuelle d'une case
- `case/content/` : Contenu visuel spécifique à chaque type de case
- `case/details/` : Popups de détails des cases

#### Launcher
- `launcher/Launcher.qml` : Interface du launcher
- `launcher/LauncherLogic.qml` : Logique de liaison QML/C++

### 5. Gestionnaire d'Assets (fichiers `asset_manager.h/cpp`)

Système central de gestion des ressources graphiques avec prise en charge des métadonnées.

**Fonctionnalités principales :**
- Chargement des assets depuis les fichiers
- Organisation par catégorie et type
- Exposition des modèles pour QML
- Gestion des métadonnées (ratio, dimensions, etc.)

### 6. Serveur de Ressources

Architecture client-serveur pour la distribution des ressources du jeu :

- Le launcher agit comme client
- Un serveur dédié stocke et distribue les packages d'assets
- Communication via API REST

## Architecture C++/QML

### Communication C++/QML

L'architecture utilise plusieurs mécanismes pour exposer les fonctionnalités C++ à QML :

1. **Enregistrement de types :** Classes C++ exposées à QML via `qmlRegisterType` et `qmlRegisterUncreatableType`
2. **Propriétés :** Utilisation intensive de `Q_PROPERTY` pour l'exposition bidirectionnelle des données
3. **Invokables :** Méthodes C++ appelables depuis QML avec `Q_INVOKABLE`
4. **Signaux et slots :** Communication événementielle entre C++ et QML

### Singleton Pattern

Plusieurs composants utilisent le pattern singleton pour un accès global et cohérent :

```cpp
// Exemple d'implémentation d'un singleton
class LauncherManager : public QObject {
    Q_OBJECT
public:
    static LauncherManager* instance();
    // ...
private:
    LauncherManager();
    static LauncherManager* m_instance;
};
```

## Système de Construction et Déploiement

### Fichiers de Projet
- `Meownopoly.pro` : Fichier principal du projet Qt
- `.qrc` : Fichiers de ressources Qt (qml.qrc, config.qrc, etc.)

### Assets
- `build/assets_v*.meow` : Packages d'assets compressés
- `build/asset_extracted/` : Assets décompressés pour le développement

## Conventions de Codage

### Nommage
- **Classes :** PascalCase (`ItemSnapable`, `CaseCatDoor`)
- **Méthodes :** camelCase (`getAssetPath()`, `loadMap()`)
- **Fichiers QML :** PascalCase.qml (`Editor.qml`, `LauncherHeader.qml`)
- **Propriétés QML :** camelCase (`unitSize`, `effectBrightness`)

### Organisation des Fichiers QML
- Un composant par fichier
- Imports au début du fichier
- Propriétés, signaux puis méthodes
- Sous-composants à la fin

### Structure des Classes C++
- Header (.h) et implémentation (.cpp) séparés
- Macro Q_OBJECT pour les classes QObject
- Propriétés exposées en haut de la classe
- Inclusion des dépendances minimisée

## Outils de Développement

### Génération de Métadonnées
Le système utilise un générateur de métadonnées pour les assets (`tools/metadata_generator.cpp`).

### Tests et Débogage
- `qml/test/` : Fichiers QML de test pour les fonctionnalités individuelles
- `debug_info.h` : Macros et fonctions utilitaires pour le débogage

## Flux de Travail Typiques

### Ajout d'un Nouveau Type de Case

1. Créer une sous-classe de `Case` ou d'une classe dérivée appropriée
2. Implémenter les méthodes virtuelles requises
3. Enregistrer la classe dans `game.cpp` via `qmlRegisterType`
4. Créer un composant QML correspondant dans `qml/case/content/`
5. Mettre à jour les fichiers de configuration dans `config/`

### Ajout d'une Nouvelle Fonctionnalité UI

1. Créer un nouveau composant QML dans le dossier approprié
2. Intégrer le composant dans la hiérarchie existante
3. Ajouter les propriétés et signaux nécessaires
4. Implémenter la logique en JavaScript QML ou en C++
5. Créer un fichier de test dans `qml/test/` pour valider

## Conclusion

Cette structure de projet modulaire permet une évolution et une maintenance efficaces. La séparation claire entre la logique C++ et l'interface QML facilite le développement parallèle et les tests unitaires.

Pour plus d'informations sur des composants spécifiques, consultez les autres documents de la documentation.

