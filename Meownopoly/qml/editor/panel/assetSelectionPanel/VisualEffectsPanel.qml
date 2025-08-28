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
        colorEffectsSection.brightnessSlider.value = targetDecoration.displaySettings.effectBrightness
        colorEffectsSection.contrastSlider.value = targetDecoration.displaySettings.effectContrast
        colorEffectsSection.saturationSlider.value = targetDecoration.displaySettings.effectSaturation
        colorEffectsSection.colorizationSlider.value = targetDecoration.displaySettings.effectColorization
        
        // Update checkboxes
        advancedEffectsSection.blurEnabledCheck.checked = targetDecoration.displaySettings.effectBlurEnabled
        advancedEffectsSection.shadowEnabledCheck.checked = targetDecoration.displaySettings.effectShadowEnabled
        
        // Update blur/shadow sliders
        advancedEffectsSection.blurSlider.value = targetDecoration.displaySettings.effectBlur
        advancedEffectsSection.shadowBlurSlider.value = targetDecoration.displaySettings.effectShadowBlur
    }
    
    onTargetDecorationChanged: {
        updateFromTarget()
    }
}
