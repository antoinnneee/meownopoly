import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"

/**
 * Conteneur principal du lobby multijoueur
 * Gère la navigation interne entre SessionList et SessionDetails
 */
Rectangle {
    id: root

    color: "#1a1a1a"

    signal backToTitleScreen()

    // Components pour le StackView
    Component {
        id: sessionListComponent
        SessionList {
            onSessionSelected: function(sessionData) {
                multiplayerStackView.push(sessionDetailsComponent, {
                    sessionName: sessionData.name,
                    sessionId: sessionData.sessionId,
                    players: sessionData.players,
                    maxPlayers: sessionData.maxPlayers
                })
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
            onBackRequested: {
                multiplayerStackView.pop()
            }
            onSessionCreateRequested: function(sessionData) {
                console.log("📝 Données de création reçues:", JSON.stringify(sessionData))
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
