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
                chatClient.requestHistory()
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ChatHeader {
            chatClient: chatClient
            drawer: chatDrawer
        }

        ChatMessagesList {
            id: messagesList
            chatClient: chatClient
            drawer: chatDrawer
        }

        ChatInputBar {
            chatClient: chatClient
            onOpenImageDialog: imageDialog.open()
        }

        ChatStatusBar {
            connected: chatClient.connected
            messageCount: messagesList.messageList ? messagesList.messageList.count : 0
            playerNickname: chatDrawer.playerNickname
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

    onOpened: {
        if (!chatClient.connected) {
            chatClient.connectToServer("ws://pattounecorp.ovh:3000", playerId, "123", playerNickname)
        }
    }
}
