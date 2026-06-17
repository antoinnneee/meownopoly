import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GameSession 1.0
import Meownopoly.Account 1.0
import theme

Rectangle {
    id: root
    required property var host
    property string hostPlayerId: ""
    property bool selectedPlayerVisible: false

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingM

        Text {
            text: "Session GameSession"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
        }

        Text {
            text: "Mon playerId"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        TextField {
            id: localPlayerIdField
            Layout.fillWidth: true
            placeholderText: "Mon playerId"
            text: AccountManager.uniqueId
            font.pixelSize: Theme.fontSizeBody
            color: host.textPrimary
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
        }

        Text {
            text: "PlayerId de l'hôte (si client)"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        TextField {
            id: hostPlayerIdField
            Layout.fillWidth: true
            placeholderText: "PlayerId de l'hôte (si client)"
            text: root.hostPlayerId
            onTextChanged: root.hostPlayerId = text
            font.pixelSize: Theme.fontSizeBody
            color: host.textPrimary
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
        }

        Text {
            visible: selectedPlayerVisible
            text: "← sélectionné depuis la liste"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
        }

        Button {
            Layout.fillWidth: true
            text: "Hôte"
            implicitHeight: 32
            background: Rectangle {
                color: parent.pressed ? host.accent : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeBody
            }
            onClicked: GameSession.startAsHost(localPlayerIdField.text)
        }

        Button {
            Layout.fillWidth: true
            text: "Client"
            implicitHeight: 32
            background: Rectangle {
                color: parent.pressed ? host.accent : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeBody
            }
            onClicked: GameSession.startAsClient(localPlayerIdField.text, hostPlayerIdField.text)
        }

        Button {
            Layout.fillWidth: true
            text: "Stop"
            implicitHeight: 32
            background: Rectangle {
                color: parent.pressed ? host.accent : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeBody
            }
            onClicked: GameSession.stop()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: GameSession.active ? "#22c55e" : "#ef4444"
            }
            Text {
                text: GameSession.active ? "Actif" : "Inactif"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeBody
            }
        }

        Text {
            visible: GameSession.active
            text: GameSession.isHost ? "Rôle : Hôte" : "Rôle : Client"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeBody
        }

        Item { Layout.fillHeight: true }
    }
}
