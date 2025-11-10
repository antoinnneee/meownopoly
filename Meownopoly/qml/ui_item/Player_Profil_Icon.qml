import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes 1.15

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
    property color frameColor: "#FFFFFF"
    property real frameWidth: Screen.pixelDensity*1
    property real fadeIntensity: 1 // Intensité de l'estompage (0.0 à 1.0)
    property real lastStopGrad:  (root.width - root.frameWidth)/root.width
    property real firstStopGrad:  1 - lastStopGrad

    property real radStopGrad: firstStopGrad * (fadeOverlay.height/topLeftFade.height)
    property real cornerRadius: root.frameWidth // Calculé pour correspondre au radStopGrad

    Component.onCompleted: {
        if (decorationParameter.decorationId == "")
        {
            var randomAsset = AssetManager.getRandomAsset(decorationParameter.decorationCategory, decorationParameter.decorationType);
            if (randomAsset.id) {
                console.log("Asset sélectionné:", randomAsset.path);
                console.log("ID:", randomAsset.id);
                console.log("Dimensions:", randomAsset.width, "x", randomAsset.height);
                decorationParameter.decorationId = randomAsset.id
            }
        }
    }

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
        radius: width
        color: "transparent"
        
        // Rectangle contenant l'image avec coins arrondis
        Rectangle {
            id: imageContainer
            anchors.fill: parent
            anchors.margins: root.frameWidth+1
            color: "transparent"
            clip: true
            
            // Image du profil
            AnimatedImage {
                id: profileImage
                anchors.fill: parent
                source: root.imagePath
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
                visible: false
                
                onStatusChanged: {
                    if (status === Image.Error) {
                        console.warn("Erreur de chargement de l'image:", root.imagePath)
                    }
                }

            }

            MultiEffect {
                source: profileImage
                anchors.fill: profileImage
                maskEnabled: true
                maskSource: mask
                Item {
                        id: mask
                        width: profileImage.width
                        height: profileImage.height
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            width: profileImage.width
                            height: profileImage.height
                            radius: root.cornerRadius
                            color: root.frameColor
                        }
                    }
            }
        }

        // Overlay horizontal pour compléter l'effet d'estompage
        Rectangle {
            id: horizontalFadeOverlay
            anchors.topMargin: (root.width - root.frameWidth) * 0.10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin:  (root.width - root.frameWidth) * 0.10
            visible: true

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1 - ((root.width - root.frameWidth)/root.width)
                    color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity)
                }
                GradientStop {
                    position: 0.10
                    color: "transparent"
                }
                GradientStop {
                    position: 0.90
                    color: "transparent"
                }
                GradientStop {
                    position: ((root.width - root.frameWidth)/root.width)
                    color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }
        
        // Overlay avec effet d'estompage vertical (inner glow)
        Rectangle {
            id: fadeOverlay
            property alias stopTop:stopTop
            anchors.fill: parent
            anchors.leftMargin:  (root.width - root.frameWidth) * 0.10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin:  (root.width - root.frameWidth) * 0.10
            visible: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    id: stopTop
                    position: firstStopGrad
                    color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity)
                }
                GradientStop {
                    position: 0.10
                    color: "transparent"
                }
                GradientStop {
                    position: 0.90
                    color: "transparent"
                }
                GradientStop {
                    position: lastStopGrad
                    color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b, root.fadeIntensity)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // Fade area pour l'angle supérieur gauche
        Shape {
            id: topLeftFade
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: fadeOverlay.left
            anchors.bottom: horizontalFadeOverlay.top

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {

                    centerX: topLeftFade.width; centerY: topLeftFade.height
                    centerRadius: topLeftFade.height
                    focalX: centerX; focalY: centerY
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        id: topW
                        position: 1 - root.radStopGrad
                        color: "white"
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }


                PathRectangle {
                    id: rectPath
                    x: 0
                    y: 0
                    width: topLeftFade.width
                    height: topLeftFade.height
                }
            }
        }
        
        // Fade area pour l'angle supérieur droit
        Shape {
            id: topRightFade
            anchors.top: parent.top
            anchors.left: fadeOverlay.right
            anchors.right: parent.right
            anchors.bottom: horizontalFadeOverlay.top

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 0; centerY: topRightFade.height
                    centerRadius: topRightFade.height
                    focalX: centerX; focalY: centerY
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1 - root.radStopGrad
                        color: "white"
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }

                PathRectangle {
                    x: 0
                    y: 0
                    width: topRightFade.width
                    height: topRightFade.height
                }
            }
        }
        
        // Fade area pour l'angle inférieur gauche
        Shape {
            id: bottomLeftFade
            anchors.top: horizontalFadeOverlay.bottom
            anchors.left: parent.left
            anchors.right: fadeOverlay.left
            anchors.bottom: parent.bottom

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: bottomLeftFade.width; centerY: 0
                    centerRadius: bottomLeftFade.height
                    focalX: centerX; focalY: centerY
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1 - root.radStopGrad
                        color: "white"
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }

                PathRectangle {
                    x: 0
                    y: 0
                    width: bottomLeftFade.width
                    height: bottomLeftFade.height
                }
            }
        }
        
        // Fade area pour l'angle inférieur droit
        Shape {
            id: bottomRightFade
            anchors.top: horizontalFadeOverlay.bottom
            anchors.left: fadeOverlay.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 0; centerY: 0
                    centerRadius: bottomRightFade.height
                    focalX: centerX; focalY: centerY
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1 - root.radStopGrad
                        color: "white"
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }

                PathRectangle {
                    x: 0
                    y: 0
                    width: bottomRightFade.width
                    height: bottomRightFade.height
                }
            }
        }
    }
    
    // Rectangle de placeholder si pas d'image
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "#E0E0E0"
//        visible: !root.assetAvailable || root.imagePath === ""
        visible: false
        
        Text {
            anchors.centerIn: parent
            text: "?"
            font.pixelSize: root.iconSize * 0.4
            font.bold: true
            color: "#BDBDBD"
        }
    }
}

