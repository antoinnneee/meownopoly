import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    id: root
    title: "Général"
    
    // Properties
    property bool updatingValues: false

    property alias zoneName: nameField.text
    property alias exclusion: exclusionSwitch.checked
    property alias speedMultiplier: speedSlider.value
    property alias accelerationMultiplier: accelerationSlider.value
    
    // Signal
    signal configurationChanged()
    
    // Functions
    function updateFromZoneParameter(zoneParam) {
      if (root.updatingValues) return
        
        // Update sliders from target values
        nameField.text = zoneParam.zoneName
        exclusionSwitch.checked = zoneParam.exclusion
        speedSlider.value = zoneParam.speedMultiplier
        accelerationSlider.value = zoneParam.accelerationMultiplier
    }
    
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
    
    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: 10
        columnSpacing: 10
        
        // Zone Name
        Label {
            text: "Nom:"
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
        }
        
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Nom de la zone"
            text: ""
            
            background: Rectangle {
                color: "#1a1a1a"
                radius: 3
                border.color: nameField.activeFocus ? "#5cb85c" : "#444444"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
            
            color: "#ffffff"
            font.pixelSize: 11
            padding: 6
            
            onEditingFinished: {
                root.configurationChanged()
            }
        }
        
        // Exclusion Mode
        Label {
            text: "Mode Exclusion:"
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
        }
        
        Switch {
            id: exclusionSwitch
            checked: true
            
            indicator: Rectangle {
                implicitWidth: 36
                implicitHeight: 20
                x: exclusionSwitch.leftPadding
                y: parent.height / 2 - height / 2
                radius: 10
                color: exclusionSwitch.checked ? "#5cb85c" : "#333333"
                border.color: exclusionSwitch.checked ? "#5cb85c" : "#555555"

                Rectangle {
                    x: exclusionSwitch.checked ? parent.width - width - 2 : 2
                    y: 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "#ffffff"
                    
                    Behavior on x {
                        NumberAnimation { duration: 150 }
                    }
                }
            }
            
            onToggled: {
                root.configurationChanged()
            }
        }

        // Speed Multiplier
        Label {
            text: "Multiplicateur Vitesse:"
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            Slider {
                id: speedSlider
                Layout.fillWidth: true
                from: 0.1
                to: 3.0
                stepSize: 0.1
                value: 1.0
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Text {
                text: speedSlider.value.toFixed(1) + "x"
                color: "#ffffff"
                font.pixelSize: 11
                Layout.preferredWidth: 30
            }
        }

        // Acceleration Multiplier
        Label {
            text: "Multiplicateur Accélération:"
            color: "#ffffff"
            font.pixelSize: 11
            font.bold: true
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            opacity: exclusionSwitch.checked ? 0.5 : 1.0
            enabled: !exclusionSwitch.checked

            Slider {
                id: accelerationSlider
                Layout.fillWidth: true
                from: 0.0
                to: 10.0
                stepSize: 0.05
                value: 1.0
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Text {
                text: accelerationSlider.value.toFixed(2) + "x"
                color: "#ffffff"
                font.pixelSize: 11
                Layout.preferredWidth: 30
            }
        }
    }
}
