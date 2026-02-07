import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 60
    color: "#333333"
    border.color: "#444444"
    border.width: 1

    property var chatClient
    signal openImageDialog()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
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
                font.pixelSize: 16
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

                onAccepted: {
                    if (inputField.text !== "" && chatClient) {
                        chatClient.sendMessage(inputField.text)
                        inputField.text = ""
                    }
                    inputField.focus = false
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
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                id: sendBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (inputField.text !== "" && chatClient) {
                        chatClient.sendMessage(inputField.text)
                        inputField.text = ""
                    }
                    inputField.focus = false
                }
            }
        }
    }
}
