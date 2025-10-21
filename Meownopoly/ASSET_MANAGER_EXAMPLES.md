# Exemples d'utilisation de l'AssetManager

## Exemples C++

### Exemple 1 : Récupérer un asset complet

```cpp
#include "asset_manager.h"

// Récupérer un asset par son ID (retourne un QVariantMap)
QVariantMap grass = AssetManager::instance()->getAssetById("decoration", "grass", "grass_01");

if (!grass["id"].toString().isEmpty()) {
    qDebug() << "Asset trouvé !";
    qDebug() << "Chemin:" << grass["path"].toString();
    qDebug() << "Extension:" << grass["extension"].toString();
    qDebug() << "Dimensions:" << grass["width"].toInt() << "x" << grass["height"].toInt();
    qDebug() << "Ratio:" << grass["ratioWidth"].toInt() << ":" << grass["ratioHeight"].toInt();
    
    // Utiliser l'asset
    QString path = grass["path"].toString();
    path.remove("file:///");
    QImage image(path);
    // ...
} else {
    qDebug() << "Asset non trouvé !";
}
```

### Exemple 2 : Vérifier l'existence avant de charger

```cpp
QString category = "decoration";
QString type = "tree";
QString id = "tree_oak";

if (AssetManager::instance()->isAssetValid(category, type, id)) {
    QVariantMap tree = AssetManager::instance()->getAssetById(category, type, id);
    QString path = tree["path"].toString();
    // Traiter l'asset...
} else {
    qDebug() << "Asset invalide, chargement d'un asset par défaut";
    // Charger un asset par défaut
}
```

### Exemple 3 : Itérer sur tous les assets d'un type

```cpp
AssetModel* model = AssetManager::instance()->getAssetModel("decoration", "grass");

if (model) {
    QList<Asset> assets = model->getAssetList();
    
    for (const Asset& asset : assets) {
        qDebug() << "ID:" << asset.id 
                 << "| Taille:" << asset.width << "x" << asset.height
                 << "| Format:" << asset.extension;
    }
}
```

### Exemple 4 : Récupérer seulement ce dont vous avez besoin

```cpp
// Si vous avez besoin seulement du chemin
QString path = AssetManager::instance()->getAssetPath("decoration", "grass", "grass_01");
image.setSource(path);

```

## Exemples QML

### Exemple 1 : Afficher une image simple

```qml
import AssetManager 1.0

Image {
    // Méthode simple : juste le chemin
    source: AssetManager.getAssetPath("decoration", "grass", "grass_01")
    
    width: 100
    height: 100
    fillMode: Image.PreserveAspectFit
}
```

### Exemple 2 : Charger avec métadonnées (dimensionnement automatique)

```qml
import AssetManager 1.0

Item {
    id: root
    
    property var asset: AssetManager.getAssetById("decoration", "tree", "1")
    
    // Utiliser AnimatedImage si c'est animé, sinon Image
    Loader {
        sourceComponent: (asset && asset.animated) ? animatedImageComponent : staticImageComponent
    }
    
    Component {
        id: animatedImageComponent
        AnimatedImage {
            source: (asset && asset.id) ? asset.path : ""
            width: 200
            height: (asset && asset.ratioWidth > 0) ? width * (asset.ratioHeight / asset.ratioWidth) : 200
            playing: true
        }
    }
    
    Component {
        id: staticImageComponent
        Image {
            source: (asset && asset.id) ? asset.path : ""
            width: 200
            height: (asset && asset.ratioWidth > 0) ? width * (asset.ratioHeight / asset.ratioWidth) : 200
        }
    }
    
    Text {
        anchors.bottom: parent.bottom
        text: {
            if (asset && asset.id) {
                var info = asset.filename + " (" + asset.extension + ")"
                if (asset.animated) {
                    info += " - ANIMÉ (" + asset.frameCount + " frames)"
                }
                return info
            }
            return "No asset"
        }
    }
}
```

### Exemple 3 : Galerie d'assets avec GridView

