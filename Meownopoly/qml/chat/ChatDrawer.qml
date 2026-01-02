import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Meownopoly.Chat 1.0
import QtQuick.Dialogs
import "."

Drawer {
    id: chatDrawer
    width: 340
    height: parent.height
    edge: Qt.RightEdge

    property string gameId: ""
    property string playerId: "Player_" + Math.floor(Math.random() * 1000)
    property bool isResizing: false

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

        // --- Header avec zone de redimensionnement ---
        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#333333"
            border.color: "#444444"
            border.width: 1

            // Zone de redimensionnement sur le bord gauche
            Rectangle {
                id: resizeHandle
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 8
                color: resizeMouseArea.pressed ? "#4A90E2" : (resizeMouseArea.containsMouse ? "#444444" : "transparent")
                z: 15

                // Indicateur visuel
                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: parent.height * 0.4
                    color: resizeMouseArea.containsMouse || chatDrawer.isResizing ? "#4A90E2" : "#666666"
                    radius: 1
                }

                MouseArea {
                    id: resizeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor
                    preventStealing: true

                    property real startX: 0
                    property real startWidth: 0
                    property int minWidth: 280
                    property int maxWidth: 600

                    onPressed: function(mouse) {
                        chatDrawer.isResizing = true
                        startX = mapToGlobal(mouse.x, mouse.y).x
                        startWidth = chatDrawer.width
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var globalX = mapToGlobal(mouse.x, mouse.y).x
                            var delta = startX - globalX
                            var newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + delta))
                            chatDrawer.width = newWidth
                        }
                    }

                    onReleased: {
                        chatDrawer.isResizing = false
                    }
                }

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 8

                // Icône chat
                Text {
                    text: "💬"
                    font.pixelSize: 20
                }

                Text {
                    text: "Chat"
                    color: "#cccccc"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }

                // Indicateur de connexion
                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: chatClient.connected ? "#4a8a4a" : "#aa4444"
                    border.color: chatClient.connected ? "#569c58" : "#cc4444"
                    border.width: 1

                    SequentialAnimation on opacity {
                        running: !chatClient.connected
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                Text {
                    text: chatDrawer.gameId
                    color: "#888888"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.maximumWidth: 80
                }
            }
        }


        // --- Liste des messages ---
        Rectangle {
            id: messagesContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#2a2a2a"
            border.color: dropArea.containsDrag ? "#4A90E2" : "#444444"
            border.width: dropArea.containsDrag ? 2 : 1

            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on border.width { NumberAnimation { duration: 150 } }

            // --- DropArea pour les images ---
            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list", "text/plain"]

                onEntered: function(drag) {
                    // Vérifier si c'est une image
                    if (drag.hasUrls) {
                        var validImage = false
                        for (var i = 0; i < drag.urls.length; i++) {
                            var url = drag.urls[i].toString().toLowerCase()
                            if (url.endsWith(".png") || url.endsWith(".jpg") ||
                                url.endsWith(".jpeg") || url.endsWith(".gif") ||
                                url.endsWith(".webp")) {
                                validImage = true
                                break
                            }
                        }
                        drag.accepted = validImage
                    }
                }

                onDropped: function(drop) {
                    if (drop.hasUrls) {
                        for (var i = 0; i < drop.urls.length; i++) {
                            var url = drop.urls[i].toString().toLowerCase()
                            if (url.endsWith(".png") || url.endsWith(".jpg") ||
                                url.endsWith(".jpeg") || url.endsWith(".gif") ||
                                url.endsWith(".webp")) {
                                chatClient.sendImage(drop.urls[i])
                            }
                        }
                    }
                }
            }

            // --- Overlay de drop ---
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
                    anchors.margins: 20
                    color: "transparent"
                    border.color: "#4A90E2"
                    border.width: 2
                    border.pixelAligned: true
                    radius: 12

                    // Bordure en pointillés simulée
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        color: "transparent"
                        border.color: "#4A90E2"
                        border.width: 1
                        radius: 10
                        opacity: 0.5
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        // Icône
                        Rectangle {
                            width: 64
                            height: 64
                            radius: 32
                            color: "#333333"
                            border.color: "#4A90E2"
                            border.width: 2
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                text: "📷"
                                font.pixelSize: 28
                                anchors.centerIn: parent
                            }

                            // Animation de pulsation
                            SequentialAnimation on scale {
                                running: dropArea.containsDrag
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.1; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: "Déposez votre image ici"
                            color: "#cccccc"
                            font.pixelSize: 14
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "PNG, JPG, GIF, WebP"
                            color: "#888888"
                            font.pixelSize: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            ListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: 8
                cacheBuffer: 500  // Réduit de 1000 pour économiser la mémoire
                model: chatClient.messages
                clip: true
                spacing: 8
                
                // Optimisations de performance
                highlightFollowsCurrentItem: false
                // reuseItems: true  // Réutiliser les delegates pour économiser la mémoire
                
                // Animation de défilement fluide mais moins coûteuse
                Behavior on contentY {
                    SmoothedAnimation {
                        velocity: 1500  // Plus rapide
                        duration: 200   // Plus court
                        easing.type: Easing.OutQuad  // Easing plus léger
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    id: messagesScrollBar
                    active: true
                    policy: ScrollBar.AsNeeded

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: parent.pressed ? "#4A90E2" : "#555555"
                    }

                    background: Rectangle {
                        implicitWidth: 6
                        color: "#333333"
                        radius: 3
                    }
                }

                delegate: Rectangle {
                    id: messageDelegate
                    width: messageList.width - 16
                    height: contentCol.height + 12
                    x: 8

                    required property var modelData
                    required property int index
                    
                    property bool isOwnMessage: modelData.sender === chatDrawer.playerId

                    color: isOwnMessage ? "#3d4a3d" : "#333333"
                    radius: 6
                    border.color: isOwnMessage ? "#4a8a4a" : "#444444"
                    border.width: 1
                    
                    antialiasing: true

                    // Animation d'apparition simplifiée (uniquement pour les nouveaux messages)
                    opacity: 0
                    Component.onCompleted: {
                        // Animer seulement si c'est le dernier message
                        if (index === messageList.count - 1) {
                            fadeInAnimation.start()
                        } else {
                            opacity = 1
                        }
                    }

                    NumberAnimation {
                        id: fadeInAnimation
                        target: messageDelegate
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 150
                        easing.type: Easing.OutQuad
                    }

                    Column {
                        id: contentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "🐱"
                                font.pixelSize: 12
                                visible: !messageDelegate.isOwnMessage
                            }

                            Text {
                                text: messageDelegate.modelData.sender
                                font.pixelSize: 10
                                font.bold: true
                                color: messageDelegate.isOwnMessage ? "#569c58" : "#4A90E2"
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "dd-mm:hh:mm"
                                font.pixelSize: 8
                                color: "#666666"
                            }
                        }

                        Text {
                            id: msgText
                            text: messageDelegate.modelData.text
                            width: parent.width
                            wrapMode: Text.Wrap
                            color: "#cccccc"
                            font.pixelSize: 12
                            visible: !messageDelegate.modelData.isImage
                        }

                        Image {
                            id: messageImage
                            source: messageDelegate.modelData.isImage ? messageDelegate.modelData.text : ""
                            visible: messageDelegate.modelData.isImage
                            asynchronous: true
                            cache: true
                            
                            // Dimensions fixes pour éviter le redimensionnement coûteux
                            width: parent.width
                            fillMode: Image.PreserveAspectFit
                            
                            // Optimisations de performance
                            smooth: false  // Désactiver l'antialiasing pendant le scroll
                            mipmap: true   // Utiliser le mipmapping pour les redimensionnements
                            // autoTransform: true
                            
                            sourceSize.height:height
                            sourceSize.width: width
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: "#444444"
                                border.width: 1
                                radius: 4
                                visible: parent.status === Image.Ready
                            }

                            BusyIndicator {
                                anchors.centerIn: parent
                                running: parent.status === Image.Loading
                                visible: running
                                
                                // Indicateur plus léger
                                width: 32
                                height: 32
                            }
                            
                            // Message d'erreur si l'image ne charge pas
                            Rectangle {
                                anchors.fill: parent
                                color: "#3a3a3a"
                                radius: 4
                                visible: parent.status === Image.Error
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "❌ Erreur de chargement"
                                    color: "#aa4444"
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }

                onCountChanged: {
                    scrollToBottomTimer.restart()
                }

                // Timer pour scroll avec délai (permet l'animation de se terminer)
                Timer {
                    id: scrollToBottomTimer
                    interval: 50
                    repeat: false
                    onTriggered: {
                        messageList.positionViewAtEnd()
                    }
                }

                // Message vide state
                Rectangle {
                    anchors.centerIn: parent
                    width: 200
                    height: 80
                    color: "#333333"
                    radius: 8
                    border.color: "#444444"
                    border.width: 1
                    visible: messageList.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "🐾"
                            font.pixelSize: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Aucun message"
                            color: "#888888"
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Commencez la conversation !"
                            color: "#666666"
                            font.pixelSize: 9
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // --- Zone de saisie ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#333333"
            border.color: "#444444"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Bouton image
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    color: imgBtnArea.containsMouse ? "#444444" : "#3a3a3a"
                    radius: 6
                    border.color: imgBtnArea.pressed ? "#4A90E2" : "#555555"
                    border.width: 1

                    Text {
                        text: "📷"
                        anchors.centerIn: parent
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: imgBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: imageDialog.open()
                    }

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                // Champ de texte
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#2a2a2a"
                    radius: 6
                    border.color: inputField.activeFocus ? "#4A90E2" : "#444444"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextField {
                        id: inputField
                        anchors.fill: parent
                        anchors.margins: 4
                        placeholderText: "Tapez un message..."
                        placeholderTextColor: "#666666"
                        color: "#cccccc"
                        font.pixelSize: 12

                        background: Rectangle {
                            color: "transparent"
                        }

                        onAccepted:  {
                            if (inputField.text !== "") {
                                chatClient.sendMessage(inputField.text)
                                inputField.text = ""
                            }
                            inputField.focus = false
                        }
                    }
                }

                // Bouton envoyer
                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 36
                    color: sendBtnArea.pressed ? "#569c58" : (sendBtnArea.containsMouse ? "#4a8a4a" : "#3d6b3d")
                    radius: 6
                    border.color: "#569c58"
                    border.width: 1
                    opacity: inputField.text !== "" ? 1.0 : 0.5

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "Envoyer"
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: sendBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (inputField.text !== "") {
                                chatClient.sendMessage(inputField.text)
                                inputField.text = ""
                            }
                            inputField.focus = false
                        }
                    }
                }
            }
        }

        // --- Barre d'état ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            color: "#2a2a2a"
            border.color: "#333333"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: chatClient.connected ? "● Connecté" : "○ Déconnecté"
                    color: chatClient.connected ? "#4a8a4a" : "#888888"
                    font.pixelSize: 9
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: messageList.count + " messages"
                    color: "#666666"
                    font.pixelSize: 9
                }

                Text {
                    text: "│"
                    color: "#444444"
                    font.pixelSize: 9
                }

                Text {
                    text: chatDrawer.playerId
                    color: "#888888"
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    Layout.maximumWidth: 100
                }
            }
        }
    }

    // Animation d'ouverture du drawer
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

    onOpened: {
        if (!chatClient.connected) {
            chatClient.connectToServer("ws://pattounecorp.ovh:3000", playerId)
        }
        // inputField.forceActiveFocus()
    }
}
