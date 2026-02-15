import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0

/**
 * Conteneur principal du lobby multijoueur
 * Gère la navigation interne entre SessionList et SessionDetails
 */
Rectangle {
    id: root

    color: "#1a1a1a"

    signal backToTitleScreen()

    // ChatClient mutualisé pour tout le lobby
    ChatClient {
        id: lobbyChatClient
        
        onConnectedChanged: {
            if (connected) {
                console.log("✅ Lobby connected, requesting sessions...")
                lobbyChatClient.requestSessionsList()
                refreshTimer.start()
            } else {
                console.log("❌ Lobby disconnected")
                refreshTimer.stop()
            }
        }

        onAvailableSessionsChanged: {
            console.log("📋 Sessions updated:", lobbyChatClient.availableSessions.length)
        }

        onErrorOccurred: function(error) {
            console.error("❌ Lobby error:", error)
        }
        
        Component.onCompleted: {
            console.log("🚀 MultiplayerLobby ChatClient connecting...")
            lobbyChatClient.connectToServer("ws://pattounecorp.ovh:3000")
        }
    }
    
    // Timer de rafraîchissement automatique
    Timer {
        id: refreshTimer
        interval: 10000
        running: false
        repeat: false
        onTriggered: {
            if (lobbyChatClient.connected) {
                lobbyChatClient.requestSessionsList()
            }
        }
    }

    // Components pour le StackView
    Component {
        id: sessionListComponent
        SessionList {
            // Passer le ChatClient mutualisé
            chatClient: lobbyChatClient
            onSessionSelected: function(sessionData) {
                lobbyChatClient.connectToSession(AccountManager.uniqueId, sessionData.password, AccountManager.nickname, sessionData.sessionId)
            }
        }
    }

    Component {
        id: sessionDetailsComponent
        SessionDetails {
            onBackRequested: {
                multiplayerStackView.pop()
            }
            onJoinRequested: {
                console.log("Join requested - fonctionnalité à implémenter")
            }
        }
    }

    Component {
        id: sessionCreationComponent
        SessionCreation {
            // Passer le ChatClient mutualisé
            chatClient: lobbyChatClient
            
            onBackRequested: {
                multiplayerStackView.pop()
            }
            
            onSessionCreateRequested: function(sessionData) {
                console.log("📝 Création de session:", JSON.stringify(sessionData))
                // Rejoindre la session (qui sera créée automatiquement par le serveur)
                lobbyChatClient.connectToSessionDirect(sessionData.sessionId, sessionData.password)
                
                // Retourner à la liste
                multiplayerStackView.pop()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // HEADER INTÉGRÉ
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: "#2a2a2a"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // Bouton retour vers TitleScreen
                BackButton {
                    onBackClicked: root.backToTitleScreen()
                }

                // Titre centré
                Item {
                    Layout.fillWidth: true

                    Text {
                        text: "🐱 Lobby Multijoueur"
                        color: "#ffffff"
                        font.pixelSize: 28
                        font.bold: true
                        anchors.centerIn: parent
                    }
                }

                // StatusIndicator
                StatusIndicator {
                    isOnline: true
                    ping: 38
                }
            }

            // Bordure inférieure
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#444444"
            }
        }

        // STACKVIEW pour navigation interne
        StackView {
            id: multiplayerStackView
            Layout.fillWidth: true
            Layout.fillHeight: true

            initialItem: sessionListComponent

            // Animations de transition
            pushEnter: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.OutQuad
                }
                PropertyAnimation {
                    property: "x"
                    from: multiplayerStackView.width
                    to: 0
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            pushExit: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            popEnter: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            popExit: Transition {
                PropertyAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 200
                    easing.type: Easing.OutQuad
                }
                PropertyAnimation {
                    property: "x"
                    from: 0
                    to: multiplayerStackView.width
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }
        }

        // FOOTER INTÉGRÉ
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#1a1a1a"

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    text: "🐾 Meownopoly"
                    color: "#666666"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1 }

                Text {
                    text: "v0.2.0 multiplayer edition"
                    color: "#808080"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                }
            }
        }
    }
}
