import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root    
    required property var logic

    // Signal émis quand un bouton est cliqué
    signal buttonClicked(int index)
    // Boutons de menu
    Row {
        id: menuSelector
        anchors.left: parent.left
        height: parent.height
        spacing: 0

        Button {
            id: expandButton
            width: 30
            height: parent.height
            property bool isExpended: false
            background: Rectangle {
                anchors.fill: parent
                color: parent.pressed ? "#555555" : "#444444"
                border.color: "#666666"
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: root.isExpanded ? "▼" : "▲"
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.fill:expandButton
            }

            onClicked: {
                console.log("Expand button clicked");
                isExpanded = !isExpanded;
            }
        }

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
                    root.buttonClicked(0);
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
                    root.buttonClicked(1);
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
                    root.buttonClicked(2);
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
                        id: widthSpinBox
                        width: 68
                        height: 16
                        from: 1
                        to: 100
                        value: logic.currentElementWidth
                        onValueChanged: logic.currentElementWidth = value;
                        stepSize: 1
                        editable: true
                        
                        contentItem: TextInput {
                            text: widthSpinBox.textFromValue(widthSpinBox.value, widthSpinBox.locale)
                            font.pixelSize: 10
                            color: "white"
                            selectionColor: "#4A90E2"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            width: parent.width - (widthSpinBox.up.indicator ? widthSpinBox.up.indicator.width : 0)
                                   - (widthSpinBox.down.indicator ? widthSpinBox.down.indicator.width : 0) - 6
                            anchors.centerIn: parent
                            
                            readOnly: !widthSpinBox.editable
                            validator: widthSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 1
                            radius: 2
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
                        id: heightSpinBox
                        width: 68
                        height: 16
                        from: 1
                        to: 100
                        value: logic.currentElementHeight
                        onValueChanged: logic.currentElementHeight = value;
                        stepSize: 1
                        editable: true

                        contentItem: TextInput {
                            text: heightSpinBox.textFromValue(heightSpinBox.value, heightSpinBox.locale)
                            font.pixelSize: 10
                            color: "white"
                            selectionColor: "#4A90E2"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            width: parent.width - (heightSpinBox.up.indicator ? heightSpinBox.up.indicator.width : 0)
                                   - (heightSpinBox.down.indicator ? heightSpinBox.down.indicator.width : 0) - 6
                            anchors.centerIn: parent
                            
                            readOnly: !heightSpinBox.editable
                            validator: heightSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            border.color: "#666666"
                            border.width: 1
                            radius: 2
                        }
                    }
                }
            }
            
            // Mouse cursor button
            Rectangle {
                id: cursorButton
                property bool checked: false
                
                width: 32
                height: 32
                radius: 4
                color: checked ? "#4A90E2" : "#444444"
                border.color: "#666666"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: "🖱️"
                    color: "white"
                    font.pixelSize: 14
                    anchors.centerIn: parent
                }
                
                MouseArea {
                    id: cursorMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
                
                ToolTip {
                    visible: cursorMouseArea.containsMouse
                    text: "Select cursor tool"
                    delay: 500
                }
            }
        }
    }
}
