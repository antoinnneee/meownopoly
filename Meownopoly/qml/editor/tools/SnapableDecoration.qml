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

    unitSizeHeight: 6
    unitSizeWidth:4

    type : ItemSnapable.DecorationTile

    property string decorationType: "grass"  // Can be "grass" or "tree"
    property var decorationModel : AssetManager.getTypeModel("decoration", decorationType)
    property string decorationId: Math.floor(Math.random() * decorationModel.rowCount())
    property string imagePath: AssetManager.getDecorationPath(decorationType, decorationId)
    
    // MultiEffect properties - Color effects (always enabled)
    property real effectBrightness: 0.0     // -1.0 to 1.0
    property real effectContrast: 0.0       // 0.0 to inf
    property real effectSaturation: 0.0     // -1.0 to inf
    property real effectColorization: 0.0   // 0.0 to 1.0
    property color effectColorizationColor: "#ffffff"
    
    // MultiEffect properties - Optional effects
    property bool effectBlurEnabled: false
    property real effectBlur: 0.0           // 0.0 to 1.0
    property int effectBlurMax: 32
    property real effectBlurMultiplier: 1.0
    
    property bool effectShadowEnabled: false
    property real effectShadowBlur: 1.0
    property color effectShadowColor: Qt.rgba(0.0, 0.0, 0.0, 1.0)
    property real effectShadowHorizontalOffset: 0.0
    property real effectShadowVerticalOffset: 0.0
    property real effectShadowOpacity: 1.0
    property real effectShadowScale: 1.0
    
    property bool effectMaskEnabled: false
    property var effectMaskSource: null
    property bool effectMaskInverted: false
    property real effectMaskThresholdMin: 0.0
    property real effectMaskThresholdMax: 1.0
    property real effectMaskSpreadAtMin: 0.0
    property real effectMaskSpreadAtMax: 0.0
    
    // Helper function to check if any effect is active
    readonly property bool hasActiveEffects: effectBrightness !== 0.0 || 
                                           effectContrast !== 0.0 || 
                                           effectSaturation !== 0.0 || 
                                           effectColorization !== 0.0 ||
                                           effectBlurEnabled || 
                                           effectShadowEnabled || 
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
        brightness: effectBrightness
        contrast: effectContrast
        saturation: effectSaturation
        colorization: effectColorization
        colorizationColor: effectColorizationColor
        
        // Blur effect
        blurEnabled: effectBlurEnabled
        blur: effectBlur
        blurMax: effectBlurMax
        blurMultiplier: effectBlurMultiplier
        
        // Shadow effect
        shadowEnabled: effectShadowEnabled
        shadowBlur: effectShadowBlur
        shadowColor: effectShadowColor
        shadowHorizontalOffset: effectShadowHorizontalOffset
        shadowVerticalOffset: effectShadowVerticalOffset
        shadowOpacity: effectShadowOpacity
        shadowScale: effectShadowScale
        
        // Mask effect
        maskEnabled: effectMaskEnabled
        maskSource: effectMaskSource
        maskInverted: effectMaskInverted
        maskThresholdMin: effectMaskThresholdMin
        maskThresholdMax: effectMaskThresholdMax
        maskSpreadAtMin: effectMaskSpreadAtMin
        maskSpreadAtMax: effectMaskSpreadAtMax
        
        // Performance optimization: auto-padding management
        autoPaddingEnabled: effectBlurEnabled || effectShadowEnabled
    }
    
    // Functions to reset effects
    function resetColorEffects() {
        effectBrightness = 0.0
        effectContrast = 0.0
        effectSaturation = 0.0
        effectColorization = 0.0
        effectColorizationColor = "#ffffff"
    }
    
    function resetBlurEffect() {
        effectBlurEnabled = false
        effectBlur = 0.0
        effectBlurMax = 32
        effectBlurMultiplier = 1.0
    }
    
    function resetShadowEffect() {
        effectShadowEnabled = false
        effectShadowBlur = 1.0
        effectShadowColor = Qt.rgba(0.0, 0.0, 0.0, 1.0)
        effectShadowHorizontalOffset = 0.0
        effectShadowVerticalOffset = 0.0
        effectShadowOpacity = 1.0
        effectShadowScale = 1.0
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
