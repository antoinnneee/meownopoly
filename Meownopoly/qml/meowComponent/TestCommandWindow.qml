import QtQuick 2.15
import QtQuick.Controls 2.15
import utils 1.0

Rectangle {
    id: root
    width: 200
    height: 600
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

        // UDP / STUN Section
        Column {
            width: parent.width
            spacing: 8

            Text {
                text: "STUN Config"
                color: "#b0b0b0"
                font.pixelSize: 12
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 30
                color: "#353535"
                radius: 4
                border.color: "#555555"

                TextInput {
                    id: ipInput
                    anchors.fill: parent
                    anchors.margins: 5
                    text: "stun.l.google.com"
                    color: "#e0e0e0"
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                }
            }

            Rectangle {
                width: parent.width
                height: 30
                color: "#353535"
                radius: 4
                border.color: "#555555"

                TextInput {
                    id: portInput
                    anchors.fill: parent
                    anchors.margins: 5
                    text: "19302"
                    color: "#e0e0e0"
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                }
            }

            Row {
                width: parent.width
                spacing: 5

                Button {
                    text: "Set STUN"
                    width: (parent.width - 5) / 2
                    height: 30
                    
                    background: Rectangle {
                        color: parent.pressed ? "#4a90e2" : "#353535"
                        border.color: "#555555"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#e0e0e0"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                    }
                    onClicked: TestManager.testSetStunServer(ipInput.text, parseInt(portInput.text))
                }

                Button {
                    text: "Start UDP"
                    width: (parent.width - 5) / 2
                    height: 30
                    
                    background: Rectangle {
                        color: parent.pressed ? "#4a90e2" : "#353535"
                        border.color: "#555555"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#e0e0e0"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                    }
                    onClicked: TestManager.testUdpServer()
                }
            }

            Button {
                text: "Send STUN Request"
                width: parent.width
                height: 30
                
                background: Rectangle {
                    color: parent.pressed ? "#4a90e2" : "#353535"
                    border.color: "#555555"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#e0e0e0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                }
                onClicked: TestManager.testSendStun()
            }
        }

        // Separator
        Rectangle {
            width: parent.width
            height: 1
            color: "#444"
        }

        // Peer Communication Section
        Column {
            width: parent.width
            spacing: 8

            Text {
                text: "Peer Communication (Uses Main Port)"
                color: "#b0b0b0"
                font.pixelSize: 12
                font.bold: true
            }
            
            // Peer Config
            Row {
                width: parent.width
                spacing: 5

                Rectangle {
                    width: (parent.width - 5) * 0.6
                    height: 30
                    color: "#353535"
                    radius: 4
                    border.color: "#555555"

                    TextInput {
                        id: peerIpInput
                        anchors.fill: parent
                        anchors.margins: 5
                        text: "127.0.0.1"
                        color: "#e0e0e0"
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true
                    }
                }

                Rectangle {
                    width: (parent.width - 5) * 0.4
                    height: 30
                    color: "#353535"
                    radius: 4
                    border.color: "#555555"

                    TextInput {
                        id: peerPortInput
                        anchors.fill: parent
                        anchors.margins: 5
                        text: "3478"
                        color: "#e0e0e0"
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true
                    }
                }
            }

            Button {
                text: "Set Peer"
                width: parent.width
                height: 30
                
                background: Rectangle {
                    color: parent.pressed ? "#4a90e2" : "#353535"
                    border.color: "#555555"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#e0e0e0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                }
                onClicked: TestManager.testSetPeer(peerIpInput.text, parseInt(peerPortInput.text))
            }

            // Messaging
            Rectangle {
                width: parent.width
                height: 30
                color: "#353535"
                radius: 4
                border.color: "#555555"

                TextInput {
                    id: messageInput
                    anchors.fill: parent
                    anchors.margins: 5
                    text: "Hello Peer!"
                    color: "#e0e0e0"
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                }
            }

            Button {
                text: "Send to Peer"
                width: parent.width
                height: 30
                
                background: Rectangle {
                    color: parent.pressed ? "#4a90e2" : "#353535"
                    border.color: "#555555"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#e0e0e0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                }
                onClicked: TestManager.testSendMessage(messageInput.text)
            }
        }

        // Separator
        Rectangle {
            width: parent.width
            height: 1
            color: "#444"
        }

        // Other tests
        Grid {
            columns: 3
            spacing: 5
            width: parent.width

            Repeater {
                model: [
                    { name: "T1", action: function() { TestManager.testAction1() } },
                    { name: "T2", action: function() { TestManager.testAction2() } },
                    { name: "T3", action: function() { TestManager.testAction3() } }
                ]

                delegate: Button {
                    text: modelData.name
                    width: (parent.width - 10) / 3
                    height: 30
                    
                    background: Rectangle {
                        color: parent.pressed ? "#4a90e2" : "#2d2d2d"
                        border.color: "#555555"
                        radius: 4
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "#e0e0e0"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
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
