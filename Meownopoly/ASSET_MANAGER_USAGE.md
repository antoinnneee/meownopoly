# Guide d'utilisation de l'Asset Manager

## Installation et Configuration

### 1. Compilation
Le système AssetManager est maintenant intégré dans le projet. Pour compiler :
- Ouvrez le projet dans Qt Creator
- Compilez normalement (Ctrl+B)

### 2. Structure des Assets
Créez la structure suivante dans votre dossier de build ou d'assets :

```
asset_extracted/
├── decoration/
│   ├── grass/
│   │   ├── metadata.json
│   │   ├── 1.png
│   │   ├── 2.png
│   │   └── 3.png
│   └── tree/
│       ├── metadata.json
│       ├── 1.png
│       └── 2.png
└── player_icons/
    ├── metadata.json
    ├── 1.png
    ├── 2.png
    ├── 3.png
    └── 4.png
```

### 3. Copie des Assets de Test
Exécutez le script `copy_test_assets.bat` pour copier les assets existants dans la nouvelle structure.

## Utilisation en QML

### 1. Accès aux Modèles Complets
```qml
// Toutes les décorations
ListView {
    model: AssetManager.decorationModel
    delegate: Image {
        source: model.path
        width: model.width
        height: model.height
    }
}

// Toutes les icônes de joueur
ListView {
    model: AssetManager.playerIconModel
    delegate: Image {
        source: model.path
        width: model.width
        height: model.height
    }
}
```

### 2. Accès aux Modèles Filtrés
```qml
// Seulement les décorations de type "grass"
ListView {
    model: AssetManager.getTypeModel("decoration", "grass")
    delegate: Image {
        source: model.path
    }
}

// Seulement les décorations de type "tree"
ListView {
    model: AssetManager.getTypeModel("decoration", "tree")
    delegate: Image {
        source: model.path
    }
}
```

### 3. Accès Direct aux Assets
```qml
// Asset de décoration spécifique
Image {
    source: AssetManager.getDecorationPath("grass", "1")
}

// Icône de joueur spécifique
Image {
    source: AssetManager.getPlayerIconPath("3")
}
```

### 4. Rechargement des Assets
```qml
Button {
    text: "Reload Assets"
    onClicked: AssetManager.loadAssets()
}
```

## Propriétés du Modèle

Chaque élément des modèles contient :
- `path` : Chemin complet vers l'image (avec file:///)
- `type` : Type d'asset (ex: "grass", "tree")
- `category` : Catégorie d'asset ("decoration", "player_icons")
- `ratio` : Ratio largeur/hauteur
- `width` : Largeur de l'image
- `height` : Hauteur de l'image
- `id` : Identifiant de l'asset
- `filename` : Nom du fichier

## Tests

### Interface de Test
Utilisez le bouton "🎨 Asset Manager Test" dans l'écran titre pour accéder à l'interface de test qui montre :
- Tous les assets de décoration
- Assets filtrés par type (grass seulement)
- Toutes les icônes de joueur
- Tests d'accès direct aux paths

### Composant AssetSelector
Le composant `AssetSelector.qml` dans l'éditeur permet de :
- Sélectionner une catégorie d'assets
- Filtrer par type (pour les décorations)
- Choisir un asset spécifique
- Voir un aperçu en temps réel

## Intégration dans l'Éditeur

Le composant `SnapableDecoration.qml` a été mis à jour pour utiliser l'AssetManager :
```qml
SnapableDecoration {
    decorationType: "grass"  // ou "tree"
    decorationId: "2"        // ID de l'asset
}
```

## Ajout de Nouveaux Types d'Assets

### Méthode Automatique (Recommandée)
1. Créez un nouveau dossier dans `asset_extracted/decoration/` ou `asset_extracted/player_icons/`
2. Placez vos images PNG/JPG dans le dossier
3. Utilisez l'interface de génération de metadata :
   - Dans l'app : "🎨 Asset Manager Test" → "📝 Generate All Metadata"
   - Ou via script : `setup_test_assets.bat`
4. Le fichier `metadata.json` sera généré automatiquement avec les bonnes dimensions

### Méthode Manuelle
1. Créez un nouveau dossier dans `asset_extracted/decoration/`
2. Ajoutez un fichier `metadata.json` avec la structure appropriée
3. Placez vos images PNG dans le dossier
4. Appelez `AssetManager.loadAssets()` pour recharger

## Génération Automatique de Metadata

### Via l'Interface QML
Dans l'application, allez à "🎨 Asset Manager Test" :
1. **Scan Assets** : Affiche tous les dossiers contenant des images
2. **Generate All Metadata** : Génère les metadata.json pour tous les dossiers
3. **Reload Assets** : Recharge les assets après génération

### API de Génération
```qml
// Scanner les assets disponibles
var availableAssets = AssetManager.scanAvailableAssets()

// Générer metadata pour un dossier spécifique
var success = AssetManager.generateMetadataForDirectory("/path/to/directory")

// Générer metadata pour tous les dossiers
var success = AssetManager.generateAllMetadata()
```

### Script de Configuration
Exécutez `setup_test_assets.bat` pour :
1. Copier les assets existants dans la nouvelle structure
2. Supprimer les anciens metadata.json
3. Préparer les tests de génération automatique

## Debugging

L'AssetManager affiche des logs de debug dans la console Qt :
- Chemin de base des assets
- Nombre d'assets chargés par catégorie
- Erreurs de chargement des metadata.json
