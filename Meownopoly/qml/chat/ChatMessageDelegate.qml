import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: messageDelegate
    width: (listView ? listView.width : 0) - 16
    height: hasData ? (contentCol.height + 12) : 0
    x: 8
    visible: hasData

    required property var modelData
    required property int index
    required property var drawer
    required property var listView
    property var chatClient: null

    property bool hasData: !!modelData
    property bool isOwnMessage: hasData && drawer && (modelData.sender === drawer.playerId)

    color: isOwnMessage ? "#3d4a3d" : "#333333"
    radius: 6
    border.color: isOwnMessage ? "#4a8a4a" : "#444444"
    border.width: 1
    antialiasing: true

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
        duration: 150
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
        anchors.margins: 8
        spacing: 4
        visible: messageDelegate.hasData

        RowLayout {
            width: parent.width
            spacing: 6

            Text {
                text: "🐱"
                font.pixelSize: 12
                visible: !messageDelegate.isOwnMessage
            }

            Text {
                text: messageDelegate.isOwnMessage ? (drawer ? drawer.playerNickname : "") : (modelData ? (modelData.senderNickname || modelData.sender || "?") : "?")
                font.pixelSize: 10
                font.bold: true
                color: messageDelegate.isOwnMessage ? "#569c58" : "#4A90E2"
                Layout.fillWidth: true
            }

            Text {
                text: (modelData && drawer && typeof drawer.formatTimestamp === "function") ? drawer.formatTimestamp(modelData.timestamp) : "--:--"
                font.pixelSize: 8
                color: "#666666"
            }

            // Badge message privé (non enregistré dans l'historique)
            Rectangle {
                visible: !!(modelData && modelData.ephemeral)
                Layout.preferredWidth: 52
                Layout.preferredHeight: 14
                radius: 3
                color: "#2a3a4a"
                border.color: "#4A90E2"
                border.width: 1

                Text {
                    text: "🔒 Privé"
                    font.pixelSize: 8
                    color: "#4A90E2"
                    anchors.centerIn: parent
                }

                ToolTip {
                    visible: ephemeralBadgeArea.containsMouse
                    text: "Message privé (non enregistré)"
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
            color: "#cccccc"
            font.pixelSize: 12
            visible: !(modelData && (modelData.isImage || modelData.isTextFile))
        }



        Column {
            visible: !!(modelData && modelData.isImage)
            width: parent.width
            spacing: 2

            // En-tête de l'image (style TextFileDisplay)
            Rectangle {
                width: parent.width
                height: 24
                color: "#667eea"
                radius: 4
                // Coins du bas non arrondis pour coller à l'image
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 4
                    color: parent.color
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 4
                    spacing: 8

                    Text {
                        text: "📷 Image"
                        font.pixelSize: 10
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                    }

                    // Bouton Copier
                    Rectangle {
                        id: copyBtn
                        width: 20
                        height: 20
                        color: copyArea.containsMouse ? "#5568d3" : "transparent"
                        radius: 3
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: copyTimer.running ? "✓" : "📋"
                            font.pixelSize: 12
                            anchors.centerIn: parent
                            color: "white"
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
                        color: saveArea.containsMouse ? "#5568d3" : "transparent"
                        radius: 3
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "💾"
                            font.pixelSize: 12
                            anchors.centerIn: parent
                            color: "white"
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
                                    saveImageDialog.currentFile = "file:///image_" + id + ".png"
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

            Image {
                id: contentImage
                source: (modelData && modelData.isImage) ? modelData.text : ""
                asynchronous: true
                cache: true
                width: parent.width
                fillMode: Image.PreserveAspectFit
                smooth: false
                mipmap: true
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
                    width: 32
                    height: 32
                }
            }
        }

        TextFileDisplay {
            visible: !!(modelData && modelData.isTextFile)
            text: (modelData && modelData.isTextFile) ? modelData.text : ""
            fileExtension: (modelData && modelData.fileExtension) ? modelData.fileExtension : "txt"
            width: parent.width
            chatClient: messageDelegate.chatClient
        }
    }
}
