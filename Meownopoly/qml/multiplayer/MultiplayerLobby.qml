import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0

import Catway 1.0
import EditorSession 1.0
/**
 * Conteneur principal du lobby multijoueur
 * Gère la navigation interne entre SessionList et SessionDetails
 */
Rectangle {
    id: root

    color: "#1a1a1a"

    signal backToTitleScreen()

    // le hostId (playerId du créateur) est transmis pour que le
    // client puisse appeler EditorSession.startAsClient avec le bon pair.
    // rawSessionName = nom utilisateur (sans prefix [EDIT:...]) ; utilisé
    // par main.qml pour nommer la carte collab côté hôte.
    // initialMap peut être null (rejoin de session existante ou non-éditeur).
    signal launchNewSession(bool isEdition, string hostId, string rawSessionName, var initialMap)
    signal launchExistingSession(bool isEdition, string hostId)

    // Stash du payload sessionCreateRequested en attente du callback
    // sessionCreated (round-trip serveur). Permet de retrouver le nom brut
    // et l'initialMap choisis par l'utilisateur pour les faire remonter à
    // main.qml via launchNewSession.
    property var _pendingCreation: null

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
    // l'utilisateur sélectionne une session, pour émettre launchExistingSession
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
            // le créateur est l'hôte. Si c'est une session éditeur,
            // on cable Catway sur ce ChatClient avant de déclencher la nav
            // (sinon les REQUEST_CONNECTION_INFO reçus plus tard ne seraient
            // pas routés vers la bonne session chat).
            const parsed = root._parseEditorPrefix(sessionName)
            // Récupère le payload SessionCreation stashé. On le consomme ici
            // (même si branche ignorée) pour ne pas qu'il traîne.
            const pending = root._pendingCreation
            root._pendingCreation = null
            const rawName     = pending ? String(pending.name || "") :
                                           String(parsed.cleanName || "")
            const initialMap  = pending ? pending.initialMap : null
            if (parsed.isEdit) {
                // si EditorSession est déjà hôte actif, c'est une
                // re-publication faite par un client qui vient de se promouvoir
                // (host migration) — ne PAS re-déclencher launchNewSession, sinon
                // main.qml empilerait un nouvel Editor et relancerait startAsHost.
                if (EditorSession.active && EditorSession.isHost) {
                    console.log("🛠️ Publication pendant promotion host — skip launchNewSession")
                    return
                }
                console.log("🛠️ Session éditeur créée (host =", parsed.hostId + ") → launchNewSession")
                Catway.setChatClient(lobbyChatClient)
                root.launchNewSession(true, parsed.hostId, rawName, initialMap)
            } else {
                root.launchNewSession(false, AccountManager.uniqueId, rawName, null)
            }
        }

        // détection de fin de join côté client. sessionIdChanged fire
        // quand connectToSessionDirect passe par setSessionId() — indispensable
        // de câbler Catway sur ce ChatClient AVANT launchExistingSession.
        onSessionIdChanged: {
            if (!lobbyChatClient.sessionId) return
            if (!root._pendingJoinEdit) return
            if (root._pendingJoinSessionId
                    && lobbyChatClient.sessionId !== root._pendingJoinSessionId) return

            console.log("🛠️ Session éditeur rejointe (host =", root._pendingJoinHostId + ") → launchExistingSession")
            Catway.setChatClient(lobbyChatClient)
            const hid = root._pendingJoinHostId
            root._pendingJoinEdit = false
            root._pendingJoinHostId = ""
            root._pendingJoinSessionId = ""
            root.launchExistingSession(true, hid)
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
            // Passer le ChatClient mutualisé
            chatClient: lobbyChatClient
            onSessionSelected: function(sessionData) {
                // si c'est une session éditeur, on arme l'état de
                // join pour que onSessionIdChanged déclenche la navigation.
                const parsed = root._parseEditorPrefix(sessionData.name || sessionData.sessionName || "")
                // Cas rejoin même session (ex: retour d'éditeur collab) :
                // ChatClient::setSessionId est no-op si l'id n'a pas changé,
                // donc sessionIdChanged ne fire pas. On déclenche la nav direct.
                if (parsed.isEdit
                        && lobbyChatClient.sessionId === sessionData.sessionId
                        && lobbyChatClient.connected) {
                    Catway.setChatClient(lobbyChatClient)
                    const isOwnSession = parsed.hostId === AccountManager.uniqueId
                    if (isOwnSession && EditorSession.active && EditorSession.isHost) {
                        console.log("🛠️ Rejoin propre session éditeur — EditorSession déjà hôte, skip launchNewSession")
                        return
                    }
                    if (isOwnSession) {
                        console.log("🛠️ Rejoin propre session éditeur (host =", parsed.hostId + ") → launchNewSession (resume host)")
                        // rejoin : le fichier local <cleanName>_map.json existe
                        // déjà. Editor.qml en mode "new" refait un mapExists
                        // check et loadMap directement si présent, donc pas
                        // besoin d'initialMap explicite.
                        root.launchNewSession(true, parsed.hostId, parsed.cleanName, null)
                    } else {
                        console.log("🛠️ Rejoin même session éditeur (host =", parsed.hostId + ") → launchExistingSession direct")
                        root.launchExistingSession(true, parsed.hostId)
                    }
                    return
                }
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
            chatClient: lobbyChatClient
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
                // encoder le mode édition dans le nom via prefix
                // "[EDIT:<hostId>]" — évite toute modification du serveur chat.
                let finalName = sessionData.name
                if (sessionData.isEditionMode) {
                    finalName = root._wrapEditorName(sessionData.name, AccountManager.uniqueId)
                    console.log("🛠️ Création session éditeur — nom encodé :", finalName)
                } else {
                    console.log("📝 Création de session:", sessionData.name)
                }
                // Stash pour récupérer le nom brut + initialMap au callback
                // sessionCreated (round-trip serveur).
                root._pendingCreation = sessionData
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
                    isOnline: lobbyChatClient.connected
                    ping: lobbyChatClient.pingMs
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
