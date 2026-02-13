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
    property int participantCount: 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            text: connected ? "● Connecté" : "○ Déconnecté"
            color: connected ? "#4a8a4a" : "#888888"
            font.pointSize: 7
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "👥 " + participantCount
            color: "#666666"
            font.pointSize: 7
        }

        Text {
            text: "│"
            color: "#444444"
            font.pointSize: 7
        }

        Text {
            text: messageCount + " messages"
            color: "#666666"
            font.pointSize: 7
        }

        Text {
            text: "│"
            color: "#444444"
            font.pointSize: 7
        }

        Text {
            text: "🐱"
            font.pointSize: 7
        }

        Text {
            text: playerNickname
            color: "#888888"
            font.pointSize: 7
            elide: Text.ElideRight
            Layout.maximumWidth: 100
        }
    }
}
