import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


Rectangle {
    id: root
    
    // Properties for the target decoration element
    property var targetDecoration: null
    
    // Visual properties
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1
    
    // Dimensions
    height: mainLayout.implicitHeight + 12
    width: mainLayout.implicitWidth
    
    // Signals
    signal effectChanged()
    
    // Main layout
    Column {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 10
        
        // Title
        Text {
            id: title
            text: "Visual Effects"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            anchors.left: parent.left
            anchors.right: parent.right
        }
        
        VEP_ColorEffectsSection {
            id: colorEffectsSection
            anchors.left: parent.left
            anchors.right: parent.right
            targetDecoration: root.targetDecoration

            onEffectChanged: {
                root.effectChanged()
            }
        }

        // Advanced Effects Section
        VEP_AdvancedEffectsSection {
            id: advancedEffectsSection
            anchors.left: parent.left
            anchors.right: parent.right
            targetDecoration: root.targetDecoration

            onEffectChanged: {
                root.effectChanged()
            }
        }
        
        // Reset buttons panel
        VEP_ResetButtonsPanel {
            id: resetButtonsPanel
            anchors.left: parent.left
            anchors.right: parent.right
            targetDecoration: root.targetDecoration
            
            onEffectChanged: {
                updateFromTarget()
                root.effectChanged()
            }
        }

    }
    
    // Functions
    function updateFromTarget() {
        if (!targetDecoration) return
        
        // Update sliders from target values
        colorEffectsSection.brightnessSlider.value = targetDecoration.effectBrightness
        colorEffectsSection.contrastSlider.value = targetDecoration.effectContrast
        colorEffectsSection.saturationSlider.value = targetDecoration.effectSaturation
        colorEffectsSection.colorizationSlider.value = targetDecoration.effectColorization
        
        // Update checkboxes
        advancedEffectsSection.blurEnabledCheck.checked = targetDecoration.effectBlurEnabled
        advancedEffectsSection.shadowEnabledCheck.checked = targetDecoration.effectShadowEnabled
        
        // Update blur/shadow sliders
        advancedEffectsSection.blurSlider.value = targetDecoration.effectBlur
        advancedEffectsSection.shadowBlurSlider.value = targetDecoration.effectShadowBlur
    }
    
    onTargetDecorationChanged: {
        updateFromTarget()
    }
}
