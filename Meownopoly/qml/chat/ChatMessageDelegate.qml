import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
        }

        Text {
            text: modelData ? (modelData.text || "") : ""
            width: parent.width
            wrapMode: Text.Wrap
            color: "#cccccc"
            font.pixelSize: 12
            visible: !(modelData && (modelData.isImage || modelData.isTextFile))
        }

        Image {
            source: (modelData && modelData.isImage) ? modelData.text : ""
            visible: !!(modelData && modelData.isImage)
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

        TextFileDisplay {
            visible: !!(modelData && modelData.isTextFile)
            text: (modelData && modelData.isTextFile) ? modelData.text : ""
            fileExtension: (modelData && modelData.fileExtension) ? modelData.fileExtension : "txt"
            width: parent.width
            chatClient: messageDelegate.chatClient
        }
    }
}
