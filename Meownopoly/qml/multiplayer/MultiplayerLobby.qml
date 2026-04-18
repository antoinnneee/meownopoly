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
 */
Rectangle {
    id: root

    color: "#1a1a1a"

    signal backToTitleScreen()

    // Phase 7 : le hostId (playerId du créateur) est transmis pour que le
    // client puisse appeler EditorSession.startAsClient avec le bon pair.
    signal lunchNewSession(bool isEdition, string hostId)
    signal lunchExistingSession(bool isEdition, string hostId)

    // ── Encodage du mode éditeur dans le nom de session ─────────────────────
    // Format : "[EDIT:<hostPlayerId>] <nom affiché>". Évite de modifier le
    // serveur chat ; le champ name est déjà transmis nativement.
    readonly property var _editPrefixRe: /^\[EDIT:([^\]]+)\]\s*(.*)$/

    function _wrapEditorName(userName, hostId) {
        return "[EDIT:" + hostId + "] " + userName
    }

    function _parseEditorPrefix(rawName) {
        if (!rawName) return { isEdit: false, hostId: "", cleanName: rawName || "" }
        const m = _editPrefixRe.exec(rawName)
        if (!m) return { isEdit: false, hostId: "", cleanName: rawName }
        return { isEdit: true, hostId: m[1], cleanName: m[2] || "" }
    }

    // État d'un join en cours : on mémorise le hostId extrait du nom quand
    // l'utilisateur sélectionne une session, pour émettre lunchExistingSession
    // une fois la connexion chat établie.
    property bool _pendingJoinEdit: false
    property string _pendingJoinHostId: ""
    property string _pendingJoinSessionId: ""

    // ChatClient mutualisé pour tout le lobbyD
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

        onErrorOccurred: function(error, errorType) {
            if (errorType === ChatClient.INVALID_PASSWORD) {
                sessionPasswordDialog.sessionIdForJoin = lobbyChatClient.sessionId
                sessionPasswordDialog.open()
                return
            }
            console.error("❌ Lobby error:", error)
        }

        onSessionCreated: function(sessionId, sessionName) {
            console.log("✅ Session créée:", sessionName, "(id:", sessionId + ")")
            lobbyChatClient.requestSessionsList()
            // Phase 7 : le créateur est l'hôte. Si c'est une session éditeur,
            // on cable Catway sur ce ChatClient avant de déclencher la nav
            // (sinon les REQUEST_CONNECTION_INFO reçus plus tard ne seraient
            // pas routés vers la bonne session chat).
            const parsed = root._parseEditorPrefix(sessionName)
            if (parsed.isEdit) {
                console.log("🛠️ Session éditeur créée (host =", parsed.hostId + ") → lunchNewSession")
                Catway.setChatClient(lobbyChatClient)
                root.lunchNewSession(true, parsed.hostId)
            } else {
                root.lunchNewSession(false, AccountManager.uniqueId)
            }
        }

        // Phase 7 : détection de fin de join côté client. sessionIdChanged fire
        // quand connectToSessionDirect passe par setSessionId() — indispensable
        // de câbler Catway sur ce ChatClient AVANT lunchExistingSession.
        onSessionIdChanged: {
            if (!lobbyChatClient.sessionId) return
            if (!root._pendingJoinEdit) return
            if (root._pendingJoinSessionId
                    && lobbyChatClient.sessionId !== root._pendingJoinSessionId) return

            console.log("🛠️ Session éditeur rejointe (host =", root._pendingJoinHostId + ") → lunchExistingSession")
            Catway.setChatClient(lobbyChatClient)
            const hid = root._pendingJoinHostId
            root._pendingJoinEdit = false
            root._pendingJoinHostId = ""
            root._pendingJoinSessionId = ""
            root.lunchExistingSession(true, hid)
        }

        Component.onCompleted: {
            console.log("🚀 MultiplayerLobby ChatClient connecting...")
            lobbyChatClient.connectToServer("ws://pattounecorp.ovh:3000")
        }
    }

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
            lobbyChatClient.connectToSessionDirect(sessionIdForJoin, sessionPasswordField.text)
            sessionPasswordField.text = ""
            sessionIdForJoin = ""
            close()
        }
    }

    // Timer de rafraîchissement automatique
    Timer {
        id: refreshTimer
        interval: 10000
        running: true
        repeat: true
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
            // SessionList lit depuis ChatSessionManager (singleton), pas besoin
            // d'injecter le ChatClient ici — l'action de join est portée par
            // lobbyChatClient du parent via onSessionSelected.
            onSessionSelected: function(sessionData) {
                // Phase 7 : si c'est une session éditeur, on arme l'état de
                // join pour que onSessionIdChanged déclenche la navigation.
                const parsed = root._parseEditorPrefix(sessionData.name || sessionData.sessionName || "")
                root._pendingJoinEdit     = parsed.isEdit
                root._pendingJoinHostId   = parsed.hostId
                root._pendingJoinSessionId = sessionData.sessionId
                lobbyChatClient.connectToSessionDirect(sessionData.sessionId, sessionData.password)
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
            // SessionCreation émet sessionCreateRequested ; c'est le parent
            // qui dispatche sur lobbyChatClient, pas besoin d'injection.
            onBackRequested: {
                multiplayerStackView.pop()
            }

            onSessionCreateRequested: function(sessionData) {
                // Phase 7 : encoder le mode édition dans le nom via prefix
                // "[EDIT:<hostId>]" — évite toute modification du serveur chat.
                let finalName = sessionData.name
                if (sessionData.isEditionMode) {
                    finalName = root._wrapEditorName(sessionData.name, AccountManager.uniqueId)
                    console.log("🛠️ Création session éditeur — nom encodé :", finalName)
                } else {
                    console.log("📝 Création de session:", sessionData.name)
                }
                lobbyChatClient.createSession(finalName, sessionData.password)
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
