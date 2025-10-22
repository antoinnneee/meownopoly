# Système d'Asset Manager - Meownopoly

## Vue d'ensemble

Le système AssetManager implémente une gestion centralisée des ressources graphiques pour Meownopoly, basé sur la spécification décrite dans `doc/ASSET_MANAGER.md`.

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
```
assets/
├── decoration/
│   ├── grass/
│   │   ├── metadata.json
│   │   └── *.png
│   └── tree/
│       ├── metadata.json
│       └── *.png
└── player_icons/
    ├── metadata.json
    └── *.png
```

## Utilisation

### Depuis QML
```qml
// Accès aux modèles
ListView {
    model: AssetManager.decorationModel
    // ou AssetManager.playerIconModel
}

// Modèles filtrés
ListView {
    model: AssetManager.getTypeModel("decoration", "grass")
}

// Accès direct
Image {
    source: AssetManager.getDecorationPath("grass", "1")
}
```

### API Principale
- `decorationModel` : Modèle de toutes les décorations
- `playerIconModel` : Modèle de toutes les icônes de joueur
- `getTypeModel(category, type)` : Modèle filtré par type
- `getDecorationPath(type, id)` : Chemin direct vers une décoration
- `getPlayerIconPath(id)` : Chemin direct vers une icône
- `loadAssets()` : Recharge tous les assets
- `setAssetsBasePath(path)` : Change le chemin de base

## Tests et Démo

### Interface de Test
Accessible via le bouton "🎨 Asset Manager Test" dans l'écran titre :
- Affiche tous les assets chargés
- Teste les modèles filtrés
- Montre l'accès direct aux paths
- Bouton de rechargement

### Composant AssetSelector
Nouveau composant `AssetSelector.qml` pour l'éditeur :
- Sélection de catégorie et type
- Grille d'aperçu des assets
- Sélection interactive

### Intégration Éditeur
Le composant `SnapableDecoration.qml` utilise maintenant l'AssetManager avec fallback vers l'ancien système.

## Installation

1. Compilez le projet dans Qt Creator
2. Exécutez `copy_test_assets.bat` pour copier les assets de test
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
