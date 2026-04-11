# Asset Manager Documentation

## Structure des dossiers
```
{AppDataPath}/assets/
  ├── decoration/
  │   ├── tags.json                 # Tags et descriptions (par catégorie)
  │   ├── grass/
  │   │   ├── metadata.json
  │   │   ├── grass_01.png
  │   │   ├── grass_02.webp
  │   │   └── ...
  │   ├── tree/
  │   │   ├── metadata.json
  │   │   ├── tree_01.png
  │   │   └── ...
  │   └── rock/
  │       ├── metadata.json
  │       └── ...
  ├── background/
  │   ├── bg1.png
  │   ├── bg2.webp
  │   └── ...
  ├── player_icons/
  │   ├── tags.json
  │   ├── metadata.json
  │   ├── avatar1.png
  │   └── ...
  └── ui/
      ├── tags.json
      └── avatar/
          ├── metadata.json
          └── ...

{AppDataPath}/models/
  ├── NomDuPack/
  │   ├── version.json          # {"version": "1.0.0", "timestamp": "..."}
  │   ├── model1.glb
  │   └── textures/
  └── AutrePack/
      └── ...
```

Le chemin de base est `QStandardPaths::AppDataLocation + "/assets/"` par défaut, modifiable via `setAssetsBasePath()`.

## Format du metadata.json
Chaque dossier contenant des assets possède un fichier `metadata.json` généré automatiquement par le `MetadataGenerator` ou manuellement :

```json
{
  "assets": [
    {
      "id": "grass_01",
      "filename": "grass_01.png",
      "extension": "png",
      "width": 100,
      "height": 150,
      "ratioWidth": 2,
      "ratioHeight": 3,
      "animated": false,
      "frameCount": 1
    },
    {
      "id": "grass_02",
      "filename": "grass_02.webp",
      "extension": "webp",
      "width": 200,
      "height": 200,
      "ratioWidth": 1,
      "ratioHeight": 1,
      "animated": true,
      "frameCount": 8
    }
  ]
}
```

### Champs
| Champ | Type | Description |
|-------|------|-------------|
| `id` | string | Identifiant unique (sans extension) |
| `filename` | string | Nom du fichier avec extension |
| `extension` | string | Extension du fichier (png, webp, jpg...). Fallback: extraite du filename, puis "png" |
| `width` | int | Largeur en pixels |
| `height` | int | Hauteur en pixels |
| `ratioWidth` | int | Ratio largeur simplifié (via GCD) |
| `ratioHeight` | int | Ratio hauteur simplifié (via GCD) |
| `animated` | bool | `true` si l'asset est animé (défaut: `false`) |
| `frameCount` | int | Nombre de frames si animé (défaut: `1`) |

## Format du tags.json

Fichier optionnel placé à la racine de chaque **catégorie** (ex: `decoration/tags.json`). Les clés sont au format `"{type}/{filename}"`. Généré par l'outil `image_tools/tagger_images.py` qui utilise Claude pour analyser visuellement les images.

```json
{
  "tree/3.png": {
    "tags": ["arbre", "aquarelle", "jaune", "vert", "rochers", "nature", "feuillage", "tronc", "végétation", "décoratif"],
    "description": "Arbre style aquarelle aux couleurs jaune et vert, posé sur des rochers."
  },
  "grass/1.png": {
    "tags": ["herbe", "vert", "pelouse", "nature", "texture", "gazon", "prairie", "sol", "végétal", "plat"],
    "description": "Touffe d'herbe verte sur fond transparent."
  }
}
```

### Champs
| Champ | Type | Description |
|-------|------|-------------|
| `tags` | string[] | 10 mots-clés décrivant le contenu, le style, les couleurs, l'ambiance |
| `description` | string | Description courte de l'image (max 200 caractères) |

### Chargement
Le `tags.json` est chargé dans `loadCategory()` avant le parcours des types. Pour chaque asset, les tags et la description sont associés via la clé `"{type}/{filename}"` et stockés dans le struct `Asset`.

### Génération
```bash
# Générer les tags pour un dossier d'assets
python image_tools/tagger_images.py ./assets/decoration tags.json --recursive

# Options
#   --recursive, -r       Inclure les sous-dossiers
#   --batch-size N        Nombre d'images par appel CLI (défaut: 5)
#   --workers N           Nombre d'appels CLI en parallèle (défaut: 2)
#   --model MODEL         Modèle Claude à utiliser (défaut: sonnet)
```

## Classe AssetManager

Singleton enregistré en QML via `AssetManager.registerQml()`.

