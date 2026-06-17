import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Meownopoly.Account 1.0
import theme
import ui_item

Rectangle {
    id: root
    color: Theme.background

    signal accountCreated()

    ParticleSystem {
        id: particleSystem
        anchors.fill: parent

        Emitter {
            id: burstEmitter
            enabled: true
            anchors.fill: parent
            lifeSpan: 2000
            size: 10
            emitRate: 3
            velocity: AngleDirection {
                angle: 270
                angleVariation: 15
                magnitude: 200
                magnitudeVariation: 50
            }
        }

        ImageParticle {
            id: firework
            source: "qrc:///particleresources/glowdot.png"
            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
            colorVariation: 0.5
            alpha: 0.75
            rotationVariation: 360
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            burstEmitter.burst(1);
            firework.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1);
        }
    }

    Text {
        id: welcomeTitle
        text: "Bienvenue sur Meownopoly!"
        color: Theme.textPrimary
        font.pixelSize: Theme.px(42)
        font.bold: true
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: parent.height * 0.12
        }
    }

    Text {
        id: subtitle
        text: "Créez votre profil pour commencer"
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeHeading
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: welcomeTitle.bottom
            topMargin: Theme.spacingXL
        }
    }

    Text {
        text: "🐱"
        font.pixelSize: Theme.px(80)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: subtitle.bottom
            topMargin: 30
        }
    }

    Rectangle {
        id: formContainer
        width: 400
        height: 450
        anchors.centerIn: parent
        color: Theme.surface
        radius: 16
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: Theme.spacingHuge

            Text {
                text: "Choisissez votre pseudo"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: Theme.surfaceAlt
                radius: Theme.radiusL
                border.color: nicknameField.activeFocus ? Theme.success : Theme.borderLight
                border.width: 2

                Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

                TextField {
                    id: nicknameField
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    placeholderText: "Entrez votre pseudo..."
                    placeholderTextColor: Theme.textDisabled
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    horizontalAlignment: Text.AlignHCenter
                    maximumLength: 20

                    background: Rectangle {
                        color: "transparent"
                    }

                    onAccepted: {
                        if (nicknameField.text.trim() !== "") {
                            createAccountButton.clicked()
                        }
                    }
                }
            }

            Text {
                text: "Serveur STUN"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.spacingL
            }

            ComboBox {
                id: stunComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                model: ListModel {
                    id: stunModel
                    ListElement { text: "Patoun Corp (Default)"; value: "pattounecorp.ovh"; port: 3478 }
                    ListElement { text: "Google"; value: "stun.l.google.com"; port: 19302 }
                    ListElement { text: "Custom"; value: "custom"; port: 0 }
                }

                textRole: "text"

                onActivated: {
                    if (currentText !== "Custom") {
                        const item = stunModel.get(currentIndex);
                        AccountManager.setStunServerURL(item.value);
                        AccountManager.setStunPort(item.port);
                    }
                }

                Component.onCompleted: {
                    const currentServer = AccountManager.stunServer;
                    const currentPort = AccountManager.stunPort;
                    let found = false;

                    for (let i = 0; i < stunModel.count; i++) {
                        const item = stunModel.get(i);
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
                visible: stunComboBox.currentText === "Custom"
                spacing: Theme.spacingL

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Theme.surfaceAlt
                    radius: Theme.radiusL
                    border.color: customHostField.activeFocus ? Theme.success : Theme.borderLight
                    border.width: 1

                    TextField {
                        id: customHostField
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        placeholderText: "Hôte (ex: stun.example.com)"
                        placeholderTextColor: Theme.textDisabled
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
                        verticalAlignment: Text.AlignVCenter
                        text: AccountManager.stunServer

                        background: null

                        onEditingFinished: {
                            if (stunComboBox.currentText === "Custom") {
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
                    border.color: customPortField.activeFocus ? Theme.success : Theme.borderLight
                    border.width: 1

                    TextField {
                        id: customPortField
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
                            if (stunComboBox.currentText === "Custom") {
                                AccountManager.setStunPort(parseInt(text))
                            }
                        }
                    }
                }
            }

            Text {
                text: nicknameField.text.length + "/20 caractères"
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeSmall
                Layout.alignment: Qt.AlignRight
            }

            Text {
                id: errorText
                text: ""
                color: Theme.dangerSoft
                font.pixelSize: Theme.fontSizeBody
                Layout.alignment: Qt.AlignHCenter
                visible: text !== ""
            }

            MeowButton {
                id: createAccountButton
                text: "Créer mon compte"
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                enabled: nicknameField.text.trim().length >= 2

                variant: "success"
                hoverZoom: false

                onClicked: {
                    const nickname = nicknameField.text.trim()

                    if (nickname.length < 2) {
                        errorText.text = "Le pseudo doit contenir au moins 2 caractères"
                        return
                    }

                    errorText.text = ""
                    AccountManager.createAccount(nickname)
                    root.accountCreated()
                }
            }
        }
    }

    Text {
        text: "Votre compte est stocké localement sur cet appareil"
        color: Theme.textDisabled
        font.pixelSize: Theme.fontSizeBody
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 30
        }
    }

    Text {
        text: "v0.2.0 editor edition"
        color: Theme.textMuted
        font.pixelSize: Theme.fontSizeMedium
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Theme.spacingL
        }
    }

    Component.onCompleted: {
        nicknameField.forceActiveFocus()
    }
}
