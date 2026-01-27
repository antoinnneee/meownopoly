import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Account 1.0

Popup {
    id: root
    width: 450
    height: 500
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    anchors.centerIn: parent

    background: Rectangle {
        color: "#2a2a2a"
        radius: 16
        border.color: "#444444"
        border.width: 1
    }

    // Confirmation dialog for key regeneration
    Popup {
        id: confirmKeyRegenPopup
        width: 350
        height: 200
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent

        background: Rectangle {
            color: "#333333"
            radius: 12
            border.color: "#ff6b6b"
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Text {
                text: "⚠️ Attention"
                color: "#ff6b6b"
                font.pixelSize: 18
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Êtes-vous sûr de vouloir renouveler vos clés de cryptage ?\n\nCette action est irréversible et peut affecter les messages chiffrés existants."
                color: "#cccccc"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Button {
                    text: "Annuler"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    background: Rectangle {
                        color: parent.pressed ? "#444444" : "#555555"
                        radius: 6
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "#cccccc"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: confirmKeyRegenPopup.close()
                }

                Button {
                    text: "Confirmer"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    background: Rectangle {
                        color: parent.pressed ? "#c62828" : "#e53935"
                        radius: 6
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        AccountManager.regenerateKeys()
                        confirmKeyRegenPopup.close()
                        keyRegeneratedAnimation.start()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 25
        spacing: 20

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "⚙️"
                font.pixelSize: 24
            }

            Text {
                text: "Paramètres du compte"
                color: "#ffffff"
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
            }

            // Close button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: closeBtn.containsMouse ? "#444444" : "transparent"

                Text {
                    text: "✕"
                    color: "#888888"
                    font.pixelSize: 16
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: closeBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.close()
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }

        // Unique ID section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Identifiant unique"
                color: "#888888"
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: "#333333"
                radius: 8
                border.color: "#444444"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "🔒"
                        font.pixelSize: 14
                    }

                    Text {
                        text: AccountManager.uniqueId
                        color: "#aaaaaa"
                        font.pixelSize: 12
                        font.family: "Consolas, Monaco, monospace"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    // Copy button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 6
                        color: copyBtn.containsMouse ? "#4A90E2" : "#444444"

                        Text {
                            text: "📋"
                            font.pixelSize: 12
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: copyBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Copy to clipboard would require C++ integration
                                copyConfirmText.visible = true
                                copyConfirmTimer.restart()
                            }
                        }
                    }
                }
            }

            Text {
                id: copyConfirmText
                text: "✓ Copié!"
                color: "#4caf50"
                font.pixelSize: 11
                visible: false

                Timer {
                    id: copyConfirmTimer
                    interval: 2000
                    onTriggered: copyConfirmText.visible = false
                }
            }

            Text {
                text: "Cet identifiant est permanent et ne peut pas être modifié."
                color: "#666666"
                font.pixelSize: 10
                font.italic: true
            }
        }

        // Nickname section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Pseudo"
                color: "#888888"
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: "#333333"
                radius: 8
                border.color: nicknameEditField.activeFocus ? "#4caf50" : "#444444"
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "🐱"
                        font.pixelSize: 14
                    }

                    TextField {
                        id: nicknameEditField
                        text: AccountManager.nickname
                        color: "#ffffff"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        maximumLength: 20

                        background: Rectangle {
                            color: "transparent"
                        }

                        onTextChanged: {
                            saveNicknameBtn.visible = text.trim() !== AccountManager.nickname && text.trim().length >= 2
                        }
                    }

                    Button {
                        id: saveNicknameBtn
                        text: "Sauvegarder"
                        visible: false
                        Layout.preferredHeight: 30

                        background: Rectangle {
                            color: parent.pressed ? "#2e7d32" : "#4caf50"
                            radius: 6
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            AccountManager.nickname = nicknameEditField.text.trim()
                            saveNicknameBtn.visible = false
                            savedAnimation.start()
                        }
                    }
                }
            }

            Text {
                id: savedText
                text: "✓ Pseudo sauvegardé!"
                color: "#4caf50"
                font.pixelSize: 11
                opacity: 0

                SequentialAnimation {
                    id: savedAnimation
                    NumberAnimation { target: savedText; property: "opacity"; to: 1; duration: 200 }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: savedText; property: "opacity"; to: 0; duration: 300 }
                }
            }
        }

        // Cryptographic keys section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Clés de cryptage"
                color: "#888888"
                font.pixelSize: 12
            }

            Rectangle {
                Layout.fillWidth: true
                height: 80
                color: "#333333"
                radius: 8
                border.color: "#444444"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "🔐"
                            font.pixelSize: 14
                        }

                        Text {
                            text: "Clé privée active"
                            color: "#cccccc"
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: "#4caf50"
                        }
                    }

                    Text {
                        text: AccountManager.keyCreatedAt !== "" ? 
                              "Créée le: " + new Date(AccountManager.keyCreatedAt).toLocaleDateString("fr-FR") :
                              "Clé non générée"
                        color: "#888888"
                        font.pixelSize: 11
                    }
                }

                // Key regenerated animation overlay
                Rectangle {
                    id: keyRegenOverlay
                    anchors.fill: parent
                    color: "#4caf50"
                    radius: 8
                    opacity: 0

                    Text {
                        text: "✓ Clés régénérées!"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    SequentialAnimation {
                        id: keyRegeneratedAnimation
                        NumberAnimation { target: keyRegenOverlay; property: "opacity"; to: 0.9; duration: 200 }
                        PauseAnimation { duration: 1500 }
                        NumberAnimation { target: keyRegenOverlay; property: "opacity"; to: 0; duration: 300 }
                    }
                }
            }

            Button {
                text: "🔄 Renouveler les clés"
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.pressed ? "#c62828" : (parent.hovered ? "#e53935" : "#d32f2f")
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: confirmKeyRegenPopup.open()
            }

            Text {
                text: "⚠️ Attention: renouveler les clés peut affecter le déchiffrement des anciens messages."
                color: "#ff9800"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }
    }
}
