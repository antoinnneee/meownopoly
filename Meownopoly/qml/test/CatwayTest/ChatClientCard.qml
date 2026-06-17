import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import Meownopoly.Account 1.0
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0
import theme

Rectangle {
    id: chatClientCard
    required property var host

    signal participantClicked(string playerId, string nickname)

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: chatColumn.implicitHeight + 24

    property ChatClient chatClient: Catway.chatClient

    ColumnLayout {
        id: chatColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingL

        Text {
            text: "Chat Client"
            color: host.textPrimary
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }

        RowLayout {
            spacing: Theme.spacingS
            Text { text: "État:"; color: host.textSecondary; font.pixelSize: Theme.fontSizeBody }
            Text {
                text: chatClient && chatClient.connected ? "Connecté" : "Déconnecté"
                color: chatClient && chatClient.connected ? "#22c55e" : host.textSecondary
                font.pixelSize: Theme.fontSizeBody
            }
        }
        RowLayout {
            spacing: Theme.spacingS
            Text { text: "Session:"; color: host.textSecondary; font.pixelSize: Theme.fontSizeBody }
            Text {
                text: (chatClient && chatClient.sessionId) ? chatClient.sessionId : "—"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeBody
                elide: Text.ElideMiddle
                Layout.maximumWidth: 180
            }
        }

        ColumnLayout {
            spacing: Theme.spacingXS
            Text { text: "URL serveur"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall; font.capitalization: Font.AllUppercase }
            TextField {
                id: fieldServerUrl
                placeholderText: "wss://..."
                placeholderTextColor: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
                implicitHeight: 38
                background: Rectangle {
                    color: Theme.surfaceAlt
                    radius: Theme.radiusM
                    border.color: fieldServerUrl.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldServerUrl.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
                text: "ws://pattounecorp.ovh:3000"
            }
        }
        Button {
            text: "Connecter au serveur"
            implicitHeight: 36
            font.pixelSize: Theme.fontSizeBody
            background: Rectangle {
                color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                radius: Theme.radiusL
            }
            contentItem: Text {
                text: parent.text
                color: Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (chatClient && fieldServerUrl.text.trim())
                    chatClient.connectToServer(fieldServerUrl.text.trim())
            }
        }

        Item { height: 4 }

        Text {
            text: "Connexion directe à une session"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.capitalization: Font.AllUppercase
        }
        ColumnLayout {
            spacing: Theme.spacingXS
            Text { text: "Nom de la session"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            TextField {
                id: fieldSessionName
                placeholderText: "ex: Ma Super Partie"
                placeholderTextColor: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
                implicitHeight: 38
                background: Rectangle {
                    color: Theme.surfaceAlt
                    radius: Theme.radiusM
                    border.color: fieldSessionName.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldSessionName.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
                text: "Session de " + AccountManager.nickname
            }
        }
        ColumnLayout {
            spacing: Theme.spacingXS
            Text { text: "Session ID"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            TextField {
                id: fieldSessionId
                placeholderText: "ex: abc123"
                placeholderTextColor: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
                implicitHeight: 38
                background: Rectangle {
                    color: Theme.surfaceAlt
                    radius: Theme.radiusM
                    border.color: fieldSessionId.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldSessionId.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
                text: "Pattoune"
            }
        }
        ColumnLayout {
            spacing: Theme.spacingXS
            Text { text: "Mot de passe"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            TextField {
                id: fieldDirectPassword
                placeholderText: "Mot de passe session"
                placeholderTextColor: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
                implicitHeight: 38
                echoMode: TextInput.Password
                background: Rectangle {
                    color: Theme.surfaceAlt
                    radius: Theme.radiusM
                    border.color: fieldDirectPassword.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldDirectPassword.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
                text: "123"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            Button {
                text: "Créer une session"
                Layout.fillWidth: true
                implicitHeight: 36
                font.pixelSize: Theme.fontSizeBody
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                    radius: Theme.radiusL
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (chatClient && fieldSessionName.text.trim())
                        chatClient.createSession(fieldSessionName.text.trim(), fieldDirectPassword.text, fieldSessionId.text.trim())
                }
            }
            Button {
                text: "Rejoindre"
                Layout.fillWidth: true
                implicitHeight: 36
                font.pixelSize: Theme.fontSizeBody
                background: Rectangle {
                    color: parent.pressed ? Theme.surfaceAlt : "transparent"
                    radius: Theme.radiusM
                    border.color: host.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: host.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (chatClient && fieldSessionId.text.trim())
                        chatClient.connectToSessionDirect(fieldSessionId.text.trim(), fieldDirectPassword.text)
                }
            }
        }

        Item { height: 4 }
        Text {
            text: "Participants à la session"
            color: host.textPrimary
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
        RowLayout {
            spacing: Theme.spacingM
            Text {
                text: chatClient && chatClient.connected
                      ? (chatClient.participantCount + " participant(s)")
                      : "— connectez-vous à une session —"
                color: host.textSecondary
                font.pixelSize: Theme.fontSizeBody
            }
            Button {
                text: "Rafraîchir"
                implicitHeight: 28
                font.pixelSize: Theme.fontSizeSmall
                visible: chatClient && chatClient.connected
                background: Rectangle {
                    color: parent.pressed ? Theme.surfaceAlt : "transparent"
                    radius: Theme.radiusS
                    border.color: host.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: host.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (chatClient)
                        chatClient.requestParticipants()
                }
            }
            Item { Layout.fillWidth: true }
        }
        ListView {
            id: participantsList
            Layout.fillWidth: true
            Layout.preferredHeight: chatClient && chatClient.connected ? Math.min(260, Math.max(80, chatClient.participantCount * 48 + 8)) : 0
            clip: true
            spacing: Theme.spacingXS
            model: chatClient && chatClient.connected ? chatClient.participants : []
            delegate: Rectangle {
                width: parent.width
                height: 44
                color: participantMouseArea.pressed ? host.cardBorder : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
                MouseArea {
                    id: participantMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        var data = modelData
                        if (!data) return
                        var pid = data.player_id || ""
                        var nick = data.player_nickname || ""
                        var card = participantsList.parent.parent
                        if (card)
                            card.participantClicked(pid, nick)
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM
                    ColumnLayout {
                        spacing: Theme.spacingXXS
                        Layout.fillWidth: true
                        Text {
                            text: modelData.player_nickname || "—"
                            color: host.textPrimary
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: !!modelData.is_host
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.player_id ? ("id: " + modelData.player_id) : ""
                            color: host.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }
                    Text {
                        text: modelData.is_host ? "Hôte" : ""
                        color: host.accent
                        font.pixelSize: Theme.fontSizeSmall
                        visible: !!modelData.is_host
                    }
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        Layout.alignment: Qt.AlignVCenter
                        color: {
                            var s = modelData.status || ""
                            if (s === "online")  return "#22c55e"
                            if (s === "offline") return "#71717a"
                            return "#71717a"
                        }
                        // ToolTip.visible: statusHover.containsMouse
                        // ToolTip.text: modelData.status || "inconnu"
                        // ToolTip.delay: 400
                        HoverHandler { id: statusHover }
                    }
                }
            }
        }
    }
}
