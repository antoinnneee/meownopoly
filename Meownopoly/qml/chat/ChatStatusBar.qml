import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 24
    color: "#2a2a2a"
    border.color: "#333333"
    border.width: 1

    property bool connected: false
    property int messageCount: 0
    property string playerNickname: ""

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            text: connected ? "● Connecté" : "○ Déconnecté"
            color: connected ? "#4a8a4a" : "#888888"
            font.pixelSize: 9
        }

        Item { Layout.fillWidth: true }

        Text {
            text: messageCount + " messages"
            color: "#666666"
            font.pixelSize: 9
        }

        Text {
            text: "│"
            color: "#444444"
            font.pixelSize: 9
        }

        Text {
            text: "🐱"
            font.pixelSize: 9
        }

        Text {
            text: playerNickname
            color: "#888888"
            font.pixelSize: 9
            elide: Text.ElideRight
            Layout.maximumWidth: 100
        }
    }
}
