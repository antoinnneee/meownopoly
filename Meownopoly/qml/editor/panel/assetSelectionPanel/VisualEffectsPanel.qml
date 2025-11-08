import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


GroupBox {
    id: root
    title: "Visual Effects"
    
    // Properties for the target decoration element
    property bool effectsLocked: false
    property bool isCollapsed: false
    
    // Dimensions
    height: (isCollapsed ? Screen.pixelDensity * 12 : mainLayout.implicitHeight +  Screen.pixelDensity * 12)
    
    // Signals
    signal effectChanged()
    
    padding: 4
    spacing: 2
    
    background: Rectangle {
        color: "#2a2a2a"
        radius: 8
        border.color: "#444444"
        border.width: 1
    }
    
    label: RowLayout {
        x: root.leftPadding
        width: root.availableWidth
        spacing: 8
        
        Text {
            text: root.title
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        
        Button {
            id: collapseButton
            Layout.preferredWidth: Screen.pixelDensity * 8
            Layout.preferredHeight: Screen.pixelDensity * 8
            flat: true
            
            background: Rectangle {
                color: "transparent"
                border.color: "#666666"
                border.width: 1
                radius: 2
            }
            
            contentItem: Text {
                text: root.isCollapsed ? "▼" : "▲"
                color: "#cccccc"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                root.isCollapsed = !root.isCollapsed
            }
        }
    }
    
    // Main layout
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: -4
        spacing: 10
        visible: !root.isCollapsed
        
        VEP_ColorEffectsSection {
            id: colorEffectsSection
            Layout.fillWidth: true

            onEffectChanged: {
                root.effectChanged()
            }
        }

        VEP_AdvancedEffectsSection{
            Layout.fillWidth: true
            onEffectChanged: {
                root.effectChanged()
            }
        }

        VEP_Rotation{
            Layout.fillWidth: true
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
      if (root.effectsLocked) return
        
        // Update sliders from target values
        colorEffectsSection.brightnessSlider.value = dispParam.effectBrightness
        colorEffectsSection.contrastSlider.value = dispParam.effectContrast
        colorEffectsSection.saturationSlider.value = dispParam.effectSaturation
        colorEffectsSection.colorizationSlider.value = dispParam.effectColorization

    }

}
