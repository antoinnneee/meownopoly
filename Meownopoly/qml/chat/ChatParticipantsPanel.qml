import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0
import "."
import theme

Rectangle {
    id: participantsPanel
    Layout.fillWidth: true
    Layout.preferredHeight: visible ? participantsPanelContent.implicitHeight + 16 : 0
    implicitHeight: participantsPanelContent.implicitHeight + 16
    color: Theme.surface
    border.color: Theme.surfaceHover
    border.width: 1
    visible: false
    clip: true

    property ChatClient chatClient: null
    property var drawer: null

    Behavior on Layout.preferredHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Column {
        id: participantsPanelContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS

        // Titre du panneau
        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            Text {
                text: "👥"
                font.pixelSize: Theme.fontSizeBody
            }

            Text {
                text: "Participants connectés"
                color: "#aaaaaa"
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: chatClient ? chatClient.participantCount.toString() : "0"
                color: Theme.accent
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }

            // Bouton rafraîchir
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                color: refreshBtnArea.containsMouse ? Theme.border : "transparent"
                radius: Theme.radiusS

                Text {
                    text: "🔄"
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: refreshBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (chatClient) chatClient.requestParticipants()
                    }
                }

                ToolTip {
                    visible: refreshBtnArea.containsMouse
                    text: "Rafraîchir la liste"
                    delay: 400
                }
            }
        }

        // Séparateur
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.surfaceHover
        }

        // Liste des participants
        Repeater {
            model: chatClient ? chatClient.participants : []

            Rectangle {
                width: participantsPanelContent.width
                height: 28
                color: participantHoverArea.containsMouse ? Theme.surfaceHover : "transparent"
                radius: Theme.radiusS

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: participantHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    // Indicateur en ligne/hors ligne/absent
                    Rectangle {
                        id: statusIndicator
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: modelData.status === "online" ? "#4a8a4a" : (modelData.status === "away" ? "#e2a94a" : "#a84a4a")
                        border.color: Qt.lighter(color, 1.2)
                        border.width: 1

                        ToolTip {
                            visible: statusIndicatorArea.containsMouse
                            text: modelData.status === "online" ? "En ligne" : (modelData.status === "away" ? "Absent" : "Hors ligne")
                            delay: 400
                        }

                        MouseArea {
                            id: statusIndicatorArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }

                    Text {
                        text: "👑"
                        font.pixelSize: Theme.fontSizeSmall
                        visible: modelData.is_host || false
                    }

                    Text {
                        text: modelData.player_nickname || modelData.player_id || "?"
                        color: (modelData.player_id === drawer.playerId) ? Theme.accent : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: modelData.player_id === drawer.playerId
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (modelData.player_id === drawer.playerId) ? "(vous)" : ""
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeTiny
                        font.italic: true
                        visible: modelData.player_id === drawer.playerId
                    }

                    // Bouton Message privé (pas pour soi-même)
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        color: privateMsgBtnArea.containsMouse ? "#334466" : "transparent"
                        radius: Theme.radiusS
                        visible: modelData.player_id !== drawer.playerId

                        Text {
                            text: "✉️"
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: privateMsgBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                drawer.privateRecipientId = modelData.player_id
                                drawer.privateRecipientNickname = modelData.player_nickname || modelData.player_id || "?"
                            }
                        }

                        ToolTip {
                            visible: privateMsgBtnArea.containsMouse
                            text: "Envoyer un message privé (non enregistré)"
                            delay: 400
                        }
                    }

                    // Bouton Kick (visible seulement pour l'hôte et pas pour soi-même)
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        color: kickBtnArea.containsMouse ? "#552222" : "transparent"
                        radius: Theme.radiusS
                        visible: {
                            if (!chatClient || chatClient.participants.length < 1) return false;
                            var isHost = chatClient.participants[0].player_id === drawer.playerId;
                            var isNotMe = modelData.player_id !== drawer.playerId;
                            return isHost && isNotMe;
                        }

                        Text {
                            text: "❌"
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: kickBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (chatClient) chatClient.kickPlayer(modelData.player_id)
                            }
                        }

                        ToolTip {
                            visible: kickBtnArea.containsMouse
                            text: "Exclure ce participant"
                            delay: 400
                        }
                    }
                }
            }
        }

        // Message si aucun participant
        Text {
            text: "Aucun participant connecté"
            color: Theme.textDisabled
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !chatClient || chatClient.participantCount === 0
            topPadding: Theme.spacingXS
            bottomPadding: Theme.spacingXS
        }
    }
}
