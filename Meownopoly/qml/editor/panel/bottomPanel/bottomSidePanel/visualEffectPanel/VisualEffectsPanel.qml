import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs
import ui_item


CollapsableGroupBox {
    id: root
    title: "Visual Effects"
    
    // Properties for the target decoration element
    property bool effectsLocked: false
    property alias colorEffectsSection: colorEffectsSection
    
    // Signals
    signal effectChanged()
    font.pointSize: 18
    
    // Main layout
    content: [
        VEP_ColorEffectsSection {
            isCollapsed : true
            id: colorEffectsSection
            Layout.fillWidth: true

            onEffectChanged: {
                root.effectChanged()
            }
        },

        VEP_AdvancedEffectsSection{
            id: advancedEffectsSection
            isCollapsed : true
            Layout.fillWidth: true
            onEffectChanged: {
                root.effectChanged()
            }
        },

        VEP_Rotation{
            id: rotationSection
            isCollapsed : true
            Layout.fillWidth: true
            onEffectChanged: {
                root.effectChanged()
            }
        }
    ]


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
            rotationAngle: rotationSection.rotationSlider.value,
            mirrorHorizontal: false, //rotationSection.horizontalMirrorCheck.checked,
            mirrorVertical: false //rotationSection.verticalMirrorCheck.checked
        }

        return effects
    }

    function updateFromDisplayParameter(dispParam) {
      if (root.effectsLocked) return


        // Update sliders from target values
        colorEffectsSection.brightnessSlider.value = dispParam.effectBrightness
        colorEffectsSection.contrastSlider.value = dispParam.effectContrast
        colorEffectsSection.saturationSlider.value = dispParam.effectSaturation
        colorEffectsSection.colorizationSlider.value = dispParam.effectColorization

        // Update advanced effects (blur and shadow)
        advancedEffectsSection.updateFromDisplayParameter(dispParam)

        // Update rotation
        rotationSection.rotationSlider.value = dispParam.rotationAngle

    }

}
