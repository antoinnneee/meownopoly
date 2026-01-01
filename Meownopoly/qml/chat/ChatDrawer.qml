import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0
import "."

Drawer {
    id: chatDrawer
    width: 300
    height: parent.height
    edge: Qt.RightEdge

    property string gameId: ""
    property string playerId: "Player_" + Math.floor(Math.random() * 1000)

    ChatClient {
        id: chatClient
        sessionId: chatDrawer.gameId
        
        onConnectedChanged: {
            if (connected) {
                console.log("Chat connected!")
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: "#2c3e50"
            
            Text {
                text: "Chat - " + chatDrawer.gameId
                color: "white"
                anchors.centerIn: parent
                font.bold: true
            }
        }

        ListView {
            id: messageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: chatClient.messages
            clip: true
            spacing: 5
            delegate: Rectangle {
                width: parent.width - 20
                height: msgText.height + 20
                x: 10
                color: modelData.sender === chatDrawer.playerId ? "#dcf8c6" : "#ffffff"
                radius: 5
                border.color: "#ecf0f1"

                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    Text {
                        text: modelData.sender
                        font.pointSize: 8
                        color: "#7f8c8d"
                    }
                    Text {
                        id: msgText
                        text: modelData.text
                        width: parent.width
                        wrapMode: Text.Wrap
                    }
                }
            }
            
            onCountChanged: {
                Qt.callLater(messageList.positionViewAtEnd)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 5
            
            TextField {
                id: inputField
                Layout.fillWidth: true
                placeholderText: "Type a message..."
                onAccepted: sendBtn.clicked()
            }

            Button {
                id: sendBtn
                text: "Send"
                onClicked: {
                    if (inputField.text !== "") {
                        chatClient.sendMessage(inputField.text)
                        inputField.text = ""
                    }
                }
            }
        }
    }

    onOpened: {
        if (!chatClient.connected) {
            chatClient.connectToServer("ws://localhost:3000", playerId)
        }
    }
}
