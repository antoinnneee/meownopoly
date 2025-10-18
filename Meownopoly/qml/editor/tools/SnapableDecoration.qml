import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import "snapable"
import AssetManager
import ItemSnapable
import DecorationParameter
import TileType
SnapableElement {
    id: root
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true


    connectionManager.onNextElementAdded:function(element) {
        if (root.blockConnections) return
        console.log("Next element added:", element)
        // Synchroniser avec les données C++ : ajouter la case suivante
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.addNext(element.snapableParameters)
            console.log("Added next case:", element.snapableParameters.caseData.name, "to", root.snapableParameters.caseData.name)
        }
    }
    connectionManager.onPreviousElementAdded:function(element) {
        if (root.blockConnections) return
        console.log("Previous element added:", element)
        // Synchroniser avec les données C++ : ajouter la case précédente
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.addPrev(element.snapableParameters)
            console.log("Added previous case:", element.snapableParameters.caseData.name, "to", root.snapableParameters.caseData.name)
        }
    }
    connectionManager.onNextElementRemoved:function(element) {
        if (root.blockConnections) return
        console.log("Next element removed:", element)
        // Synchroniser avec les données C++ : supprimer la case suivante
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.removeNext(element.snapableParameters)
            console.log("Removed next case:", element.snapableParameters.caseData.name, "from", root.snapableParameters.caseData.name)
        }
    }
    connectionManager.onPreviousElementRemoved:function(element) {
        if (root.blockConnections) return
        console.log("Previous element removed:", element)
        // Synchroniser avec les données C++ : supprimer la case précédente
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.removePrev(element.snapableParameters)
            console.log("Removed previous case:", element.snapableParameters.caseData.name, "from", root.snapableParameters.caseData.name)
        }
    }

    Component.onCompleted: {
        // Synchroniser les connexions existantes depuis les données C++ vers l'interface
        syncConnectionsFromCaseData()
    }

    // Fonction pour synchroniser les connexions depuis les données C++ vers l'interface QML
    function syncConnectionsFromCaseData() {
        if (!root.snapableParameters) return

        // Cette fonction pourrait être appelée pour synchroniser les connexions existantes
        // depuis les données C++ vers l'interface QML si nécessaire
        console.log("Syncing connections for case:", root.snapableParameters.caseData.name)
        console.log("- Next cases count:", root.snapableParameters.next ? root.snapableParameters.next.length : 0)
        console.log("- Previous cases count:", root.snapableParameters.prev ? root.snapableParameters.prev.length : 0)
    }

    property string imagePath: AssetManager.getAssetPath(snapableParameters.decorationParameter.decorationCategory, snapableParameters.decorationParameter.decorationType, snapableParameters.decorationParameter.decorationId)

    property bool effectMaskEnabled: false
    property var effectMaskSource: null
    property bool effectMaskInverted: false
    property real effectMaskThresholdMin: 0.0
    property real effectMaskThresholdMax: 1.0
    property real effectMaskSpreadAtMin: 0.0
    property real effectMaskSpreadAtMax: 0.0

    // Helper function to check if any effect is active
    readonly property bool hasActiveEffects: snapableParameters.displayParameter.effectBrightness !== 0.0 ||
                                             snapableParameters.displayParameter.effectContrast !== 0.0 ||
                                             snapableParameters.displayParameter.effectSaturation !== 0.0 ||
                                             snapableParameters.displayParameter.effectColorization !== 0.0 ||
                                             snapableParameters.displayParameter.effectBlurEnabled ||
                                             snapableParameters.displayParameter.effectShadowEnabled ||
                                             effectMaskEnabled

    // Helper function to check if any transform is active
    readonly property bool hasActiveTransforms: snapableParameters.displayParameter.rotationAngle !== 0.0 ||
                                                snapableParameters.displayParameter.mirrorHorizontal ||
                                                snapableParameters.displayParameter.mirrorVertical

    // Performance optimization: only create MultiEffect when needed
    readonly property bool shouldCreateEffect: hasActiveEffects


    AnimatedImage {
        id: tileImage
        anchors.fill: parent
        source: snapableParameters.decorationParameter.getAnimePath(imagePath)
        z: 1  // Assurer que le contenu est sous les poignées
        asynchronous: true
        cache: true  // Cache the image to prevent reloading
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

        // Mask effect ??
        maskEnabled: effectMaskEnabled
        maskSource: effectMaskSource
        maskInverted: effectMaskInverted
        maskThresholdMin: effectMaskThresholdMin
        maskThresholdMax: effectMaskThresholdMax
        maskSpreadAtMin: effectMaskSpreadAtMin
        maskSpreadAtMax: effectMaskSpreadAtMax

        // Performance optimization: auto-padding management
        autoPaddingEnabled: false//displayParameter.effectBlurEnabled || displayParameter.effectShadowEnabled
    }

    function isTransparent(mouse){

        var deltaHeight = tileImage.height - tileImage.paintedHeight
        var deltaWidth = tileImage.width - tileImage.paintedWidth

        var imageX = mouse.x - deltaWidth/2
        var imageY = mouse.y - deltaHeight/2

        var flag = AssetManager.isTransparent(tileImage.paintedWidth/imageX, tileImage.paintedHeight/imageY, imagePath)

        return flag;
    }

    // Functions to reset effects
    function resetColorEffects() {
        snapableParameters.displayParameter.effectBrightness = 0.0
        snapableParameters.displayParameter.effectContrast = 0.0
        snapableParameters.displayParameter.effectSaturation = 0.0
        snapableParameters.displayParameter.effectColorization = 0.0
        snapableParameters.displayParameter.effectColorizationColor = "#ffffff"
    }

    function resetBlurEffect() {
        snapableParameters.displayParameter.effectBlurEnabled = false
        snapableParameters.displayParameter.effectBlur = 0.0
        snapableParameters.displayParameter.effectBlurMax = 32
        snapableParameters.displayParameter.effectBlurMultiplier = 1.0
    }

    function resetShadowEffect() {
        snapableParameters.displayParameter.effectShadowEnabled = false
        snapableParameters.displayParameter.effectShadowBlur = 1.0
        snapableParameters.displayParameter.effectShadowColor = Qt.rgba(0.0, 0.0, 0.0, 1.0)
        snapableParameters.displayParameter.effectShadowHorizontalOffset = 0.0
        snapableParameters.displayParameter.effectShadowVerticalOffset = 0.0
        snapableParameters.displayParameter.effectShadowOpacity = 1.0
        snapableParameters.displayParameter.effectShadowScale = 1.0
    }

    function resetMaskEffect() {
        effectMaskEnabled = false
        effectMaskSource = null
        effectMaskInverted = false
        effectMaskThresholdMin = 0.0
        effectMaskThresholdMax = 1.0
        effectMaskSpreadAtMin = 0.0
        effectMaskSpreadAtMax = 0.0
    }

    function resetAllEffects() {
        resetColorEffects()
        resetBlurEffect()
        resetShadowEffect()
        resetMaskEffect()
    }

    // Functions to reset transforms
    function resetRotation() {
        snapableParameters.displayParameter.rotationAngle = 0.0
    }

    function resetMirror() {
        snapableParameters.displayParameter.mirrorHorizontal = false
        snapableParameters.displayParameter.mirrorVertical = false
    }

    function resetAllTransforms() {
        resetRotation()
        resetMirror()
    }

    function applyVisualEffects(effects)    // generate from VisualEffectsPanel@getCurrentEffects()
    {
        // Apply color effects
        snapableParameters.displayParameter.effectBrightness = effects.brightness
        snapableParameters.displayParameter.effectContrast = effects.contrast
        snapableParameters.displayParameter.effectSaturation = effects.saturation
        snapableParameters.displayParameter.effectColorization = effects.colorization
        snapableParameters.displayParameter.effectColorizationColor = effects.colorizationColor

        // Apply advanced effects
        snapableParameters.displayParameter.effectBlurEnabled = effects.blurEnabled
        snapableParameters.displayParameter.effectBlur = effects.blur
        snapableParameters.displayParameter.effectShadowEnabled = effects.shadowEnabled
        snapableParameters.displayParameter.effectShadowBlur = effects.shadowBlur

        // Apply transform effects
        snapableParameters.displayParameter.rotationAngle = effects.rotationAngle
        snapableParameters.displayParameter.mirrorHorizontal = effects.mirrorHorizontal
        snapableParameters.displayParameter.mirrorVertical = effects.mirrorVertical
    }
}
