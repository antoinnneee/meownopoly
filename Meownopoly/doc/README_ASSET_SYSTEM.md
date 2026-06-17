# Système d'Asset Manager - Meownopoly

## Vue d'ensemble

Le système AssetManager implémente une gestion centralisée des ressources graphiques pour Meownopoly, basé sur la spécification décrite dans `doc/architecture/ASSET_MANAGER.md`.

## Caractéristiques

✅ **Implémenté :**
- Classe AssetManager C++ avec singleton pattern
- Modèles QML pour les assets (AssetModel)
- Support des catégories : décorations et icônes de joueur
- Filtrage par type d'asset
- Interface QML pour accès direct aux assets
- Chargement automatique des métadonnées JSON
- Intégration avec l'architecture Qt/QML existante

## Architecture

### Classes C++
- `AssetManager` : Gestionnaire principal, singleton
- `AssetModel` : Modèle QML héritant de QAbstractListModel

### Structure des Données
Le chargement est strictement à **deux niveaux** : `loadCategory()` parcourt les sous-dossiers de *type* (asset_manager.cpp:499-504) et `loadTypeFromDirectory()` lit le `metadata.json` situé à l'intérieur de chaque dossier de type (asset_manager.cpp:510-516). Un `metadata.json` placé directement à la racine d'une catégorie n'est jamais chargé. Le seul fichier lu au niveau catégorie est `tags.json` (asset_manager.cpp:479, optionnel).

```
assets/
├── decoration/
│   ├── tags.json          (optionnel, niveau catégorie)
│   ├── grass/
│   │   ├── metadata.json
│   │   └── *.png
│   └── tree/
│       ├── metadata.json
│       └── *.png
└── player_icons/
    ├── tags.json          (optionnel, niveau catégorie)
    └── <type>/
        ├── metadata.json
        └── *.png
```

## Utilisation

### Depuis QML
```qml
// Modèle filtré (catégorie + type)
ListView {
    model: AssetManager.getAssetModel("decoration", "grass")
}

// Accès direct au chemin d'un asset
Image {
    source: AssetManager.getAssetPath("decoration", "grass", "1")
}
```

### API Principale
- `getAssetModel(category, type)` : Modèle filtré (catégorie + type) pour ListView/GridView
- `getAssetPath(category, type, id)` : Chemin direct vers un asset
- `loadAssets()` : Recharge tous les assets
- `setAssetsBasePath(path)` : Change le chemin de base

## Tests et Démo

### Interface de Test
Accessible via le bouton "🎨 Asset Manager Test" dans l'écran titre :
- Affiche tous les assets chargés
- Teste les modèles filtrés
- Montre l'accès direct aux paths
- Bouton de rechargement

### Composant AssetSelectionPanel
La sélection d'assets de l'éditeur est portée par `AssetSelectionPanel.qml` et ses sous-composants `ASP_*` (`ASP_CategoryGrid.qml`, `ASP_Grid.qml`, `ASP_Item.qml`, etc.), sous `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/` :
- Sélection de catégorie et type
- Grille d'aperçu des assets
- Sélection interactive

### Intégration Éditeur
Le composant `SnapableDecoration.qml` utilise maintenant l'AssetManager avec fallback vers l'ancien système.

## Installation

1. Compilez le projet dans Qt Creator
2. Les assets sont chargés depuis `<AppData>/assets/` (chemin défini dans le constructeur d'AssetManager, asset_manager.cpp:153). Placez-y vos catégories/types ou appelez `AssetManager.setAssetsBasePath(...)`.
3. Lancez l'application et testez via "🎨 Asset Manager Test"

## Extensibilité

Pour ajouter de nouveaux types d'assets :
1. Créez le dossier approprié dans la structure
2. Ajoutez un `metadata.json` avec les métadonnées
3. Placez les fichiers PNG
4. Appelez `AssetManager.loadAssets()`

## Notes Techniques

- Pas de cache manuel (géré par QML)
- Pas de préchargement
- Types déterminés dynamiquement par les noms de dossiers
- Support des chemins file:/// pour les assets locaux
- Modèles thread-safe avec QAbstractListModel
