import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

GroupBox {
    title: "Color Effects"
    id: control

    property var targetDecoration: null
    property alias brightnessSlider: brightnessSlider
    property alias contrastSlider: contrastSlider
    property alias saturationSlider: saturationSlider
    property alias colorizationSlider: colorizationSlider

    signal effectChanged()
    padding:4
    spacing: 2

    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }
    
    label: Text {
        color: "#cccccc"
        x: control.leftPadding
        width: control.availableWidth
        text: control.title
        elide: Text.ElideRight
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: -4
        spacing: 1
        
        // Brightness control
        VEP_Slider {
            id: brightnessSlider

            Layout.topMargin: 0
            Layout.fillWidth: true
            sliderText: "Brightness:"
            onEffectChanged: function(value) {
                if (targetDecoration) {
                    targetDecoration.effectBrightness = value
                    control.effectChanged()
                }
            }
        }

        // Contrast control
        VEP_Slider {
            id: contrastSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Contrast:"
            onEffectChanged: function(value) {
                if (targetDecoration) {
                    targetDecoration.effectContrast = value
                    control.effectChanged()
                }
            }
        }
        
        // Saturation control
        VEP_Slider {
            id: saturationSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Saturation:"
            onEffectChanged: function(value) {
                if (targetDecoration) {
                    targetDecoration.effectSaturation = value
                    control.effectChanged()
                }
            }
        }
        
        // Colorization control
        VEP_Slider {
            id: colorizationSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Colorization:"
            onEffectChanged: function(value) {
                if (targetDecoration) {
                    targetDecoration.effectColorization = value
                    control.effectChanged()
                }
            }
        }
        
        // Colorization color picker
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Color:"
                color: "#cccccc"
                font.pixelSize: 11
                Layout.preferredWidth: 80
            }
            
            Rectangle {
                id: colorPreview
                Layout.preferredWidth: 30
                Layout.preferredHeight: 20
                color: targetDecoration ? targetDecoration.effectColorizationColor : "#ffffff"
                border.color: "#666666"
                border.width: 1
                radius: 3
                property color customModelColor: "#ffffff"
                ColorDialog {
                    id: colorDialog
                    selectedColor: colorPreview.customModelColor
                    onAccepted: colorPreview.customModelColor = selectedColor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: colorDialog.open()
                }
            }
            
            // Color presets
            Row {
                spacing: 3
                
                Repeater {
                    model: ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", colorPreview.customModelColor]
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: modelData
                        border.color: "#666666"
                        border.width: 1
                        radius: 2
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (targetDecoration) {
                                    targetDecoration.effectColorizationColor = modelData
                                    effectChanged()
                                }
                            }
                        }
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
        }
    }
}
