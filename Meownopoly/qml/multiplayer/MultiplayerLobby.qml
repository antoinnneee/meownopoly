import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0

import Catway 1.0

/**
 * Conteneur principal du lobby multijoueur
 * Gère la navigation interne entre SessionList et SessionDetails
 * La gestion des sessions est déléguée à ChatSessionManager (singleton).
 */

Rectangle {
    id: root

    color: "#1a1a1a"

    signal backToTitleScreen()
    signal lunchNewSession(bool isEdition)
    signal lunchExistingSession(bool isEdition)

    // Popup mot de passe lorsque INVALID_PASSWORD (session protégée)
    Dialog {
        id: sessionPasswordDialog
        title: "Mot de passe requis"
        modal: true
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 40)

        property string sessionIdForJoin: ""

        background: Rectangle {
            color: "#2a2a2a"
            border.color: "#E67E22"
            border.width: 2
            radius: 12
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                text: "Cette session est protégée. Entrez le mot de passe :"
                color: "#e0e0e0"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: sessionPasswordField
                placeholderText: "Mot de passe"
                echoMode: TextInput.Password
                color: "#f5f0ff"
                font.pixelSize: 14
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                background: Rectangle {
                    color: "#1a1a1a"
                    border.color: sessionPasswordField.activeFocus ? "#E67E22" : "#555555"
                    border.width: 2
                    radius: 8
                }

                onAccepted: sessionPasswordDialog.acceptAndJoin()
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: acceptAndJoin()
        onRejected: {
            sessionPasswordField.text = ""
            sessionIdForJoin = ""
        }

        function acceptAndJoin() {
            if (sessionIdForJoin.length === 0) return
            const client = ChatSessionManager.joinSession(sessionIdForJoin, sessionPasswordField.text)
            ChatSessionManager.setActiveSession(client)
            sessionPasswordField.text = ""
            sessionIdForJoin = ""
            close()
        }
    }

    // Components pour le StackView
    Component {
        id: sessionListComponent
        SessionList {
            onSessionSelected: function(sessionData) {
                const client = ChatSessionManager.joinSession(sessionData.sessionId, sessionData.password ?? "")
                ChatSessionManager.setActiveSession(client)
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
                console.log("📝 Création de session:", sessionData.name)
                const client = ChatSessionManager.createAndJoinSession(sessionData.name, sessionData.password)
                ChatSessionManager.setActiveSession(client)
                multiplayerStackView.pop()
            }
        }
    }

    // Gestion des erreurs remontées par les clients de session du manager
    Connections {
        target: ChatSessionManager
        function onSessionError(sessionId, error, errorType) {
            if (errorType === 1) { // ChatClient.INVALID_PASSWORD = 1
                sessionPasswordDialog.sessionIdForJoin = sessionId
                sessionPasswordDialog.open()
                return
            }
            console.error("❌ Lobby session error [" + sessionId + "]:", error)
        }
        function onSessionJoined(client, sessionId) {
            console.log("✅ Session rejointe:", sessionId)
            ChatSessionManager.requestSessionsRefresh()
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
                    isOnline: ChatSessionManager.serverConnected
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
