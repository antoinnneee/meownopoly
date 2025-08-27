import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import "../editor/tools"
import "../editor"

Rectangle {
    id: window
    width: 1200
    height: 800
    visible: true

    color: "#2a2a2a"


    GridManager{
        id: gridManager
        logic: logic
    }
    EditorLogic{
        id: logic
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Left side - Test decorations
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Column {
                spacing: 20
                width: parent.width
                
                Text {
                    text: "Test Decorations with Visual Effects"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                // Test decoration 1 - Brightness effect
                SnapableDecoration {
                    id: decoration1
                    width: 200
                    height: 150
                    decorationType: "grass"
                    decorationId: "0"
                    gridManager: gridManager
                    
                    // Apply brightness effect
                    effectBrightness: 0.5
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Brightness: 0.5"
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                
                // Test decoration 2 - Saturation effect
                SnapableDecoration {
                    id: decoration2
                    width: 200
                    height: 150
                    decorationType: "grass"
                    decorationId: "0"
                    gridManager: gridManager
                    
                    // Apply desaturation effect
                    effectSaturation: -0.8
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Saturation: -0.8"
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                
                // Test decoration 3 - Colorization effect
                SnapableDecoration {
                    id: decoration3
                    width: 200
                    height: 150
                    decorationType: "grass"
                    decorationId: "0"
                    gridManager: gridManager
                    
                    // Apply colorization effect
                    effectColorization: 0.7
                    effectColorizationColor: "#ff6600"
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Colorization: Orange"
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                
                // Test decoration 4 - Blur effect
                SnapableDecoration {
                    id: decoration4
                    width: 200
                    height: 150
                    decorationType: "grass"
                    decorationId: "0"
                    gridManager: gridManager
                    
                    // Apply blur effect
                    effectBlurEnabled: true
                    effectBlur: 0.5
                    effectBlurMax: 16
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Blur: 0.5"
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                
                // Test decoration 5 - Shadow effect
                SnapableDecoration {
                    id: decoration5
                    width: 200
                    height: 150
                    decorationType: "grass"
                    decorationId: "0"
                    gridManager: gridManager
                    
                    // Apply shadow effect
                    effectShadowEnabled: true
                    effectShadowColor: "#ff0000"
                    effectShadowHorizontalOffset: 10
                    effectShadowVerticalOffset: 10
                    effectShadowBlur: 0.8
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Shadow: Red"
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                
                // Test decoration 6 - Combined effects
                SnapableDecoration {
                    id: decoration6
                    width: 200
                    height: 150
                    decorationType: "grass"
                    decorationId: "0"

                    gridManager: gridManager
                    // Apply multiple effects
                    effectBrightness: 0.3
                    effectContrast: 0.2
                    effectSaturation: 0.5
                    effectColorization: 0.3
                    effectColorizationColor: "#00ff88"
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Combined Effects"
                        color: "white"
                        font.pixelSize: 12
                    }
                }
            }
        }
        
        // Right side - Interactive controls
        Rectangle {
            Layout.preferredWidth: 350
            Layout.fillHeight: true
            color: "#333333"
            radius: 8
            border.color: "#555555"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15
                
                Text {
                    text: "Interactive Controls"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }
                
                Text {
                    text: "Test Decoration"
                    color: "#cccccc"
                    font.pixelSize: 14
                }
                
                // Interactive test decoration
                SnapableDecoration {
                    id: interactiveDecoration
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 100
                    Layout.alignment: Qt.AlignHCenter
                    decorationType: "grass"
                    decorationId: "0"
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 10
                        
                        // Brightness control
                        GroupBox {
                            Layout.fillWidth: true
                            title: "Brightness"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                
                                Slider {
                                    id: brightnessSlider
                                    Layout.fillWidth: true
                                    from: -1.0
                                    to: 1.0
                                    value: 0.0
                                    
                                    onValueChanged: {
                                        interactiveDecoration.effectBrightness = value
                                    }
                                }
                                
                                Text {
                                    text: "Value: " + brightnessSlider.value.toFixed(2)
                                    color: "#cccccc"
                                    font.pixelSize: 10
                                }
                            }
                        }
                        
                        // Saturation control
                        GroupBox {
                            Layout.fillWidth: true
                            title: "Saturation"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                
                                Slider {
                                    id: saturationSlider
                                    Layout.fillWidth: true
                                    from: -1.0
                                    to: 2.0
                                    value: 0.0
                                    
                                    onValueChanged: {
                                        interactiveDecoration.effectSaturation = value
                                    }
                                }
                                
                                Text {
                                    text: "Value: " + saturationSlider.value.toFixed(2)
                                    color: "#cccccc"
                                    font.pixelSize: 10
                                }
                            }
                        }
                        
                        // Colorization control
                        GroupBox {
                            Layout.fillWidth: true
                            title: "Colorization"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                
                                Slider {
                                    id: colorizationSlider
                                    Layout.fillWidth: true
                                    from: 0.0
                                    to: 1.0
                                    value: 0.0
                                    
                                    onValueChanged: {
                                        interactiveDecoration.effectColorization = value
                                    }
                                }
                                
                                Text {
                                    text: "Amount: " + colorizationSlider.value.toFixed(2)
                                    color: "#cccccc"
                                    font.pixelSize: 10
                                }
                                
                                Row {
                                    spacing: 5
                                    
                                    Repeater {
                                        model: ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff"]
                                        
                                        Rectangle {
                                            width: 25
                                            height: 25
                                            color: modelData
                                            border.color: "#666666"
                                            border.width: 1
                                            radius: 3
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    interactiveDecoration.effectColorizationColor = modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Blur control
                        GroupBox {
                            Layout.fillWidth: true
                            title: "Blur"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                
                                CheckBox {
                                    id: blurCheckBox
                                    text: "Enable Blur"
                                    
                                    onCheckedChanged: {
                                        interactiveDecoration.effectBlurEnabled = checked
                                    }
                                }
                                
                                Slider {
                                    id: blurSlider
                                    Layout.fillWidth: true
                                    from: 0.0
                                    to: 1.0
                                    value: 0.0
                                    enabled: blurCheckBox.checked
                                    
                                    onValueChanged: {
                                        interactiveDecoration.effectBlur = value
                                    }
                                }
                                
                                Text {
                                    text: "Amount: " + blurSlider.value.toFixed(2)
                                    color: blurCheckBox.checked ? "#cccccc" : "#666666"
                                    font.pixelSize: 10
                                }
                            }
                        }
                        
                        // Reset button
                        Button {
                            Layout.fillWidth: true
                            text: "Reset All Effects"
                            
                            onClicked: {
                                interactiveDecoration.resetAllEffects()
                                brightnessSlider.value = 0.0
                                saturationSlider.value = 0.0
                                colorizationSlider.value = 0.0
                                blurCheckBox.checked = false
                                blurSlider.value = 0.0
                            }
                        }
                        
                        // Performance info
                        Rectangle {
                            Layout.fillWidth: true
                            height: 60
                            color: "#444444"
                            radius: 4
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                
                                Text {
                                    text: "Performance Info"
                                    color: "#cccccc"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                
                                Text {
                                    text: "Effects Active: " + (interactiveDecoration.hasActiveEffects ? "Yes" : "No")
                                    color: "#cccccc"
                                    font.pixelSize: 10
                                }
                                
                                Text {
                                    text: "MultiEffect Created: " + (interactiveDecoration.shouldCreateEffect ? "Yes" : "No")
                                    color: "#cccccc"
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
