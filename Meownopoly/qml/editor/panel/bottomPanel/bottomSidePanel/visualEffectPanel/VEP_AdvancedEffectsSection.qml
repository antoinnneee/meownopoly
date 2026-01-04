import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs

import QtQuick.Controls.impl
import ui_item

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

        console.log("Advanced Effects blur : ", dispParam.effectBlur)
        console.log("Advanced Effects effectShadowBlur : ", dispParam.effectShadowBlur)
        // // Update blur/shadow sliders
        blurSlider.value = dispParam.effectBlur
        shadowBlurSlider.value = dispParam.effectShadowBlur
    }


    content: [
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            CheckBox {
                id: blurEnabledCheck
                Layout.fillHeight: true

                onCheckedChanged: {
                        control.effectChanged()
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20

                    x: blurEnabledCheck.text ? (blurEnabledCheck.mirrored ? blurEnabledCheck.width - width - blurEnabledCheck.rightPadding : blurEnabledCheck.leftPadding) : blurEnabledCheck.leftPadding + (blurEnabledCheck.availableWidth - width) / 2
                    y: blurEnabledCheck.topPadding + (blurEnabledCheck.availableHeight - height) / 2
                    color: blurEnabledCheck.checked ? "#4CAF50" : "#444444"
                    border.width: blurEnabledCheck.visualFocus ? 2 : 1
                    border.color:  "#666666" 
                    radius: 3

                    ColorImage {
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
                        defaultColor: "#cfd0d1"
                        color: blurEnabledCheck.palette.text
                        source: "qrc:/qt-project.org/imports/QtQuick/Controls/Basic/images/check.png"
                        visible: blurEnabledCheck.checkState === Qt.Checked
                    }
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
            
            CheckBox {
                id: shadowEnabledCheck

                Layout.fillHeight: true
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20

                    x: shadowEnabledCheck.text ? (shadowEnabledCheck.mirrored ? shadowEnabledCheck.width - width - shadowEnabledCheck.rightPadding : shadowEnabledCheck.leftPadding) : shadowEnabledCheck.leftPadding + (shadowEnabledCheck.availableWidth - width) / 2
                    y: shadowEnabledCheck.topPadding + (shadowEnabledCheck.availableHeight - height) / 2
                    color: shadowEnabledCheck.checked ? "#4CAF50" : "#444444"
                    border.width: shadowEnabledCheck.visualFocus ? 2 : 1
                    border.color:  "#666666" 
                    radius: 3

                    ColorImage {
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
                        defaultColor: "#cfd0d1"
                        color: shadowEnabledCheck.palette.text
                        source: "qrc:/qt-project.org/imports/QtQuick/Controls/Basic/images/check.png"
                        visible: shadowEnabledCheck.checkState === Qt.Checked
                    }
                }

                
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
