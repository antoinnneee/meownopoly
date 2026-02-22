import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0
import "."

Rectangle {
    id: participantsPanel
    Layout.fillWidth: true
    Layout.preferredHeight: visible ? participantsPanelContent.implicitHeight + 16 : 0
    implicitHeight: participantsPanelContent.implicitHeight + 16
    color: "#2d2d2d"
    border.color: "#3a3a3a"
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
        anchors.margins: 8
        spacing: 4

        // Titre du panneau
        RowLayout {
            width: parent.width
            spacing: 6

            Text {
                text: "👥"
                font.pointSize: 9
            }

            Text {
                text: "Participants connectés"
                color: "#aaaaaa"
                font.pointSize: 8
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: chatClient ? chatClient.participantCount.toString() : "0"
                color: "#4A90E2"
                font.pointSize: 8
                font.bold: true
            }

            // Bouton rafraîchir
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                color: refreshBtnArea.containsMouse ? "#444444" : "transparent"
                radius: 4

                Text {
                    text: "🔄"
                    font.pointSize: 8
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
            color: "#3a3a3a"
        }

        // Liste des participants
        Repeater {
            model: chatClient ? chatClient.participants : []

            Rectangle {
                width: participantsPanelContent.width
                height: 28
                color: participantHoverArea.containsMouse ? "#383838" : "transparent"
                radius: 4

                Behavior on color { ColorAnimation { duration: 100 } }

                MouseArea {
                    id: participantHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

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
                        font.pointSize: 8
                        visible: modelData.is_host || false
                    }

                    Text {
                        text: modelData.player_nickname || modelData.player_id || "?"
                        color: (modelData.player_id === drawer.playerId) ? "#4A90E2" : "#cccccc"
                        font.pointSize: 8
                        font.bold: modelData.player_id === drawer.playerId
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (modelData.player_id === drawer.playerId) ? "(vous)" : ""
                        color: "#888888"
                        font.pointSize: 7
                        font.italic: true
                        visible: modelData.player_id === drawer.playerId
                    }

                    // Bouton Message privé (pas pour soi-même)
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        color: privateMsgBtnArea.containsMouse ? "#334466" : "transparent"
                        radius: 4
                        visible: modelData.player_id !== drawer.playerId

                        Text {
                            text: "🔒"
                            font.pointSize: 8
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
                        radius: 4
                        visible: {
                            if (!chatClient || chatClient.participants.length < 1) return false;
                            var isHost = chatClient.participants[0].player_id === drawer.playerId;
                            var isNotMe = modelData.player_id !== drawer.playerId;
                            return isHost && isNotMe;
                        }

                        Text {
                            text: "❌"
                            font.pointSize: 8
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
            color: "#666666"
            font.pointSize: 8
            font.italic: true
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !chatClient || chatClient.participantCount === 0
            topPadding: 4
            bottomPadding: 4
        }
    }
}