### Caractéristiques principales
- Pas de système de cache d'images (géré par QML)
- Pas de préchargement d'images
- Pas de redimensionnement
- Types et catégories découverts dynamiquement par la structure de dossiers
- Fallback automatique vers `qrc:/asset/nopic.webp` quand un asset n'est pas trouvé
- Cache interne des modèles par clé `{category}_{type}`

### API complète

#### Accès aux assets (méthodes recommandées)

```cpp
// Récupère un asset complet par son ID — retourne QVariantMap
Q_INVOKABLE QVariantMap getAssetById(category, type, id);

// Récupère un asset complet par son nom de fichier — retourne QVariantMap
Q_INVOKABLE QVariantMap getAssetByFilename(category, type, filename);

// Récupère un asset aléatoire — retourne QVariantMap
Q_INVOKABLE QVariantMap getRandomAsset(category, type);
```

Les `QVariantMap` retournés contiennent tous les champs du modèle (voir section "Structure du modèle QML"). Vérifier `if (asset.id)` en QML pour savoir si l'asset a été trouvé.

#### Accès aux chemins

```cpp
// Chemin complet d'un asset par ID (utilise l'extension des métadonnées)
Q_INVOKABLE QString getAssetPath(category, type, id);

// Construit un chemin manuellement : file:///{basePath}/{category}/{type}/{filename}
Q_INVOKABLE QString buildAssetPath(category, type, filename);

// Chemin vers la version animée : {id}-animated.webp
Q_INVOKABLE QString getAnimatedGifPath(category, type, id);

// Chemin vers l'asset de fallback (qrc:/asset/nopic.webp)
Q_INVOKABLE QString getDefaultAssetPath();

// Chemin AppData de l'application
Q_INVOKABLE QString getAppDataPath();
```

#### Modèles pour QML (ListView, GridView, Repeater)

```cpp
// Retourne un AssetModel filtré par catégorie et type (mis en cache)
Q_INVOKABLE AssetModel* getAssetModel(category, type);
```

#### Discovery et validation

```cpp
// Liste les catégories disponibles (ex: ["decoration", "player_icons", "ui"])
Q_INVOKABLE QStringList getAvailableCategories();

// Liste les types d'une catégorie (ex: ["grass", "tree", "rock"])
Q_INVOKABLE QStringList getAvailableTypes(category);

// Liste les backgrounds disponibles (dossier background/, retourne les chemins file:///)
Q_INVOKABLE QStringList getAvailableBackgrounds();

// Liste les modèles 3D disponibles (sous-dossiers de {AppData}/models/)
Q_INVOKABLE QStringList getAvailableModels();

// Vérifie si un asset existe
Q_INVOKABLE bool isAssetValid(category, type, id);

// Scanne et décrit les assets (ex: "decoration/grass (5 images)")
Q_INVOKABLE QStringList scanAvailableAssets();
```

#### Génération de métadonnées

```cpp
// Génère metadata.json pour un répertoire (scanne png, jpg, jpeg, bmp, gif, webp)
Q_INVOKABLE bool generateMetadataForDirectory(directoryPath);

// Génère metadata.json pour tous les répertoires d'assets, puis recharge
Q_INVOKABLE bool generateAllMetadata();
```

#### Chargement et configuration

```cpp
// Charge/recharge tous les assets depuis le basePath
Q_INVOKABLE void loadAssets();
Q_INVOKABLE void reloadAssets();

// Change le chemin de base et recharge
Q_INVOKABLE void setAssetsBasePath(basePath);
```

#### Utilitaires

```cpp
// Vérifie si un pixel est transparent (cache d'images interne)
Q_INVOKABLE bool isTransparent(float px, float py, QString path);
```

### Propriétés QML

| Propriété | Type | Description |
|-----------|------|-------------|
| `categories` | QStringList | Liste des catégories détectées |
| `assetsBasePath` | QString | Chemin de base des assets |

### Structure du modèle QML (AssetModel)

Chaque élément du modèle expose ces rôles :

| Rôle | Type | Description |
|------|------|-------------|
| `path` | string | Chemin complet (`file:///...`) |
| `type` | string | Type d'asset (nom du sous-dossier, ex: "grass", "tree") |
| `category` | string | Catégorie (nom du dossier parent, ex: "decoration") |
| `ratioWidth` | int | Ratio largeur simplifié |
| `ratioHeight` | int | Ratio hauteur simplifié |
| `width` | int | Largeur en pixels |
| `height` | int | Hauteur en pixels |
| `id` | string | Identifiant de l'asset |
| `filename` | string | Nom du fichier |
| `extension` | string | Extension du fichier |
| `animated` | bool | Si l'asset est animé |
| `frameCount` | int | Nombre de frames d'animation |
| `tags` | QStringList | Liste de mots-clés (depuis `tags.json`, vide si absent) |
| `description` | string | Description courte (depuis `tags.json`, vide si absent) |

