import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import Meownopoly.Chat 1.0

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
        anchors.margins: 12
        spacing: 10

        Text {
            text: "Chat Client"
            color: host.textPrimary
            font.pixelSize: 15
            font.bold: true
        }

        RowLayout {
            spacing: 6
            Text { text: "État:"; color: host.textSecondary; font.pixelSize: 12 }
            Text {
                text: chatClient && chatClient.connected ? "Connecté" : "Déconnecté"
                color: chatClient && chatClient.connected ? "#22c55e" : host.textSecondary
                font.pixelSize: 12
            }
        }
        RowLayout {
            spacing: 6
            Text { text: "Session:"; color: host.textSecondary; font.pixelSize: 12 }
            Text {
                text: (chatClient && chatClient.sessionId) ? chatClient.sessionId : "—"
                color: host.textPrimary
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.maximumWidth: 180
            }
        }

        ColumnLayout {
            spacing: 4
            Text { text: "URL serveur"; color: host.textSecondary; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
            TextField {
                id: fieldServerUrl
                placeholderText: "wss://..."
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                background: Rectangle {
                    color: "#222226"
                    radius: 6
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
            onClicked: {
                if (chatClient && fieldServerUrl.text.trim())
                    chatClient.connectToServer(fieldServerUrl.text.trim())
            }
        }

        Item { height: 4 }

        Text {
            text: "Connexion directe à une session"
            color: host.textSecondary
            font.pixelSize: 11
            font.capitalization: Font.AllUppercase
        }
        ColumnLayout {
            spacing: 4
            Text { text: "Session ID"; color: host.textSecondary; font.pixelSize: 11 }
            TextField {
                id: fieldSessionId
                placeholderText: "ex: abc123"
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: fieldSessionId.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldSessionId.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
            }
        }
        ColumnLayout {
            spacing: 4
            Text { text: "Mot de passe"; color: host.textSecondary; font.pixelSize: 11 }
            TextField {
                id: fieldDirectPassword
                placeholderText: "Mot de passe session"
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                echoMode: TextInput.Password
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: fieldDirectPassword.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldDirectPassword.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
            }
        }
        Button {
            text: "Rejoindre la session"
            implicitHeight: 36
            font.pixelSize: 12
            background: Rectangle {
                color: parent.pressed ? "#2d2d35" : "transparent"
                radius: 6
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

        Item { height: 4 }
        Text {
            text: "Participants à la session"
            color: host.textPrimary
            font.pixelSize: 15
            font.bold: true
        }
        RowLayout {
            spacing: 8
            Text {
                text: chatClient && chatClient.connected
                      ? (chatClient.participantCount + " participant(s)")
                      : "— connectez-vous à une session —"
                color: host.textSecondary
                font.pixelSize: 12
            }
            TextField {
                id: fieldRequestConnectionRecipient
                placeholderText: "ID (vide = tous)"
                placeholderTextColor: "#71717a"
                font.pixelSize: 11
                implicitHeight: 28
                Layout.preferredWidth: 100
                visible: chatClient && chatClient.connected
                background: Rectangle {
                    color: "#222226"
                    radius: 4
                    border.color: fieldRequestConnectionRecipient.activeFocus ? host.accent : host.cardBorder
                    border.width: 1
                }
                color: host.textPrimary
            }
            ColumnLayout {
                spacing: 4
                visible: chatClient && chatClient.connected
                Button {
                    text: "Rafraîchir"
                    implicitHeight: 28
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: parent.pressed ? "#2d2d35" : "transparent"
                        radius: 4
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
                Button {
                    text: "Demander infos connexion"
                    implicitHeight: 28
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: parent.pressed ? "#2d2d35" : "transparent"
                        radius: 4
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
                            chatClient.sendRequestConnectionInfo(fieldRequestConnectionRecipient.text.trim(), "", 0)
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }
        ListView {
            id: participantsList
            Layout.fillWidth: true
            Layout.preferredHeight: chatClient && chatClient.connected ? Math.min(260, Math.max(80, chatClient.participantCount * 48 + 8)) : 0
            clip: true
            spacing: 4
            model: chatClient && chatClient.connected ? chatClient.participants : []
            delegate: Rectangle {
                width: parent.width
                height: 44
                color: participantMouseArea.pressed ? host.cardBorder : "#222226"
                radius: 6
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
                        if (card && card.fieldRequestConnectionRecipient)
                            card.fieldRequestConnectionRecipient.text = pid
                        if (card)
                            card.participantClicked(pid, nick)
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text {
                            text: modelData.player_nickname || "—"
                            color: host.textPrimary
                            font.pixelSize: 13
                            font.bold: !!modelData.is_host
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.player_id ? ("id: " + modelData.player_id) : ""
                            color: host.textSecondary
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }
                    Text {
                        text: modelData.is_host ? "Hôte" : ""
                        color: host.accent
                        font.pixelSize: 11
                        visible: !!modelData.is_host
                    }
                    Text {
                        text: modelData.status || "—"
                        color: host.textSecondary
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
