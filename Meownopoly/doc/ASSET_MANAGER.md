# Asset Manager Documentation

## Structure des dossiers
```
assets/
  ├── decoration/
  │   ├── grass/
  │   │   ├── metadata.json
  │   │   ├── 1.png
  │   │   ├── 2.png
  │   │   └── ...
  │   └── tree/
  │       ├── metadata.json
  │       ├── 1.png
  │       ├── 2.png
  │       └── ...
  └── player_icons/
      ├── metadata.json
      ├── 1.png
      ├── 2.png
      └── ...
```

## Format du metadata.json
Chaque dossier contenant des assets aura son propre fichier metadata.json :

```json
{
  "assets": [
    {
      "id": "1",
      "filename": "1.png",
      "ratio": 1.5,
      "width": 100,
      "height": 150
    },
    {
      "id": "2",
      "filename": "2.png",
      "ratio": 1.0,
      "width": 200,
      "height": 200
    }
  ]
}
```

## Classe AssetManager

### Caractéristiques principales
- Pas de système de cache (géré par QML)
- Pas de préchargement
- Pas de redimensionnement
- Pas de gestion mémoire manuelle
- Types d'assets basés sur les noms de dossiers (pas d'énumération)

### Fonctionnalités
1. **Lecture des métadonnées**
   - Chargement des fichiers metadata.json
   - Construction des modèles pour QML

2. **Interface pour QML**
   - Accès aux modèles d'assets par catégorie
   - Accès aux métadonnées individuelles
   - Résolution des chemins d'images
   - Filtrage des modèles par type

3. **Filtrage des assets**
   - Génération de modèles filtrés par type
   - Accès rapide aux assets d'un type spécifique

### Exemple d'utilisation en QML
```qml
// Utilisation du modèle complet de décorations
ListView {
    model: AssetManager.decorationModel
    delegate: Image {
        source: model.path
        width: model.width
        height: model.height
    }
}

// Utilisation du modèle filtré pour les arbres uniquement
ListView {
    model: AssetManager.getTypeModel("decoration", "tree")
    delegate: Image {
        source: model.path
        width: model.width
        height: model.height
    }
}

// Accès à une décoration spécifique
Image {
    source: AssetManager.getDecorationPath("grass", "1")
}
```

### Structure du modèle QML
Chaque élément du modèle contient :
- `path` : Chemin complet vers l'image
- `type` : Type d'asset (nom du dossier parent, ex: "grass", "tree")
- `category` : Catégorie d'asset ("decoration", "player_icon")
- `ratio` : Ratio largeur/hauteur
- `width` : Largeur de l'image
- `height` : Hauteur de l'image
- `id` : Identifiant de l'asset
- `filename` : Nom du fichier

## Catégories actuelles
1. **Décorations** (`decoration/`)
   - grass
   - tree

2. **Icônes de joueur** (`player_icons/`)

## Notes importantes
- Les types sont déterminés dynamiquement par les noms des dossiers
- Pas de hachage ni de date de modification
- Structure extensible pour de futures catégories d'assets
- Pas de validation de format d'image (supposé PNG)
