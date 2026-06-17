import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs

import QtQuick.Controls.impl
import ui_item
import theme

CollapsableGroupBox {
    id: control
    title: "Advanced Effects"
    
    property alias blurSlider: blurSlider
    property alias blurEnabledCheck: blurEnabledCheck
    property alias shadowBlurSlider: shadowBlurSlider
    property alias shadowEnabledCheck: shadowEnabledCheck


    signal effectChanged()


    function updateFromDisplayParameter(dispParam) {
        // // Update checkboxes
         blurEnabledCheck.checked = dispParam.effectBlurEnabled
         shadowEnabledCheck.checked = dispParam.effectShadowEnabled

        // // Update blur/shadow sliders
        blurSlider.value = dispParam.effectBlur
        shadowBlurSlider.value = dispParam.effectShadowBlur
    }


    content: [
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            MeowCheckBox {
                id: blurEnabledCheck
                Layout.fillHeight: true
                accentColor: Theme.success

                onCheckedChanged: {
                        control.effectChanged()
                }
            }
            
            VEP_Slider {
                id: blurSlider
                Layout.fillWidth: true
                Layout.fillHeight: true
                sliderText: "Blur:"
                from: 0
                to: 1
                onEffectChanged: function(value) {
                        control.effectChanged()
                }
            }

        },
        // Shadow effect
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            
            MeowCheckBox {
                id: shadowEnabledCheck
                Layout.fillHeight: true
                accentColor: Theme.success

                onCheckedChanged: {
                    control.effectChanged()
                }
            }
            
            VEP_Slider {
                id: shadowBlurSlider
                Layout.fillHeight: true
                Layout.fillWidth: true
                sliderText: "Shadow Blur:"
                from: 0
                to: 1
                onEffectChanged: function(value) {
                        control.effectChanged()
                }
            }
        }
    ]
}
