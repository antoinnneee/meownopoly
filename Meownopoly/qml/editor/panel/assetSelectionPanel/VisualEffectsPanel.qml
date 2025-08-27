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
    implicitHeight: mainLayout.implicitHeight + 20
    
    // Signals
    signal effectChanged()
    
    // Main layout
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Title
        Text {
            text: "Visual Effects"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }
        
        VEP_ColorEffectsSection {
            id: colorEffectsSection
            Layout.fillHeight: true
            Layout.fillWidth: true
            targetDecoration: root.targetDecoration

            onEffectChanged: {
                root.effectChanged()
            }
        }

        // Advanced Effects Section
        VEP_AdvancedEffectsSection {
            id: advancedEffectsSection
            Layout.fillHeight: true
            Layout.fillWidth: true
            targetDecoration: root.targetDecoration

            onEffectChanged: {
                root.effectChanged()
            }
        }
        
        // Reset all button
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: "Reset Color Effects"
                Layout.fillWidth: true
                
                onClicked: {
                    if (targetDecoration) {
                        targetDecoration.resetColorEffects()
                        updateFromTarget()
                        effectChanged()
                    }
                }
                
                background: Rectangle {
                    color: parent.pressed ? "#666666" : "#555555"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#cccccc"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                text: "Reset All Effects"
                Layout.fillWidth: true
                
                onClicked: {
                    if (targetDecoration) {
                        targetDecoration.resetAllEffects()
                        updateFromTarget()
                        effectChanged()
                    }
                }
                
                background: Rectangle {
                    color: parent.pressed ? "#ff6666" : "#ff4444"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
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
