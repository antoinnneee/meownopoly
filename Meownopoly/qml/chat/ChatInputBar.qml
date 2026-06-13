import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0
import Catway 1.0
import theme

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: recipientId ? 88 : 60
    color: Theme.surfaceAlt
    border.color: Theme.border
    border.width: 1

    property var chatClient
    property var drawer
    property string recipientId: ""
    property string recipientNickname: ""
    signal openImageDialog()
    signal openTextFileDialog()
    signal clearRecipient()
    signal createSnapableRequested(string jsonString)
    signal focusReleased()

    Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutCubic } }

    function sendCurrentMessage() {
        if (inputField.text !== "" && chatClient) {
            var text = inputField.text.trim()
            var cmd = SlashCommands.commandFromText(text)
            if (cmd === SlashCommands.stun) {
                Catway.setupNewPort()
            } else if (cmd === SlashCommands.ping) {
                chatClient.sendPing()
            } else if (cmd === SlashCommands.create) {
                var jsonString = text.substring(SlashCommands.create.length).trim()
                createSnapableRequested(jsonString)
            } else {
                chatClient.sendMessage(inputField.text, recipientId || "", recipientNickname || "")
            }
            inputField.text = ""
        }
        inputField.focus = false
        focusReleased()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS

        // Bandeau "Message privé à : X"
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            visible: !!recipientId
            color: "#2a3a4a"
            radius: Theme.radiusS
            border.color: Theme.accent
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                spacing: Theme.spacingS

                Text {
                    text: "🔒"
                    font.pixelSize: Theme.fontSizeSmall
                }
                Text {
                    text: "Message privé à : " + (recipientNickname || recipientId || "?")
                    color: Theme.accent
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    color: clearRecipientArea.containsMouse ? Theme.border : "transparent"
                    radius: Theme.radiusXS

                    Text {
                        text: "✕"
                        color: "#aaaaaa"
                        font.pixelSize: Theme.fontSizeSmall
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
        spacing: Theme.spacingM

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            color: imgBtnArea.containsMouse ? Theme.hover(Theme.surfaceHover) : Theme.surfaceHover
            radius: Theme.radiusM
            border.color: imgBtnArea.pressed ? Theme.accent : Theme.borderLight
            border.width: 1

            Text {
                text: "📷"
                anchors.centerIn: parent
                font.pixelSize: Theme.fontSizeLarge
            }

            MouseArea {
                id: imgBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: openImageDialog()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            color: fileBtnArea.containsMouse ? Theme.hover(Theme.surfaceHover) : Theme.surfaceHover
            radius: Theme.radiusM
            border.color: fileBtnArea.pressed ? Theme.violetStart : Theme.borderLight
            border.width: 1

            Text {
                text: "📄"
                anchors.centerIn: parent
                font.pixelSize: Theme.fontSizeLarge
            }

            MouseArea {
                id: fileBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: openTextFileDialog()
            }

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radiusM
            border.color: inputField.activeFocus ? Theme.accent : Theme.border
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

            TextField {
                id: inputField
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                placeholderText: "Tapez un message..."
                placeholderTextColor: Theme.textDisabled
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeBody

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
            color: sendBtnArea.pressed ? Theme.accentAlt : (sendBtnArea.containsMouse ? "#4a8a4a" : "#3d6b3d")
            radius: Theme.radiusM
            border.color: Theme.accentAlt
            border.width: 1
            opacity: inputField.text !== "" ? 1.0 : 0.5

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Text {
                    text: "Envoyer"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
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