```qml
import QtQuick 2.15
import AssetManager 1.0

GridView {
    id: assetGallery
    
    width: 800
    height: 600
    cellWidth: 150
    cellHeight: 180
    
    // Récupérer le modèle pour une catégorie/type
    model: AssetManager.getAssetModel("decoration", "grass")
    
    delegate: Item {
        width: assetGallery.cellWidth
        height: assetGallery.cellHeight
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Rectangle {
                width: 120
                height: 120
                color: "#f0f0f0"
                border.color: "#ccc"
                
                Image {
                    anchors.centerIn: parent
                    source: model.path
                    width: 100
                    height: 100 * (model.ratioHeight / model.ratioWidth)
                    fillMode: Image.PreserveAspectFit
                    
                    // Afficher les dimensions au survol
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        ToolTip.visible: containsMouse
                        ToolTip.text: model.width + "x" + model.height
                    }
                }
            }
            
            Text {
                width: 120
                text: model.id
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
            
            Text {
                width: 120
                text: model.extension.toUpperCase()
                color: "gray"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
```

### Exemple 4 : Sélecteur d'assets avec catégories

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager 1.0

Item {
    id: assetSelector
    
    property string selectedCategory: "decoration"
    property string selectedType: "grass"
    property var selectedAsset: null
    
    Column {
        anchors.fill: parent
        spacing: 10
        
        // Sélection de catégorie
        ComboBox {
            id: categoryCombo
            width: parent.width
            model: AssetManager.getAvailableCategories()
            onCurrentTextChanged: {
                selectedCategory = currentText
                typeCombo.model = AssetManager.getAvailableTypes(currentText)
            }
        }
        
        // Sélection de type
        ComboBox {
            id: typeCombo
            width: parent.width
            model: AssetManager.getAvailableTypes(selectedCategory)
            onCurrentTextChanged: {
                selectedType = currentText
                assetList.model = AssetManager.getAssetModel(selectedCategory, currentText)
            }
        }
        
        // Liste des assets
        ListView {
            id: assetList
            width: parent.width
            height: 300
            
            model: AssetManager.getAssetModel(selectedCategory, selectedType)
            
            delegate: ItemDelegate {
                width: assetList.width
                
                Row {
                    spacing: 10
                    
                    Image {
                        source: model.path
                        width: 50
                        height: 50
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    Column {
                        Text { text: model.id }
                        Text { 
                            text: model.width + "x" + model.height + " (" + model.extension + ")"
                            color: "gray"
                            font.pixelSize: 10
                        }
                    }
                }
                
                onClicked: {
                    // Récupérer l'asset complet
                    selectedAsset = AssetManager.getAssetById(
                        selectedCategory, 
                        selectedType, 
                        model.id
                    )
                    console.log("Asset sélectionné:", selectedAsset.path)
                }
            }
        }
        
        // Aperçu de l'asset sélectionné
        Rectangle {
            width: parent.width
            height: 200
            color: "#f5f5f5"
            visible: selectedAsset !== null
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Image {
                    source: selectedAsset ? selectedAsset.path : ""
                    width: 150
                    height: selectedAsset ? 150 * (selectedAsset.ratioHeight / selectedAsset.ratioWidth) : 150
                    fillMode: Image.PreserveAspectFit
                }
                
                Text {
                    text: selectedAsset ? selectedAsset.id : ""
                    font.bold: true
                }
            }
        }
    }
}
```

### Exemple 5 : Vérification avant affichage

```qml
import AssetManager 1.0

Image {
    property string assetCategory: "decoration"
    property string assetType: "grass"
    property string assetId: "grass_01"
    
    Component.onCompleted: {
        if (AssetManager.isAssetValid(assetCategory, assetType, assetId)) {
            var asset = AssetManager.getAssetById(assetCategory, assetType, assetId)
            
            // Vérifier que l'asset a bien été récupéré
            if (asset && asset.id) {
                source = asset.path
                
                // Adapter les dimensions
                if (asset.ratioWidth > 0 && asset.ratioHeight > 0) {
                    width = 200
                    height = 200 * (asset.ratioHeight / asset.ratioWidth)
                }
            } else {
                console.warn("Asset non récupéré")
                source = "qrc:/images/placeholder.png"
            }
        } else {
            console.warn("Asset non trouvé, chargement d'un placeholder")
            source = "qrc:/images/placeholder.png"
        }
    }
}
```

### Exemple 6 : Repeater avec différents types

```qml
import QtQuick 2.15
import AssetManager 1.0

