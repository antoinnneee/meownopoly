# Guide de détection et gestion des animations

## 🎬 Détection automatique des animations

L'AssetManager détecte automatiquement si un fichier image est animé lors de la génération des métadonnées.

### Formats supportés
- **WebP animé** (.webp) - Détection automatique
- **GIF animé** (.gif) - Détection automatique
- Images statiques - frameCount = 1

## 📊 Champs liés aux animations

Chaque asset dispose de deux nouveaux champs :

| Champ | Type | Description |
|-------|------|-------------|
| `animated` | `bool` | `true` si l'asset est animé, `false` sinon |
| `frameCount` | `int` | Nombre de frames (1 pour image statique, >1 pour animations) |

## 🔍 Détecter une animation

### En QML

```qml
property var asset: AssetManager.getAssetById("decoration", "tree", "1")

Component.onCompleted: {
    if (asset.animated) {
        console.log("C'est une animation avec", asset.frameCount, "frames")
    } else {
        console.log("C'est une image statique")
    }
}
```

### En C++

```cpp
QVariantMap asset = AssetManager::instance()->getAssetById("decoration", "tree", "1");

if (asset["animated"].toBool()) {
    int frames = asset["frameCount"].toInt();
    qDebug() << "Animation détectée avec" << frames << "frames";
} else {
    qDebug() << "Image statique";
}
```

## 💡 Exemples d'utilisation

### Exemple 1 : Choisir automatiquement entre Image et AnimatedImage

```qml
import QtQuick 2.15
import AssetManager 1.0

Item {
    id: root
    
    property string assetCategory: "decoration"
    property string assetType: "tree"
    property string assetId: "1"
    
    property var asset: AssetManager.getAssetById(assetCategory, assetType, assetId)
    
    Loader {
        id: imageLoader
        anchors.fill: parent
        
        sourceComponent: {
            if (!asset || !asset.id) {
                return null
            }
            return asset.animated ? animatedComponent : staticComponent
        }
    }
    
    Component {
        id: animatedComponent
        
        AnimatedImage {
            source: asset.path
            playing: true
            fillMode: Image.PreserveAspectFit
            
            Text {
                anchors.top: parent.bottom
                text: asset.frameCount + " frames"
                color: "green"
            }
        }
    }
    
    Component {
        id: staticComponent
        
        Image {
            source: asset.path
            fillMode: Image.PreserveAspectFit
            
            Text {
                anchors.top: parent.bottom
                text: "Image statique"
                color: "blue"
            }
        }
    }
}
```

### Exemple 2 : Galerie avec indicateur d'animation

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager 1.0

