# Documentation de l'AssetManager

## 📚 Guide de navigation

Bienvenue dans la documentation complète de l'AssetManager de Meownopoly !

### Documents disponibles

1. **[ASSET_MANAGER_USAGE.md](ASSET_MANAGER_USAGE.md)** - Guide d'utilisation complet
   - Vue d'ensemble du système
   - Structure des assets
   - Toutes les méthodes disponibles
   - Cas d'usage typiques
   - Bonnes pratiques
   - Guide de debugging

2. **[ASSET_MANAGER_EXAMPLES.md](ASSET_MANAGER_EXAMPLES.md)** - Exemples pratiques
   - Exemples C++ détaillés
   - Exemples QML complets
   - Cas d'usage avancés
   - Code prêt à l'emploi

3. **[ASSET_MANAGER_ANIMATION.md](ASSET_MANAGER_ANIMATION.md)** - ⭐ NOUVEAU : Guide des animations
   - Détection automatique des WebP/GIF animés
   - Utilisation de `animated` et `frameCount`
   - Exemples Image vs AnimatedImage
   - Optimisation des performances

4. **[README_ASSET_SYSTEM.md](README_ASSET_SYSTEM.md)** - Documentation technique du système
   - Architecture globale
   - Détails d'implémentation
   - Format des fichiers

## 🚀 Démarrage rapide

### Pour les développeurs QML

```qml
// Afficher une image
Image {
    source: AssetManager.getAssetPath("decoration", "grass", "grass_01")
}

// Avec métadonnées complètes
property var asset: AssetManager.getAssetById("decoration", "grass", "grass_01")
Image {
    source: asset.path
    width: 200
    height: 200 * (asset.ratioHeight / asset.ratioWidth)
}

// Liste d'assets
ListView {
    model: AssetManager.getAssetModel("decoration", "grass")
    delegate: Image {
        source: model.path
        width: 64; height: 64
    }
}
```

### Pour les développeurs C++

```cpp
        // Récupérer un asset complet (RECOMMANDÉ) - Retourne QVariantMap
QVariantMap asset = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");
if (!asset["id"].toString().isEmpty()) {
    QString path = asset["path"].toString();
    QString extension = asset["extension"].toString();
    int width = asset["width"].toInt();
    // ...
}

// Récupérer seulement le chemin
QString path = AssetManager::instance()->getAssetPath("decoration", "grass", "grass_01");

// Travailler avec un modèle
AssetModel* model = AssetManager::instance()->getAssetModel("decoration", "grass");
```

## 📖 Méthodes principales

| Méthode | Usage | Retour |
|---------|-------|--------|
| `getAssetById()` | ⭐ **RECOMMANDÉ** - Récupère un asset complet | `QVariantMap` (objet en QML) |
| `getAssetByFilename()` | Récupère un asset par nom de fichier | `QVariantMap` (objet en QML) |
| `getAssetPath()` | Récupère seulement le chemin | `QString` |
| `getAssetModel()` | Pour ListView/GridView en QML | `AssetModel*` |
| `isAssetValid()` | Vérifie l'existence | `bool` |
| `getAvailableTypes()` | Liste les types d'une catégorie | `QStringList` |
| `getAvailableCategories()` | Liste toutes les catégories | `QStringList` |

## 🏗️ Structure des assets

```
asset_extracted/
  ├── decoration/
  │   ├── grass/
  │   │   ├── metadata.json
  │   │   ├── grass_01.png
  │   │   └── grass_02.webp
  │   └── tree/
  │       ├── metadata.json
  │       └── oak_01.jpg
  └── player_icons/
      └── cats/
          ├── metadata.json
          └── cat_01.png
```

## 📝 Structure Asset (QVariantMap)

Les méthodes `getAssetById()` et `getAssetByFilename()` retournent un objet (QVariantMap en C++, objet JavaScript en QML) :

```javascript
// En QML - accès direct aux propriétés
var asset = AssetManager.getAssetById("decoration", "grass", "grass_01")
console.log(asset.path)       // "file:///..."
console.log(asset.type)       // "grass"
console.log(asset.category)   // "decoration"
console.log(asset.extension)  // "png"
console.log(asset.width)      // 256
console.log(asset.animated)   // false (ou true pour WebP animé)
console.log(asset.frameCount) // 1 (ou plus pour animations)
```

```cpp
// En C++ - accès via QVariantMap
QVariantMap asset = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");
QString path = asset["path"].toString();
int width = asset["width"].toInt();
bool animated = asset["animated"].toBool();
int frameCount = asset["frameCount"].toInt();
```

## 🔧 Configuration

### Activer le debug

Dans `asset_manager.h` :
```cpp
#define ENABLE_ASSET_DEBUG 1
```

### Changer le chemin des assets

```cpp
AssetManager::instance()->setAssetsBasePath("mon/nouveau/chemin");
```

## 🎯 Cas d'usage courants

### 1. Afficher un asset simple
```qml
Image { source: AssetManager.getAssetPath("decoration", "grass", "grass_01") }
```

