import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import "snapable"
import AssetManager
import ItemSnapable

SnapableElement {
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    displaySettings.unitSizeHeight: 6
    displaySettings.unitSizeWidth:4

    type : ItemSnapable.DecorationTile

    property string decorationType: "grass"  // Can be "grass" or "tree"
    property var decorationModel : AssetManager.getTypeModel("decoration", decorationType)
    property string decorationId: Math.floor(Math.random() * decorationModel.rowCount())
    property string imagePath: AssetManager.getDecorationPath(decorationType, decorationId)
    
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
                                           
    // Performance optimization: only create MultiEffect when needed
    readonly property bool shouldCreateEffect: hasActiveEffects

    Component.onCompleted: {
        console.log("Decoration created with model:", decorationModel)
        console.log("model length:", decorationModel.rowCount())
    }

    Image {
        id: tileImage
        anchors.fill: parent
        source: imagePath
        z: 1  // Assurer que le contenu est sous les poignées
        asynchronous: true
        cache: true  // Cache the image to prevent reloading
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down
        
        // Hide source image when effects are applied for optimal performance
        visible: !hasActiveEffects

        onStatusChanged: {
            if (status === Image.Error) {
                console.log("AssetManager path failed, falling back to legacy system")
            }
        }
    }
    
    // MultiEffect component - only visible when effects are active
    MultiEffect {
        id: multiEffect
        anchors.fill: parent
        source: tileImage
        z: 2  // Above the source image but below handles
        visible: shouldCreateEffect
        
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
        autoPaddingEnabled: displaySettings.effectBlurEnabled || displaySettings.effectShadowEnabled
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
}
