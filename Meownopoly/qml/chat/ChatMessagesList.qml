import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: messagesContainer
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: "#2a2a2a"
    border.color: dropArea.containsDrag ? "#4A90E2" : "#444444"
    border.width: dropArea.containsDrag ? 2 : 1

    property var chatClient
    property var drawer
    property alias messageList: messageList

    signal countChanged(int count)

    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on border.width { NumberAnimation { duration: 150 } }

    // Extensions de fichiers texte acceptées
    property var textFileExtensions: [
        ".txt", ".md", ".json", ".xml", ".csv", ".log", ".yml", ".yaml", ".toml", ".ini", ".cfg",
        ".js", ".ts", ".py", ".cpp", ".c", ".h", ".hpp", ".java", ".cs", ".go", ".rs", ".rb",
        ".php", ".swift", ".kt", ".qml", ".html", ".css", ".sql", ".sh", ".bat"
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
            anchors.margins: 20
            color: "transparent"
            border.color: "#4A90E2"
            border.width: 2
            border.pixelAligned: true
            radius: 12

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

                Rectangle {
                    width: 64
                    height: 64
                    radius: 32
                    color: "#333333"
                    border.color: "#4A90E2"
                    border.width: 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "📎"
                        font.pixelSize: 28
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
                    color: "#cccccc"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Images ou fichiers texte"
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
        model: chatClient ? chatClient.messages : null
        clip: true
        spacing: 8
        highlightFollowsCurrentItem: false
        reuseItems: true

        Behavior on contentY {
            SmoothedAnimation {
                velocity: 1500
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        ScrollBar.vertical: ScrollBar {
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

        delegate: Item {
            required property var modelData
            required property int index
            width: messageList.width - 16
            height: delegateImpl.height + 12
            x: 8

            ChatMessageDelegate {
                id: delegateImpl
                drawer: messagesContainer.drawer
                listView: messageList
                modelData: parent.modelData
                index: parent.index
                chatClient: messagesContainer.chatClient
            }
        }

        onCountChanged: {
            scrollToBottomTimer.restart()
            messagesContainer.countChanged(messageList.count)
        }

        Timer {
            id: scrollToBottomTimer
            interval: 50
            repeat: false
            onTriggered: messageList.positionViewAtEnd()
        }

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
