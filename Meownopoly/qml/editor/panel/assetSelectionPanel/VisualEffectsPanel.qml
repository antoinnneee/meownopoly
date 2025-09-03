import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


Rectangle {
    id: root
    
    // Properties for the target decoration element
    property var targetDecoration: null
    property bool effectsLocked: false
    
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
        
        // Title with lock button
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 10

            Text {
                id: title
                text: "Visual Effects"
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                id: lockButton
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                color: root.effectsLocked ? "#4a4a4a" : "#3a3a3a"
                border.color: "#666666"
                border.width: 1
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: root.effectsLocked ? "🔒" : "🔓"
                    font.pixelSize: 16
                }

                MouseArea {
                    id: lockMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: lockButton.opacity = 0.8
                    onExited: lockButton.opacity = 1.0
                    onClicked: root.toggleLock()
                }

                ToolTip {
                    visible: lockMouseArea.containsMouse
                    text: root.effectsLocked ? "Déverrouiller les effets visuels" : "Verrouiller les effets visuels"
                }
            }
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
        
        // // Transform Section
        VEP_TransformSection {
            id: transformSection
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
                root.updateFromTarget()
                root.effectChanged()
            }
        }

    }
    
    // Functions
    function toggleLock() {
        root.effectsLocked = !root.effectsLocked
    }

    function getCurrentEffects() {
        var effects = {
            // Color effects
            brightness: colorEffectsSection.brightnessSlider.value,
            contrast: colorEffectsSection.contrastSlider.value,
            saturation: colorEffectsSection.saturationSlider.value,
            colorization: colorEffectsSection.colorizationSlider.value,
            colorizationColor: colorEffectsSection.colorPresets.length > 0 &&
                              colorEffectsSection.activePresetIndex >= 0 ?
                              colorEffectsSection.colorPresets[colorEffectsSection.activePresetIndex].color : "#ffffff",

            // Advanced effects
            blurEnabled: advancedEffectsSection.blurEnabledCheck.checked,
            blur: advancedEffectsSection.blurSlider.value,
            shadowEnabled: advancedEffectsSection.shadowEnabledCheck.checked,
            shadowBlur: advancedEffectsSection.shadowBlurSlider.value,

            // Transform effects
            rotationAngle: transformSection.rotationSlider.value,
            mirrorHorizontal: transformSection.horizontalMirrorCheck.checked,
            mirrorVertical: transformSection.verticalMirrorCheck.checked
        }
        return effects
    }

    function updateFromTarget() {
        if (!targetDecoration || root.effectsLocked) return
        
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
        
        // Update transform section
        transformSection.updateFromTarget()
    }
    
    onTargetDecorationChanged: {
        updateFromTarget()
    }
}
