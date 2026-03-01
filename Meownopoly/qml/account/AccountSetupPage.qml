import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Meownopoly.Account 1.0

Rectangle {
    id: root
    color: "#1a1a1a"

    signal accountCreated()

    // Fireworks system (same as TitleScreen)
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

    // Title
    Text {
        id: welcomeTitle
        text: "Bienvenue sur Meownopoly!"
        color: "#ffffff"
        font.pixelSize: 42
        font.bold: true
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: parent.height * 0.12
        }
    }

    // Subtitle
    Text {
        id: subtitle
        text: "Créez votre profil pour commencer"
        color: "#cccccc"
        font.pixelSize: 20
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: welcomeTitle.bottom
            topMargin: 12
        }
    }

    // Cat emoji decoration
    Text {
        text: "🐱"
        font.pixelSize: 80
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: subtitle.bottom
            topMargin: 30
        }
    }

    // Main form container
    Rectangle {
        id: formContainer
        width: 400
        height: 450
        anchors.centerIn: parent
        color: "#2a2a2a"
        radius: 16
        border.color: "#444444"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            // Nickname label
            Text {
                text: "Choisissez votre pseudo"
                color: "#cccccc"
                font.pixelSize: 16
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Nickname input field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "#333333"
                radius: 8
                border.color: nicknameField.activeFocus ? "#4caf50" : "#555555"
                border.width: 2

                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextField {
                    id: nicknameField
                    anchors.fill: parent
                    anchors.margins: 4
                    placeholderText: "Entrez votre pseudo..."
                    placeholderTextColor: "#666666"
                    color: "#ffffff"
                    font.pixelSize: 16
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

            // STUN Server Label
            Text {
                text: "Serveur STUN"
                color: "#cccccc"
                font.pixelSize: 16
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
            }

            // STUN Server Selection
            ComboBox {
                id: stunComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                model: ListModel {
                    id: stunModel
                    ListElement { text: "Patoun Corp (Default)"; value: "pattouncorp.ovh"; port: 3000 }
                    ListElement { text: "Google"; value: "stun.l.google.com"; port: 19302 }
                    ListElement { text: "Custom"; value: "custom"; port: 0 }
                }

                textRole: "text"

                onActivated: {
                    if (currentText !== "Custom") {
                        var item = stunModel.get(currentIndex);
                        AccountManager.setStunServerURL(item.value);
                        AccountManager.setStunPort(item.port);
                    }
                }

                Component.onCompleted: {
                    // Initialize selection based on current settings
                    var currentServer = AccountManager.stunServer;
                    var currentPort = AccountManager.stunPort;
                    var found = false;

                    for (var i = 0; i < stunModel.count; i++) {
                        var item = stunModel.get(i);
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
                visible: stunComboBox.currentText === "Custom"
                spacing: 10

                // Custom Host
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#333333"
                    radius: 8
                    border.color: customHostField.activeFocus ? "#4caf50" : "#555555"
                    border.width: 1

                    TextField {
                        id: customHostField
                        anchors.fill: parent
                        anchors.margins: 4
                        placeholderText: "Hôte (ex: stun.example.com)"
                        placeholderTextColor: "#666666"
                        color: "#ffffff"
                        font.pixelSize: 12
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

                // Custom Port
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 40
                    color: "#333333"
                    radius: 8
                    border.color: customPortField.activeFocus ? "#4caf50" : "#555555"
                    border.width: 1

                    TextField {
                        id: customPortField
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
                             if (stunComboBox.currentText === "Custom") {
                                AccountManager.setStunPort(parseInt(text))
                             }
                        }
                    }
                }
            }

            // Character count
            Text {
                text: nicknameField.text.length + "/20 caractères"
                color: "#666666"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignRight
            }

            // Error message
            Text {
                id: errorText
                text: ""
                color: "#ff6b6b"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
                visible: text !== ""
            }

            // Create account button
            Button {
                id: createAccountButton
                text: "Créer mon compte"
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                enabled: nicknameField.text.trim().length >= 2

                background: Rectangle {
                    color: {
                        if (!createAccountButton.enabled) return "#555555"
                        return createAccountButton.pressed ? "#2e7d32" : "#4caf50"
                    }
                    radius: 8

                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                contentItem: Text {
                    text: createAccountButton.text
                    color: createAccountButton.enabled ? "white" : "#888888"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    var nickname = nicknameField.text.trim()
                    
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

    // Info text at bottom
    Text {
        text: "Votre compte est stocké localement sur cet appareil"
        color: "#666666"
        font.pixelSize: 12
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 30
        }
    }

    // Version text
    Text {
        text: "v0.2.0 editor edition"
        color: "#808080"
        font.pixelSize: 14
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }
    }

    Component.onCompleted: {
        nicknameField.forceActiveFocus()
    }
}
