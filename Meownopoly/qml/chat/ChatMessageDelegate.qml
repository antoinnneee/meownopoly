import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import theme

Rectangle {
    id: messageDelegate
    required property var modelData
    required property int index
    required property var drawer
    required property var listView
    property var chatClient: null

    property var fullScreenMode: null
    property bool hasData: !!modelData
    property bool isOwnMessage: hasData && drawer && (modelData.sender === drawer.playerId)

    signal openFullScreenMsg(var modelMsg)

    visible: hasData

    // Style distinct : nos messages = bulle verte à droite, les autres = gris à gauche
    color: isOwnMessage ? "#1e4620" : Theme.surfaceAlt
    radius: Theme.radiusXXL
    border.color: isOwnMessage ? "#2d6b30" : Theme.border
    border.width: isOwnMessage ? 1.5 : 1
    antialiasing: true

    width: fullScreenMode
           ? parent.width
           : Math.min((listView ? listView.width : 320) - 24,
                       Math.max(140, (listView ? listView.width : 320) * 0.78))
    height: fullScreenMode
            ? parent.height
            : (hasData ? (contentCol.height + 12) : 0)

    // width: Math.min((listView ? listView.width : 320) - 24, Math.max(140, (listView ? listView.width : 320) * 0.78))
    // height: hasData ? (contentCol.height + 12) : 0

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onDoubleClicked: {
            openFullScreenMsg(messageDelegate.modelData)
            console.log("Double-clicked message ")
        }
    }

    opacity: 0
    Component.onCompleted: {
        var isLast = listView && (index === listView.count - 1)
        if (isLast) {
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
        duration: Theme.durationNormal
        easing.type: Easing.OutQuad
    }

    FileDialog {
        id: saveImageDialog
        title: "Enregistrer l'image"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        property string currentImageId: ""
        onAccepted: {
            if (messageDelegate.chatClient && currentImageId) {
                messageDelegate.chatClient.saveImageToFile(currentImageId, saveImageDialog.selectedFile)
            }
        }
    }
    Timer {
        id: copyTimer
        interval: 1500
    }

    Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS
        visible: messageDelegate.hasData

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS
            layoutDirection: messageDelegate.isOwnMessage ? Qt.RightToLeft : Qt.LeftToRight

            Text {
                text: "🐱"
                font.pixelSize: Theme.fontSizeBody
                visible: !messageDelegate.isOwnMessage
            }

            Text {
                text: messageDelegate.isOwnMessage ? "Vous" : (modelData ? (modelData.senderNickname || modelData.sender || "?") : "?")
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                color: messageDelegate.isOwnMessage ? "#7bc97f" : Theme.accent
                Layout.fillWidth: true
            }

            Text {
                text: (modelData && drawer && typeof drawer.formatTimestamp === "function") ? drawer.formatTimestamp(modelData.timestamp) : "--:--"
                font.pixelSize: Theme.fontSizeTiny
                color: messageDelegate.isOwnMessage ? "#9ccc9e" : Theme.textDisabled
            }

            // Badge message privé : afficher le destinataire pour nos envois, "Reçu en privé" pour les autres
            Rectangle {
                visible: !!(modelData && modelData.ephemeral)
                Layout.preferredWidth: Math.max(52, ephemeralLabel.implicitWidth + 10)
                Layout.preferredHeight: 14
                radius: Theme.radiusXS
                color: "#2a3a4a"
                border.color: Theme.accent
                border.width: 1

                Text {
                    id: ephemeralLabel
                    text: messageDelegate.isOwnMessage && (modelData.recipientNickname || modelData.recipientId)
                        ? ("🔒 À : " + (modelData.recipientNickname || modelData.recipientId || "?"))
                        : "🔒 Privé"
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.accent
                    anchors.centerIn: parent
                }

                ToolTip {
                    visible: ephemeralBadgeArea.containsMouse
                    text: messageDelegate.isOwnMessage && (modelData.recipientNickname || modelData.recipientId)
                        ? ("Message privé à " + (modelData.recipientNickname || modelData.recipientId) + " (non enregistré)")
                        : "Message privé (non enregistré)"
                    delay: 400
                }

                MouseArea {
                    id: ephemeralBadgeArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }

        Text {
            text: modelData ? (modelData.text || "") : ""
            width: parent.width
            wrapMode: Text.Wrap
            color: messageDelegate.isOwnMessage ? Theme.textSoft : Theme.textSecondary
            font.pixelSize: Theme.fontSizeBody
            visible: !(modelData && (modelData.isImage || modelData.isTextFile))
        }



        Column {
            visible: !!(modelData && modelData.isImage)

            width: parent.width
            spacing: Theme.spacingXXS

            // En-tête de l'image (style TextFileDisplay)
            Rectangle {
                width: parent.width
                height: 24
                color: Theme.violetStart
                radius: Theme.radiusS
                // Coins du bas non arrondis pour coller à l'image
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 4
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingXS
                    spacing: Theme.spacingM

                    Text {
                        text: "📷 Image"
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                    }

                    // Bouton Copier
                    Rectangle {
                        id: copyBtn
                        width: 20
                        height: 20
                        color: copyArea.containsMouse ? Theme.violetEnd : "transparent"
                        radius: Theme.radiusXS
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: copyTimer.running ? "✓" : "📋"
                            font.pixelSize: Theme.fontSizeBody
                            anchors.centerIn: parent
                            color: Theme.textPrimary
                        }
                        
                        MouseArea {
                            id: copyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (messageDelegate.chatClient && contentImage.source.toString().startsWith("image://chat_images/")) {
                                    let id = contentImage.source.toString().replace("image://chat_images/", "")
                                    messageDelegate.chatClient.copyImageToClipboard(id)
                                    copyTimer.start()
                                }
                            }
                        }
                        ToolTip {
                            visible: copyArea.containsMouse
                            text: "Copier l'image"
                            delay: 400
                        }
                    }

                    // Bouton Sauver
                    Rectangle {
                        id: saveBtn
                        width: 20
                        height: 20
                        color: saveArea.containsMouse ? Theme.violetEnd : "transparent"
                        radius: Theme.radiusXS
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "💾"
                            font.pixelSize: Theme.fontSizeBody
                            anchors.centerIn: parent
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            id: saveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (contentImage.source.toString().startsWith("image://chat_images/")) {
                                    let id = contentImage.source.toString().replace("image://chat_images/", "")
                                    saveImageDialog.currentImageId = id
                                    saveImageDialog.currentFile = "file:///image_" + id + ".webp"
                                    saveImageDialog.open()
                                }
                            }
                        }
                        ToolTip {
                            visible: saveArea.containsMouse
                            text: "Enregistrer sous..."
                            delay: 400
                        }
                    }
                }
            }

            // Placeholder visible UNIQUEMENT pendant le chargement de l'image.
            // Il réserve une hauteur fixe pour que la ListView ne « saute » pas en bas
            // au moment où l'image se décode. Une fois Image.Ready, on bascule sur la
            // vraie Image (sans hauteur explicite) qui prend exactement sa taille
            // peintée — donc plus de bulle « trop grande » par rapport à l'image.
            Item {
                id: imagePlaceholder
                width: parent.width
                height: 200
                visible: contentImage.status !== Image.Ready
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radiusS
                }
                BusyIndicator {
                    anchors.centerIn: parent
                    running: contentImage.status === Image.Loading
                    visible: running
                    width: 32
                    height: 32
                }
            }

            Image {
                id: contentImage
                source: (modelData && modelData.isImage) ? modelData.text : ""
                asynchronous: true
                cache: true
                width: parent.width
                // Pas de hauteur explicite : on laisse l'Image se dimensionner sur son
                // implicitHeight (= taille réellement peintée après scaling sourceSize).
                // Mettre `height: implicitHeight` casse le calcul quand width change et
                // donne une bulle plus grande que l'image — d'où le bug précédent.
                fillMode: Image.PreserveAspectFit
                smooth: false
                mipmap: true
                sourceSize.width: width
                visible: status === Image.Ready

                // Quand l'image finit son chargement, sa hauteur change : si la ListView
                // était collée au bas, on la fait re-snapper pour rester au dernier message.
                onStatusChanged: {
                    if (status === Image.Ready && messageDelegate.listView
                            && messageDelegate.listView.stickToBottom) {
                        messageDelegate.listView.snapToBottom()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radiusS
                    visible: parent.status === Image.Ready
                }
            }
        }

        TextFileDisplay {
            visible: !!(modelData && modelData.isTextFile)
            text: (modelData && modelData.isTextFile) ? modelData.text : ""
            fileExtension: (modelData && modelData.fileExtension) ? modelData.fileExtension : "txt"
            width: parent.width
            chatClient: messageDelegate.chatClient
            fullScreenHeight:  messageDelegate.fullScreenMode ? messageDelegate.height : -1
        }
    }
}
