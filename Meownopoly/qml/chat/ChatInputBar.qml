import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: recipientId ? 88 : 60
    color: "#333333"
    border.color: "#444444"
    border.width: 1

    property var chatClient
    property var drawer
    property string recipientId: ""
    property string recipientNickname: ""
    signal openImageDialog()
    signal openTextFileDialog()
    signal clearRecipient()

    Behavior on Layout.preferredHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    function sendCurrentMessage() {
        if (inputField.text !== "" && chatClient) {
            var text = inputField.text.trim()
            if (text.startsWith("/ping")) {
                chatClient.sendPing()
            } else {
                chatClient.sendMessage(inputField.text, recipientId || "", recipientNickname || "")
            }
            inputField.text = ""
        }
        inputField.focus = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        // Bandeau "Message privé à : X"
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            visible: !!recipientId
            color: "#2a3a4a"
            radius: 4
            border.color: "#4A90E2"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 6

                Text {
                    text: "🔒"
                    font.pointSize: 8
                }
                Text {
                    text: "Message privé à : " + (recipientNickname || recipientId || "?")
                    color: "#4A90E2"
                    font.pointSize: 8
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    color: clearRecipientArea.containsMouse ? "#444444" : "transparent"
                    radius: 3

                    Text {
                        text: "✕"
                        color: "#aaaaaa"
                        font.pointSize: 8
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: clearRecipientArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearRecipient()
                    }

                    ToolTip {
                        visible: clearRecipientArea.containsMouse
                        text: "Envoyer à tous"
                        delay: 400
                    }
                }
            }
        }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

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
                font.pointSize: 12
            }

            MouseArea {
                id: imgBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: openImageDialog()
            }

            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            color: fileBtnArea.containsMouse ? "#444444" : "#3a3a3a"
            radius: 6
            border.color: fileBtnArea.pressed ? "#667eea" : "#555555"
            border.width: 1

            Text {
                text: "📄"
                anchors.centerIn: parent
                font.pointSize: 12
            }

            MouseArea {
                id: fileBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: openTextFileDialog()
            }

            Behavior on color { ColorAnimation { duration: 100 } }
        }

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
                font.pointSize: 9

                background: Rectangle {
                    color: "transparent"
                }

                onAccepted: {
                    sendCurrentMessage()
                }
            }
        }

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
                    font.pointSize: 8
                    font.bold: true
                }
            }

            MouseArea {
                id: sendBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    sendCurrentMessage()
                }
            }
        }
    }
    }
}