## Exemples d'utilisation en QML

### Récupérer un asset par ID (recommandé)
```qml
var asset = AssetManager.getAssetById("decoration", "grass", "grass_01")
if (asset.id) {
    myImage.source = asset.path
    myImage.width = asset.width
    myImage.height = asset.height
}
```

### Asset aléatoire
```qml
var randomAsset = AssetManager.getRandomAsset("decoration", "grass")
if (randomAsset.id) {
    decorationParameter.decorationId = randomAsset.id
}
```

### Utiliser un modèle dans une GridView
```qml
GridView {
    model: AssetManager.getAssetModel("decoration", "grass")
    delegate: Image {
        source: model.path
        width: model.width
        height: model.height
    }
}
```

### Naviguer dans les catégories et types
```qml
var categories = AssetManager.getAvailableCategories()
for (var i = 0; i < categories.length; i++) {
    var types = AssetManager.getAvailableTypes(categories[i])
    console.log(categories[i] + ": " + types.join(", "))
}
```

### Générer les métadonnées
```qml
var success = AssetManager.generateAllMetadata()
if (success) {
    console.log("Metadata générées avec succès")
}
```

### Chemin d'un asset spécifique
```qml
Image {
    source: AssetManager.getAssetPath("decoration", "grass", "grass_01")
}
```

### Recherche par tags et description
```qml
// Filtrer les assets visibles dans un Repeater (utilisé dans ASP_Grid)
visible: {
    if (searchText === "") return true

    const searchLower = searchText.toLowerCase()
    const idMatch = (model.id || "").toString().toLowerCase().includes(searchLower)
    const filenameMatch = (model.filename || "").toLowerCase().includes(searchLower)
    const descriptionMatch = (model.description || "").toLowerCase().includes(searchLower)

    let tagsMatch = false
    const tags = model.tags || []
    for (let i = 0; i < tags.length; i++) {
        if (tags[i].toLowerCase().includes(searchLower)) {
            tagsMatch = true
            break
        }
    }

    return idMatch || filenameMatch || descriptionMatch || tagsMatch
}
```

### Accéder aux tags d'un asset
```qml
var asset = AssetManager.getAssetById("decoration", "tree", "3")
if (asset.id) {
    console.log("Tags:", asset.tags)           // ["arbre", "aquarelle", ...]
    console.log("Description:", asset.description) // "Arbre style aquarelle..."
}
```

### Backgrounds disponibles
```qml
ComboBox {
    model: AssetManager.getAvailableBackgrounds()
}
```

## MetadataGenerator

Classe utilitaire (`cpp/tools/metadata_generator.h`) qui scanne les dossiers d'assets et génère les fichiers `metadata.json`.

### Fonctionnement
1. Scanne les fichiers images (png, jpg, jpeg, bmp, gif, webp)
2. Tri naturel des fichiers (1.png, 2.png, 10.png — pas 1, 10, 2)
3. Lecture des dimensions via `QImageReader`
4. Calcul du ratio simplifié via GCD
5. Détection des animations (GIF/WebP multi-frames)
6. Écriture du `metadata.json`

### Formats supportés
- PNG, JPG/JPEG, BMP, GIF, WebP

## Modèles 3D

Les modèles 3D sont gérés séparément des assets 2D, via le `LauncherManager` et le serveur de ressources.

### Format des packs
- Extension : `.meow` (archive compressée)
- Nommage : `{nom}_v{version}.meow` (ex: `PionChat_v1.0.0.meow`)
- Contenu : dossier compressé avec un `model_manifest.json`

### Manifest modèle
```json
{
  "version": "1.0.0",
  "name": "PionChat",
  "type": "model",
  "timestamp": "2025-01-15T10:30:00"
}
```

### Workflow
1. Le launcher récupère la liste des packs via `GET /api/models/list`
2. L'UI affiche les packs avec leur version locale vs serveur
3. Le téléchargement passe par la queue de téléchargement (comme les assets)
4. Après extraction, un `version.json` local est créé pour le suivi

## Notes techniques
- Les types sont déterminés dynamiquement par les noms des dossiers
- Les chemins retournés utilisent le préfixe `file:///` pour QML
- Structure extensible pour de futures catégories d'assets
- Formats d'image supportés : PNG, JPG, JPEG, BMP, GIF, WebP
- Les téléchargements sont vérifiés par checksum SHA-256
- Asset de fallback : `qrc:/asset/nopic.webp` (256x256)
