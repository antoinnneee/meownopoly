import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    id: root
    title: "Friction"
    
    // Properties
    property var targetZoneParameter: null
    property bool updatingValues: false
    
    // Signal
    signal configurationChanged()
    
    background: Rectangle {
        color: "#2a2a2a"
        radius: 4
        border.color: "#444444"
        border.width: 1
    }
    
    label: Text {
        text: root.title
        color: "#cccccc"
        font.pixelSize: 12
        font.bold: true
        leftPadding: 8
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // Note explicative
        Text {
            text: "🎯 Force de friction appliquée aux objets dans la zone"
            font.italic: true
            font.pixelSize: 11
            color: "#8a8a8a"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Friction Strength
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text {
                text: "Friction Strength:"
                color: "#cccccc"
                font.pixelSize: 12
                Layout.preferredWidth: 120
            }
            
            Slider {
                id: frictionSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: targetZoneParameter ? targetZoneParameter.frictionStrenght : 0.0
                
                background: Rectangle {
                    x: frictionSlider.leftPadding
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    width: frictionSlider.availableWidth
                    height: 6
                    radius: 3
                    color: "#1a1a1a"
                    
                    Rectangle {
                        width: frictionSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#4a9c4e" }
                            GradientStop { position: 1.0; color: "#6bc96f" }
                        }
                    }
                }
                
                handle: Rectangle {
                    x: frictionSlider.leftPadding + frictionSlider.visualPosition * (frictionSlider.availableWidth - width)
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: frictionSlider.pressed ? "#7bd97f" : "#5cb85c"
                    border.color: "#ffffff"
                    border.width: 2
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
                
                onMoved: {
                    if (!root.updatingValues && targetZoneParameter) {
                        targetZoneParameter.frictionStrenght = value
                        root.configurationChanged()
                    }
                }
            }
            
            // Value display
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 24
                color: "#1a1a1a"
                radius: 4
                border.color: "#444444"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: frictionSlider.value.toFixed(2)
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
    
    // Function to update controls from the target
    function updateControls() {
        if (!targetZoneParameter) return
        
        updatingValues = true
        frictionSlider.value = targetZoneParameter.frictionStrenght
        console.log("friction updated", targetZoneParameter.frictionStrenght)
        updatingValues = false
    }
}
