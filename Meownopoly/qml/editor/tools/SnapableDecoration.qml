import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import "snapable"
import AssetManager
import ItemSnapable
import DecorationParameter

SnapableElement {
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    displaySettings.unitSizeHeight: 6
    displaySettings.unitSizeWidth:4

    type : ItemSnapable.DecorationTile

    property string imagePath: AssetManager.getAssetPath(decorationSettings.decorationCategory, decorationSettings.decorationType, decorationSettings.decorationId)

    // MultiEffect properties - Color effects (always enabled)
    displaySettings.effectBrightness: 0.0
    displaySettings.effectContrast: 0.0
    displaySettings.effectSaturation: 0.0
    displaySettings.effectColorization: 0.0
    displaySettings.effectColorizationColor: "#ffffff"

    // MultiEffect properties - Optional effects
    displaySettings.effectBlurEnabled: false
    displaySettings.effectBlur: 0.0           // 0.0 to 1.0
    displaySettings.effectBlurMax: 32
    displaySettings.effectBlurMultiplier: 1.0

    displaySettings.effectShadowEnabled: false
    displaySettings.effectShadowBlur: 1.0
    displaySettings.effectShadowColor: Qt.rgba(0.0, 0.0, 0.0, 1.0)
    displaySettings.effectShadowHorizontalOffset: 0.0
    displaySettings.effectShadowVerticalOffset: 0.0
    displaySettings.effectShadowOpacity: 1.0
    displaySettings.effectShadowScale: 1.0

    // Rotation properties
    displaySettings.rotationAngle: 0.0

    // Mirror properties
    displaySettings.mirrorHorizontal: false
    displaySettings.mirrorVertical: false

    property bool effectMaskEnabled: false
    property var effectMaskSource: null
    property bool effectMaskInverted: false
    property real effectMaskThresholdMin: 0.0
    property real effectMaskThresholdMax: 1.0
    property real effectMaskSpreadAtMin: 0.0
    property real effectMaskSpreadAtMax: 0.0

    // Helper function to check if any effect is active
    readonly property bool hasActiveEffects: displaySettings.effectBrightness !== 0.0 ||
                                             displaySettings.effectContrast !== 0.0 ||
                                             displaySettings.effectSaturation !== 0.0 ||
                                             displaySettings.effectColorization !== 0.0 ||
                                             displaySettings.effectBlurEnabled ||
                                             displaySettings.effectShadowEnabled ||
                                             effectMaskEnabled

    // Helper function to check if any transform is active
    readonly property bool hasActiveTransforms: displaySettings.rotationAngle !== 0.0 ||
                                                displaySettings.mirrorHorizontal ||
                                                displaySettings.mirrorVertical

    // Performance optimization: only create MultiEffect when needed
    readonly property bool shouldCreateEffect: hasActiveEffects


    AnimatedImage {
        id: tileImage
        anchors.fill: parent
        source: decorationSettings.getAnimePath(imagePath)
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
                xScale: displaySettings.mirrorHorizontal ? -1 : 1
                yScale: displaySettings.mirrorVertical ? -1 : 1
                origin.x: tileImage.width / 2
                origin.y: tileImage.height / 2
            },
            Rotation{
                angle: displaySettings.rotationAngle
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
                xScale: displaySettings.mirrorHorizontal ? -1 : 1
                yScale: displaySettings.mirrorVertical ? -1 : 1
                origin.x: multiEffect.width / 2
                origin.y: multiEffect.height / 2
            },
            Rotation{
                angle: displaySettings.rotationAngle
                origin.x: multiEffect.width / 2
                origin.y: multiEffect.height / 2
            }
        ]

        // Color effects (always available)
        brightness: displaySettings.effectBrightness
        contrast: displaySettings.effectContrast
        saturation: displaySettings.effectSaturation
        colorization: displaySettings.effectColorization
        colorizationColor: displaySettings.effectColorizationColor

        // Blur effect
        blurEnabled: displaySettings.effectBlurEnabled
        blur: displaySettings.effectBlur
        blurMax: displaySettings.effectBlurMax
        blurMultiplier: displaySettings.effectBlurMultiplier

        // Shadow effect
        shadowEnabled: displaySettings.effectShadowEnabled
        shadowBlur: displaySettings.effectShadowBlur
        shadowColor: displaySettings.effectShadowColor
        shadowHorizontalOffset: displaySettings.effectShadowHorizontalOffset
        shadowVerticalOffset: displaySettings.effectShadowVerticalOffset
        shadowOpacity: displaySettings.effectShadowOpacity
        shadowScale: displaySettings.effectShadowScale

        // Mask effect ??
        maskEnabled: effectMaskEnabled
        maskSource: effectMaskSource
        maskInverted: effectMaskInverted
        maskThresholdMin: effectMaskThresholdMin
        maskThresholdMax: effectMaskThresholdMax
        maskSpreadAtMin: effectMaskSpreadAtMin
        maskSpreadAtMax: effectMaskSpreadAtMax

        // Performance optimization: auto-padding management
        autoPaddingEnabled: false//displaySettings.effectBlurEnabled || displaySettings.effectShadowEnabled
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
        displaySettings.effectBrightness = 0.0
        displaySettings.effectContrast = 0.0
        displaySettings.effectSaturation = 0.0
        displaySettings.effectColorization = 0.0
        displaySettings.effectColorizationColor = "#ffffff"
    }

    function resetBlurEffect() {
        displaySettings.effectBlurEnabled = false
        displaySettings.effectBlur = 0.0
        displaySettings.effectBlurMax = 32
        displaySettings.effectBlurMultiplier = 1.0
    }

    function resetShadowEffect() {
        displaySettings.effectShadowEnabled = false
        displaySettings.effectShadowBlur = 1.0
        displaySettings.effectShadowColor = Qt.rgba(0.0, 0.0, 0.0, 1.0)
        displaySettings.effectShadowHorizontalOffset = 0.0
        displaySettings.effectShadowVerticalOffset = 0.0
        displaySettings.effectShadowOpacity = 1.0
        displaySettings.effectShadowScale = 1.0
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
        displaySettings.rotationAngle = 0.0
    }

    function resetMirror() {
        displaySettings.mirrorHorizontal = false
        displaySettings.mirrorVertical = false
    }

    function resetAllTransforms() {
        resetRotation()
        resetMirror()
    }

    function applyVisualEffects(effects)    // generate from VisualEffectsPanel@getCurrentEffects()
    {
        // Apply color effects
        displaySettings.effectBrightness = effects.brightness
        displaySettings.effectContrast = effects.contrast
        displaySettings.effectSaturation = effects.saturation
        displaySettings.effectColorization = effects.colorization
        displaySettings.effectColorizationColor = effects.colorizationColor

        // Apply advanced effects
        displaySettings.effectBlurEnabled = effects.blurEnabled
        displaySettings.effectBlur = effects.blur
        displaySettings.effectShadowEnabled = effects.shadowEnabled
        displaySettings.effectShadowBlur = effects.shadowBlur

        // Apply transform effects
        displaySettings.rotationAngle = effects.rotationAngle
        displaySettings.mirrorHorizontal = effects.mirrorHorizontal
        displaySettings.mirrorVertical = effects.mirrorVertical
    }
}
