import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Account 1.0

Popup {
    id: root
    width: 450
    height: 600
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

    // Confirmation régénération identifiant
    Popup {
        id: confirmRegenIdPopup
        width: 380
        height: 320
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
            spacing: 16

            Text {
                text: "⚠️ Changer d'identifiant"
                color: "#ff6b6b"
                font.pixelSize: 18
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Vous serez considéré comme un nouveau joueur dans le chat. Vos anciens messages resteront affichés avec l'ancien identifiant.\n\nToute donnée liée à cet ID (parties, sauvegardes) pourrait ne plus vous être associée.\n\nCette action est irréversible."
                color: "#cccccc"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

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
                    onClicked: confirmRegenIdPopup.close()
                }

                Button {
                    text: "Régénérer"
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
                        if (AccountManager.regenerateUniqueId()) {
                            confirmRegenIdPopup.close()
                            idRegeneratedAnimation.start()
                        }
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
                text: "Utilisé pour vous identifier (chat, etc.). Vous pouvez le régénérer ci-dessous."
                color: "#666666"
                font.pixelSize: 10
                font.italic: true
            }

            Button {
                text: "🔄 Régénérer l'identifiant"
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                background: Rectangle {
                    color: parent.pressed ? "#555555" : (parent.hovered ? "#444444" : "#3a3a3a")
                    radius: 8
                    border.color: "#ff9800"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ff9800"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: confirmRegenIdPopup.open()
            }

            Rectangle {
                id: idRegenOverlay
                Layout.fillWidth: true
                height: 44
                color: "#4caf50"
                radius: 8
                opacity: 0
                visible: opacity > 0
                Text {
                    text: "✓ Identifiant régénéré! Reconnectez le chat pour l'utiliser."
                    color: "white"
                    font.pixelSize: 11
                    anchors.centerIn: parent
                    width: parent.width - 16
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                SequentialAnimation {
                    id: idRegeneratedAnimation
                    running: false
                    NumberAnimation { target: idRegenOverlay; property: "opacity"; to: 0.95; duration: 200 }
                    PauseAnimation { duration: 2500 }
                    NumberAnimation { target: idRegenOverlay; property: "opacity"; to: 0; duration: 300 }
                }
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

        // STUN Server section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Serveur STUN"
                color: "#888888"
                font.pixelSize: 12
            }

            ComboBox {
                id: stunPopupComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: 45

                model: ListModel {
                    id: stunPopupModel
                    ListElement { text: "Patoun Corp (Default)"; value: "pattouncorp.ovh"; port: 3000 }
                    ListElement { text: "Google"; value: "stun.l.google.com"; port: 19302 }
                    ListElement { text: "Custom"; value: "custom"; port: 0 }
                }

                textRole: "text"

                delegate: ItemDelegate {
                    width: stunPopupComboBox.width
                    contentItem: Text {
                        text: model.text
                        color: "#cccccc"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.highlighted ? "#444444" : "#333333"
                    }
                    highlighted: stunPopupComboBox.highlightedIndex === index
                }

                indicator: Canvas {
                    id: canvas
                    x: stunPopupComboBox.width - width - 10
                    y: stunPopupComboBox.topPadding + (stunPopupComboBox.availableHeight - height) / 2
                    width: 12
                    height: 8
                    contextType: "2d"

                    Connections {
                        target: stunPopupComboBox
                        function onPressedChanged() { canvas.requestPaint(); }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        if (!ctx) return;
                        ctx.reset();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width / 2, height);
                        ctx.closePath();
                        ctx.fillStyle = "#cccccc";
                        ctx.fill();
                    }
                }

                contentItem: Text {
                    leftPadding: 10
                    rightPadding: stunPopupComboBox.indicator.width + stunPopupComboBox.spacing
                    text: stunPopupComboBox.displayText
                    font: stunPopupComboBox.font
                    color: "#ffffff"
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    implicitWidth: 120
                    implicitHeight: 40
                    color: "#333333"
                    border.color: stunPopupComboBox.pressed ? "#4caf50" : "#444444"
                    border.width: 1
                    radius: 8
                }

                popup: Popup {
                    y: stunPopupComboBox.height - 1
                    width: stunPopupComboBox.width
                    implicitHeight: contentItem.implicitHeight
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: stunPopupComboBox.popup.visible ? stunPopupComboBox.delegateModel : null
                        currentIndex: stunPopupComboBox.highlightedIndex

                        ScrollIndicator.vertical: ScrollIndicator { }
                    }

                    background: Rectangle {
                        border.color: "#444444"
                        color: "#333333"
                        radius: 8
                    }
                }

                onActivated: {
                    if (currentText !== "Custom") {
                        var item = stunPopupModel.get(currentIndex);
                        AccountManager.setStunServer(item.value);
                        AccountManager.setStunPort(item.port);
                    }
                }

                Component.onCompleted: {
                    // Initialize selection based on current settings
                    var currentServer = AccountManager.stunServer;
                    var currentPort = AccountManager.stunPort;
                    var found = false;

                    for (var i = 0; i < stunPopupModel.count; i++) {
                        var item = stunPopupModel.get(i);
                        if (item.value === currentServer && item.port === currentPort) {
                            currentIndex = i;
                            found = true;
                            break;
                        }
                    }

                    if (!found) {
                        currentIndex = 2; // Custom
                    }
                }
            }

            // Custom STUN Details (Visible only if Custom is selected)
            RowLayout {
                Layout.fillWidth: true
                visible: stunPopupComboBox.currentText === "Custom"
                spacing: 10

                // Custom Host
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#333333"
                    radius: 8
                    border.color: customHostPopupField.activeFocus ? "#4caf50" : "#444444"
                    border.width: 1

                    TextField {
                        id: customHostPopupField
                        anchors.fill: parent
                        anchors.margins: 4
                        placeholderText: "Hôte"
                        placeholderTextColor: "#666666"
                        color: "#ffffff"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        text: AccountManager.stunServer

                        background: null

                        onEditingFinished: {
                             if (stunPopupComboBox.currentText === "Custom") {
                                AccountManager.setStunServer(text)
                             }
                        }
                    }
                }

                // Custom Port
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    color: "#333333"
                    radius: 8
                    border.color: customPortPopupField.activeFocus ? "#4caf50" : "#444444"
                    border.width: 1

                    TextField {
                        id: customPortPopupField
                        anchors.fill: parent
                        anchors.margins: 4
                        placeholderText: "Port"
                        placeholderTextColor: "#666666"
                        color: "#ffffff"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: AccountManager.stunPort.toString()
                        validator: IntValidator { bottom: 1; top: 65535 }

                        background: null

                        onEditingFinished: {
                             if (stunPopupComboBox.currentText === "Custom") {
                                AccountManager.setStunPort(parseInt(text))
                             }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
