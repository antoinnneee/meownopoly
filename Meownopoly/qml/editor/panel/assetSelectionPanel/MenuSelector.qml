import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

Item {
    id: topToolbar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: -35
    height: 35
    z: 10
    
    // Boutons de menu
    Row {
        id: menuSelector
        anchors.left: parent.left
        height: parent.height
        spacing: 0
        
        Rectangle {
            width: 100
            height: parent.height
            color: "#b05758" // Rouge plus sombre
            radius: 4
            border.width: 1
            border.color: "#862a2a"
            
            Text {
                text: "Menu Assets"
                anchors.centerIn: parent
                font.pixelSize: 12
                font.bold: true
                color: "white"
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.opacity = 0.9
                onExited: parent.opacity = 1.0
                onClicked: {
                    // Logique à implémenter plus tard
                }
            }
        }
        
        Rectangle {
            width: 100
            height: parent.height
            color: "#b3ab48" // Jaune plus sombre
            radius: 4
            border.width: 1
            border.color: "#8a8224"
            
            Text {
                text: "Menu Cases"
                anchors.centerIn: parent
                font.pixelSize: 12
                font.bold: true
                color: "white"
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.opacity = 0.9
                onExited: parent.opacity = 1.0
                onClicked: {
                    // Logique à implémenter plus tard
                }
            }
        }
        
        Rectangle {
            width: 100
            height: parent.height
            color: "#4a90e2" // Bleu plus sombre
            radius: 4
            border.width: 1
            border.color: "#306aa8"
            
            Text {
                text: "Menu Edition"
                anchors.centerIn: parent
                font.pixelSize: 12
                font.bold: true
                color: "white"
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.opacity = 0.9
                onExited: parent.opacity = 1.0
                onClicked: {
                    // Logique à implémenter plus tard
                }
            }
        }
    }
    
    // Contrôles de dimensions et outil curseur
    Rectangle {
        id: controlsBackground
        anchors.left: menuSelector.right
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: controlsRow.width + 20
        color: "#333333"
        radius: 4
        border.color: "#444444"
        border.width: 1
        
        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 10
            height: parent.height
            
            // Size selectors
            Column {
                spacing: 2
                width: 100
                height: 34
                anchors.verticalCenter: parent.verticalCenter
                
                // Width selector
                Row {
                    spacing: 4
                    width: parent.width
                    height: 16
                    
                    Text {
                        text: "W:"
                        color: "white"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                    }
                    
                    SpinBox {
                        id: topWidthSpinBox
                        width: 68
                        height: 16
                        from: 1
                        to: 100
                        value: logic.currentElementWidth
                        stepSize: 1
                        editable: true
                        
                        contentItem: TextInput {
                            text: topWidthSpinBox.textFromValue(topWidthSpinBox.value, topWidthSpinBox.locale)
                            font.pixelSize: 10
                            color: "white"
                            selectionColor: "#4A90E2"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            width: parent.width - (topWidthSpinBox.up.indicator ? topWidthSpinBox.up.indicator.width : 0)
                                   - (topWidthSpinBox.down.indicator ? topWidthSpinBox.down.indicator.width : 0) - 6
                            anchors.centerIn: parent
                            
                            readOnly: !topWidthSpinBox.editable
                            validator: topWidthSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 1
                            radius: 2
                        }
                        
                        onValueChanged: {
                            logic.currentElementWidth = value
                            // Mise à jour du spinbox
                            console.log("Width:", value)
                        }
                    }
                }
                
                // Height selector
                Row {
                    spacing: 4
                    width: parent.width
                    height: 16
                    
                    Text {
                        text: "H:"
                        color: "white"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                    }
                    
                    SpinBox {
                        id: topHeightSpinBox
                        width: 68
                        height: 16
                        from: 1
                        to: 100
                        value: logic.currentElementHeight
                        stepSize: 1
                        editable: true
                        
                        contentItem: TextInput {
                            text: topHeightSpinBox.textFromValue(topHeightSpinBox.value, topHeightSpinBox.locale)
                            font.pixelSize: 10
                            color: "white"
                            selectionColor: "#4A90E2"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            width: parent.width - (topHeightSpinBox.up.indicator ? topHeightSpinBox.up.indicator.width : 0)
                                   - (topHeightSpinBox.down.indicator ? topHeightSpinBox.down.indicator.width : 0) - 6
                            anchors.centerIn: parent
                            
                            readOnly: !topHeightSpinBox.editable
                            validator: topHeightSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 1
                            radius: 2
                        }
                        
                        onValueChanged: {
                            logic.currentElementHeight = value
                            // Mise à jour du spinbox
                            console.log("Height:", value)
                        }
                    }
                }
            }
            
            // Mouse cursor button
            Rectangle {
                id: topCursorButton
                property bool checked: false
                
                width: 32
                height: 32
                radius: 4
                color: checked ? "#4A90E2" : "#444444"
                border.color: "#666666"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: "???"
                    color: "white"
                    font.pixelSize: 14
                    anchors.centerIn: parent
                }
                
                MouseArea {
                    id: topCursorMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onClicked: {
                        topCursorButton.checked = !topCursorButton.checked
                        // Mise à jour de l'état de sélection
                        isSelectionActive = topCursorButton.checked
                        console.log("Mode sélection: " + topCursorButton.checked)
                        selectionModeChanged(topCursorButton.checked)
                        if (!topCursorButton.checked) {
                            logic.cancelSelection()
                        }
                    }
                }
                
                ToolTip {
                    visible: topCursorMouseArea.containsMouse
                    text: "Select cursor tool"
                    delay: 500
                }
            }
        }
    }
}
