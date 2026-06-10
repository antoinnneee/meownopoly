import QtQuick 2.15
import QtQuick.Controls 2.15
import utils 1.0
import theme

Rectangle {
    id: root
    width: 200
    height: 600
    color: Theme.surface
    border.color: Theme.accent
    border.width: 2
    radius: Theme.radiusL
    clip: true

    DragHandler {
        target: root
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingL

        Text {
            text: "C++ Test Commands"
            color: Theme.textSoft
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }

        // UDP / STUN Section
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Text {
                text: "STUN Config"
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 30
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.borderLight

                TextInput {
                    id: ipInput
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    text: "stun.l.google.com"
                    color: Theme.textSoft
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                }
            }

            Rectangle {
                width: parent.width
                height: 30
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.borderLight

                TextInput {
                    id: portInput
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    text: "19302"
                    color: Theme.textSoft
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingXS

                Button {
                    text: "Set STUN"
                    width: (parent.width - 5) / 2
                    height: 30

                    background: Rectangle {
                        color: parent.pressed ? Theme.accent : Theme.surfaceAlt
                        border.color: Theme.borderLight
                        radius: Theme.radiusS
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSoft
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    // onClicked: TestManager.testSetStunServer(ipInput.text, parseInt(portInput.text))
                }

                Button {
                    text: "Start UDP"
                    width: (parent.width - 5) / 2
                    height: 30

                    background: Rectangle {
                        color: parent.pressed ? Theme.accent : Theme.surfaceAlt
                        border.color: Theme.borderLight
                        radius: Theme.radiusS
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSoft
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    onClicked: TestManager.testUdpServer()
                }
            }

            Button {
                text: "Send STUN Request"
                width: parent.width
                height: 30

                background: Rectangle {
                    color: parent.pressed ? Theme.accent : Theme.surfaceAlt
                    border.color: Theme.borderLight
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textSoft
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeSmall
                }
                onClicked: TestManager.testSendStun()
            }
        }

        // Separator
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // Peer Communication Section
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Text {
                text: "Peer Communication (Uses Main Port)"
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }

            // Peer Config
            Row {
                width: parent.width
                spacing: Theme.spacingXS

                Rectangle {
                    width: (parent.width - 5) * 0.6
                    height: 30
                    color: Theme.surfaceAlt
                    radius: Theme.radiusS
                    border.color: Theme.borderLight

                    TextInput {
                        id: peerIpInput
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        text: "127.0.0.1"
                        color: Theme.textSoft
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true
                    }
                }

                Rectangle {
                    width: (parent.width - 5) * 0.4
                    height: 30
                    color: Theme.surfaceAlt
                    radius: Theme.radiusS
                    border.color: Theme.borderLight

                    TextInput {
                        id: peerPortInput
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        text: "3478"
                        color: Theme.textSoft
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
                    color: parent.pressed ? Theme.accent : Theme.surfaceAlt
                    border.color: Theme.borderLight
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textSoft
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // Messaging
            Rectangle {
                width: parent.width
                height: 30
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.borderLight

                TextInput {
                    id: messageInput
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    text: "Hello Peer!"
                    color: Theme.textSoft
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                }
            }

            Button {
                text: "Send to Peer"
                width: parent.width
                height: 30

                background: Rectangle {
                    color: parent.pressed ? Theme.accent : Theme.surfaceAlt
                    border.color: Theme.borderLight
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textSoft
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // Separator
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // Other tests
        Grid {
            columns: 3
            spacing: Theme.spacingXS
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
                        color: parent.pressed ? Theme.accent : Theme.surface
                        border.color: Theme.borderLight
                        radius: Theme.radiusS
                    }

                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSoft
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.fontSizeSmall
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
                color: parent.pressed ? Theme.danger : Theme.surfaceHover
                radius: Theme.radiusS
            }

            contentItem: Text {
                text: parent.text
                color: Theme.textSoft
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeSmall
            }

            onClicked: root.visible = false
        }
    }
}
