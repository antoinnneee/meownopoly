import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0
import QtQuick.Dialogs
import Catway 1.0
import "."

Drawer {
    id: chatDrawer
    width: 340
    height: parent.height
    edge: Qt.RightEdge

    // chatClient suit Catway.chatClient en priorité ; tombe sur internalChatClient si nul.
    property var chatClient: Catway.chatClient ?? internalChatClient

    property string gameId: ""
    property string playerId: AccountManager.uniqueId
    property string playerNickname: AccountManager.nickname
    property bool isResizing: false
    property int _prevMessageCount: 0
    property string privateRecipientId: ""
    property string privateRecipientNickname: ""

    signal openFullScreenMsg(var modelMsg)
    signal createSnapableRequested(string jsonString)
    signal focusReleased()

    background: Rectangle {
        color: "#E6222222"
        border.color: "#333333"
        border.width: 1
    }

    // Client de secours (utilisé tant qu'aucune session n'est active via Catway)
    ChatClient {
        id: internalChatClient
    }

    // Réagit aux changements de session active dans Catway
    Connections {
        target: Catway
        function onChatClientChanged() {
            // La propriété chatClient se met à jour automatiquement via le binding.
            // Réinitialiser le compteur de messages pour éviter une fausse notification.
            chatDrawer._prevMessageCount = chatDrawer.chatClient
                ? chatDrawer.chatClient.messages.length
                : 0
        }
    }

    // Gestion des erreurs de session (notamment mot de passe requis)
    Connections {
        target: ChatSessionManager
        function onSessionError(sessionId, error, errorType) {
            if (errorType === 1) { // ChatClient.INVALID_PASSWORD = 1
                sessionPasswordDialog.sessionIdForJoin = sessionId
                sessionPasswordDialog.open()
            }
        }
    }

    // Dialog mot de passe pour sessions protégées (accessible depuis le sélecteur de session)
    Dialog {
        id: sessionPasswordDialog
        title: "Mot de passe requis"
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(320, chatDrawer.width - 24)

        property string sessionIdForJoin: ""

        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#4A90E2"
            border.width: 2
            radius: 10
        }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: "Session protégée — entrez le mot de passe :"
                color: "#cccccc"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: pwdField
                placeholderText: "Mot de passe"
                echoMode: TextInput.Password
                color: "#f5f0ff"
                font.pixelSize: 13
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: "#1a1a1a"
                    border.color: pwdField.activeFocus ? "#4A90E2" : "#555555"
                    border.width: 2
                    radius: 6
                }

                onAccepted: sessionPasswordDialog.acceptAndJoin()
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: acceptAndJoin()
        onRejected: {
            pwdField.text = ""
            sessionIdForJoin = ""
        }

        function acceptAndJoin() {
            if (sessionIdForJoin.length === 0) return
            const client = ChatSessionManager.joinSession(sessionIdForJoin, pwdField.text)
            ChatSessionManager.setActiveSession(client)
            pwdField.text = ""
            sessionIdForJoin = ""
            close()
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
            chatClient: chatDrawer.chatClient
            drawer: chatDrawer
            onToggleParticipantsPanel: participantsPanel.visible = !participantsPanel.visible
            onSessionJoinRequested: function(sessionId, sessionName) {
                const client = ChatSessionManager.joinSession(sessionId, "")
                ChatSessionManager.setActiveSession(client)
            }
        }

        // Panneau dépliable des participants
        ChatParticipantsPanel {
            id: participantsPanel
            chatClient: chatDrawer.chatClient
            drawer: chatDrawer
        }

        ChatMessagesList {
            id: messagesList
            chatClient: chatDrawer.chatClient
            drawer: chatDrawer
            onOpenFullScreenMsg: function(modelMsg) {
                chatDrawer.openFullScreenMsg(modelMsg)
            }
        }

        ChatInputBar {
            chatClient: chatDrawer.chatClient
            drawer: chatDrawer
            recipientId: chatDrawer.privateRecipientId
            recipientNickname: chatDrawer.privateRecipientNickname
            onOpenImageDialog: imageDialog.open()
            onOpenTextFileDialog: textFileDialog.open()
            onClearRecipient: {
                chatDrawer.privateRecipientId = ""
                chatDrawer.privateRecipientNickname = ""
            }
            onCreateSnapableRequested: function(jsonString) {
                chatDrawer.createSnapableRequested(jsonString)
            }
            onFocusReleased: chatDrawer.focusReleased()
        }

        ChatStatusBar {
            connected: chatDrawer.chatClient ? chatDrawer.chatClient.connected : false
            messageCount: messagesList.messageList ? messagesList.messageList.count : 0
            playerNickname: chatDrawer.playerNickname
            participantCount: chatDrawer.chatClient ? chatDrawer.chatClient.participantCount : 0
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
        // Le fallback internalChatClient se connecte seulement si aucune session n'est active
        if (!Catway.chatClient) {
            internalChatClient.connectToServer("ws://pattounecorp.ovh:3000")
        }
    }

    onOpened: {
        // Si le client actif n'est pas connecté et qu'on utilise le fallback, on (re)connecte
        if (!chatClient.connected && chatClient === internalChatClient) {
            internalChatClient.connectToServer("ws://pattounecorp.ovh:3000")
            internalChatClient.connectToSession(playerId, "123", playerNickname)
        }
        // Force le retour en bas à chaque ouverture du drawer : la ListView peut
        // contenir des messages avec des images dont le chargement asynchrone vient
        // tout juste de se terminer (ou est encore en cours). Le re-stick + re-snap
        // garantit qu'on apparaît au dernier message, pas au milieu.
        if (messagesList.messageList) {
            messagesList.messageList.stickToBottom = true
            messagesList.messageList.snapToBottom()
        }
    }
}
