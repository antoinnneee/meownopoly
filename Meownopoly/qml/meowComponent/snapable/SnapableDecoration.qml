import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects

import AssetManager
import ItemSnapable
import DecorationParameter
import TileType

SnapableElement {
    id: root

    // --- Properties ---
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    property bool assetAvailable : (snapableParameters.decorationParameter.decorationCategory != ""
                                    && snapableParameters.decorationParameter.decorationType  != ""
                                    && snapableParameters.decorationParameter.decorationId  != "")
    property var asset: (assetAvailable) ? AssetManager.getAssetById(snapableParameters.decorationParameter.decorationCategory, snapableParameters.decorationParameter.decorationType, snapableParameters.decorationParameter.decorationId) : ""


    property string imagePath: (asset && asset.id) ? asset.path : ""
    property string extension: (asset && asset.id) ? asset.extension : ""

    // Helper function to check if any effect is active
    readonly property bool hasActiveEffects: snapableParameters.displayParameter.effectBrightness !== 0.0 ||
                                             snapableParameters.displayParameter.effectContrast !== 0.0 ||
                                             snapableParameters.displayParameter.effectSaturation !== 0.0 ||
                                             snapableParameters.displayParameter.effectColorization !== 0.0 ||
                                             snapableParameters.displayParameter.effectBlurEnabled ||
                                             snapableParameters.displayParameter.effectShadowEnabled

    // Helper function to check if any transform is active
    readonly property bool hasActiveTransforms: snapableParameters.displayParameter.rotationAngle !== 0.0 ||
                                                snapableParameters.displayParameter.mirrorHorizontal ||
                                                snapableParameters.displayParameter.mirrorVertical

    // Performance optimization: only create MultiEffect when needed
    readonly property bool shouldCreateEffect: hasActiveEffects

    // --- Component.onCompleted ---
    Component.onCompleted: {
    }

    // --- Items ---
    AnimatedImage {
        id: tileImage
        anchors.fill: parent
        source:  (assetAvailable) ? imagePath : ""
        z: 1  // Assurer que le contenu est sous les poignées
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down

        // Hide source image when effects are applied for optimal performance
        visible: !hasActiveEffects

        // Apply mirror effects using scale
        transform: [
            Scale{
                xScale: snapableParameters.displayParameter.mirrorHorizontal ? -1 : 1
                yScale: snapableParameters.displayParameter.mirrorVertical ? -1 : 1
                origin.x: tileImage.width / 2
                origin.y: tileImage.height / 2
            },
            Rotation{
                angle: snapableParameters.displayParameter.rotationAngle
                origin.x: tileImage.width / 2
                origin.y: tileImage.height / 2
                // axis.y:0.2
                axis.z:1
            }
        ]
        onStatusChanged: {
            if (status === Image.Error) {
                console.log("AssetManager path failed, falling back to legacy system")
            }
        }
    }

    MultiEffect {
        id: multiEffect
        anchors.fill: parent
        source: tileImage
        z: 2  // Above the source image but below handles
        visible: shouldCreateEffect

        // Apply the same transforms as the source image

        transform: [
            Scale{
                xScale: snapableParameters.displayParameter.mirrorHorizontal ? -1 : 1
                yScale: snapableParameters.displayParameter.mirrorVertical ? -1 : 1
                origin.x: multiEffect.width / 2
                origin.y: multiEffect.height / 2
            },
            Rotation{
                angle: snapableParameters.displayParameter.rotationAngle
                origin.x: multiEffect.width / 2
                origin.y: multiEffect.height / 2
            }
        ]

        // Color effects (always available)
        brightness: snapableParameters.displayParameter.effectBrightness
        contrast: snapableParameters.displayParameter.effectContrast
        saturation: snapableParameters.displayParameter.effectSaturation
        colorization: snapableParameters.displayParameter.effectColorization
        colorizationColor: snapableParameters.displayParameter.effectColorizationColor

        // Blur effect
        blurEnabled: snapableParameters.displayParameter.effectBlurEnabled
        blur: snapableParameters.displayParameter.effectBlur
        blurMax: snapableParameters.displayParameter.effectBlurMax
        blurMultiplier: snapableParameters.displayParameter.effectBlurMultiplier

        // Shadow effect
        shadowEnabled: snapableParameters.displayParameter.effectShadowEnabled
        shadowBlur: snapableParameters.displayParameter.effectShadowBlur
        shadowColor: snapableParameters.displayParameter.effectShadowColor
        shadowHorizontalOffset: snapableParameters.displayParameter.effectShadowHorizontalOffset
        shadowVerticalOffset: snapableParameters.displayParameter.effectShadowVerticalOffset
        shadowOpacity: snapableParameters.displayParameter.effectShadowOpacity
        shadowScale: snapableParameters.displayParameter.effectShadowScale


        // Performance optimization: auto-padding management
        autoPaddingEnabled:false // snapableParameters.displayParameter.effectShadowEnabled
    }

    // --- Functions ---
    function isTransparent(mouse){

        var deltaHeight = tileImage.height - tileImage.paintedHeight
        var deltaWidth = tileImage.width - tileImage.paintedWidth

        var imageX = mouse.x - deltaWidth/2
        var imageY = mouse.y - deltaHeight/2

        var flag = AssetManager.isTransparent(tileImage.paintedWidth/imageX, tileImage.paintedHeight/imageY, imagePath)

        return flag;
    }
}