Column {
    spacing: 20
    
    Repeater {
        model: ["grass", "tree", "rock"]
        
        delegate: Column {
            property string currentType: modelData
            
            Text {
                text: "Type: " + currentType
                font.bold: true
            }
            
            Row {
                spacing: 10
                
                Repeater {
                    model: AssetManager.getAssetModel("decoration", currentType)
                    
                    delegate: Image {
                        source: model.path
                        width: 64
                        height: 64
                        fillMode: Image.PreserveAspectFit
                        
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: model.id
                            font.pixelSize: 8
                        }
                    }
                }
            }
        }
    }
}
```

## Exemples de génération de métadonnées

### Générer pour un nouveau répertoire

```cpp
// Après avoir ajouté des images dans asset_extracted/decoration/flowers/
bool success = AssetManager::instance()->generateMetadataForDirectory(
    "asset_extracted/decoration/flowers"
);

if (success) {
    qDebug() << "Métadonnées générées avec succès";
    AssetManager::instance()->reloadAssets();
} else {
    qDebug() << "Erreur lors de la génération des métadonnées";
}
```

### Régénérer toutes les métadonnées

```cpp
// Si vous avez modifié plusieurs répertoires
bool success = AssetManager::instance()->generateAllMetadata();

if (success) {
    qDebug() << "Toutes les métadonnées ont été régénérées";
}
```

### En QML (via un bouton d'admin)

```qml
import AssetManager 1.0

Button {
    text: "Régénérer les métadonnées"
    
    onClicked: {
        console.log("Génération des métadonnées...")
        var success = AssetManager.generateAllMetadata()
        
        if (success) {
            console.log("Métadonnées régénérées avec succès")
            statusText.text = "Métadonnées mises à jour !"
        } else {
            console.error("Erreur lors de la génération")
            statusText.text = "Erreur !"
        }
    }
}
```

## Cas d'usage avancés

### Précharger des assets au démarrage

```cpp
// Dans main.cpp ou au démarrage de l'application
void preloadAssets() {
    QStringList categories = {"decoration", "player_icons", "background"};
    
    for (const QString& category : categories) {
        QStringList types = AssetManager::instance()->getAvailableTypes(category);
        
        for (const QString& type : types) {
            // Précharger le modèle (mise en cache)
            AssetModel* model = AssetManager::instance()->getAssetModel(category, type);
            qDebug() << "Préchargé:" << category << "/" << type 
                     << "(" << model->rowCount() << "assets)";
        }
    }
}
```

### Créer un cache d'images optimisé

```cpp
QMap<QString, QImage> imageCache;

void cacheAssets(const QString& category, const QString& type) {
    AssetModel* model = AssetManager::instance()->getAssetModel(category, type);
    QList<Asset> assets = model->getAssetList();
    
    for (const Asset& asset : assets) {
        QString path = asset.path;
        path.remove("file:///");
        
        QImage image(path);
        if (!image.isNull()) {
            imageCache[asset.id] = image;
        }
    }
}
```

## Résumé des meilleures pratiques

1. **Utilisez `getAssetById()`** pour récupérer un asset complet avec toutes ses métadonnées
2. **Utilisez `getAssetPath()`** si vous avez seulement besoin du chemin
3. **Utilisez `getAssetModel()`** pour afficher des listes d'assets en QML
4. **Vérifiez toujours** si un asset est valide avant de l'utiliser
5. **Générez les métadonnées** après avoir ajouté de nouveaux assets
6. **Activez le debug** pendant le développement pour identifier les problèmes

