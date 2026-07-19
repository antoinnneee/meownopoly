pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "launcher/"
import "editor"
import "account/"
import "multiplayer/"
import ui_item

import QtQuick.Window
import Qt.labs.platform
import QtCore

import Game
import Meownopoly.Account 1.0
import Catway 1.0
import EditorSession 1.0
import EditorOpBus 1.0

import theme


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

    // Fermeture de la fenêtre (X, Alt+F4…) : si on est hôte d'une session
    // collab active, annoncer le départ pour que les clients élisent un
    // successeur immédiatement. broadcastReliable est queued sur le worker
    // Catway ; on retarde la fermeture de 300 ms le temps que le paquet UDP
    // parte effectivement.
    onClosing: function(close) {
        if (closeDelayTimer.running) return
        if (EditorSession.active && EditorSession.isHost) {
            console.log("[main] window closing — handover hôte (checkpoint D37) + delay close")
            close.accepted = false
            // T4-3 : point d'entrée unique consolidé — checkpoint D37 embarqué
            // dans HostLeaving 0x2A, puis coordination 0x46 (physique) et arrêt
            // ordonné ProposalSession/StateBus, puis stop.
            EditorSession.beginHostHandover()
            closeDelayTimer.start()
        }
    }

    Timer {
        id: closeDelayTimer
        interval: 300
        repeat: false
        onTriggered: Qt.quit()
    }

    StackView {
        id: stackView
        objectName: "mainStackView"
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
                stackView.push(gameplayModulesTest)
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

            onAiHostLobbyRequested: {
                stackView.push(aiHostLobbyPage)
            }

            onCatwayTestRequested: {
                stackView.push(catwayTest)
            }
        }
    }

    Component {
        id: aiHostLobbyPage

        Rectangle {
            id: aiHostPage
            objectName: "aiHostLobbyPage"
            color: Theme.background

            MeowButton {
                id: aiHostBackButton
                objectName: "aiHostLobbyBackButton"
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: Theme.spacingXXL
                }
                variant: "ghost"
                glossy: false
                hoverZoom: false
                iconText: "←"
                text: qsTr("Retour")
                onClicked: stackView.pop()
            }

            Text {
                id: aiHostTitle
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: Theme.spacingXXL
                }
                text: qsTr("Héberger une partie IA")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeDisplay
                font.bold: true
            }

            ScrollView {
                id: aiHostScroll
                anchors {
                    top: aiHostTitle.bottom
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: Theme.spacingL
                }
                clip: true

                Item {
                    width: aiHostScroll.availableWidth
                    height: Math.max(aiHostScroll.availableHeight,
                                     aiHostLobby.implicitHeight + 2 * Theme.spacingXXL)

                    AiHostLobby {
                        id: aiHostLobby
                        objectName: "aiHostLobby"
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth,
                                        parent.width - 2 * Theme.spacingXXL)
                        height: implicitHeight

                        onHostRequested: {
                            // Le handshake reste latché dans le singleton pendant la
                            // création de session. replace() évite qu'un retour depuis
                            // le lobby multijoueur ramène sur le préflight IA.
                            stackView.replace(multiplayerLobby)
                        }
                    }
                }
            }
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
                // Phase 3.7 — si collab, l'éditeur affiche d'abord un popup
                // "conserver la carte locale ?". La continuation ci-dessous
                // tourne APRÈS le choix utilisateur (ou immédiatement si
                // pas en collab). Elle couple la coupure propre Catway/undo
                // au pop de l'Editor sur le StackView.
                function _doExit(keep) {
                    if (EditorSession.active) {
                        // T4-3 : sortie consolidée en C++ (beginHostHandover).
                        // Hôte : checkpoint D37 + HostLeaving 0x2A PUIS 0x46
                        // physique (coordination anti double-autorité) + arrêt
                        // ordonné des sessions V3, puis stop. Client : arrêt
                        // ordonné de ses sessions V3 puis stop.
                        console.log("[main] EditorSession.beginHostHandover (retour menu) — keep =", keep)
                        EditorOpBus.clearUndo()
                        EditorSession.beginHostHandover()
                    }
                    stackView.pop()
                }
                // beginSessionExit gère popup+purge éventuelle ; hors collab
                // il invoque la continuation immédiatement avec keep=true.
                // Résolu via scoping chain — la fonction est sur l'Editor qui
                // englobe ce handler.
                beginSessionExit(_doExit)
            }
            // l'éditeur a détecté la nouvelle session lobby du
            // nouvel hôte (après host migration) → on relance le p2pStateMachine
            // existant avec skipPush (l'éditeur est déjà au-dessus de la pile).
            onReconnectRequested: function(sessionId, hostId) {
                console.log("[main] reconnect editor → host =", hostId,
                            "session =", sessionId)
                if (!Catway.chatClient) {
                    console.warn("[main] Catway.chatClient null — abandon reconnect")
                    return
                }
                // session_id inchangé (le nouvel hôte a juste
                // renommé la session côté serveur). Pas de re-join WS — on
                // garde la même connexion, ses participants, son historique.
                // Juste relancer le p2p state machine vers le nouvel hôte.
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
    // Page de test des modules de gameplay (vie / inventaire / monnaie).
    // Remplace l'ancien "Test Component" (bouton test3DRequested du TitleScreen).
    Component {
        id: gameplayModulesTest
        GameplayModulesTestPage {
            width: root.width
            height: root.height
            onBackRequested: stackView.pop()
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

            // host vient de créer une session (éditeur ou jeu).
            // Si éditeur, on démarre EditorSession.startAsHost et on push l'éditeur.
            // rawSessionName / initialMap : voir MultiplayerLobby.launchNewSession.
            onLaunchNewSession: function(isEdition, hostId, rawSessionName, initialMap) {
                if (!isEdition) {
                    console.log("[main] launchNewSession (jeu) — pas encore câblé")
                    return
                }
                console.log("[main] Host démarre EditorSession, playerId =", AccountManager.uniqueId,
                            "session =", rawSessionName,
                            "initialMap =", JSON.stringify(initialMap))
                // T4-3 : entrée de session PROPRE — purge tout état de
                // migration résiduel (checkpoint, suspension) d'une session
                // précédente. Ne PAS purger sur le chemin reconnect.
                EditorSession.clearMigrationState()
                const ok = EditorSession.startAsHost(AccountManager.uniqueId)
                if (!ok) {
                    console.warn("[main] EditorSession.startAsHost a échoué (GameSession active ?)")
                    return
                }
                // Garde le lobby (et son ChatClient collab) vivant en dessous
                // de l'éditeur — ne pas pop. Retour au menu dépilera Editor
                // puis Lobby proprement.
                // initialProperties : Editor.initializeEditor() les lit au
                // Component.onCompleted pour choisir entre carte vide au
                // nom de session et carte existante conservant ses méta.
                stackView.push(editor, {
                    "hostInitialMap": {
                        "sessionName": rawSessionName || "",
                        "initialMap":  initialMap || null
                    }
                })
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
                // Purge un éventuel PlayerNetwork résiduel pour ce hostId :
                // cas typique où l'ancien hôte rejoint après migration (il garde
                // en cache l'IP/port/p2pConnected du pair devenu hôte). Sans
                // purge, p2pStateMachine voit p2pConnected=true instantanément,
                // skip le hole-punch, et envoie Hello vers un port mort → pas
                // de FullSync. On laisse REPLY_CONNECTION_INFO recréer le pair
                // avec les bonnes coordonnées.
                const stale = Catway.playerById(hostId)
                if (stale) {
                    console.log("[main] purge PlayerNetwork résiduel pour", hostId)
                    Catway.removePlayer(stale)
                }
                // T4-3 : entrée fraîche par le lobby (pas un reconnect
                // post-migration) — purge de l'état de migration résiduel.
                EditorSession.clearMigrationState()
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

    // quand le pair local se promeut hôte (host migration), on
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
            // on GARDE le même session_id pour que les survivants
            // restent sur le même canal de chat (même historique, même clé).
            // On renomme juste le prefix [EDIT:...] pour que le lobby affiche
            // le nouvel hôte. Les survivants reconnaissent directement via
            // hole-punch sur la session existante — aucun re-join chat nécessaire.
            const pid = EditorSession.localPlayerId
            const sid = Catway.chatClient.sessionId
            // Cherche le nom courant dans availableSessions pour préserver la
            // partie "user" après le prefix [EDIT:...].
            let oldName = ""
            const list = Catway.chatClient.availableSessions || []
            for (let i = 0; i < list.length; ++i) {
                if (list[i].sessionId === sid) {
                    oldName = list[i].name || ""
                    break
                }
            }
            const stripped = oldName.replace(/^\[EDIT:[^\]]+\]\s*/, "")
            const newName = "[EDIT:" + pid + "] " + (stripped || "Session")
            console.log("[main] promotion — renameSession:", oldName, "→", newName)
            Catway.chatClient.renameSession(newName)
            // Transfert d'ownership côté serveur : sans ça, l'ancien hôte
            // (premier joined_at) garderait isHost=true, et son retour
            // éventuel dans la session lui redonnerait les droits admin
            // + confusion UI ("badge hôte" alors qu'il est client P2P).
            console.log("[main] promotion — transferHost → " + pid)
            Catway.chatClient.transferHost(pid)
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
        // true quand on se reconnecte à un nouvel hôte (editor déjà
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
