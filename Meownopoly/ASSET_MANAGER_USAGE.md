# Guide d'utilisation de l'AssetManager

## Vue d'ensemble

L'AssetManager gère les assets organisés selon cette structure :
```
asset_extracted/
  ├── category1/
  │   ├── type1/
  │   │   ├── metadata.json
  │   │   ├── asset1.png
  │   │   └── asset2.webp
  │   └── type2/
  │       ├── metadata.json
  │       └── asset3.jpg
  └── category2/
      └── type3/
          ├── metadata.json
          └── asset4.png
```

## Structure Asset

Les méthodes `getAssetById()` et `getAssetByFilename()` retournent un **QVariantMap** (objet JavaScript en QML) contenant :

```javascript
// En QML, vous accédez aux champs comme ceci :
{
    path: "file:///...",           // Chemin complet de l'asset
    type: "grass",                 // Type de l'asset
    category: "decoration",        // Catégorie
    ratioWidth: 1,                 // Ratio largeur (simplifié)
    ratioHeight: 1,                // Ratio hauteur (simplifié)
    width: 256,                    // Largeur en pixels
    height: 256,                   // Hauteur en pixels
    id: "grass_01",                // Identifiant unique (sans extension)
    filename: "grass_01.png",      // Nom du fichier avec extension
    extension: "png",              // Extension du fichier (png, jpg, webp, etc.)
    animated: false,               // true si l'asset est animé (WebP animé, GIF)
    frameCount: 1                  // Nombre de frames (1 pour image statique)
}
```

En C++, c'est un `QVariantMap` :
```cpp
QVariantMap asset = AssetManager::instance()->getAssetById(...);
QString path = asset["path"].toString();
int width = asset["width"].toInt();
bool animated = asset["animated"].toBool();
int frameCount = asset["frameCount"].toInt();
```

## Méthodes principales

### 1. Récupérer un asset complet (RECOMMANDÉ)

#### Par ID (le plus courant)
```cpp
// C++
QVariantMap asset = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");
if (!asset["id"].toString().isEmpty()) {
    qDebug() << "Path:" << asset["path"].toString();
    qDebug() << "Extension:" << asset["extension"].toString();
    qDebug() << "Size:" << asset["width"].toInt() << "x" << asset["height"].toInt();
}

// QML (RECOMMANDÉ)
var asset = AssetManager.getAssetById("decoration", "grass", "grass_01")
if (asset.id) {
    console.log("Path:", asset.path)
    console.log("Extension:", asset.extension)
    console.log("Size:", asset.width, "x", asset.height)
}
```

#### Par nom de fichier
```cpp
// C++
QVariantMap asset = AssetManager::instance()->getAssetByFilename("decoration", "grass", "grass_01.png");

// QML
var asset = AssetManager.getAssetByFilename("decoration", "grass", "grass_01.png")
if (asset.id) {
    image.source = asset.path
}
```

### 2. Récupérer seulement le chemin d'un asset

```cpp
// C++
QString path = AssetManager::instance()->getAssetPath("decoration", "grass", "grass_01");
// Retourne: "file:///path/to/asset_extracted/decoration/grass/grass_01.png"

// QML
var path = AssetManager.getAssetPath("decoration", "grass", "grass_01")
```

### 4. Travailler avec un modèle (pour ListView, Repeater, etc.)

```qml
// QML - Récupérer le modèle
property var grassModel: AssetManager.getAssetModel("decoration", "grass")

ListView {
    model: grassModel
    delegate: Item {
        // Accès direct aux rôles
        Image {
            source: model.path
        }
        Text {
            text: model.id + " (" + model.extension + ")"
        }
        Text {
            text: model.width + "x" + model.height
        }
    }
}
```

### 5. Vérifier si un asset existe

```cpp
// C++
bool exists = AssetManager::instance()->isAssetValid("decoration", "grass", "grass_01");

// QML
var exists = AssetManager.isAssetValid("decoration", "grass", "grass_01")
```

### 6. Lister les catégories et types disponibles

```cpp
// C++
QStringList categories = AssetManager::instance()->getAvailableCategories();
QStringList types = AssetManager::instance()->getAvailableTypes("decoration");

// QML
var categories = AssetManager.getAvailableCategories()
var types = AssetManager.getAvailableTypes("decoration")
```

## Génération de métadonnées

### Générer pour un répertoire spécifique
```cpp
AssetManager::instance()->generateMetadataForDirectory("asset_extracted/decoration/grass");
```

### Générer pour tous les assets
```cpp
AssetManager::instance()->generateAllMetadata();
```

Le fichier `metadata.json` généré contient :
```json
{
    "assets": [
        {
            "id": "grass_01",
            "filename": "grass_01.png",
            "extension": "png",
            "ratioWidth": 1,
            "ratioHeight": 1,
            "width": 256,
            "height": 256
        }
    ]
}
```

## Cas d'usage typiques

### Afficher un asset dans QML
```qml
Image {
    source: AssetManager.getAssetPath("decoration", "grass", "grass_01")
}
```

### Charger un asset avec métadonnées en C++
```cpp
Asset asset = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");
if (!asset.id.isEmpty()) {
    // Utiliser asset.path pour l'affichage
    // Utiliser asset.width/height pour le dimensionnement
    // Utiliser asset.extension pour la gestion du format
}
```

### Créer une galerie d'assets
```qml
GridView {
    model: AssetManager.getAssetModel("decoration", "grass")
    delegate: Column {
        Image {
            source: model.path
            width: 100
            height: 100 * (model.ratioHeight / model.ratioWidth)
        }
        Text {
            text: model.id
        }
        Text {
            text: model.extension.toUpperCase()
            color: "gray"
        }
    }
}
```

## Différences entre les méthodes

| Méthode | Retour | Utilisation |
|---------|--------|-------------|
| `getAssetById()` | QVariantMap (objet en QML) | **Recommandé** - Accès à toutes les métadonnées |
| `getAssetByFilename()` | QVariantMap (objet en QML) | Quand vous connaissez le nom de fichier exact |
| `getAssetPath()` | QString (chemin) | Quand vous avez besoin seulement du chemin |
| `getAssetModel()` | AssetModel* | Pour afficher une liste d'assets en QML |
| `isAssetValid()` | bool | Pour vérifier l'existence avant de charger |

## Bonnes pratiques

1. **Préférer `getAssetById()`** pour récupérer un asset complet avec toutes ses métadonnées
2. **Utiliser `getAssetPath()`** uniquement si vous avez besoin du chemin seul
3. **Utiliser `getAssetModel()`** pour afficher des listes d'assets en QML
4. **Toujours vérifier** si l'asset retourné est valide :
   - En QML : `if (asset.id) { ... }`
   - En C++ : `if (!asset["id"].toString().isEmpty()) { ... }`
5. **Générer les métadonnées** après avoir ajouté de nouveaux assets
6. **Extensions supportées** : png, jpg, jpeg, webp

## Debugging

Activez le debug dans `asset_manager.h` :
```cpp
#define ENABLE_ASSET_DEBUG 1
```

Cela affichera des logs détaillés sur :
- Le chargement des assets
- Les recherches d'assets
- Les erreurs de parsing
- Les créations de modèles

