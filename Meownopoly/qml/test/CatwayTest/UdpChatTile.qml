import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: udpChatCard
    required property var host

    Layout.fillWidth: true
    Layout.preferredHeight: 180
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        Text {
            text: "Chat UDP"
            color: host.textPrimary
            font.pixelSize: 15
            font.bold: true
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            TextArea {
                id: udpChatLog
                readOnly: true
                text: "(Les messages UDP s'afficheront ici.)"
                font.pixelSize: 12
                font.family: "Consolas"
                color: host.textPrimary
                background: Rectangle { color: "#222226"; radius: 4 }
                padding: 8
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: udpChatInput
                placeholderText: "Message à envoyer en UDP..."
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 36
                Layout.fillWidth: true
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: udpChatInput.activeFocus ? host.accent : host.cardBorder
                    border.width: udpChatInput.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                onAccepted: udpChatCard.sendUdpMessage()
            }
            Button {
                text: "Envoyer"
                implicitHeight: 36
                font.pixelSize: 12
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: udpChatCard.sendUdpMessage()
            }
        }
    }
    function sendUdpMessage() {
        var msg = udpChatInput.text.trim()
        if (msg.length === 0) return
        udpChatLog.text += "\n[envoyé] " + msg
        udpChatInput.clear()
        // TODO: envoi UDP réel
    }
}
