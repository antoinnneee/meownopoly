import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import AssetManager
import DecorationParameter

/**
 * Composant d'icône de profil de joueur
 * Affiche une image dans un cadre blanc arrondi avec effet d'estompage
 */
Item {
    id: root
    
    // Propriétés configurables
    property DecorationParameter decorationParameter: DecorationParameter {}
    property real iconSize: Screen.pixelDensity * 30
    property real cornerRadius: 8
    property color frameColor: "#FFFFFF"
    property real frameWidth: 4
    property real fadeIntensity: 0.3 // Intensité de l'estompage (0.0 à 1.0)
    
    // Taille par défaut
    width: iconSize
    height: iconSize
    
    // Vérifier si l'asset est disponible
    readonly property bool assetAvailable: (decorationParameter.decorationCategory !== "" &&
                                           decorationParameter.decorationType !== "" &&
                                           decorationParameter.decorationId !== "")
    
    // Récupérer l'asset depuis AssetManager
    readonly property var asset: assetAvailable ? 
        AssetManager.getAssetById(
            decorationParameter.decorationCategory,
            decorationParameter.decorationType,
            decorationParameter.decorationId
        ) : null
    
    readonly property string imagePath: (asset && asset.id) ? asset.path : ""
    
    // Rectangle conteneur principal avec coins arrondis
    Rectangle {
        id: container
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.frameColor
        clip: true
        
        // Rectangle contenant l'image avec coins arrondis
        Rectangle {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: root.frameWidth
            radius: root.cornerRadius - root.frameWidth
            color: "transparent"
            clip: true
            
            // Image du profil
            Image {
                id: profileImage
                anchors.fill: parent
                source: root.imagePath
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
                
                onStatusChanged: {
                    if (status === Image.Error) {
                        console.warn("Erreur de chargement de l'image:", root.imagePath)
                    }
                }
            }
            
            // Overlay avec effet d'estompage vertical (inner glow)
            Rectangle {
                id: fadeOverlay
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { 
                        position: 0.0
                        color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity)
                    }
                    GradientStop { 
                        position: 0.15
                        color: "transparent"
                    }
                    GradientStop { 
                        position: 0.85
                        color: "transparent"
                    }
                    GradientStop { 
                        position: 1.0
                        color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity)
                    }
                }
            }
            
            // Overlay horizontal pour compléter l'effet d'estompage
            Rectangle {
                id: horizontalFadeOverlay
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { 
                        position: 0.0
                        color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity * 0.6)
                    }
                    GradientStop { 
                        position: 0.15
                        color: "transparent"
                    }
                    GradientStop { 
                        position: 0.85
                        color: "transparent"
                    }
                    GradientStop { 
                        position: 1.0
                        color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity * 0.6)
                    }
                }
            }
        }
    }
    
    // Rectangle de placeholder si pas d'image
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "#E0E0E0"
        visible: !root.assetAvailable || root.imagePath === ""
        
        Text {
            anchors.centerIn: parent
            text: "?"
            font.pixelSize: root.iconSize * 0.4
            font.bold: true
            color: "#BDBDBD"
        }
    }
}

