import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui_item"

/**
 * Vue complète de la liste des sessions disponibles
 * Utilise le ChatClient mutualisé du parent
 */
Rectangle {
    id: root

    color: "#1a1a1a"

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
        anchors.margins: 24
        spacing: 20

        // HEADER INTÉGRÉ
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                text: "Sessions Disponibles"
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: chatClient.connected ?
                          ("🐱 " + chatClient.availableSessions.length + " parties en cours") :
                          "🔌 Connexion au serveur..."
                color: chatClient.connected ? "#888888" : "#ff9800"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // COMPTEUR EN LIGNE INTÉGRÉ
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 40
            color: "#2a2a2a"
            radius: 20
            border.color: chatClient.connected ? "#4caf50" : "#666666"
            border.width: 2

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: chatClient.connected ? "🌐" : "⏳"
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: chatClient.connected ? "Serveur connecté" : "Connexion..."
                    color: chatClient.connected ? "#4caf50" : "#888888"
                    font.pixelSize: 14
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
                    spacing: 16

                    Text {
                        text: chatClient.connected ? "😿" : "⏳"
                        font.pixelSize: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: chatClient.connected ?
                                  "Aucune partie disponible pour l'instant" :
                                  "Connexion au serveur..."
                        color: "#888888"
                        font.pixelSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Créez une nouvelle session pour commencer !"
                        color: "#666666"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: chatClient.connected
                    }
                }
            }

            ListView {
                id: sessionsListView
                model: chatClient.availableSessions
                spacing: 12
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

            particleColor: "#E67E22"
            particleColorVariation: "#ff9800"
            particleCount: 25

            background: Rectangle {
                color: parent.enabled ?
                           (parent.down ? "#d35400" : "#E67E22") : "#555555"
                radius: 8
                border.color: parent.enabled ?
                                  (parent.hovered ? "#FFFFFF" : "#d35400") : "#666666"
                border.width: 2

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 6
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }
            }




            contentItem: Text {
                text: parent.text
                font.pixelSize: 16
                font.bold: true
                color: parent.enabled ? "white" : "#888888"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                multiplayerStackView.push(sessionCreationComponent)
            }
        }

        // HELP TEXT INTÉGRÉ avec bouton refresh
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Text {
                text: "💡 Cliquez sur une session pour rejoindre"
                color: "#666666"
                font.pixelSize: 14
                font.italic: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                text: "🔄"
                width: 32
                height: 32

                background: Rectangle {
                    color: parent.pressed ? "#444444" : "#333333"
                    radius: 16
                    border.color: "#555555"
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: "#cccccc"
                    font.pixelSize: 16
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
