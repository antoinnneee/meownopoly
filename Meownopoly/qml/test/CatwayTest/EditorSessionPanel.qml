import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EditorSession 1.0
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
            text: "Session EditorSession"
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
            text: "Session ID (optionnel, libellé dossier autosave)"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        TextField {
            id: sessionIdField
            Layout.fillWidth: true
            placeholderText: "ex: editor-dev-001"
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

        // Avertissement si une GameSession est active (exclusivité)
        Text {
            visible: GameSession.active
            Layout.fillWidth: true
            text: "⚠ GameSession active — arrêter avant de démarrer l'éditeur."
            color: Theme.warning
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        Button {
            Layout.fillWidth: true
            text: "Hôte"
            implicitHeight: 32
            enabled: !GameSession.active
            background: Rectangle {
                color: parent.pressed ? host.accent : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
                opacity: parent.enabled ? 1.0 : 0.5
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeBody
            }
            onClicked: EditorSession.startAsHost(localPlayerIdField.text, sessionIdField.text)
        }

        Button {
            Layout.fillWidth: true
            text: "Client"
            implicitHeight: 32
            enabled: !GameSession.active
            background: Rectangle {
                color: parent.pressed ? host.accent : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
                opacity: parent.enabled ? 1.0 : 0.5
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeBody
            }
            onClicked: EditorSession.startAsClient(localPlayerIdField.text,
                                                   hostPlayerIdField.text,
                                                   sessionIdField.text)
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
            onClicked: EditorSession.stop()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: EditorSession.active ? "#22c55e" : "#ef4444"
            }
            Text {
                text: EditorSession.active ? "Actif" : "Inactif"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeBody
            }
        }

        Text {
            visible: EditorSession.active
            text: (EditorSession.isHost ? "Rôle : Hôte" : "Rôle : Client")
                  + (EditorSession.sessionId ? " — session : " + EditorSession.sessionId : "")
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeBody
        }

        Item { Layout.fillHeight: true }
    }
}
