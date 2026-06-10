import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 24
    color: Theme.surface
    border.color: Theme.surfaceAlt
    border.width: 1

    property bool connected: false
    property int messageCount: 0
    property string playerNickname: ""
    property int participantCount: 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXL
        anchors.rightMargin: Theme.spacingXL
        spacing: Theme.spacingM

        Text {
            text: connected ? "● Connecté" : "○ Déconnecté"
            color: connected ? "#4a8a4a" : Theme.textMuted
            font.pixelSize: Theme.fontSizeTiny
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "👥 " + participantCount
            color: Theme.textDisabled
            font.pixelSize: Theme.fontSizeTiny
        }

        Text {
            text: "│"
            color: Theme.border
            font.pixelSize: Theme.fontSizeTiny
        }

        Text {
            text: messageCount + " messages"
            color: Theme.textDisabled
            font.pixelSize: Theme.fontSizeTiny
        }

        Text {
            text: "│"
            color: Theme.border
            font.pixelSize: Theme.fontSizeTiny
        }

        Text {
            text: "🐱"
            font.pixelSize: Theme.fontSizeTiny
        }

        Text {
            text: playerNickname
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeTiny
            elide: Text.ElideRight
            Layout.maximumWidth: 100
        }
    }
}
