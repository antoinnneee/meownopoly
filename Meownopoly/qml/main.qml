pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "launcher/"
import "board"
import "editor"
import "account/"
import "multiplayer/"

import QtQuick.Window
import Qt.labs.platform
import QtCore

import Game
import Meownopoly.Account 1.0
import Catway 1.0
import EditorSession 1.0
import EditorOpBus 1.0


ApplicationWindow {
    id: root
    
    Settings {
        id: stVideoConfig
        category: "Video"
    }

    width: {
        let res = stVideoConfig.value("resolution", "1280x720")
        let parts = res.split("x")
        return parts.length === 2 ? parseInt(parts[0]) : 1280
    }
    
    height: {
        let res = stVideoConfig.value("resolution", "1280x720")
        let parts = res.split("x")
        return parts.length === 2 ? parseInt(parts[1]) : 720
    }
    
    visible: true
    title: "Meownopoly"
    
    visibility: (Qt.platform.os === "android") ? Window.FullScreen
        : ((stVideoConfig.value("fullscreen", false) === "true" || stVideoConfig.value("fullscreen", false) === true) ? Window.FullScreen : Window.Windowed)

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: AccountManager.hasAccount ? titleScreen : accountSetup
    }

    // Account setup page for first launch
    Component {
        id: accountSetup
        AccountSetupPage {
            onAccountCreated: {
                stackView.replace(titleScreen)
            }
        }
    }

    Component {
        id: titleScreen
        TitleScreen {
            onStartGameRequested: {
                stackView.push(gameBoard)
            }

            onEditorRequested:{
                //stackView.pop()
                stackView.push(editor)
            }
            onTestViewRequested: {
                stackView.pop()
                stackView.push(test_view)
            }

            onCaseCreatorRequested: {
                stackView.pop()
            }

            onTest3DRequested: {
                stackView.pop()
                stackView.push(test_view)
            }
            
            onLauncherRequested: {
                stackView.pop()
                stackView.push(launcher)
            }
            
            onAssetManagerTestRequested: {
                stackView.push(assetManagerTest)
            }
            
            onMultiplayerLobbyRequested: {
                stackView.push(multiplayerLobby)
            }

            onCatwayTestRequested: {
                stackView.push(catwayTest)
            }
        }
    }

    Component {
        id: gameBoard
        GameBoard {
            width:root.width
            height:root.height
            visible: false
        }
    }

    Component {
        id: editor
        Editor {
            width:root.width
            height:root.height
            visible: false
            appPositionX: root.x
            appPositionY: root.y
            escMenu.onReturnToMainMenu: {
                console.log("Retour au menu principal demandé")
                // Phase 7 : si on est en session collaborative, couper proprement
                // avant de quitter l'éditeur (stop libère Catway et clear undo).
                if (EditorSession.active) {
                    console.log("[main] EditorSession.stop (retour menu)")
                    EditorOpBus.clearUndo()
                    EditorSession.stop()
                }
                stackView.pop()
            }
            // Phase 8 : l'éditeur a détecté la nouvelle session lobby du
            // nouvel hôte (après host migration) → on relance le p2pStateMachine
            // existant avec skipPush (l'éditeur est déjà au-dessus de la pile).
            onReconnectRequested: function(sessionId, hostId) {
                console.log("[main] reconnect editor → host =", hostId,
                            "session =", sessionId)
                if (!Catway.chatClient) {
                    console.warn("[main] Catway.chatClient null — abandon reconnect")
                    return
                }
                Catway.chatClient.connectToSessionDirect(sessionId, "")
                p2pStateMachine.targetHostId = hostId
                p2pStateMachine.state = "STUN"
                p2pStateMachine.attempts = 0
                p2pStateMachine.requestSent = false
                p2pStateMachine.holePunchSent = false
                p2pStateMachine.skipPush = true
                if (Catway.localPortCount() === 0) Catway.setupNewPort()
                p2pStateMachine.start()
            }
        }
    }
    Component{
        id: test_view
        TEST_3D{
            width:root.width
            height:root.height
            visible: false
        }
    }
    Component {
        id: testPaw
        TEST_PAW_MENU{
            width:root.width
            height:root.height
            visible: false
        }
    }


    Component {
        id: testComp
        Test_Comp {
            width: root.width
            height: root.height
            visible: false
            
            // Fonction pour revenir à l'écran titre
            function goBack() {
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }

    Component {
        id: launcher
        Launcher {
            width: root.width
            height: root.height
            visible: false
            
            onBackRequested: {
                stackView.pop()
                stackView.push(titleScreen)
            }
            onLaunchGame: {
                // Ici on peut ajouter la logique pour lancer le jeu principal
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }
    
    Component {
        id: assetManagerTest
        TEST_ASSET_MANAGER {
            width: root.width
            height: root.height
            visible: false
            
            onBackRequested: {
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }
    
    Component {
        id: multiplayerLobby
        MultiplayerLobby {
            width: root.width
            height: root.height

            onBackToTitleScreen: {
                stackView.pop()
            }

            // Phase 7 : host vient de créer une session (éditeur ou jeu).
            // Si éditeur, on démarre EditorSession.startAsHost et on push l'éditeur.
            onLaunchNewSession: function(isEdition, hostId) {
                if (!isEdition) {
                    console.log("[main] launchNewSession (jeu) — pas encore câblé")
                    return
                }
                console.log("[main] Host démarre EditorSession, playerId =", AccountManager.uniqueId)
                const ok = EditorSession.startAsHost(AccountManager.uniqueId)
                if (!ok) {
                    console.warn("[main] EditorSession.startAsHost a échoué (GameSession active ?)")
                    return
                }
                // Garde le lobby (et son ChatClient collab) vivant en dessous
                // de l'éditeur — ne pas pop. Retour au menu dépilera Editor
                // puis Lobby proprement.
                stackView.push(editor)
            }

            // Client a rejoint une session existante. Si c'est une session
            // éditeur, on doit :
            //   1. Avoir un socket STUN publiquement connu (setupNewPort).
            //   2. Envoyer REQUEST_CONNECTION_INFO au host (chat signalisation).
            //   3. Attendre que Catway ait reçu REPLY_CONNECTION_INFO et créé
            //      le PlayerNetwork avec IP/port.
            //   4. Appeler initiateHolePunch pour envoyer UDP_HOLE_PUNCH_REQUEST
            //      + HP:STRIKE (sans ça, seul le heartbeat essaie, ~10 s).
            //   5. Attendre isP2pConnected.
            //   6. Démarrer EditorSession.startAsClient et push editor.
            onLaunchExistingSession: function(isEdition, hostId) {
                if (!isEdition) {
                    console.log("[main] launchExistingSession (jeu) — pas encore câblé")
                    return
                }
                if (!hostId || hostId === AccountManager.uniqueId) {
                    console.warn("[main] Session éditeur sans hostId valide :", hostId)
                    return
                }
                console.log("[main] Client → négociation P2P avec host =", hostId)
                p2pStateMachine.targetHostId = hostId
                p2pStateMachine.state = "STUN"
                p2pStateMachine.attempts = 0
                p2pStateMachine.requestSent = false
                p2pStateMachine.holePunchSent = false

                // Force un setupNewPort si aucun socket STUN-assigné disponible.
                // Sinon, on réutilise le dernier port de la liste.
                if (Catway.localPortCount() === 0) {
                    console.log("[main] setupNewPort()")
                    Catway.setupNewPort()
                }
                p2pStateMachine.start()
            }
        }
    }

    // Phase 8 : quand le pair local se promeut hôte (host migration), on
    // publie une nouvelle session lobby "[EDIT:<localId>] Map". Les clients
    // survivants la verront apparaître dans `availableSessions` et se
    // reconnecteront automatiquement (cf. Editor.onReconnectRequested).
    Connections {
        target: EditorSession
        function onPromotedToHost() {
            if (!Catway.chatClient) {
                console.warn("[main] promoteToHost: Catway.chatClient null — skip publish")
                return
            }
            const pid = EditorSession.localPlayerId
            // Le chat server ne permet pas deux sessions du même owner en
            // même temps ; on renomme en `[EDIT:<pid>] Session ré-hôtée`.
            const name = "[EDIT:" + pid + "] Session ré-hôtée"
            console.log("[main] promotion — createSession:", name)
            Catway.chatClient.createSession(name, "")
        }
    }

    // Machine à états du hole-punch client.
    // Poll à 300 ms avec timeout global ~15 s. Chaque état avance dès que
    // la condition passe.
    Timer {
        id: p2pStateMachine
        interval: 300
        repeat: true
        property string targetHostId: ""
        property string state: ""            // STUN | REQUEST | PUNCH | WAIT | DONE
        property int attempts: 0
        property bool requestSent: false
        property bool holePunchSent: false
        // Phase 8 : true quand on se reconnecte à un nouvel hôte (editor déjà
        // dans la pile) — on n'empile pas un 2e Editor à la fin.
        property bool skipPush: false
        readonly property int maxAttempts: 50   // ~15 s

        onTriggered: {
            attempts++
            if (attempts > maxAttempts) {
                console.warn("[main] Timeout P2P global — abandon (state =", state + ")")
                stop()
                state = ""
                return
            }

            // 1) Attendre STUN. Après Catway.setupNewPort(), le socket STUN-assigné
            //    est transféré dans localPorts (lastLocalPort). currentSocketInfo()
            //    devient null puis réinitialisé en socket vide — inutile ici.
            if (state === "STUN") {
                const si = Catway.lastLocalPort()
                if (!si || !si.publicAddress || si.publicAddress.length === 0 || !si.publicPort) {
                    return  // pas encore
                }
                console.log("[main] STUN ok :", si.publicAddress + ":" + si.publicPort, "→ REQUEST")
                state = "REQUEST"
            }

            // 2) Envoyer REQUEST_CONNECTION_INFO au host.
            if (state === "REQUEST") {
                if (!requestSent) {
                    const si = Catway.lastLocalPort()
                    if (!si) return
                    if (!Catway.chatClient) {
                        console.warn("[main] Catway.chatClient null — abandon")
                        stop(); state = ""; return
                    }
                    console.log("[main] sendRequestConnectionInfo →", targetHostId)
                    Catway.chatClient.sendRequestConnectionInfo(
                        targetHostId,
                        si.publicAddress || "",
                        si.publicPort    || 0,
                        si.localPort     || 0)
                    requestSent = true
                }
                // Attendre que Catway ait créé/peuplé le PlayerNetwork côté client.
                const p = Catway.playerById(targetHostId)
                if (p && p.ip && p.ip.length > 0 && p.port > 0) {
                    console.log("[main] Player du host prêt :", p.ip + ":" + p.port, "→ PUNCH")
                    state = "PUNCH"
                } else {
                    return
                }
            }

            // 3) Initier le hole-punch explicitement.
            if (state === "PUNCH") {
                const p = Catway.playerById(targetHostId)
                if (!p) { return }
                if (!holePunchSent) {
                    console.log("[main] initiateHolePunch →", targetHostId)
                    Catway.initiateHolePunch(p)
                    holePunchSent = true
                }
                state = "WAIT"
            }

            // 4) Attendre p2pConnected. NB: en QML la Q_PROPERTY est `p2pConnected`
            // (le getter C++ s'appelle isP2pConnected mais ce n'est pas le nom
            // de la propriété).
            if (state === "WAIT") {
                const p = Catway.playerById(targetHostId)
                if (p && p.p2pConnected) {
                    console.log("[main] P2P établi avec", targetHostId,
                                "(après", attempts * interval, "ms) → startAsClient")
                    stop()
                    state = "DONE"
                    const ok = EditorSession.startAsClient(AccountManager.uniqueId, targetHostId)
                    if (!ok) {
                        console.warn("[main] EditorSession.startAsClient a échoué")
                        skipPush = false
                        return
                    }
                    if (skipPush) {
                        console.log("[main] reconnect post-migration — skip push editor")
                        skipPush = false
                    } else {
                        // Garde le lobby + son ChatClient vivant sous l'éditeur.
                        stackView.push(editor)
                    }
                }
            }
        }
    }

    Component {
        id: catwayTest
        CatwayTest {
            width: root.width
            height: root.height

            onBackRequested: {
                stackView.pop()
            }
        }
    }
}