GridView {
    id: gallery
    
    width: 800
    height: 600
    cellWidth: 150
    cellHeight: 180
    
    model: AssetManager.getAssetModel("decoration", "tree")
    
    delegate: Item {
        width: gallery.cellWidth
        height: gallery.cellHeight
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            color: "#f0f0f0"
            border.color: model.animated ? "#4CAF50" : "#ccc"
            border.width: 2
            
            Column {
                anchors.centerIn: parent
                spacing: 5
                
                // Image ou AnimatedImage selon le type
                Loader {
                    width: 120
                    height: 120
                    
                    sourceComponent: model.animated ? animImg : staticImg
                    
                    Component {
                        id: animImg
                        AnimatedImage {
                            source: model.path
                            fillMode: Image.PreserveAspectFit
                            playing: true
                        }
                    }
                    
                    Component {
                        id: staticImg
                        Image {
                            source: model.path
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
                
                Text {
                    text: model.id
                    font.bold: true
                }
                
                // Badge d'animation
                Rectangle {
                    visible: model.animated
                    width: 60
                    height: 20
                    color: "#4CAF50"
                    radius: 3
                    
                    Text {
                        anchors.centerIn: parent
                        text: model.frameCount + " frames"
                        color: "white"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
```

### Exemple 3 : Contrôle de lecture d'animation

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager 1.0

Item {
    id: animationPlayer
    
    property var asset: AssetManager.getAssetById("decoration", "water", "1")
    property bool isPlaying: true
    
    Column {
        anchors.centerIn: parent
        spacing: 20
        
        AnimatedImage {
            id: animImage
            source: (asset && asset.animated) ? asset.path : ""
            playing: isPlaying
            visible: asset && asset.animated
            
            width: 300
            height: 300
            fillMode: Image.PreserveAspectFit
        }
        
        Text {
            visible: asset && asset.animated
            text: "Frame: " + animImage.currentFrame + " / " + asset.frameCount
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            visible: asset && asset.animated
            
            Button {
                text: isPlaying ? "Pause" : "Play"
                onClicked: isPlaying = !isPlaying
            }
            
            Button {
                text: "Restart"
                onClicked: {
                    animImage.currentFrame = 0
                    isPlaying = true
                }
            }
        }
        
        Text {
            visible: !asset || !asset.animated
            text: "Cet asset n'est pas animé"
            color: "gray"
        }
    }
}
```

### Exemple 4 : Filtrer uniquement les animations

```qml
import QtQuick 2.15
import AssetManager 1.0

ListView {
    id: animatedOnlyList
    
    width: 400
    height: 600
    
    // Récupérer tous les assets
    property var allAssets: AssetManager.getAssetModel("decoration", "tree")
    
    // Filtrer pour n'afficher que les animés
    model: ListModel {
        id: filteredModel
    }
    
    Component.onCompleted: {
        for (var i = 0; i < allAssets.rowCount(); i++) {
            var asset = allAssets.data(allAssets.index(i, 0), 0x0100) // PathRole
            
            // Récupérer l'asset complet pour vérifier s'il est animé
            var fullAsset = AssetManager.getAssetById(
                allAssets.data(allAssets.index(i, 0), 0x0102), // CategoryRole
                allAssets.data(allAssets.index(i, 0), 0x0101), // TypeRole
                allAssets.data(allAssets.index(i, 0), 0x0107)  // IdRole
            )
            
            if (fullAsset.animated) {
                filteredModel.append({
                    "path": fullAsset.path,
                    "id": fullAsset.id,
                    "frameCount": fullAsset.frameCount
                })
            }
        }
        
        console.log("Trouvé", filteredModel.count, "animations")
    }
    
    delegate: Item {
        width: parent.width
        height: 80
        
        Row {
            spacing: 10
            
            AnimatedImage {
                source: model.path
                width: 64
                height: 64
                playing: true
            }
            
            Column {
                Text {
                    text: model.id
                    font.bold: true
                }
                Text {
                    text: model.frameCount + " frames"
                    color: "green"
                }
            }
        }
    }
}
```

## 🔄 Régénération des métadonnées

Pour que la détection automatique fonctionne sur vos assets existants, vous devez régénérer les métadonnées :

### En C++

```cpp
// Régénérer pour un répertoire spécifique
AssetManager::instance()->generateMetadataForDirectory(
    "asset_extracted/decoration/tree"
);

// Ou régénérer pour tous les assets
AssetManager::instance()->generateAllMetadata();

// Puis recharger
AssetManager::instance()->reloadAssets();
```

### En QML

```qml
Button {
    text: "Régénérer les métadonnées"
    onClicked: {
        console.log("Régénération en cours...")
        var success = AssetManager.generateAllMetadata()
        if (success) {
            console.log("Métadonnées régénérées !")
            AssetManager.reloadAssets()
        }
    }
}
```

## 📝 Format des métadonnées

Les fichiers `metadata.json` générés contiennent maintenant :

```json
{
    "assets": [
        {
            "id": "tree_animated",
            "filename": "tree_animated.webp",
            "extension": "webp",
            "animated": true,
            "frameCount": 24,
            "width": 256,
            "height": 256,
            "ratioWidth": 1,
            "ratioHeight": 1
        },
        {
            "id": "tree_static",
            "filename": "tree_static.png",
            "extension": "png",
            "animated": false,
            "frameCount": 1,
            "width": 256,
            "height": 256,
            "ratioWidth": 1,
            "ratioHeight": 1
        }
    ]
}
```

## ⚡ Optimisation des performances

### Charger conditionnellement

```qml
// N'utiliser AnimatedImage que si nécessaire
Loader {
    sourceComponent: asset.animated ? animatedComponent : imageComponent
}
```

### Arrêter les animations hors vue

```qml
AnimatedImage {
    playing: visible && asset.animated
}
```

### Limiter le nombre d'animations simultanées

```qml
GridView {
    model: myModel
    delegate: AnimatedImage {
        // Jouer seulement les animations visibles
        playing: PathView.isCurrentItem && model.animated
    }
}
```

## 🎯 Bonnes pratiques

1. **Toujours vérifier** `asset.animated` avant d'utiliser AnimatedImage
2. **Utiliser Loader** pour charger le bon composant (Image vs AnimatedImage)
3. **Régénérer les métadonnées** après avoir ajouté de nouveaux assets
4. **Arrêter les animations** quand elles ne sont pas visibles pour les performances
5. **frameCount = 1** pour toutes les images statiques (pas besoin de vérifier si > 0)

## 🔍 Debugging

Activez le debug pour voir les informations de détection :

```cpp
// Dans asset_manager.h
#define ENABLE_ASSET_DEBUG 1
```

Vous verrez alors des logs comme :
```
[ASSET_INFO] Processing tree_1.webp - Animated: true Frames: 24
[ASSET_INFO] Processing grass_01.png - Animated: false Frames: 1
```

