import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Account 1.0
import theme

Popup {
    id: root
    width: 450
    height: 600
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    anchors.centerIn: parent

    background: Rectangle {
        color: Theme.surface
        radius: 16
        border.color: Theme.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingHuge
        spacing: Theme.spacingHuge

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "⚙️"
                font.pixelSize: Theme.fontSizeDisplay
            }

            Text {
                text: "Paramètres du compte"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeHeading
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: closeBtn.containsMouse ? Theme.border : "transparent"

                Text {
                    text: "✕"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeLarge
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

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Text {
                text: "Identifiant unique"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: Theme.surfaceAlt
                radius: Theme.radiusL
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Text {
                        text: "🔒"
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    Text {
                        text: AccountManager.uniqueId
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                        font.family: "Consolas, Monaco, monospace"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: Theme.radiusM
                        color: copyBtn.containsMouse ? Theme.accent : Theme.border

                        Text {
                            text: "📋"
                            font.pixelSize: Theme.fontSizeBody
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: copyBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
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
                color: Theme.success
                font.pixelSize: Theme.fontSizeSmall
                visible: false

                Timer {
                    id: copyConfirmTimer
                    interval: 2000
                    onTriggered: copyConfirmText.visible = false
                }
            }

            Text {
                text: "Utilisé pour vous identifier (chat, etc.). Vous pouvez le régénérer ci-dessous."
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeCaption
                font.italic: true
            }

            Button {
                text: "🔄 Régénérer l'identifiant"
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                background: Rectangle {
                    color: parent.pressed ? Theme.borderLight : (parent.hovered ? Theme.border : Theme.surfaceHover)
                    radius: Theme.radiusL
                    border.color: Theme.warning
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.warning
                    font.pixelSize: Theme.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: confirmRegenIdPopup.open()
            }

            Rectangle {
                id: idRegenOverlay
                Layout.fillWidth: true
                height: 44
                color: Theme.success
                radius: Theme.radiusL
                opacity: 0
                visible: opacity > 0
                Text {
                    text: "✓ Identifiant régénéré! Reconnectez le chat pour l'utiliser."
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Text {
                text: "Pseudo"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
            }

            Rectangle {
                Layout.fillWidth: true
                height: 45
                color: Theme.surfaceAlt
                radius: Theme.radiusL
                border.color: nicknameEditField.activeFocus ? Theme.success : Theme.border
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    Text {
                        text: "🐱"
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    TextField {
                        id: nicknameEditField
                        text: AccountManager.nickname
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeMedium
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
                            color: parent.pressed ? Theme.pressed(Theme.success) : Theme.success
                            radius: Theme.radiusM
                        }

                        contentItem: Text {
                            text: parent.text
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSmall
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
                color: Theme.success
                font.pixelSize: Theme.fontSizeSmall
                opacity: 0

                SequentialAnimation {
                    id: savedAnimation
                    NumberAnimation { target: savedText; property: "opacity"; to: 1; duration: 200 }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: savedText; property: "opacity"; to: 0; duration: 300 }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Text {
                text: "Serveur STUN"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
            }

            ComboBox {
                id: stunPopupComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: 45

                model: ListModel {
                    id: stunPopupModel
                    ListElement { text: "Patoun Corp (Default)"; value: "pattounecorp.ovh"; port: 3478 }
                    ListElement { text: "Google"; value: "stun.l.google.com"; port: 19302 }
                    ListElement { text: "Custom"; value: "custom"; port: 0 }
                }

                textRole: "text"

                delegate: ItemDelegate {
                    width: stunPopupComboBox.width
                    contentItem: Text {
                        text: model.text
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeMedium
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.highlighted ? Theme.border : Theme.surfaceAlt
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
                        const ctx = getContext("2d");
                        if (!ctx) return;
                        ctx.reset();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(width, 0);
                        ctx.lineTo(width / 2, height);
                        ctx.closePath();
                        ctx.fillStyle = Theme.textSecondary;
                        ctx.fill();
                    }
                }

                contentItem: Text {
                    leftPadding: Theme.spacingL
                    rightPadding: stunPopupComboBox.indicator.width + stunPopupComboBox.spacing
                    text: stunPopupComboBox.displayText
                    font: stunPopupComboBox.font
                    color: Theme.textPrimary
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    implicitWidth: 120
                    implicitHeight: 40
                    color: Theme.surfaceAlt
                    border.color: stunPopupComboBox.pressed ? Theme.success : Theme.border
                    border.width: 1
                    radius: Theme.radiusL
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
                        border.color: Theme.border
                        color: Theme.surfaceAlt
                        radius: Theme.radiusL
                    }
                }

                onActivated: {
                    if (currentText !== "Custom") {
                        const item = stunPopupModel.get(currentIndex);
                        AccountManager.setStunServerURL(item.value);
                        AccountManager.setStunPort(item.port);
                    }
                }

                Component.onCompleted: {
                    const currentServer = AccountManager.stunServer;
                    const currentPort = AccountManager.stunPort;
                    let found = false;

                    for (let i = 0; i < stunPopupModel.count; i++) {
                        const item = stunPopupModel.get(i);
                        if (item.value === currentServer && item.port === currentPort) {
                            currentIndex = i;
                            found = true;
                            break;
                        }
                    }

                    if (!found) {
                        currentIndex = 2
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: stunPopupComboBox.currentText === "Custom"
                spacing: Theme.spacingL

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Theme.surfaceAlt
                    radius: Theme.radiusL
                    border.color: customHostPopupField.activeFocus ? Theme.success : Theme.border
                    border.width: 1

                    TextField {
                        id: customHostPopupField
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        placeholderText: "Hôte"
                        placeholderTextColor: Theme.textDisabled
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
                        verticalAlignment: Text.AlignVCenter
                        text: AccountManager.stunServer

                        background: null

                        onEditingFinished: {
                            if (stunPopupComboBox.currentText === "Custom") {
                                AccountManager.setStunServerURL(text)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    color: Theme.surfaceAlt
                    radius: Theme.radiusL
                    border.color: customPortPopupField.activeFocus ? Theme.success : Theme.border
                    border.width: 1

                    TextField {
                        id: customPortPopupField
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        placeholderText: "Port"
                        placeholderTextColor: Theme.textDisabled
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
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

    Popup {
        id: confirmRegenIdPopup
        width: 380
        height: 320
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: parent

        background: Rectangle {
            color: Theme.surfaceAlt
            radius: Theme.radiusXXL
            border.color: Theme.dangerSoft
            border.width: 2
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingHuge
            spacing: Theme.spacingXXL

            Text {
                text: "⚠️ Changer d'identifiant"
                color: Theme.dangerSoft
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Vous serez considéré comme un nouveau joueur dans le chat. Vos anciens messages resteront affichés avec l'ancien identifiant.\n\nToute donnée liée à cet ID (parties, sauvegardes) pourrait ne plus vous être associée.\n\nCette action est irréversible."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXL

                Button {
                    text: "Annuler"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: parent.pressed ? Theme.border : Theme.borderLight
                        radius: Theme.radiusM
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
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
                        color: parent.pressed ? Theme.pressed(Theme.danger) : Theme.danger
                        radius: Theme.radiusM
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
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
}
