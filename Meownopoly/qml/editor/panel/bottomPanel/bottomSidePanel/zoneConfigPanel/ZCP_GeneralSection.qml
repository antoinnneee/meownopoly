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
    property alias frictionStrength: frictionSlider.value
    
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
        frictionSlider.value = zoneParam.frictionStrenght
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

                background: Rectangle {
                    x: speedSlider.leftPadding
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: speedSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: "#3a3a3a"

                    Rectangle {
                        width: speedSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#4CAF50"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: "#ffffff"
                    border.color: "#4CAF50"
                    border.width: 2
                }
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 45
                height: 26
                radius: 4
                color: "#2a2a2a"
                border.color: "#4CAF50"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "×" + speedSlider.value.toFixed(1)
                    color: "#ffffff"
                    font.pointSize: 8
                    font.bold: true
                }
            }
        }

        // Friction
        Label {
            text: "Friction:"
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
                id: frictionSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: 0.0

                background: Rectangle {
                    x: frictionSlider.leftPadding
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: frictionSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: "#3a3a3a"

                    Rectangle {
                        width: frictionSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#5DADE2"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: frictionSlider.leftPadding + frictionSlider.visualPosition * (frictionSlider.availableWidth - width)
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: "#ffffff"
                    border.color: "#5DADE2"
                    border.width: 2
                }
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 45
                height: 26
                radius: 4
                color: "#2a2a2a"
                border.color: "#5DADE2"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: frictionSlider.value.toFixed(2)
                    color: "#ffffff"
                    font.pointSize: 8
                    font.bold: true
                }
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

                background: Rectangle {
                    x: accelerationSlider.leftPadding
                    y: accelerationSlider.topPadding + accelerationSlider.availableHeight / 2 - height / 2
                    implicitWidth: 100
                    implicitHeight: 4
                    width: accelerationSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: "#3a3a3a"

                    Rectangle {
                        width: accelerationSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#FF9800"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: accelerationSlider.leftPadding + accelerationSlider.visualPosition * (accelerationSlider.availableWidth - width)
                    y: accelerationSlider.topPadding + accelerationSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: 7
                    color: "#ffffff"
                    border.color: "#FF9800"
                    border.width: 2
                }
                
                onMoved: {
                        root.configurationChanged()
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 45
                height: 26
                radius: 4
                color: "#2a2a2a"
                border.color: "#FF9800"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "×" + accelerationSlider.value.toFixed(2)
                    color: "#ffffff"
                    font.pointSize: 8
                    font.bold: true
                }
            }
        }
    }
}
