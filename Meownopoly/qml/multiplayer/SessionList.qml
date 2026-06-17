import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme
import "../ui_item"

/**
 * Vue complète de la liste des sessions disponibles
 * Utilise le ChatClient mutualisé du parent
 */
Rectangle {
    id: root

    color: Theme.background

    // Propriété pour recevoir le ChatClient du parent
    required property var chatClient

    signal sessionSelected(var sessionData)

    Component.onCompleted: {
        console.log("🚀 SessionList loaded, chatClient ready:", chatClient !== null)
        // Le ChatClient est déjà connecté depuis MultiplayerLobby
        if (chatClient && chatClient.connected) {
            chatClient.requestSessionsList()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingHuge
        spacing: Theme.spacingHuge

        // HEADER INTÉGRÉ
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacingM

            Text {
                text: "Sessions Disponibles"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeDisplay
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: chatClient.connected ?
                          ("🐱 " + chatClient.availableSessions.length + " parties en cours") :
                          "🔌 Connexion au serveur..."
                color: chatClient.connected ? Theme.textMuted : Theme.warning
                font.pixelSize: Theme.fontSizeTitle
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // COMPTEUR EN LIGNE INTÉGRÉ
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 40
            color: Theme.surface
            radius: 20
            border.color: chatClient.connected ? Theme.success : Theme.textDisabled
            border.width: 2

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingL

                Text {
                    text: chatClient.connected ? "🌐" : "⏳"
                    font.pixelSize: Theme.fontSizeTitle
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: chatClient.connected ? "Serveur connecté" : "Connexion..."
                    color: chatClient.connected ? Theme.success : Theme.textMuted
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // LISTE DES SESSIONS (DONNÉES RÉELLES)
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Message si aucune session
            Item {
                width: parent.width
                height: sessionsListView.count === 0 ? 200 : 0
                visible: sessionsListView.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXXL

                    Text {
                        text: chatClient.connected ? "😿" : "⏳"
                        font.pixelSize: Theme.px(48)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: chatClient.connected ?
                                  "Aucune partie disponible pour l'instant" :
                                  "Connexion au serveur..."
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeLarge
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Créez une nouvelle session pour commencer !"
                        color: Theme.textDisabled
                        font.pixelSize: Theme.fontSizeMedium
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: chatClient.connected
                    }
                }
            }

            ListView {
                id: sessionsListView
                model: chatClient.availableSessions
                spacing: Theme.spacingXL
                width: parent.width
                height: parent.height
                delegate: SessionCard {
                    name:         modelData.name        ?? ""
                    sessionId:    modelData.sessionId   ?? ""
                    players:      modelData.players     ?? 0
                    maxPlayers:   modelData.maxPlayers  ?? 4
                    hostNickname: modelData.hostNickname ?? ""
                    onlineCount:  modelData.onlineCount ?? 0

                    onClicked: {
                        console.log("Session sélectionnée:", sessionId, "-", name)
                        root.sessionSelected({
                            name:       name,
                            sessionId:  sessionId,
                            players:    players,
                            maxPlayers: maxPlayers
                        })
                    }
                }
            }
        }

        // BOUTON CRÉATION (ParticleButton direct)
        ParticleButton {
            text: "➕ Créer une Session"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 55

            enabled: chatClient.connected

            // Style unifié via MeowButton : couleur orange « action principale ».
            baseColor: "#E67E22"

            particleColor: "#E67E22"
            particleColorVariation: Theme.warning
            particleCount: 25

            onClicked: {
                multiplayerStackView.push(sessionCreationComponent)
            }
        }

        // HELP TEXT INTÉGRÉ avec bouton refresh
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacingXXL

            Text {
                text: "💡 Cliquez sur une session pour rejoindre"
                color: Theme.textDisabled
                font.pixelSize: Theme.fontSizeMedium
                font.italic: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                text: "🔄"
                width: 32
                height: 32

                background: Rectangle {
                    color: parent.pressed ? Theme.border : Theme.surfaceAlt
                    radius: 16
                    border.color: Theme.borderLight
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeLarge
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (chatClient.connected) {
                        chatClient.requestSessionsList()
                    }
                }

                ToolTip {
                    visible: parent.hovered
                    text: "Rafraîchir la liste"
                    delay: 500
                }
            }
        }
    }
}
