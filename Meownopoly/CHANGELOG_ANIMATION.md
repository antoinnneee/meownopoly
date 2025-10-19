# Changelog - Détection automatique des animations

## Version - 19 Octobre 2025

### ✨ Nouvelles fonctionnalités

#### 🎬 Détection automatique des animations WebP/GIF

L'AssetManager détecte maintenant automatiquement si un fichier image est animé lors de la génération des métadonnées.

**Nouveaux champs dans la structure Asset :**
- `animated` (bool) - Indique si l'asset est animé
- `frameCount` (int) - Nombre de frames (toujours >= 1, 1 pour images statiques)

**Formats supportés :**
- WebP animé (.webp)
- GIF animé (.gif)
- Images statiques (PNG, JPG, JPEG) - frameCount = 1

### 🔧 Modifications techniques

#### Fichiers modifiés

**asset_manager.h :**
- Ajout de `bool animated` et `int frameCount` dans `struct Asset`
- Ajout de `AnimatedRole` et `FrameCountRole` dans `enum AssetRoles`
- Mise à jour de la signature de `addAsset()` avec les nouveaux paramètres

**asset_manager.cpp :**
- Mise à jour de `data()` pour retourner les nouveaux rôles
- Mise à jour de `roleNames()` pour exposer "animated" et "frameCount" à QML
- Mise à jour de `addAsset()` pour stocker animated et frameCount
- Mise à jour de `assetToVariantMap()` pour inclure les nouveaux champs
- **Modification de `generateMetadataForDirectory()` :**
  - Utilisation de `QImageReader::supportsAnimation()` pour détecter les animations
  - Utilisation de `QImageReader::imageCount()` pour compter les frames
  - frameCount = 1 pour les images statiques (jamais 0)
  - Ajout de logs de debug pour voir la détection
- **Modification de `loadTypeFromDirectory()` :**
  - Chargement des champs "animated" et "frameCount" depuis metadata.json
  - Valeurs par défaut : animated=false, frameCount=1

### 📚 Documentation

**Nouveaux fichiers :**
- `ASSET_MANAGER_ANIMATION.md` - Guide complet sur l'utilisation des animations
  - Exemples de détection
  - Utilisation avec Image vs AnimatedImage
  - Galeries avec indicateurs d'animation
  - Contrôle de lecture
  - Filtrage des animations
  - Optimisations de performance

**Fichiers mis à jour :**
- `ASSET_MANAGER_USAGE.md` - Ajout des champs animated et frameCount
- `ASSET_MANAGER_EXAMPLES.md` - Exemples mis à jour avec gestion animations
- `ASSET_MANAGER_INDEX.md` - Ajout de la section animations dans les nouveautés

### 💡 Exemples d'utilisation

#### En QML - Détection simple

```qml
var asset = AssetManager.getAssetById("decoration", "tree", "1")

if (asset.animated) {
    console.log("Animation avec", asset.frameCount, "frames")
} else {
    console.log("Image statique")
}
```

#### En QML - Chargement conditionnel

```qml
Loader {
    sourceComponent: asset.animated ? animatedComponent : staticComponent
}

Component {
    id: animatedComponent
    AnimatedImage {
        source: asset.path
        playing: true
    }
}

Component {
    id: staticComponent
    Image {
        source: asset.path
    }
}
```

#### Depuis le modèle ListView/GridView

```qml
GridView {
    model: AssetManager.getAssetModel("decoration", "tree")
    
    delegate: Item {
        // model.animated est directement accessible
        // model.frameCount est directement accessible
        
        Rectangle {
            color: model.animated ? "green" : "gray"
            
            Text {
                text: model.animated ? 
                    model.frameCount + " frames" : 
                    "Statique"
            }
        }
    }
}
```

### 🔄 Migration

#### Pour les utilisateurs existants

1. **Régénérer les métadonnées** pour tous vos assets :
   ```cpp
   AssetManager::instance()->generateAllMetadata();
   AssetManager::instance()->reloadAssets();
   ```

2. **Vérifier vos fichiers metadata.json** - ils devraient maintenant contenir :
   ```json
   {
       "animated": true/false,
       "frameCount": nombre
   }
   ```

3. **Mettre à jour votre code QML** si nécessaire pour utiliser AnimatedImage pour les assets animés

#### Rétrocompatibilité

✅ **100% rétrocompatible** - Les anciens fichiers metadata.json sans les champs animated/frameCount fonctionneront avec les valeurs par défaut :
- `animated` = false
- `frameCount` = 1

### ⚡ Optimisations

La détection se fait uniquement lors de la génération des métadonnées, pas à chaque chargement. Les métadonnées sont mises en cache, donc :
- ✅ Pas d'impact sur les performances au runtime
- ✅ Détection une seule fois par asset
- ✅ Informations immédiatement disponibles

### 🐛 Corrections

- Simplification de `getAssetPath()` pour utiliser directement le modèle au lieu de `getAssetElement()`
- Suppression de la méthode `getAssetElement()` qui n'était plus utilisée

### 📝 Notes techniques

**Détection d'animation :**
- Utilise `QImageReader` qui supporte nativement WebP et GIF
- `supportsAnimation()` retourne true si le format supporte l'animation
- `imageCount()` retourne le nombre de frames (1 pour image statique)
- La détection est fiable et basée sur Qt, pas sur l'extension du fichier

**Valeurs :**
- `frameCount` est **toujours >= 1** (jamais 0)
- Images statiques : `animated=false`, `frameCount=1`
- Animations : `animated=true`, `frameCount>1`

### 🎯 Prochaines étapes possibles

Pour aller plus loin, on pourrait ajouter :
- Durée totale de l'animation
- FPS (frames par seconde)
- Taille du fichier
- Support d'autres formats animés (APNG, etc.)
- Prévisualisation des animations dans l'éditeur

### 📞 Support

Pour toute question ou problème :
- Consultez `ASSET_MANAGER_ANIMATION.md` pour des exemples complets
- Activez `ENABLE_ASSET_DEBUG 1` pour voir les logs de détection
- Vérifiez que Qt supporte bien WebP (devrait être le cas avec Qt 6.9.1)

