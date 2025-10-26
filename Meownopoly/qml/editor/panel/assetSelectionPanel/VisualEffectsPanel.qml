import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


Rectangle {
    id: root
    
    // Properties for the target decoration element
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
        
        // Title with mirror buttons and lock button
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
            
            VEP_ButtonMirror {
                id: horizontalMirrorButton
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                isHorizontal: true
                isMirrored: transformSection.horizontalMirrorCheck.checked
                onClicked: {
                    transformSection.horizontalMirrorCheck.checked = !transformSection.horizontalMirrorCheck.checked
                }
            }
            
            VEP_ButtonMirror {
                id: verticalMirrorButton
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                isHorizontal: false
                isMirrored: transformSection.verticalMirrorCheck.checked
                onClicked: {
                    transformSection.verticalMirrorCheck.checked = !transformSection.verticalMirrorCheck.checked
                }
            }
            
            VEP_ButtonLock {
                id: lockButton
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                effectsLocked: root.effectsLocked
                onClicked: root.effectsLocked = !root.effectsLocked
            }
        }
        
        VEP_ColorEffectsSection {
            id: colorEffectsSection
            anchors.left: parent.left
            anchors.right: parent.right

            onEffectChanged: {
                root.effectChanged()
            }
        }

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

    function updateFromDisplayParameter(dispParam) {
        console.log("update from disp")
      if (root.effectsLocked) return
        
        // Update sliders from target values
        colorEffectsSection.brightnessSlider.value = dispParam.effectBrightness
        colorEffectsSection.contrastSlider.value = dispParam.effectContrast
        colorEffectsSection.saturationSlider.value = dispParam.effectSaturation
        colorEffectsSection.colorizationSlider.value = dispParam.effectColorization

    }

}
