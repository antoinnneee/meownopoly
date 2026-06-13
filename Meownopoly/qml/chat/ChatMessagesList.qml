import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

Rectangle {
    id: messagesContainer
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: Theme.surface

    border.color: dropArea.containsDrag ? Theme.accent : Theme.border
    border.width: dropArea.containsDrag ? 2 : 1

    property var chatClient
    property var drawer
    property alias messageList: messageList

    signal countChanged(int count)
    signal openFullScreenMsg(var modelMsg)

    Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
    Behavior on border.width { NumberAnimation { duration: Theme.durationNormal } }

    // Extensions de fichiers texte acceptées
    property var textFileExtensions: [
        ".txt", ".md", ".json", ".xml", ".csv", ".log", ".yml", ".yaml", ".toml", ".ini", ".cfg",
        ".js", ".ts", ".py", ".cpp", ".c", ".h", ".hpp", ".java", ".cs", ".go", ".rs", ".rb",
        ".php", ".swift", ".kt", ".qml", ".html", ".css", ".sql", ".sh", ".bat", ".qml"
    ]

    function isTextFileUrl(url) {
        var lower = url.toString().toLowerCase()
        for (var i = 0; i < textFileExtensions.length; i++) {
            if (lower.endsWith(textFileExtensions[i])) return true
        }
        return false
    }

    function isImageUrl(url) {
        var lower = url.toString().toLowerCase()
        return lower.endsWith(".png") || lower.endsWith(".jpg") ||
               lower.endsWith(".jpeg") || lower.endsWith(".gif") ||
               lower.endsWith(".webp")
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]

        onEntered: function(drag) {
            if (drag.hasUrls) {
                var validFile = false
                for (var i = 0; i < drag.urls.length; i++) {
                    if (isImageUrl(drag.urls[i]) || isTextFileUrl(drag.urls[i])) {
                        validFile = true
                        break
                    }
                }
                drag.accepted = validFile
            }
        }

        onDropped: function(drop) {
            if (drop.hasUrls && chatClient) {
                for (var i = 0; i < drop.urls.length; i++) {
                    if (isImageUrl(drop.urls[i])) {
                        chatClient.sendImage(drop.urls[i])
                    } else if (isTextFileUrl(drop.urls[i])) {
                        chatClient.sendTextFile(drop.urls[i])
                    }
                }
            }
        }
    }

    Rectangle {
        id: dropOverlay
        anchors.fill: parent
        color: "#E6222222"
        opacity: dropArea.containsDrag ? 1 : 0
        visible: opacity > 0
        z: 100

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingHuge
            color: "transparent"
            border.color: Theme.accent
            border.width: 2
            border.pixelAligned: true
            radius: Theme.radiusXXL

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                color: "transparent"
                border.color: Theme.accent
                border.width: 1
                radius: Theme.radiusXL
                opacity: 0.5
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXL

                Rectangle {
                    width: 64
                    height: 64
                    radius: 32
                    color: Theme.surfaceAlt
                    border.color: Theme.accent
                    border.width: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "📎"
                        font.pixelSize: Theme.fontSizeDisplay
                        anchors.centerIn: parent
                    }

                    SequentialAnimation on scale {
                        running: dropArea.containsDrag
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.1; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                    }
                }

                Text {
                    text: "Déposez votre fichier ici"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Images ou fichiers texte"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    ListView {
        id: messageList
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        model: chatClient ? chatClient.messages : null
        clip: true
        spacing: Theme.spacingXS
        highlightFollowsCurrentItem: false
        reuseItems: true
        // Matérialise plus d'items hors écran pour que ListView mesure leur vraie hauteur
        // et que la ScrollBar reflète mieux la taille réelle du contenu (en particulier
        // quand un item « grand » — image, fichier texte — change la hauteur globale).
        cacheBuffer: 2000

        // Vrai tant que la vue est « collée » au dernier message. Devient false dès que
        // l'utilisateur fait un scroll manuel vers le haut, et redevient true dès qu'il
        // remonte au bas. Sert à décider si on doit re-snapper en bas à chaque changement
        // de contentHeight (chargements async d'images, mesure tardive de TextEdit, etc.).
        property bool stickToBottom: true

        function snapToBottom() {
            // positionViewAtEnd() ne suffit pas seul si une image vient d'être ajoutée :
            // sa hauteur est encore en cours de calcul. On planifie via un Timer pour
            // laisser au layout le temps de se stabiliser, puis on retente plusieurs fois.
            scrollToBottomTimer.restart()
        }

        Behavior on contentY {
            SmoothedAnimation {
                velocity: 1500
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        // Re-stick à chaque changement de hauteur du contenu : c'est ce qui rattrape les
        // chargements asynchrones (Image, TextEdit) qui font « grandir » des delegates
        // déjà visibles APRÈS le premier positionViewAtEnd().
        onContentHeightChanged: {
            if (stickToBottom)
                positionViewAtEnd()
        }

        // Détection du scroll utilisateur. On ne change stickToBottom que sur les
        // mouvements pilotés par l'utilisateur (flick / drag), pas sur les
        // repositionnements programmatiques.
        onMovementEnded: {
            stickToBottom = atYEnd
        }

        ScrollBar.vertical: ScrollBar {
            active: true
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: parent.pressed ? Theme.accent : Theme.borderLight
            }
            background: Rectangle {
                implicitWidth: 6
                color: Theme.surfaceAlt
                radius: 3
            }
        }

        delegate: Item {
            required property var modelData
            required property int index
            width: messageList.width - 16
            height: delegateImpl.height + 8
            x: 8

            readonly property bool isOwn: modelData && messagesContainer.drawer && (modelData.sender === messagesContainer.drawer.playerId)

            ChatMessageDelegate {
                id: delegateImpl
                drawer: messagesContainer.drawer
                listView: messageList
                modelData: parent.modelData
                index: parent.index
                chatClient: messagesContainer.chatClient
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingXS
                anchors.left: parent.isOwn ? undefined : parent.left
                anchors.right: parent.isOwn ? parent.right : undefined
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                onOpenFullScreenMsg: function(modelMsg) {
                    messagesContainer.openFullScreenMsg(modelMsg)
                }
            }
        }

        onCountChanged: {
            // Nouveau message → si on était collé en bas, y rester. On force aussi
            // stickToBottom à true au tout premier rendu (count passe de 0 à N) pour
            // que l'ouverture du chat parte bien sur le dernier message.
            if (stickToBottom)
                scrollToBottomTimer.restart()
            messagesContainer.countChanged(messageList.count)
        }

        // Plusieurs « tirs » différés pour rattraper les chargements asynchrones.
        // Le premier (50 ms) gère le cas habituel ; les suivants (200/600 ms)
        // attrapent les images qui mettent plus de temps à se décoder/mesurer.
        Timer {
            id: scrollToBottomTimer
            interval: 50
            repeat: false
            onTriggered: {
                messageList.positionViewAtEnd()
                scrollToBottomLateTimer.restart()
            }
        }
        Timer {
            id: scrollToBottomLateTimer
            interval: 200
            repeat: false
            onTriggered: {
                if (messageList.stickToBottom) {
                    messageList.positionViewAtEnd()
                    scrollToBottomVeryLateTimer.restart()
                }
            }
        }
        Timer {
            id: scrollToBottomVeryLateTimer
            interval: 400
            repeat: false
            onTriggered: {
                if (messageList.stickToBottom)
                    messageList.positionViewAtEnd()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 200
            height: 80
            color: Theme.surfaceAlt
            radius: Theme.radiusL
            border.color: Theme.border
            border.width: 1
            visible: messageList.count === 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM

                Text {
                    text: "🐾"
                    font.pixelSize: Theme.fontSizeDisplay
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Aucun message"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Commencez la conversation !"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSizeTiny
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
