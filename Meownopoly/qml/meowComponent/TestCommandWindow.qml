import QtQuick 2.15
import QtQuick.Controls 2.15
import utils 1.0

Rectangle {
    id: root
    width: 200
    height: 180
    color: "#252525"
    border.color: "#4a90e2"
    border.width: 2
    radius: 8
    clip: true

    DragHandler {
        target: root
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Text {
            text: "C++ Test Commands"
            color: "#e0e0e0"
            font.bold: true
            font.pixelSize: 14
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        Grid {
            columns: 2
            spacing: 10
            width: parent.width

            Repeater {
                model: [
                    { name: "Test 1", action: function() { TestManager.testAction1() } },
                    { name: "Test 2", action: function() { TestManager.testAction2() } },
                    { name: "Test 3", action: function() { TestManager.testAction3() } },
                    { name: "Send STUN", action: function() { TestManager.testSendStun() } },
                    { name: "Start UDP", action: function() { TestManager.testUdpServer() } }
                ]

                delegate: Button {
                    text: modelData.name
                    width: (parent.width - 10) / 2
                    height: 40
                    
                    background: Rectangle {
                        color: parent.pressed ? "#4a90e2" : (parent.hovered ? "#353535" : "#2d2d2d")
                        border.color: "#555555"
                        radius: 4
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "#e0e0e0"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                    }

                    onClicked: modelData.action()
                }
            }
        }

        Button {
            text: "Fermer"
            width: parent.width
            height: 30
            
            background: Rectangle {
                color: parent.pressed ? "#e74c3c" : "#3a3a3a"
                radius: 4
            }

            contentItem: Text {
                text: parent.text
                color: "#e0e0e0"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
            }

            onClicked: root.visible = false
        }
    }
}
