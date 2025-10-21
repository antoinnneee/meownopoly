import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    
    // Properties
    property int from: 0
    property int to: 9999
    property int value: 0
    property int stepSize: 1
    property bool editable: true
    property string suffix: "K"

    implicitHeight: 32
    implicitWidth: 150
    
    // Main container
    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
        radius: 4
        border.color: textField.activeFocus ? "#569c58" : "#444444"
        border.width: 1
        
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
        
        RowLayout {
            anchors.fill: parent
            spacing: 0
            
            // Decrease button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                color: decreaseArea.pressed ? "#333333" : (decreaseArea.containsMouse ? "#2a2a2a" : "transparent")
                radius: 4
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.value > root.from ? "#cccccc" : "#555555"
                }
                
                MouseArea {
                    id: decreaseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.value > root.from
                    
                    onClicked: {
                        if (root.value > root.from) {
                            root.value = Math.max(root.from, root.value - root.stepSize)
                            root.valueChanged()
                        }
                    }
                    
                    // Auto-repeat on press and hold
                    onPressAndHold: {
                        repeatTimer.targetValue = -1
                        repeatTimer.start()
                    }
                    
                    onReleased: {
                        repeatTimer.stop()
                    }
                }
            }
            
            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: "#333333"
            }
            
            // Text input field
            TextField {
                id: textField
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                text: formatNumber(root.value) + root.suffix
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
                
                readOnly: !root.editable
                selectByMouse: true
                
                background: Rectangle {
                    color: "transparent"
                }
                
                validator: IntValidator {
                    bottom: root.from
                    top: root.to
                }
                
                onEditingFinished: {
                    // Enlever les espaces et le suffixe pour parser
                    var cleanText = text.replace(root.suffix, "").replace(/\s/g, "")
                    var newValue = parseInt(cleanText)
                    if (!isNaN(newValue)) {
                        root.value = Math.max(root.from, Math.min(root.to, newValue))
                        text = formatNumber(root.value) + root.suffix
                        root.valueChanged()
                    } else {
                        text = formatNumber(root.value) + root.suffix
                    }
                }
                
                onActiveFocusChanged: {
                    if (activeFocus) {
                        selectAll()
                    }
                }
                
                Keys.onUpPressed: {
                    root.value = Math.min(root.to, root.value + root.stepSize)
                    root.valueChanged()
                }
                
                Keys.onDownPressed: {
                    root.value = Math.max(root.from, root.value - root.stepSize)
                    root.valueChanged()
                }
            }
            
            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: "#333333"
            }
            
            // Increase button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                color: increaseArea.pressed ? "#333333" : (increaseArea.containsMouse ? "#2a2a2a" : "transparent")
                radius: 4
                
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 16
                    font.bold: true
                    color: root.value < root.to ? "#cccccc" : "#555555"
                }
                
                MouseArea {
                    id: increaseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.value < root.to
                    
                    onClicked: {
                        if (root.value < root.to) {
                            root.value = Math.min(root.to, root.value + root.stepSize)
                            root.valueChanged()
                        }
                    }
                    
                    // Auto-repeat on press and hold
                    onPressAndHold: {
                        repeatTimer.targetValue = 1
                        repeatTimer.start()
                    }
                    
                    onReleased: {
                        repeatTimer.stop()
                    }
                }
            }
        }
    }
    
    // Timer for auto-repeat
    Timer {
        id: repeatTimer
        interval: 100
        repeat: true
        property int targetValue: 0
        
        onTriggered: {
            if (targetValue > 0 && root.value < root.to) {
                root.value = Math.min(root.to, root.value + root.stepSize)
                root.valueChanged()
            } else if (targetValue < 0 && root.value > root.from) {
                root.value = Math.max(root.from, root.value - root.stepSize)
                root.valueChanged()
            }
        }
    }
    
    // Function to format number with thousands separator
    function formatNumber(num) {
        return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ")
    }
}