### 2. Galerie d'assets
```qml
GridView {
    model: AssetManager.getAssetModel("decoration", "grass")
    delegate: Image { source: model.path }
}
```

### 3. Asset avec dimensions dynamiques
```cpp
QVariantMap asset = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");
int width = asset["width"].toInt();
int height = asset["height"].toInt();
int ratioW = asset["ratioWidth"].toInt();
int ratioH = asset["ratioHeight"].toInt();
```

### 4. Vérifier avant de charger
```cpp
if (AssetManager::instance()->isAssetValid("decoration", "grass", "grass_01")) {
    // Charger l'asset
}
```

### 5. Générer les métadonnées
```cpp
AssetManager::instance()->generateAllMetadata();
```

## 🆕 Nouveautés

### 🎬 Détection automatique des animations

L'AssetManager détecte maintenant automatiquement si un asset est animé (WebP animé, GIF) :
- **Détection automatique** lors de la génération des métadonnées
- Champ `animated` (bool) indique si l'asset est animé
- Champ `frameCount` (int) donne le nombre de frames (1 pour images statiques)
- Supporte WebP animé et GIF

```qml
// En QML - Choisir automatiquement le bon composant
var asset = AssetManager.getAssetById("decoration", "tree", "1")
if (asset.animated) {
    console.log("Animation détectée avec", asset.frameCount, "frames")
    // Utiliser AnimatedImage
} else {
    console.log("Image statique")
    // Utiliser Image classique
}
```

Voir **[ASSET_MANAGER_ANIMATION.md](ASSET_MANAGER_ANIMATION.md)** pour plus de détails.

### Gestion de l'extension des fichiers

L'AssetManager gère automatiquement les extensions :
- **png**, **jpg**, **jpeg**, **webp** supportés
- Extension stockée dans les métadonnées
- Détection automatique lors de la génération
- Accessible via `asset.extension`

```cpp
QVariantMap asset = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");
qDebug() << "Extension:" << asset["extension"].toString(); // "png", "webp", etc.
```

```qml
// En QML
var asset = AssetManager.getAssetById("decoration", "grass", "grass_01")
if (asset.id) {
    console.log("Extension:", asset.extension) // "png", "webp", etc.
}
```

### Méthodes simplifiées

Nouvelles méthodes pour récupérer directement un asset complet :
- `getAssetById()` - Par identifiant (recommandé)
- `getAssetByFilename()` - Par nom de fichier

Ces méthodes retournent un `QVariantMap` (objet JavaScript en QML) avec toutes les métadonnées de l'asset.

**Vérification en QML :**
```qml
var asset = AssetManager.getAssetById("decoration", "grass", "grass_01")
if (asset && asset.id) {
    // Asset trouvé, utiliser asset.path, asset.extension, etc.
}
```

## 📚 Pour aller plus loin

- **Débutants** : Commencez par [ASSET_MANAGER_USAGE.md](ASSET_MANAGER_USAGE.md)
- **Exemples pratiques** : Consultez [ASSET_MANAGER_EXAMPLES.md](ASSET_MANAGER_EXAMPLES.md)
- **Architecture technique** : Lisez [README_ASSET_SYSTEM.md](README_ASSET_SYSTEM.md)
- **Code source** : Voir `asset_manager.h` et `asset_manager.cpp` (commentés)

## ❓ Questions fréquentes

### Comment ajouter de nouveaux assets ?

1. Placez vos images dans `asset_extracted/category/type/`
2. Générez les métadonnées : `AssetManager::instance()->generateMetadataForDirectory()`
3. Rechargez : `AssetManager::instance()->reloadAssets()`

### Quelle méthode utiliser pour récupérer un asset ?

- **Asset complet** : `getAssetById()` ⭐ RECOMMANDÉ
- **Seulement le chemin** : `getAssetPath()`
- **Pour des listes QML** : `getAssetModel()`

### Comment vérifier si un asset existe ?

```cpp
bool exists = AssetManager::instance()->isAssetValid(category, type, id);
```

### Comment activer les logs de debug ?

Dans `asset_manager.h`, changez :
```cpp
#define ENABLE_ASSET_DEBUG 1
```

### Quelles extensions sont supportées ?

- PNG (.png)
- JPEG (.jpg, .jpeg)
- WebP (.webp)

## 🐛 Debugging

Si vous rencontrez des problèmes :

1. **Activez le debug** (`ENABLE_ASSET_DEBUG 1`)
2. **Vérifiez** que `metadata.json` existe dans chaque dossier
3. **Régénérez** les métadonnées si nécessaire
4. **Vérifiez** les chemins avec `AssetManager.scanAvailableAssets()`

## 📞 Support

Pour plus d'informations, consultez :
- Le code source commenté dans `asset_manager.h`
- Les exemples dans `ASSET_MANAGER_EXAMPLES.md`
- La documentation complète dans `ASSET_MANAGER_USAGE.md`

