import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0
import QtQuick.Dialogs
import "."

Drawer {
    id: chatDrawer
    width: 340
    height: parent.height
    edge: Qt.RightEdge

    property string gameId: ""
    property string playerId: AccountManager.uniqueId
    property string playerNickname: AccountManager.nickname
    property bool isResizing: false
    property int _prevMessageCount: 0
    // Message privé : destinataire sélectionné (vide = envoi à tous)
    property string privateRecipientId: ""
    property string privateRecipientNickname: ""

    background: Rectangle {
        color: "#E6222222"
        border.color: "#333333"
        border.width: 1
    }

    ChatClient {
        id: chatClient
        sessionId: chatDrawer.gameId

        onConnectedChanged: {
            if (connected) {
                console.log("Chat connected!")
                connectToSession(playerId, "123", playerNickname)
            } else {
                console.log("Chat disconnected!")
            }
        }
    }

    function formatTimestamp(ts) {
        if (!ts) return "--:--"
        let date = new Date(ts)
        if (isNaN(date.getTime())) {
            date = new Date(ts.replace(" ", "T"))
            if (isNaN(date.getTime())) return ts
        }
        let now = new Date()
        let isToday = date.getDate() === now.getDate() &&
                      date.getMonth() === now.getMonth() &&
                      date.getFullYear() === now.getFullYear()
        let hours = date.getHours().toString().padStart(2, '0')
        let minutes = date.getMinutes().toString().padStart(2, '0')
        if (isToday) {
            return hours + ":" + minutes
        } else {
            let day = date.getDate().toString().padStart(2, '0')
            let month = (date.getMonth() + 1).toString().padStart(2, '0')
            return day + "/" + month + " " + hours + ":" + minutes
        }
    }

    FileDialog {
        id: imageDialog
        title: "Choose an image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.webp)"]
        onAccepted: {
            chatClient.sendImage(imageDialog.selectedFile)
        }
    }

    FileDialog {
        id: textFileDialog
        title: "Choose a text file"
        nameFilters: [
            "Text files (*.txt *.md *.json *.xml *.csv *.log *.yml *.yaml *.toml *.ini *.cfg)",
            "Source code (*.js *.ts *.py *.cpp *.c *.h *.hpp *.java *.cs *.go *.rs *.rb *.php *.swift *.kt *.qml *.html *.css *.sql *.sh *.bat)",
            "All files (*)"
        ]
        onAccepted: {
            chatClient.sendTextFile(textFileDialog.selectedFile)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ChatHeader {
            id: chatHeader
            chatClient: chatClient
            drawer: chatDrawer
            onToggleParticipantsPanel: participantsPanel.visible = !participantsPanel.visible
        }

        // Panneau dépliable des participants
        Rectangle {
            id: participantsPanel
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? participantsPanelContent.implicitHeight + 16 : 0
            color: "#2d2d2d"
            border.color: "#3a3a3a"
            border.width: 1
            visible: false
            clip: true

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

                            // Indicateur en ligne/hors ligne
                            Rectangle {
                                id: statusIndicator
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: modelData.status === "online" ? "#4a8a4a" : "#a84a4a"
                                border.color: Qt.lighter(color, 1.2)
                                border.width: 1

                                ToolTip {
                                    visible: statusIndicatorArea.containsMouse
                                    text: modelData.status === "online" ? "En ligne" : "Hors ligne"
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
                                color: (modelData.player_id === chatDrawer.playerId) ? "#4A90E2" : "#cccccc"
                                font.pointSize: 8
                                font.bold: modelData.player_id === chatDrawer.playerId
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: (modelData.player_id === chatDrawer.playerId) ? "(vous)" : ""
                                color: "#888888"
                                font.pointSize: 7
                                font.italic: true
                                visible: modelData.player_id === chatDrawer.playerId
                            }

                            // Bouton Message privé (pas pour soi-même)
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                color: privateMsgBtnArea.containsMouse ? "#334466" : "transparent"
                                radius: 4
                                visible: modelData.player_id !== chatDrawer.playerId

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
                                        chatDrawer.privateRecipientId = modelData.player_id
                                        chatDrawer.privateRecipientNickname = modelData.player_nickname || modelData.player_id || "?"
                                    }
                                }

                                ToolTip {
                                    visible: privateMsgBtnArea.containsMouse
                                    text: "Envoyer un message privé (non enregistré)"
                                    delay: 400
                                }
                            }

                            // Bouton Kick (visible seulement pour l'hôte et pas pour soi-même)
                            // Positionné à droite de la ligne du participant
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                color: kickBtnArea.containsMouse ? "#552222" : "transparent"
                                radius: 4
                                visible: {
                                    if (!chatClient || chatClient.participants.length < 1) return false;
                                    var isHost = chatClient.participants[0].player_id === chatDrawer.playerId;
                                    var isNotMe = modelData.player_id !== chatDrawer.playerId;
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

        ChatMessagesList {
            id: messagesList
            chatClient: chatClient
            drawer: chatDrawer
        }

        ChatInputBar {
            chatClient: chatClient
            drawer: chatDrawer
            recipientId: chatDrawer.privateRecipientId
            recipientNickname: chatDrawer.privateRecipientNickname
            onOpenImageDialog: imageDialog.open()
            onOpenTextFileDialog: textFileDialog.open()
            onClearRecipient: {
                chatDrawer.privateRecipientId = ""
                chatDrawer.privateRecipientNickname = ""
            }
        }

        ChatStatusBar {
            connected: chatClient.connected
            messageCount: messagesList.messageList ? messagesList.messageList.count : 0
            playerNickname: chatDrawer.playerNickname
            participantCount: chatClient.participantCount
        }
    }

    enter: Transition {
        NumberAnimation {
            property: "position"
            from: 0
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "position"
            from: 1
            to: 0
            duration: 200
            easing.type: Easing.InCubic
        }
    }

    ChatToastPopup {
        id: messageToastPopup
        parent: chatDrawer.parent
    }

    Connections {
        target: messagesList
        function onCountChanged(count) {
            if (!chatDrawer.opened && count === _prevMessageCount + 1 && count > 0) {
                var list = chatClient.messages
                if (list && list.length > 0) {
                    var last = list[list.length - 1]
                    var msgText = (last && last.text) ? last.text : ""
                    var senderName = (last && last.senderNickname) ? last.senderNickname : ((last && last.sender) ? last.sender : "?")
                    if (last && last.isImage) msgText = "📷 Image"
                    messageToastPopup.show(senderName, msgText)
                }
            }
            _prevMessageCount = count
        }
    }

    Component.onCompleted: {
        chatClient.connectToServer("ws://pattounecorp.ovh:3000")
    }

    onOpened: {
        if (!chatClient.connected) {
            chatClient.connectToServer("ws://pattounecorp.ovh:3000")
            chatClient.connectToSession(playerId, "123", playerNickname)
        }
    }
}
