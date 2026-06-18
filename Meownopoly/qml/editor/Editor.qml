import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml
import QtCore

import UiStyle

import ItemSnapable

import meowComponent

import Game
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import EditDelta 1.0
import AssetManager
import ItemSnapableFactory
import ui_item
import Catway 1.0
import EditorSession 1.0
import EditorOpBus 1.0
import Meownopoly.Account 1.0

import chat
import world3d 1.0

import QtQuick3D
import QtQuick3D.Helpers
import QtQuick.Effects

import editor
import playerConfigPanel 1.0
import playerPanel
import zonePanel
import templatePanel
import assetSelectionPanel
import caseSelectionPanel
import config3dPanel
import "."

import MeowPainter 1.0
import theme

Base_Board {
    id: root

    color: "lightblue"
    border.width: 0
    focus: true

    property int appPositionX: 0
    property int appPositionY: 0

    // Hauteur du panneau de module "bas" actif (deco/case/zone/template/player) ;
    // 0 sinon. Remplace l'ancien selectionPanel.height (D4).
    readonly property bool _bottomModuleActive:
        ["deco", "case", "zone", "template", "player", "config3d"].indexOf(moduleManager.selectedModuleId) !== -1
    readonly property real _bottomPanelHeight: _bottomModuleActive ? Screen.pixelDensity * 75 : 0

    property int availableHeight: height - _bottomPanelHeight
    property alias groupeSelection: workArea.groupeSelection

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    // Asset selection properties
    property bool isAssetSelected: logic ? logic.isAssetSelected : false
    property alias editorSidePanel: sidePanel

    property alias escMenu: escMenu
    property alias fullScreenMsgPopup: fullScreenMsgPopup
    property alias view3D: gameScene.view3D

    signal openNewMapMenu
    property alias entity: gameScene.entity

    // Passé par main.qml au push quand l'utilisateur crée une session collab
    // en tant qu'hôte. Null si mono ou client. Structure :
    //   {
    //     sessionName: "mySession",       // nom saisi dans SessionCreation
    //     initialMap:  {
    //       mode:    "new" | "existing",  // new → fichier vide ; existing → load
    //       mapName: "myExistingMap"      // utilisé seulement si mode=="existing"
    //     }
    //   }
    // initializeEditor s'en sert pour router vers le bon flow (create+load vs
    // load direct) AVANT que le premier Hello client n'arrive — le FullSync
    // lira le mapInfo ainsi positionné.
    property var hostInitialMap: null

    // la reconnexion auto après host migration est pilotée par main.qml
    // (qui possède le p2pStateMachine). Émis depuis `onHostLost` quand le pair
    // local n'est pas élu — la session de chat reste la MÊME (le nouvel hôte
    // l'a juste renommée côté serveur), donc pas de re-join chat nécessaire.
    signal reconnectRequested(string sessionId, string hostId)

    // MapInfo est déjà défini dans Base_Board, on met juste à jour le nom ici
    Component.onCompleted: {
        initializeEditor()

        // Phase 4 — World3D + LocalPlayerSpawner + CameraRig + InputController
        // remplacent les anciens singletons EntityEngine / CameraController /
        // World3DTools. La création du body "player" est faite par
        // LocalPlayerSpawner (déclaratif) ; le PhysicsActor positionne
        // l'entity 3D en lisant bodyState chaque frame.
        cameraRig.setTarget(entity, gameGrid, logic ? logic.mouseLogic : null)

        // Démarrage auto du moteur physique : sans ça, les cmds des
        // spawners/bridges sont perdues (QueuedConnection sans worker
        // récepteur). Le badge PhysicsStatusPanel reste utile pour
        // toggle stop/start manuellement.
        if (pattounxWorld && !pattounxWorld.running) pattounxWorld.start()

        // Activer le mode édition pour les zones d'exclusion
        gameGrid.isEdit = true

        // si la session collab est déjà active lors de l'ouverture
        // de l'éditeur (cas usuel : startAsClient déclenché depuis le panel
        // de test avant navigation), le signal `activeChanged` est déjà passé
        // → on déclenche manuellement le Hello côté client.
        if (EditorSession.active && !EditorSession.isHost) {
            console.log("[FullSync] client → envoi Hello (déjà actif au chargement)")
            EditorSession.sendEvent(EditorMessageType.Hello, {
                "nickname": AccountManager.nickname || "",
                "assetPackHash": ""
            })
        }
    }

    Keys.onPressed: function (event) {
        // Zoom clavier + / - : réutilise automationHooks.zoomCamera (même
        // logique que le zoom molette ×1.1/cran, recentré viewport + sync 3D).
        // Qt.Key_Equal couvre le `+` non-shifté de certaines dispositions.
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            automationHooks.zoomCamera(1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Minus) {
            automationHooks.zoomCamera(-1)
            event.accepted = true
            return
        }
        // Phase 4 : InputController remplace EntityEngine.keysHandler
        inputController.handlePress(event)
        // Debug jitter : J = trace 3 sec sur le PhysicsActor du joueur.
        // Logs CSV "[JITTER]" dans la console (grep + analyse tableur).
        if (event.key === Qt.Key_J && !event.isAutoRepeat) {
            playerActor.startJitterTrace(180)
        }
        // Pass to EditorController
        EditorController.keysHandler.Keys.pressed(event)
    }
    Keys.onReleased: function (event) {
        inputController.handleRelease(event)
        EditorController.keysHandler.Keys.released(event)
    }

    // Menu d'échappement
    EditorEscMenu {
        id: escMenu
        z: UiStyle.z_CONFIG_PANEL
        onVisibleChanged: {
            if (!visible) {
                // Redonner le focus à l'éditeur quand le menu se ferme
                root.forceActiveFocus()
            }
        }
        onIndexSaveEvent: stEnableAutoSave.sync()
    }

    BtSideMenu {
        id: btSelection
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingL
        z: UiStyle.z_HUD + 1

        property real xOrigin
        property real yOrigin

        property bool fixExtand: false

        function resetPosition() {
            xOrigin = x
            yOrigin = y
            btChat.x = x
            btChat.y = y
            btInfoMap.x = x
            btInfoMap.y = y
            btModule.x = x
            btModule.y = y
        }

        Component.onCompleted: resetPosition()
        onXChanged: resetPosition()
        onYChanged: resetPosition()

        onBtClicked:  btSelection.fixExtand = !btSelection.fixExtand

        Text {
            id: lock
            text: "🔒"
            opacity: 0.5
            visible: btSelection.fixExtand
        }

        MouseArea {
            id: btSelMouseArea
            propagateComposedEvents: true
            hoverEnabled: true

            Component.onCompleted:{
                width = parent.width
                height = parent.height
            }

            onEntered: extand()
            onExited: retract()

            function extand() {
                height = (btSelection.height * 4) + 10
                btInfoMap.y =   (Screen.pixelDensity * 20)  + 10
                btChat.y =      (Screen.pixelDensity * 20) * 2  + 10
                btModule.y =    (Screen.pixelDensity * 20) * 3  + 10
            }
             function retract() {
                 if (btSelection.fixExtand) return
                btInfoMap.x = btSelection.xOrigin; btInfoMap.y = btSelection.yOrigin
                btChat.x = btSelection.xOrigin; btChat.y = btSelection.yOrigin
                btModule.x = btSelection.xOrigin; btModule.y = btSelection.yOrigin
            }
        }
    }
    BtSideMenu {
        id: btInfoMap
        emojiBt: "ℹ️"
        colorBt: Theme.accent
        onBtClicked: mapInfoPanel.openDrawer()
        Behavior on y {SmoothedAnimation { velocity : 500}}
    }

    BtSideMenu {
        id: btChat
        emojiBt: "💬"
        colorBt: Theme.success
        onBtClicked: chatDrawer.open()
        Behavior on y {SmoothedAnimation { velocity : 500}}
    }

    // Bouton déclencheur du gestionnaire de modules (icône hud "1"), déplacé
    // ici depuis l'ancien header de la ListView du ModuleManager. Se déploie
    // avec btInfoMap/btChat au survol de btSelection et ouvre le popup de
    // sélection des modules.
    BtSideMenu {
        id: btModule
        source: AssetManager.getAssetById("ui", "hud", "1").path
        onBtClicked: moduleManager.openAddPopup()
        Behavior on y {SmoothedAnimation { velocity : 500}}
    }

    ChatDrawer {
        id: chatDrawer
        gameId: "Pattoune" /*root.mapInfo.mapName*/
        z: UiStyle.z_HUD
        onOpenFullScreenMsg: function(modelMsg) {
            chatDrawer.close()
            fullScreenMsgPopup.currentModel = modelMsg
            fullScreenMsgPopup.open()
        }
        onCreateSnapableRequested: function(jsonString) {
            try {
                var parsed = JSON.parse(jsonString)
                if (Array.isArray(parsed)) {
                    for (var i = 0; i < parsed.length; ++i) {
                        var item = ItemSnapableFactory.createItemSnapableFromJson(parsed[i])
                        logic.tileLogic.createItemSnapableTile(item)
                    }
                } else {
                    var item = ItemSnapableFactory.createItemSnapableFromJson(parsed)
                    logic.tileLogic.createItemSnapableTile(item)
                }
            } catch (e) {
                console.error("Erreur /create :", e)
            }
        }

        onClosed: root.forceActiveFocus()
        onFocusReleased: root.forceActiveFocus()

        Component.onCompleted: {
            // En mode collab, le ChatClient de Catway est déjà celui du lobby
            // (pointant sur la session collab). Ne pas l'écraser avec celui
            // de ChatDrawer (qui parle à la session "Pattoune" générale),
            // sinon REQUEST_CONNECTION_INFO partirait dans le mauvais canal.
            if (!EditorSession.active) {
                Catway.setChatClient(chatDrawer.chatClient)
            } else {
                console.log("[Editor] collab actif — Catway.chatClient laissé tel quel (lobby)")
            }
        }
    }

    MenuMapAtStart {
        id: newMapMenu
        z: UiStyle.z_HUD
        visible: false
        logic: logic

        onNewMapSet: {
            console.log("New map created:", newMapInfo.mapName)
            // Level 2 — on sérialise directement newMapInfo (saisi dans
            // le menu) + 0 tuiles. Plus besoin de `createMapFile` (saveMap
            // crée le fichier atomiquement) ni de `mapInfo.setMapInfo` (la
            // helper n'existe plus : Base_Board.mapInfo est un binding sur
            // Map.currentMap.mapInfo, qui sera mis à jour par le loadMap).
            // Level 4 — plus besoin de logic.removeCurrentMap() :
            // Game.loadMap en fin de flow émet clearCurrentMap qui wipe.
            Game.saveMap(newMapInfo, [], MapTypes.CUSTOM)
            Game.loadMap(newMapInfo.mapName, MapTypes.CUSTOM)
        }
    }

    // Connexion du signal pour ouvrir le menu de création de carte
    onOpenNewMapMenu: {
        newMapMenu.visible = true
        newMapMenu.enabled = true
    }

    MapInfoPanel {
        id: mapInfoPanel
        anchors.fill: parent
        logic: logic
        moduleManager: moduleManager
        sidePanel: sidePanel

        z: UiStyle.z_HUD
    }

    // Level 2 — la Connections mapInfoChanged qui recopiait Map.mapInfo
    // dans l'inline Base_Board.mapInfo a été supprimée : Base_Board.mapInfo
    // est maintenant un binding direct sur MapFileManager.currentMap.mapInfo,
    // donc la synchro est automatique.

    // Connexion pour écouter la demande de création de carte depuis le drawer
    Connections {
        target: mapInfoPanel.mapInfoDrawer
        function onRequestNewMap() {
            root.openNewMapMenu()
        }
    }

    AdminCommandPanel {
        id: adminCommandPanel
        visible: false
        enabled: visible

        height: Screen.pixelDensity * 100
        z: UiStyle.z_CONFIG_PANEL
    }

    Settings {
        id: stEnableAutoSave
        category: "Editor/SaveConfig"
        // Renommé depuis "currentMap" pour lever la confusion avec
        // MapFileManager.currentMap (pointeur Map* live, sans rapport).
        // Cette string persiste uniquement le nom du dernier .json custom
        // ouvert, pour le recharger au prochain démarrage.
        property var lastOpenedMap: value("lastOpenedMap", mapInfo.autosaveMapName)
        property int saveEvent: value("saveEvent", "1")
        Component.onCompleted: {
            // Migration one-shot : si l'ancienne clé "currentMap" existe et
            // "lastOpenedMap" pas encore, on copie. L'ancienne clé reste
            // présente (QML Settings n'expose pas de remove) mais devient
            // inerte. À purger plus tard si besoin.
            const legacy = value("currentMap", "")
            if (legacy !== "" && value("lastOpenedMap", "") === "") {
                setValue("lastOpenedMap", legacy)
                lastOpenedMap = legacy
            }
            sync()
        }
    }

    BusyIndicator {
        id: savingIndicator
        z: UiStyle.z_HUD
        anchors.right: parent.right
        anchors.top: parent.top
        width: Screen.pixelDensity * 10
        height: width
        running: false
    }

    Connections {
        target: Game
        function onForceUnselectAll() {
            logic.mouseLogic.unselectSelectedElements()
        }
    }

    Connections {
        target: ItemSnapableFactory
        function onCreateItemRequested(jsonData) {
            var item = ItemSnapableFactory.createItemSnapableFromJson(jsonData)
            logic.tileLogic.createItemSnapableTile(item)
        }
        function onCreateItemsRequested(jsonArray) {
            for (var i = 0; i < jsonArray.length; ++i) {
                var item = ItemSnapableFactory.createItemSnapableFromJson(jsonArray[i])
                logic.tileLogic.createItemSnapableTile(item)
            }
        }
    }

    // applier distant. EditorOpBus positionne `isApplyingRemote=true`
    // pendant l'émission — les mutations déclenchées ci-dessous passeront par
    // submitOp mais seront droppées (pas de re-broadcast, pas de boucle).
    Connections {
        target: EditorOpBus
        function onRemoteOpReceived(op) {

            function findByUuid(uuid) {
                return snapableTilesList.find(function(t) {
                    return t && t.snapableParameters
                        && String(t.snapableParameters.uniqueId) === uuid
                })
            }

            switch (op.op) {
            case EditorOpType.CreateItem: {
                const newItem = ItemSnapableFactory.createItemSnapableFromJson(op.item)
                logic.tileLogic.createItemSnapableTile(newItem)
                break
            }

            case EditorOpType.DeleteItem: {
                const victim = findByUuid(op.target)
                if (victim) logic.tileLogic.deleteElement(victim)
                break
            }

            case EditorOpType.MoveItem: {
                const mover = findByUuid(op.target)
                if (mover && mover.snapableParameters) {
                    mover.snapableParameters.displayParameter.gridRelativePositionX = op.gridX
                    mover.snapableParameters.displayParameter.gridRelativePositionY = op.gridY
                    if (mover.snapToGridFromGridPos) mover.snapToGridFromGridPos()
                }
                break
            }

            case EditorOpType.ResizeItem: {
                const rsz = findByUuid(op.target)
                if (rsz && rsz.snapableParameters) {
                    rsz.snapableParameters.displayParameter.unitSizeWidth  = op.w
                    rsz.snapableParameters.displayParameter.unitSizeHeight = op.h
                }
                break
            }

            case EditorOpType.SetDisplayParameter: {
                const dt = findByUuid(op.target)
                if (dt && dt.snapableParameters && op.fields) {
                    const dp = dt.snapableParameters.displayParameter
                    for (const key in op.fields) {
                        dp[key] = op.fields[key]
                    }
                }
                break
            }

            case EditorOpType.SetZoneParameter: {
                const zt = findByUuid(op.target)
                if (zt && zt.applyPhysicSettings && op.fields) {
                    zt.applyPhysicSettings(op.fields)
                }
                break
            }

            case EditorOpType.SetCaseData: {
                const ct = findByUuid(op.target)
                if (ct && ct.snapableParameters && ct.snapableParameters.caseData && op.fields) {
                    const cd = ct.snapableParameters.caseData
                    for (const k in op.fields) {
                        // Changement de type = remplacement du sous-objet ;
                        // on délègue à la méthode dédiée pour préserver les invariants.
                        if (k === "type" && ct.snapableParameters.changeCaseDataType) {
                            if (op.fields[k] !== cd.type) {
                                ct.snapableParameters.changeCaseDataType(op.fields[k])
                            }
                        } else {
                            cd[k] = op.fields[k]
                        }
                    }
                }
                break
            }

            case EditorOpType.LinkItems: {
                const linkSrc = findByUuid(op.source)
                const linkDst = findByUuid(op.target)
                if (linkSrc && linkDst && linkSrc.connectionManager) {
                    if (op.kind === "next") {
                        linkSrc.connectionManager.addNextElement(linkDst)
                    } else if (op.kind === "previous") {
                        linkSrc.connectionManager.addPreviousElement(linkDst)
                    }
                }
                break
            }

            case EditorOpType.UnlinkItems: {
                const unSrc = findByUuid(op.source)
                const unDst = findByUuid(op.target)
                if (unSrc && unDst && unSrc.connectionManager) {
                    if (op.kind === "next") {
                        unSrc.connectionManager.removeNextElement(unDst)
                    } else if (op.kind === "previous") {
                        unSrc.connectionManager.removePreviousElement(unDst)
                    }
                }
                break
            }

            case EditorOpType.AddPlayerProfile: {
                if (mapInfo && op.profile)
                    mapInfo.addPlayerProfileFromJson(JSON.stringify(op.profile))
                break
            }

            case EditorOpType.RemovePlayerProfile: {
                if (mapInfo && op.id) mapInfo.removePlayerProfile(op.id)
                break
            }

            case EditorOpType.UpdatePlayerProfile: {
                if (mapInfo && op.id) {
                    mapInfo.updatePlayerProfile(op.id,
                        JSON.stringify(op.fields || ({})))
                }
                break
            }

            case EditorOpType.ReorderPlayerProfile: {
                if (mapInfo && op.id !== undefined && op.newIndex !== undefined)
                    mapInfo.reorderPlayerProfile(op.id, op.newIndex)
                break
            }

            case EditorOpType.SetMapPlayerLimits: {
                if (mapInfo) {
                    if (op.minPlayers !== undefined) mapInfo.minPlayers = op.minPlayers
                    if (op.maxPlayers !== undefined) mapInfo.maxPlayers = op.maxPlayers
                }
                break
            }

            case EditorOpType.ApplyState: {
                // Pattern B : delta Map applyBefore/after sur le peer.
                // Supporte à la fois un op unique et un batch (transactions).
                // `before`/`after` sont optionnels dans le payload : seul le
                // côté correspondant à applyBefore est envoyé (économie de BP).
                function _apply(sub) {
                    const before = sub.before || ({})
                    const after  = sub.after  || ({})
                    Game.applyRemoteDelta(sub.type, sub.tileId, sub.groupId,
                                          before, after, !!sub.applyBefore)
                    // Rebind x/y des tiles sélectionnées (qui auraient un binding
                    // cassé par un drag local).
                    _rebindTileIfSelected(sub.tileId)
                }

                if (op.batch === true) {
                    const ops = op.ops || []
                    for (let i = 0; i < ops.length; i++) _apply(ops[i])
                } else {
                    _apply(op)
                }
                break
            }

            default:
                console.log("[Editor] remote op inconnue:", JSON.stringify(op))
                break
            }
        }
    }

    // Après qu'un delta remote ait été appliqué au Map, on force un rebind x/y
    // sur la tile QML correspondante. Raison : le binding de base
    // `x: gridRelativePositionX * gridSize` peut avoir été cassé (sélection
    // locale → MouseLogic_Base.createBindingsForElement remplace par
    // `groupeSelection.x + offset`, resize direct targetElement.x = ...).
    // Si la tile est sélectionnée localement, on la désélectionne aussi.
    function _rebindTileIfSelected(tileId) {
        if (!tileId) return
        const tiles = snapableTilesList
        for (let i = 0; i < tiles.length; i++) {
            const el = tiles[i]
            if (!el || !el.snapableParameters) continue
            if (String(el.snapableParameters.uniqueId) !== tileId) continue
            const elRef = el
            // Désélectionner d'abord si sélectionné (sinon le rebind sera
            // ré-écrasé par MouseLogic au prochain event).
            if (logic && logic.mouseLogic && logic.mouseLogic.selectedElements) {
                const sel = logic.mouseLogic.selectedElements
                if (sel.indexOf(elRef) !== -1) {
                    logic.mouseLogic.selectedElements =
                        sel.filter(function(x) { return x !== elRef })
                    if (elRef.elementReleased) elRef.elementReleased()
                }
            }
            elRef.x = Qt.binding(function() {
                return elRef.snapableParameters.displayParameter.gridRelativePositionX
                     * elRef.gridManager.gridSize
            })
            elRef.y = Qt.binding(function() {
                return elRef.snapableParameters.displayParameter.gridRelativePositionY
                     * elRef.gridManager.gridSize
            })
            console.log("[Editor] remote delta → rebind x/y for",
                        tileId, "→",
                        elRef.snapableParameters.displayParameter.gridRelativePositionX,
                        elRef.snapableParameters.displayParameter.gridRelativePositionY)
            return
        }
    }

    // ─── full-sync à la connexion ─────────────────────────────────
    //
    // Protocole :
    //   1. Client devient actif → envoie Hello à l'hôte.
    //   2. Hôte reçoit Hello → snapshot atomique de la liste des tuiles, split
    //      en chunks (~20 KB chacun, sous le plafond reliable 32 KB), chaque
    //      chunk envoyé en point-à-point au seul senderId.
    //   3. Client accumule les chunks dans un buffer indexé ; quand tous sont
    //      là, wipe l'état local et reconstruit depuis le snapshot (tout ça
    //      dans un beginApplyRemote/endApplyRemote pour bloquer la remontée).
    //
    // Pas de serverSeq en v1 : reliable.io garantit l'ordre par endpoint, donc
    // les ops qui arrivent après les chunks s'appliquent sur l'état reconstruit.
    QtObject {
        id: fullSyncBuffer
        property var chunks: ({})   // index → string
        property int expected: -1
    }

    function _fullSyncChunkSize() { return 20000 }

    // Positionné à true pendant initializeEditor pour éviter de broadcaster
    // FullSync sur les Game.loadMap d'initialisation (pas de pair connecté
    // de toute façon, mais évite le bruit + la sérialisation gratuite).
    property bool _suppressFullSyncBroadcast: false

    // Raccourci : broadcast FullSync à tous les peers (reliable).
    // Utilisé quand l'hôte change de carte en cours de session (Phase 3.4).
    function _sendFullSyncToAll() {
        if (!EditorSession.active || !EditorSession.isHost) return
        if (_suppressFullSyncBroadcast) return
        _sendFullSync("")
    }

    // targetId vide → broadcastEvent ; sinon sendEventTo.
    function _sendFullSync(targetId) {
        // Sérialise la liste des tuiles courante + mapInfo de l'hôte. Le
        // mapInfo est nécessaire côté client pour :
        //   - aligner le nom de carte affiché sur celui que l'hôte édite
        //   - router les sauvegardes locales vers le bon fichier
        //     `<mapInfo.mapName>_map.json`
        // (sans ça, le client saverait sur son propre autosave jusqu'à la
        // prochaine action explicite).
        console.log("[FullSync] host scan snapableTilesList.length =",
                    snapableTilesList.length)
        const tiles = []
        for (let i = 0; i < snapableTilesList.length; i++) {
            const t = snapableTilesList[i]
            if (!t) {
                console.warn("[FullSync] tile", i, "null/undefined — skipping")
                continue
            }
            if (!t.snapableParameters) {
                console.warn("[FullSync] tile", i, "has no snapableParameters — skipping")
                continue
            }
            try {
                const raw = t.snapableParameters.toJSON()
                if (i === 0) console.log("[FullSync] sample tile[0] JSON:", raw)
                tiles.push(JSON.parse(raw))
            } catch (e) {
                console.warn("[FullSync] tile", i, "JSON error:", e,
                             "raw=", t.snapableParameters.toJSON())
            }
        }
        // Sérialise le mapInfo courant (nom, description, background, etc.).
        // 3D/caméra à ajouter plus tard — cf. gap noté dans CLAUDE.md.
        let mapInfoObj = null
        try {
            mapInfoObj = JSON.parse(mapInfo.toJSON())
        } catch (e) {
            console.warn("[FullSync] mapInfo JSON error:", e)
        }
        const payload = JSON.stringify({
            snapableTiles: tiles,
            mapInfo:       mapInfoObj
        })
        const CHUNK = _fullSyncChunkSize()
        const count = Math.max(1, Math.ceil(payload.length / CHUNK))
        const dest  = targetId ? targetId : "(broadcast)"
        console.log("[FullSync] host → " + dest
                    + " : " + tiles.length + " tuiles sérialisées, "
                    + "mapInfo.name=" + (mapInfoObj ? mapInfoObj.name : "null") + ", "
                    + payload.length + " octets, " + count + " chunks")
        for (let c = 0; c < count; c++) {
            const chunk = {
                "chunkIndex": c,
                "chunkCount": count,
                "payload":    payload.substr(c * CHUNK, CHUNK)
            }
            if (targetId)
                EditorSession.sendEventTo(targetId, EditorMessageType.FullSync, chunk)
            else
                EditorSession.broadcastEvent(EditorMessageType.FullSync, chunk)
        }
    }

    // Wrapper rétro-compatible — conserve l'ancien nom utilisé par le handler
    // Hello (réponse ciblée au joiner uniquement).
    function _sendFullSyncTo(senderId) { _sendFullSync(senderId) }

    function _receiveFullSyncChunk(payload) {
        const idx   = payload.chunkIndex
        const count = payload.chunkCount
        if (fullSyncBuffer.expected !== count) {
            // Nouveau stream ou premier chunk — reset.
            fullSyncBuffer.chunks = ({})
            fullSyncBuffer.expected = count
        }
        fullSyncBuffer.chunks[idx] = payload.payload
        // Tous reçus ?
        let got = 0
        for (const k in fullSyncBuffer.chunks) got++
        if (got < count) return

        // Réassemble dans l'ordre.
        let joined = ""
        for (let i = 0; i < count; i++) {
            joined += fullSyncBuffer.chunks[i] || ""
        }
        fullSyncBuffer.chunks = ({})
        fullSyncBuffer.expected = -1

        let snapshot
        try { snapshot = JSON.parse(joined) }
        catch (e) {
            console.warn("[FullSync] JSON parse failed:", e)
            return
        }

        _applyFullSyncSnapshot(snapshot)
    }

    function _applyFullSyncSnapshot(snapshot) {
        const tiles       = (snapshot && snapshot.snapableTiles) || []
        const newMapInfo  = (snapshot && snapshot.mapInfo)        || null
        // mémoriser AVANT toute mutation de mapInfo pour E12 (purge ancien
        // fichier de session côté client quand l'hôte change de carte).
        const previousMapName = String(mapInfo.mapName || "")
        const newMapName      = newMapInfo ? String(newMapInfo.name || "") : ""

        console.log("[FullSync] applying snapshot —", tiles.length,
                    "tuiles reçues, mapInfo.name=", newMapName,
                    "previousMapName=", previousMapName)
        if (tiles.length > 0) {
            console.log("[FullSync] sample incoming tile[0]:",
                        JSON.stringify(tiles[0]).substring(0, 300))
        }

        EditorOpBus.beginApplyRemote()
        try {
            // 1) Applique le mapInfo reçu AVANT de reconstruire les tuiles.
            //    Raison : si une sauvegarde locale se déclenchait entre-temps
            //    (p.ex. save-on-modification sur l'insertion de tuile), elle
            //    écrirait avec le bon nom. Passe par
            //    Game.applyRemoteDelta(MetadataChanged) → Map.setMapInfo →
            //    signal mapInfoChanged → Connections dans Editor.qml qui
            //    recopient dans le mapInfo QML (Base_Board inline).
            if (newMapInfo) {
                Game.applyRemoteDelta(EditDelta.MetadataChanged, "", "",
                                      {}, newMapInfo, false)
            }

            // 2) Phase 3.5 — purge disque côté client.
            //    E7  : fichier local portant le nouveau mapName (collision
            //          résiduelle d'une session antérieure ou d'une carte
            //          mono éponyme) → supprimer avant que les saves ne
            //          l'écrasent silencieusement.
            //    E12 : ancien fichier de session (previousMapName différent
            //          et non-autosave) → supprimer, il est obsolète.
            //    La différenciation mono/collab (à venir) évitera de toucher
            //    aux vraies cartes mono. Pour l'instant, comportement brut
            //    comme validé.
            if (newMapName &&
                MapFileManager.mapExists(newMapName, MapTypes.CUSTOM)) {
                console.log("[FullSync] E7 purge collision locale:", newMapName)
                Game.deleteMap(newMapName, MapTypes.CUSTOM)
            }
            if (previousMapName && previousMapName !== newMapName &&
                previousMapName !== mapInfo.autosaveMapName &&
                MapFileManager.mapExists(previousMapName, MapTypes.CUSTOM)) {
                console.log("[FullSync] E12 purge ancien fichier session:",
                            previousMapName)
                Game.deleteMap(previousMapName, MapTypes.CUSTOM)
            }

            // 3) Wipe local (QML) — les tiles reconstruites ci-dessous sont
            //    de toute façon de nouvelles instances.
            const toDelete = snapableTilesList.slice()
            console.log("[FullSync] wiping", toDelete.length, "tuiles locales")
            for (let i = 0; i < toDelete.length; i++) {
                if (toDelete[i]) logic.tileLogic.deleteElement(toDelete[i])
            }
            // 4) Reconstruit via Game.applyRemoteDelta(TileAdded) — ajoute au
            //    m_tiles C++ ET émet `tileRestoredFromHistory` qui est
            //    consommé par `onFoundItemSnapableTile` pour créer le QML.
            //    Un seul code path, m_tiles cohérent avec les tiles QML,
            //    donc les ops TileModified entrantes pourront être appliquées.
            let rebuilt = 0
            for (let j = 0; j < tiles.length; j++) {
                const t = tiles[j]
                const uuid = t && t.uniqueId ? String(t.uniqueId) : ""
                if (!uuid) {
                    console.warn("[FullSync] tile sans uniqueId — skip", j)
                    continue
                }
                Game.applyRemoteDelta(EditDelta.TileAdded, uuid, "", {}, t, false)
                rebuilt++
            }
            console.log("[FullSync] rebuilt", rebuilt, "/", tiles.length, "tuiles")
            // 5) Rétablit les connexions (next/prev) depuis les JSON.
            logic.tileLogic.builtConnections()
        } finally {
            EditorOpBus.endApplyRemote()
        }
    }

    Connections {
        target: EditorSession

        // Client qui vient de devenir actif → salue l'hôte pour réclamer un
        // FullSync. Hôte n'envoie pas Hello.
        function onActiveChanged() {
            if (EditorSession.active && !EditorSession.isHost) {
                console.log("[FullSync] client → envoi Hello (activeChanged)")
                EditorSession.sendEvent(EditorMessageType.Hello, {
                    "nickname": AccountManager.nickname || "",
                    "assetPackHash": ""   // TODO: calculer
                })
            }
        }

        function onEditorEventReceived(type, senderId, payload) {
            const hex = "0x" + type.toString(16)
            switch (type) {
            case EditorMessageType.Hello:
                console.log("[FullSync] host ← Hello from", senderId)
                if (EditorSession.isHost) {
                    _sendFullSyncTo(senderId)
                }
                break
            case EditorMessageType.FullSync:
                console.log("[FullSync] client ← chunk", payload.chunkIndex,
                            "/", payload.chunkCount)
                if (!EditorSession.isHost) {
                    _receiveFullSyncChunk(payload)
                }
                break
            default:
                console.log("[EditorSession] event non implémenté:", hex)
                break
            }
        }

        // curseur distant reçu (UDP brut, ~20 Hz).
        function onCursorReceived(senderId, x, y) {
            root._upsertRemoteCursor(senderId, x, y)
        }

        // hôte perdu. L'élection détermine le nouvel hôte de façon
        // déterministe (plus petit playerId du roster cache, ancien hôte exclu).
        // - Si `electedHostId === localPlayerId` : promotion auto, l'état local
        //   est préservé et le pair devient hôte (les autres doivent rejoindre
        //   via le lobby pour reprendre la collab).
        // - Sinon : fallback monoposte. L'état est conservé mais la session
        //   collab est terminée jusqu'à une nouvelle entrée par le lobby.
        function onHostLost(electedHostId) {
            console.warn("[EditorSession] hôte perdu — élu :", electedHostId,
                         "(moi =", EditorSession.localPlayerId + ")")
            if (electedHostId && electedHostId === EditorSession.localPlayerId) {
                // `promoteToHost` fait stop+startAsHost en interne, préserve l'état.
                // main.qml reçoit `promotedToHost` et renomme la session chat
                // (MÊME sessionId) — aucun re-join nécessaire pour les autres.
                console.log("[EditorSession] Je suis le nouvel hôte — promotion.")
                // Phase 3.6 : save forcé de l'état courant AVANT promotion,
                // hors politique. Garantit qu'un crash pendant la fenêtre
                // stop→startAsHost ne laisse pas le nouvel hôte avec un
                // fichier local obsolète (le dernier état reçu de l'ancien
                // hôte peut ne pas être encore sur disque si le peer tournait
                // en politique Manuel/Intervalle).
                const savedOk = Game.saveCurrentMap()
                console.log("[EditorSession] save forcé avant promotion → ok=", savedOk)
                EditorSession.promoteToHost()
            } else if (electedHostId) {
                // le nouvel hôte a conservé la MÊME session de chat
                // (rename côté serveur, pas de createSession). Donc on peut
                // relancer P2P directement sur la session actuelle — pas de
                // polling, pas d'attente de découverte.
                const sid = Catway.chatClient ? Catway.chatClient.sessionId : ""
                if (!sid) {
                    console.warn("[Reconnect] pas de session chat active — stop")
                    EditorSession.stop()
                    return
                }
                console.log("[Reconnect] auto →", electedHostId, "via session", sid)
                EditorSession.stop()
                // Wipe les tuiles QML locales ET réinitialise la Map C++ pour
                // que le FullSync reçu du nouvel hôte reconstruise proprement
                // (sinon applyRemoteDelta(TileAdded) no-ope sur les uuids déjà
                // présents dans Game.m_tiles → carte vide visuellement).
                EditorOpBus.beginApplyRemote()
                try {
                    const toDelete = snapableTilesList.slice()
                    for (let i = 0; i < toDelete.length; i++) {
                        if (toDelete[i]) logic.tileLogic.deleteElement(toDelete[i])
                    }
                } finally {
                    EditorOpBus.endApplyRemote()
                }
                Game.initEmptyCollabMap()
                root.reconnectRequested(sid, electedHostId)
            } else {
                console.log("[EditorSession] Aucun candidat — monoposte.")
                EditorSession.stop()
            }
        }

        // un pair a quitté → purge curseur/sélection locale.
        function onPeerLeft(playerId) {
            console.log("[EditorSession] pair parti:", playerId)
            const copy = {}
            for (const k in root.remoteCursors)
                if (k !== playerId) copy[k] = root.remoteCursors[k]
            root.remoteCursors = copy
            root._remoteCursorKeys = Object.keys(copy)
        }

        // op rejetée (rate-limit ou autre) → log côté auteur.
        function onOpRejected(reject) {
            console.warn("[EditorSession] op rejetée:", JSON.stringify(reject))
        }
    }

    // ─── présence curseurs ───────────────────────────────────────
    //
    // Envoi : timer 20 Hz qui pousse la position `mainMa` (mappée en workArea
    // coords) via EditorSession.sendCursor. La position côté pair s'affiche
    // dans ses propres workArea coords — scroll/zoom indépendants.
    //
    // Réception : upsert dans une map playerId → {x, y, lastSeen} + signal
    // cursorsChanged pour forcer le Repeater à se mettre à jour. Prune auto
    // toutes les 500 ms des entrées sans nouvelles depuis 2 s.

    property var remoteCursors: ({})
    property var _remoteCursorKeys: []

    // Position courante du pointeur dans le référentiel workArea, alimentée
    // par le HoverHandler ci-dessous (qui capte aussi le hover sans clic).
    property real _hoverX: -99999
    property real _hoverY: -99999

    signal _cursorsChanged()

    function _colorForPlayer(pid) {
        let h = 0
        for (let i = 0; i < pid.length; i++)
            h = (h * 131 + pid.charCodeAt(i)) & 0xFFFF
        return Qt.hsla((h % 360) / 360.0, 0.7, 0.55, 1.0)
    }

    function _applyToSelectionAndSave(opKind, applyFn) {
        const sel = logic.mouseLogic.selectedElements
        for (let i = 0; i < sel.length; ++i) applyFn(sel[i])
        saveMapDelayer.pendingOpKind = opKind
        saveMapDelayer.restart()
    }

    function _upsertRemoteCursor(pid, x, y) {
        // Important : réassigner un nouvel objet (pas de mutation en place)
        // pour que le binding `_entry` du delegate Repeater se ré-évalue.
        // QML ne détecte pas les mutations de champs sur un var existant.
        const copy = {}
        for (const k in remoteCursors) copy[k] = remoteCursors[k]
        copy[pid] = { "x": x, "y": y, "lastSeen": Date.now() }
        remoteCursors = copy
        _remoteCursorKeys = Object.keys(copy)
    }

    Timer {
        id: cursorSendTimer
        interval: 50        // 20 Hz
        repeat: true
        running: EditorSession.active
        property real lastX: -99999
        property real lastY: -99999
        onTriggered: {
            // Utilise _hoverX/_hoverY (alimenté par le HoverHandler de workArea)
            // plutôt que mainMa.mouseX/mouseY — ces derniers sont masqués par
            // les MouseAreas enfants (tuiles, grille) qui consomment le hover.
            //
            // conversion en unités de grille avant envoi. Le
            // repère commun entre pairs est la position en cases (fractionnelle),
            // invariante par zoom (gridSize local) et résolution d'écran. Les
            // coords workArea en pixels dépendent de `mmSize` qui peut différer
            // entre pairs. Division par gameGrid.gridSize → la case `N` est à
            // la valeur `N` quel que soit le zoom local.
            const gs = gameGrid ? gameGrid.gridSize : 0
            if (!gs) return
            const x = root._hoverX
            const y = root._hoverY
            if (x === -99999) return                 // pas encore de position
            if (x === lastX && y === lastY) return   // pas bougé
            lastX = x
            lastY = y
            EditorSession.sendCursor(x / gs, y / gs)
        }
    }

    // pendant un drag-select, le HoverHandler de workArea
    // cesse d'émettre (pointeur grabbed par mainMa). On complète la source de
    // position avec mainMa.onPositionChanged — qui fire aussi pendant le press —
    // en mappant les coords root→workArea. Les deux sources coexistent sans
    // conflit (dernière vue écrase).
    Connections {
        target: mainMa
        enabled: EditorSession.active
        function onPositionChanged(mouse) {
            const p = mainMa.mapToItem(workArea, mouse.x, mouse.y)
            root._hoverX = p.x
            root._hoverY = p.y
        }
    }

    Timer {
        id: cursorPruneTimer
        interval: 500
        repeat: true
        running: EditorSession.active
        onTriggered: {
            const now = Date.now()
            let changed = false
            const kept = {}
            for (const pid in remoteCursors) {
                if (now - remoteCursors[pid].lastSeen < 2000) {
                    kept[pid] = remoteCursors[pid]
                } else {
                    changed = true
                }
            }
            if (changed) {
                remoteCursors = kept
                _remoteCursorKeys = Object.keys(kept)
            }
        }
    }

    // ─── broadcast de la sélection locale ────────────────────────
    //
    // Connectée sur selectedElementsChanged de mouseLogic : debounce 100 ms,
    // puis envoie SelectionUpdate{uuids} en reliable. L'hôte rebroadcast
    // aux autres clients via EditorSession::onReliableReceived.

    Timer {
        id: selectionBroadcastDebounce
        interval: 100
        repeat: false
        onTriggered: {
            if (!EditorSession.active) return
            const els = logic.mouseLogic ? logic.mouseLogic.selectedElements : []
            const uuids = []
            for (let i = 0; i < els.length; i++) {
                if (els[i] && els[i].snapableParameters) {
                    uuids.push(String(els[i].snapableParameters.uniqueId))
                }
            }
            EditorSession.sendEvent(EditorMessageType.SelectionUpdate, { "uuids": uuids })
        }
    }

    Connections {
        target: logic.mouseLogic
        ignoreUnknownSignals: true
        function onSelectedElementsChanged() {
            if (EditorSession.active) selectionBroadcastDebounce.restart()
        }
    }

    Connections {
        target: Game

        function onFoundItemSnapableTile(itemSnapableData) {
            // load disque ne doit JAMAIS émettre d'op réseau.
            // Filet de sécurité : wrap begin/endApplyRemote → submitOp drop.
            EditorOpBus.beginApplyRemote()
            try {
                logic.tileLogic.createItemSnapableTile(itemSnapableData)
            } finally {
                EditorOpBus.endApplyRemote()
            }
        }

        function onMapLoaded(map) {
            Logger.success("Map loaded", "MAP_LOADING")
            logic.tileLogic.builtConnections()

            // Level 2 — plus besoin de recopier map.mapInfo dans
            // Base_Board.mapInfo : le binding sur MapFileManager.currentMap
            // .mapInfo s'en occupe dès que setCurrentMap propage le signal.
            //
            // Petite subtilité : ce handler fire AVANT setCurrentMap
            // (cf. Game::loadMap), donc `mapInfo` pointe encore sur
            // l'ancienne Map (ou _fallback). On lit `map.mapInfo.mapName`
            // directement via le paramètre pour persister lastOpenedMap.
            if (map && map.mapInfo &&
                    map.mapInfo.mapName !== stEnableAutoSave.lastOpenedMap)
                stEnableAutoSave.setValue("lastOpenedMap", map.mapInfo.mapName)

            // Phase 3.4 : si l'hôte change de carte en cours de session,
            // broadcaster la nouvelle carte à tous les peers. Le flag
            // _suppressFullSyncBroadcast est à true pendant initializeEditor
            // pour ne pas tirer sur les Game.loadMap d'initialisation (au
            // moment desquels personne n'est connecté de toute façon).
            if (EditorSession.active && EditorSession.isHost &&
                    !root._suppressFullSyncBroadcast) {
                console.log("[FullSync] host a changé de carte en session — broadcast")
                _sendFullSyncToAll()
            }
        }

        function onTileRemoved(tileId) {
            for (var i = 0; i < logic.snapableTilesList.length; i++) {
                if (logic.snapableTilesList[i].snapableParameters.uniqueId === tileId) {
                    logic.tileLogic.deleteElement(logic.snapableTilesList[i])
                    break
                }
            }
        }

        function onClearCurrentMap() {
            logic.removeCurrentMap()
        }

        function onAfterRestoration(tileIds) {
            // Resync des connexions visuelles après undo/redo
            logic.tileLogic.rebuildConnectionsFor(tileIds)
        }
    }

    wheelHandler: Editor_WheelHandler {
        logic: root.logic
    }

    logic: EditorLogic {
        id: logic
        parent: root
        workArea: workArea
        editorGrid: gameGrid
        selectionRect: selectionRect
        mapInfo: root.mapInfo
        editorSidePanel: sidePanel
        // D3d-2/D3e — état de pose désormais détenu et écrit par logic
        // (via DecoPanel/CasePanel → logic.updateSelectedAsset/setCaseType).
        // Plus de binding depuis selectionPanel (deco/case bespoke).
    }

    mainMa.anchors.bottomMargin: mapInfoPanel.x > height ? 0 : _bottomPanelHeight

    // Stack vertical des badges, ancré top-left.
    // CollabStatusPanel (visible uniquement si EditorSession.active) en
    // tête ; il a un comportement spécial : Column saute les enfants
    // `visible: false`, donc en mono les test panels remontent naturellement
    // à la place du badge collab. Les panels expanded des badges s'ancrent à
    // `parent.top/right` du badge → ils dépassent à droite du badge dans son
    // slot Column (comportement OK).
    Column {
        id: leftBadgeStack
        z: 10000
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Theme.spacingXL
        anchors.leftMargin: Theme.spacingXL
        spacing: Theme.spacingS

        CollabStatusPanel {}
        PhysicsStatusPanel {}
    }

    // Barre horizontale du gestionnaire de modules, en haut de l'éditeur :
    // entre les badges d'informations (leftBadgeStack, à gauche) et les
    // boutons HUD BtSideMenu (btSelection, à droite). Le "+" et les vignettes
    // de module ont la même dimension que les BtSideMenu.
    ModuleManager {
        id: moduleManager
        z: UiStyle.z_HUD
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingL
        anchors.left: leftBadgeStack.right
        anchors.leftMargin: Theme.spacingL
        anchors.right: btSelection.left
        anchors.rightMargin: Theme.spacingL
        height: btSelection.height
        itemSize: btSelection.height

        onModuleAdded: function (moduleId) {
            console.log("[ModuleManager] module ajouté :", moduleId)
        }

        // Chaque panneau de module (deco/case/zone/template/player + config) se
        // montre/masque via son propre binding `visible: moduleManager
        // .selectedModuleId === ...`. Ici, uniquement les effets de bord des
        // modules sans panneau ancré.
        onModuleSelected: function (moduleId) {
            // Les panneaux de module s'affichent via leur binding `visible`.
            // Seul `chat` a un effet de bord (ouvrir le drawer).
            if (moduleId === "chat") {
                chatDrawer.open()
            }
        }
    }

    // Phase 3 — sync live des zones physiques. Reçoit les events de
    // ItemSnapableEvents (singleton C++) et pousse upsertZone/removeZone
    // vers le `physicsWorld` global. Reste inerte tant que le moteur n'est
    // pas démarré (badge PhysicsStatusPanel).
    EditorPhysicsBridge {
        id: editorPhysicsBridge
        physicsWorld: pattounxWorld
    }

    // Layer GPU qui dessine TOUTES les zones d'exclusion en un seul item
    // viewport-cullé. Remplace les ZoneCanvasPainter individuels (1 par
    // tile) qui freezaient au zoom extrême — leur backing texture suivait
    // la taille de la zone × gridSize → centaines de MB par tile à
    // mmSize=200+. Le canvas couvre seulement le Base_Board visible et
    // skipe les zones hors-viewport. Activé par défaut quand
    // _useZonesOverlay (cf. qmlapp.cpp), bypass via env MEOW_ZONES_RENDERER=per-tile.
    readonly property bool _useZonesOverlayActive:
        (typeof _useZonesOverlay !== "undefined") && _useZonesOverlay

    ZonesOverlayPainter {
        id: zonesOverlay
        anchors.fill: parent
        z: UiStyle.z_BACKGROUND + 1 // au-dessus du background, sous workArea
        visible: root._useZonesOverlayActive
        enabled: false // pas d'interception clic
        gridSize: gameGrid.gridSize
        viewportOffsetX: gameGrid.x
        viewportOffsetY: gameGrid.y
        // Itère snapableTilesList et lit chaque tile.zoneParameter.* :
        // QML enregistre une dépendance par accès → réévaluation au moindre
        // change (drag, polygon edit, color change, selection).
        //
        // IMPORTANT : on lit `t.x` / `t.y` (PIXELS courants du
        // SnapableElement) plutôt que `dp.gridRelativePositionX/Y`. Pendant
        // un drag, x/y suivent la souris en continu alors que la position
        // grille n'est mise à jour qu'au snap (release). Sans ça l'overlay
        // restait figé à l'ancienne position grille pendant tout le drag.
        zones: {
            const list = []
            const tiles = root.snapableTilesList
            if (!tiles) return list
            const gs = gameGrid.gridSize
            const invGs = gs > 0 ? 1.0 / gs : 0
            for (let i = 0; i < tiles.length; i++) {
                const t = tiles[i]
                if (!t || !t.snapableParameters) continue
                if (t.snapableParameters.tileType !== ItemSnapable.PhysicZoneTile) continue
                const zp = t.snapableParameters.zoneParameter
                if (!zp) continue
                const pts = zp.polygonPoints
                if (!pts || pts.length < 3) continue
                list.push({
                    posGridX: t.x * invGs,
                    posGridY: t.y * invGs,
                    points: pts,
                    color: zp.zoneColor,
                    strokeColor: Qt.darker(zp.zoneColor, 1.3),
                    strokeWidth: t.isSelected ? 3 : 2,
                    opacity: t.isSelected ? 1.0 : 0.7,
                    hatchSpacing: 12
                })
            }
            return list
        }
    }


    // Zone de travail de l'éditeur (par-dessus la grille)
    Base_WorkArea {
        id: workArea
        z: UiStyle.z_WORKAREA
        anchors.fill: gameGrid

        // tracking position souris en mode hover (sans clic).
        // HoverHandler coexiste avec les MouseAreas des tuiles/grille et
        // reporte une position même quand un enfant capte les évènements.
        HoverHandler {
            id: cursorHoverHandler
            enabled: EditorSession.active
            onPointChanged: {
                root._hoverX = point.position.x
                root._hoverY = point.position.y
            }
        }

        World3D {
            id: gameScene
            x: -gameGrid.x
            y: -gameGrid.y
            width: root.width
            height: root.height
            z: 5.99 // Z-index relatif à workArea (au milieu des plans 2D)

            // Bind camera magnification to grid scale level
            cameraMagnification: gameGrid.scaleLevel
            gridManager: gameGrid

            // Quand un profil est en test (panel Player Config), le modèle
            // 3D du player principal devient celui du profil. Sinon Princess.
            // `modelName` ne dépend que de `_testedProfile.modelName`. Comme
            // _testedProfile est ré-évalué à chaque update du MapInfo, on
            // récupère toujours l'instance courante (Game.updateMapMetadata
            // recrée les PlayerProfile à chaque commit).
            modelName: workArea._testedProfile
                         ? workArea._testedProfile.modelName
                         : "Princess"
            // Re-skin Color ID Map du profil testé (skin + variante + équipe).
            colorVariant: workArea._testedProfile
                            ? workArea._testedProfile.colorVariant
                            : ""

            // Flou + désaturation de la scène 3D quand un effet de zone à `blur`
            // est actif. Un calque 2D au-dessus ne peut pas flouter une View3D
            // vivante, donc on passe par le layer de la View3D elle-même. Le
            // layer n'est activé que pendant l'effet → coût nul hors zone.
            layer.enabled: screenEffectController.renderEffect
                           && screenEffectController.renderEffect.blur > 0
                           && screenEffectController.amount > 0.001
            layer.smooth: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 48
                blur: screenEffectController.renderEffect
                      ? screenEffectController.renderEffect.blur * screenEffectController.amount
                      : 0
                // saturation MultiEffect : 0 = normal, -1 = niveaux de gris.
                saturation: screenEffectController.renderEffect
                            ? screenEffectController.renderEffect.saturation * screenEffectController.amount
                            : 0
            }
        }

        // --- Effets visuels de zone (givré, toxique, …) ---
        // Le contrôleur écoute les entrées/sorties de zone du moteur physique et
        // résout l'effet via ZoneParameter.screenEffectId → MapInfo.screenEffects.
        ScreenEffectController {
            id: screenEffectController
            physicsWorld: pattounxWorld
            tilesList: root.snapableTilesList
            mapInfo: root.mapInfo
            onlyActorId: "player"   // ne réagit qu'au joueur local de l'éditeur
        }

        // Overlay 2D plein écran (teinte + vignette + pulsation). Géométrie
        // calquée sur gameScene pour rester fixe à l'écran malgré le pan/zoom.
        ScreenEffectOverlay {
            id: screenEffectOverlay
            x: -gameGrid.x
            y: -gameGrid.y
            width: root.width
            height: root.height
            z: 6.0  // juste au-dessus de gameScene (5.99), sous les panneaux UI
            effect: screenEffectController.renderEffect
            amount: screenEffectController.amount
        }

        // Phase 4 — joueur local. Body créé/détruit par le spawner ; le
        // PhysicsActor lit bodyState et positionne `gameScene.entity`.
        // Quand un profil est en test, ses params remplacent les défauts via
        // `_resyncMainPlayer()` (re-upsert manuel — LocalPlayerSpawner ne
        // réagit pas aux changements de `params`/`radius`). Le body est le
        // même ("player"), seule la spec évolue ; upsertBody C++ préserve
        // position et velocity (cf. pattounx_engine_v2.cpp:31-44).
        LocalPlayerSpawner {
            id: localPlayerSpawner
            physicsWorld: pattounxWorld
            actorId: "player"
            radius: 0.2
            params: ({ acceleration: 30.0, maxSpeed: 30.0, linearDamping: 0.1 })
        }

        // Profil actuellement en test, résolu via l'id stable. Re-évalué à
        // chaque update du mapInfo (Game.updateMapMetadata recrée
        // PlayerProfile* à chaque commit). Si pas en test ou map non chargée
        // → null.
        readonly property var _testedProfile: {
            const id = PCP_TestController.profileId
            if (!id) return null
            const m = MapFileManager.currentMap
            if (!m || !m.mapInfo) return null
            return m.mapInfo.playerProfileById(id)
        }

        function _resyncMainPlayer() {
            if (!pattounxWorld || !pattounxWorld.running) return
            const p = workArea._testedProfile
            if (p) {
                pattounxWorld.createKinematicActor("player",
                    Qt.vector2d(0, 0),   // ignoré : upsertBody préserve la pos
                    p.radius,
                    {
                        mass:            p.mass,
                        acceleration:    p.acceleration,
                        maxSpeed:        p.maxSpeed,
                        linearDamping:   p.linearDamping,
                        staticFriction:  p.staticFriction,
                        dynamicFriction: p.dynamicFriction,
                        bounceFactor:    p.bounceFactor
                    })
            } else {
                // Restaurer les défauts du player de test de l'éditeur.
                pattounxWorld.createKinematicActor("player",
                    Qt.vector2d(0, 0),
                    0.2,
                    { acceleration: 30.0, maxSpeed: 30.0, linearDamping: 0.1 })
            }
        }

        // Bascule on/off du test (start/stop) ou recréation du PlayerProfile
        // après update mapInfo → re-upsert avec les params courants. Pas de
        // handler `on_TestedProfileChanged` direct (capitalisation casse-tête
        // avec préfixe `_`) — on passe par Connections sur l'id du singleton.
        Connections {
            target: PCP_TestController
            function onProfileIdChanged() { workArea._resyncMainPlayer() }
        }

        // Live update : la cible Connections suit `_testedProfile`. Quand le
        // profile est recréé (nouvelle instance même id) ou que les sliders
        // mutent ses Q_PROPERTY, on re-upsert. ignoreUnknownSignals couvre le
        // cas target=null entre détachement/rattachement.
        Connections {
            target: workArea._testedProfile
            ignoreUnknownSignals: true
            function onRadiusChanged()          { workArea._resyncMainPlayer() }
            function onMassChanged()            { workArea._resyncMainPlayer() }
            function onAccelerationChanged()    { workArea._resyncMainPlayer() }
            function onMaxSpeedChanged()        { workArea._resyncMainPlayer() }
            function onLinearDampingChanged()   { workArea._resyncMainPlayer() }
            function onStaticFrictionChanged()  { workArea._resyncMainPlayer() }
            function onDynamicFrictionChanged() { workArea._resyncMainPlayer() }
            function onBounceFactorChanged()    { workArea._resyncMainPlayer() }
        }

        PhysicsActor {
            id: playerActor
            world3D: gameScene
            bodyId: "player"
            node3D: gameScene.entity
        }

        // Touches → physicsWorld.pushInput. Le toggle FreeCam (Key_F) bascule
        // le mode du CameraRig (Follow ↔ FreeCam) et synchronise enabled de
        // l'input "personnage" — en FreeCam, l'input pilote la caméra (via
        // CameraRig.moveManual côté FrameAnimation freeCamLoop).
        InputController {
            id: inputController
            actorId: "player"
            physicsWorld: pattounxWorld
            // Phase 6 — keymap restreinte à ZQSD (les flèches sont
            // réservées au 2e joueur quand multiActor est actif).
            keymap: ({
                up:            Qt.Key_Z,
                down:          Qt.Key_S,
                left:          Qt.Key_Q,
                right:         Qt.Key_D,
                sprint:        Qt.Key_Shift,
                freeCamToggle: Qt.Key_F
            })
            // En démarrage, on est en mode FreeCam (cohérent avec ancien
            // EntityEngine.freeCamMode = true par défaut). Donc input
            // personnage désactivé, input caméra actif.
            enabled: cameraRig.mode === CameraRig.Follow
            onToggleFreeCamRequested: {
                // setMode gère les transitions proprement (recompute offset
                // au passage en Follow, pas de saut visuel).
                cameraRig.setMode(cameraRig.mode === CameraRig.Follow
                                  ? CameraRig.FreeCam
                                  : CameraRig.Follow)
                inputController.releaseAll()
                console.log("[Editor] FreeCam",
                            cameraRig.mode === CameraRig.FreeCam ? "ON" : "OFF")
            }
        }

        CameraRig {
            id: cameraRig
            world3D: gameScene
            mode: CameraRig.FreeCam   // démarre en FreeCam (ancien comportement)
            smoothSpeed: 2.0
        }

        // Boucle FreeCam : si on est en FreeCam, l'input ZQSD pilote la caméra
        // au lieu du joueur (pas de pushInput). On reproduit la branche
        // EntityEngine.movementLoop.freeCamMode.
        FrameAnimation {
            running: cameraRig.mode === CameraRig.FreeCam
            onTriggered: {
                if (!cameraRig.world3D || !cameraRig.world3D.camera) return
                // Vecteur d'input reconstruit depuis l'état des touches du
                // controller (les touches restent trackées même quand
                // enabled=false côté pushInput personnage).
                const ix = (inputController._r ? 1 : 0) - (inputController._l ? 1 : 0)
                const iy = (inputController._d ? 1 : 0) - (inputController._u ? 1 : 0)
                if (ix === 0 && iy === 0) return
                let vx = ix, vy = iy
                const lenSq = vx * vx + vy * vy
                if (lenSq > 1) {
                    const len = Math.sqrt(lenSq)
                    vx /= len; vy /= len
                }
                // 30 unités/s × 10 = vitesse FreeCam de l'ancien EntityEngine
                cameraRig.moveManual(vx, vy, 300, frameTime)
            }
        }

        Component.onCompleted: {
            EditorController.init(logic, null, escMenu, fullScreenMsgPopup,
                                  adminCommandPanel)
        }

        // overlay des curseurs distants. Enfant de workArea pour
        // suivre scroll/zoom du grid.
        //
        // les coordonnées reçues sont en UNITÉS DE GRILLE
        // (fractionnelles), pas en pixels. Conversion locale via
        // `gameGrid.gridSize` — invariant par zoom : case N s'affiche à la
        // même position-case quel que soit mmSize. Rebinding automatique
        // quand l'utilisateur local zoome (gridSize change → x/y recalculés).
        Item {
            id: remoteCursorsOverlay
            anchors.fill: parent
            z: 100000
            visible: EditorSession.active

            Repeater {
                model: root._remoteCursorKeys
                delegate: Item {
                    readonly property var _entry: root.remoteCursors[modelData]
                    readonly property color _color: root._colorForPlayer(modelData)
                    readonly property real _gs: gameGrid ? gameGrid.gridSize : 0
                    x: _entry ? _entry.x * _gs : 0
                    y: _entry ? _entry.y * _gs : 0
                    width: 1; height: 1
                    visible: !!_entry && _gs > 0

                    // Lissage visuel — le timer d'envoi tourne à 20 Hz (50 ms)
                    // donc une interpolation ~60 ms OutQuad couvre un cycle
                    // sans retard perceptible. OutQuad évite le rebond.
                    Behavior on x {
                        NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                    }
                    Behavior on y {
                        NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                    }

                    // Flèche de curseur stylisée
                    Canvas {
                        width: 20; height: 22
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.fillStyle = parent._color
                            ctx.strokeStyle = "white"
                            ctx.lineWidth = 1.5
                            ctx.beginPath()
                            ctx.moveTo(1, 1)
                            ctx.lineTo(1, 18)
                            ctx.lineTo(6, 13)
                            ctx.lineTo(10, 20)
                            ctx.lineTo(13, 18)
                            ctx.lineTo(9, 11)
                            ctx.lineTo(16, 11)
                            ctx.closePath()
                            ctx.fill()
                            ctx.stroke()
                        }
                        Connections {
                            target: parent
                            function on_ColorChanged() { parent.requestPaint() }
                        }
                    }

                    // Étiquette playerId tronqué
                    Rectangle {
                        x: 18; y: 14
                        radius: Theme.radiusXS
                        color: parent._color
                        width: label.implicitWidth + 10
                        height: label.implicitHeight + 4
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.length > 8 ? modelData.substring(0, 8) : modelData
                            color: "white"
                            font.pixelSize: Theme.fontSizeCaption
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    // Popup plein écran pour afficher un message agrandi
    Popup {
        id: fullScreenMsgPopup

        property var currentModel: null
        onClosed: chatDrawer.open()

        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: root.width * 0.75
        height: root.height * 0.7

        padding: 0

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusXXL
            border.color: Theme.border
            border.width: 1

            // Barre de titre
            Rectangle {
                id: popupHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 40
                color: Theme.surfaceAlt
                radius: Theme.radiusXXL

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.radius
                    color: parent.color
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingXXL
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Message"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }

                Rectangle {
                    id: closeBt
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: closeBtArea.containsMouse ? Theme.pressed(Theme.danger) : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }

                    MouseArea {
                        id: closeBtArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            chatDrawer.close()
                            fullScreenMsgPopup.close()
                        }
                    }
                }
            }
        }

        ChatMessageDelegate {
            fullScreenMode : true
            modelData : fullScreenMsgPopup.currentModel
            anchors.bottom: parent.bottom
            index : 0
            drawer : null
            listView : fullScreenMsgPopup
            hasData: true
        }

        Overlay.modal: Rectangle {
            color: "#aa000000"
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationNormal; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1; to: 0.92; duration: Theme.durationNormal; easing.type: Easing.InCubic }
        }
    }

    // Phase 3.7 — popup de fin de session collab : demande à l'utilisateur
    // s'il conserve le fichier local <mapName>_map.json créé/mis à jour
    // pendant la session. Ouvert par beginSessionExit(); la continuation
    // (stop + pop côté main.qml) est appelée après le choix de l'utilisateur.
    property var _pendingExitContinuation: null

    Popup {
        id: sessionExitConfirmPopup
        modal: true
        dim: true
        closePolicy: Popup.NoAutoClose   // pas d'esc/click-outside — choix obligatoire
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 420
        height: 220

        property string mapNameAtExit: ""

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusXL
            border.color: Theme.accent
            border.width: 1
        }

        contentItem: Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingHuge
                spacing: Theme.spacingXL

                Text {
                    text: "Quitter la session collab"
                    color: Theme.accent
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "Conserver le fichier local «" +
                          sessionExitConfirmPopup.mapNameAtExit + "_map.json» sur votre ordinateur ?"
                    color: Theme.textSoft
                    font.pixelSize: Theme.fontSizeBody
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: "« Supprimer » efface la copie locale reçue pendant la session. " +
                          "« Conserver » la garde — vous pourrez la rouvrir en mode mono."
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                    font.italic: true
                    wrapMode: Text.WordWrap
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingL

                    MeowButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        iconText: "🗑️"
                        text: "Supprimer"
                        variant: "danger"
                        fontSize: Theme.fontSizeMedium
                        hoverZoom: false
                        onClicked: root._resolveSessionExit(false)
                    }

                    MeowButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        iconText: "💾"
                        text: "Conserver"
                        variant: "primary"
                        fontSize: Theme.fontSizeMedium
                        hoverZoom: false
                        onClicked: root._resolveSessionExit(true)
                    }
                }
            }
        }
    }

    // Appelée par main.qml avant de faire EditorSession.stop() + pop.
    // Si la session collab est active, affiche le popup et laisse
    // l'utilisateur choisir. Sinon appelle immédiatement la continuation
    // (= pas en collab, rien à supprimer).
    function beginSessionExit(continuation) {
        if (!EditorSession.active) {
            if (continuation) continuation(true)
            return
        }
        _pendingExitContinuation = continuation
        sessionExitConfirmPopup.mapNameAtExit = String(mapInfo.mapName || "")
        sessionExitConfirmPopup.open()
    }

    function _resolveSessionExit(keepLocal) {
        const mapName = sessionExitConfirmPopup.mapNameAtExit
        if (!keepLocal && mapName && mapName !== mapInfo.autosaveMapName) {
            // Purge le fichier local <mapName>_map.json avant la continuation.
            // Note : si la carte existait en tant que mono AVANT la session,
            // sa suppression ici l'écrase aussi. La différenciation mono/collab
            // future isolera les deux (note : voir CLAUDE.md).
            console.log("[SessionExit] user refuse conservation — purge", mapName)
            Game.deleteMap(mapName, MapTypes.CUSTOM)
        } else if (keepLocal) {
            console.log("[SessionExit] user conserve", mapName)
        }
        sessionExitConfirmPopup.close()
        const cont = _pendingExitContinuation
        _pendingExitContinuation = null
        if (cont) cont(keepLocal)
    }

    // cursor and link trakers
    Trackers {}

    // Asset preview cursor
    AssetPreviewCursor {
        id: assetPreview
        parent: workArea
        assetCategory: logic.currentSelectedAssetCategory
        assetType: logic.currentSelectedAssetType
        assetId: logic.currentSelectedAssetId
        caseType: logic.caseTypeSelected
        isCasePreview: logic.caseTypeSelected !== -1
        unitSizeWidth: logic.tileLogic.currentElementWidth
        unitSizeHeight: logic.tileLogic.currentElementHeight
        gridManager: gameGrid
        sidePanel: sidePanel
    }

    // Template preview cursor
    TemplatePreviewCursor {
        id: templatePreview
        parent: workArea
        gridManager: gameGrid
        templateData: logic.mouseLogic
                      && logic.mouseLogic.isPlacementMode ? logic.mouseLogic.placementTemplateData : null
        // Binding déclaratif : suit previewMouseX/Y du MouseLogic_Template
        // (mis à jour par templatePlacementTracker dans Trackers.qml).
        mouseX: logic.mouseLogic && logic.mouseLogic.previewMouseX !== undefined
                ? logic.mouseLogic.previewMouseX : 0
        mouseY: logic.mouseLogic && logic.mouseLogic.previewMouseY !== undefined
                ? logic.mouseLogic.previewMouseY : 0
    }

    // Prévisualisation du polygone pendant le dessin
    PolygonPreviewCursor {
        id: polygonPreview
        parent: workArea
        gridManager: gameGrid
        visible: logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON
                 && points.length > 0
        zoneColor: logic.mouseLogic
                   && logic.mouseLogic.currentZoneColor ? logic.mouseLogic.currentZoneColor : "#FF5722"

        Component.onCompleted: {
            logic.polygonPreview = polygonPreview
        }
    }

    // Rectangle de sélection
    SelectionRect {
        id: selectionRect
        z: UiStyle.z_SELECTION_RECT
    }

    // D3 — conteneur bespoke du module "Joueur". Affiché à la place du
    // SelectionPanel legacy quand le module "player" est actif dans le
    // ModuleManager. Migration incrémentale : SelectionPanel rétrécit module
    // par module, puis sera supprimé en D4.
    PlayerPanel {
        id: playerPanel
        logic: logic
        visible: moduleManager.selectedModuleId === "player"
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left
        height: visible ? Screen.pixelDensity * 75 : 0
    }

    // D3 — conteneur bespoke du module "Zone".
    ZonePanel {
        id: zonePanel
        logic: logic
        visible: moduleManager.selectedModuleId === "zone"
        onFocusReleased: root.focus = true
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left
        height: visible ? Screen.pixelDensity * 75 : 0
    }

    // D3 — conteneur bespoke du module "Template".
    TemplatePanel {
        id: templatePanel
        logic: logic
        visible: moduleManager.selectedModuleId === "template"
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left
        height: visible ? Screen.pixelDensity * 75 : 0
    }

    // D3d-2 — conteneur bespoke du module "Déco".
    DecoPanel {
        id: decoPanel
        logic: logic
        visible: moduleManager.selectedModuleId === "deco"
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left
        height: visible ? Screen.pixelDensity * 75 : 0
    }

    // D3e — conteneur bespoke du module "Case".
    CasePanel {
        id: casePanel
        logic: logic
        visible: moduleManager.selectedModuleId === "case"
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left
        height: visible ? Screen.pixelDensity * 75 : 0
    }


    // D5 — conteneur bespoke du module "Config 3D" (contrôles caméra via CameraRig).
    Config3DPanel {
        id: config3dPanel
        cameraRig: cameraRig
        visible: moduleManager.selectedModuleId === "config3d"
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left
        height: visible ? Screen.pixelDensity * 75 : 0
    }

    BottomSidePanel {
        id: sidePanel
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        // D3f — le panneau de config est désormais un module : visible et glissé
        // en place quand la vignette "config" est active (sinon hors écran à droite).
        // Plus de pilotage par les flèches ▼/▶ legacy du SelectionPanel.
        visible: moduleManager.selectedModuleId === "config"
        x: visible ? parent.width - width : parent.width
        logic: logic
        //Connect the selected decoration element for effects
        Timer {
            id: saveMapDelayer
            interval: 200

            // au commit debouncé, émettre les ops correspondant à l'état
            // courant des panels (effets visuels, settings physiques), une par
            // élément sélectionné. Log-only.
            property string pendingOpKind: ""  // "display" | "zone" | ""

            function flushOps() {
                const els = logic.mouseLogic.selectedElements
                if (!els || els.length === 0) { pendingOpKind = ""; return }

                if (pendingOpKind === "display") {
                    const effects = root.editorSidePanel.visualEffectsPanel.getCurrentEffects()
                    const fields = {
                        "effectBrightness":        effects.brightness,
                        "effectContrast":          effects.contrast,
                        "effectSaturation":        effects.saturation,
                        "effectColorization":      effects.colorization,
                        // la couleur de colorization était absente
                        // → les pairs voyaient l'intensité changer mais pas la
                        // teinte choisie. On envoie la string #RRGGBB, que le
                        // QColor côté remote accepte via assignation.
                        "effectColorizationColor": String(effects.colorizationColor),
                        "effectBlurEnabled":       effects.blurEnabled,
                        "effectBlur":              effects.blur,
                        "effectShadowEnabled":     effects.shadowEnabled,
                        "effectShadowBlur":        effects.shadowBlur,
                        "rotationAngle":           effects.rotationAngle,
                        "mirrorHorizontal":        effects.mirrorHorizontal,
                        "mirrorVertical":          effects.mirrorVertical
                    }
                    for (var i = 0; i < els.length; i++) {
                        if (!els[i] || !els[i].snapableParameters) continue
                        EditorOpBus.recordOp({
                            "op":     EditorOpType.SetDisplayParameter,
                            "target": String(els[i].snapableParameters.uniqueId),
                            "fields": fields
                        })
                    }
                } else if (pendingOpKind === "zone") {
                    const physic = root.editorSidePanel.zoneConfigurationPanel.getCurrentPhysicSettings()
                    for (var j = 0; j < els.length; j++) {
                        if (!els[j] || !els[j].snapableParameters) continue
                        EditorOpBus.recordOp({
                            "op":     EditorOpType.SetZoneParameter,
                            "target": String(els[j].snapableParameters.uniqueId),
                            "fields": physic
                        })
                    }
                }
                pendingOpKind = ""
            }

            onTriggered: {
                var txId = Game.beginTransaction()
                for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                    var el = logic.mouseLogic.selectedElements[i]
                    if (el && el.snapableParameters)
                        Game.updateMap(EditDelta.TileModified, el.snapableParameters, txId)
                }
                Game.commitTransaction()
            }
        }

        onFocusReleased: root.focusReleased()

        onEffectChanged: {
            const effects = root.editorSidePanel.visualEffectsPanel.getCurrentEffects()
            root._applyToSelectionAndSave("display", function(el) { el.applyVisualEffects(effects) })
        }

        onConnectionRequested: function (kind) {
            var targetElement = connectionsConfigurationPanel.targetSnapableElement

            /* save selected element to reasign it */
            var selectedElements = []
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                selectedElements.push(logic.mouseLogic.selectedElements[i])
            }
            console.log("onConnectionRequested", kind, selectedElements)
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_SELECTION_LINK)
            logic.mouseLogic.kind = kind
            logic.mouseLogic.setSelectedElementList(selectedElements)
            logic.mouseLogic.linkSourceCase = targetElement

            // Afficher la prévisualisation du lien
            if (logic.mouseLogic && logic.mouseLogic.showLinkPreview) {
                logic.mouseLogic.showLinkPreview()
            }
        }

        onModelSelected: function (name) {
            gameScene.modelName = name
        }
        onConfigurationChanged: {
            const physicSettings = root.editorSidePanel.zoneConfigurationPanel.getCurrentPhysicSettings()
            root._applyToSelectionAndSave("zone", function(el) { el.applyPhysicSettings(physicSettings) })
        }
    }

    function initializeEditor() {
        // Flag suppression du broadcast FullSync pendant l'init : les
        // Game.loadMap ci-dessous déclenchent tous onMapLoaded, qui
        // autrement rebroadcasterait une carte encore en cours de
        // construction. Personne n'est connecté à ce stade, mais c'est plus
        // propre que de spammer broadcastEvent dans le vide.
        root._suppressFullSyncBroadcast = true
        try {
            _initializeEditorImpl()
        } finally {
            root._suppressFullSyncBroadcast = false
        }
    }

    function _initializeEditorImpl() {
        // Client en mode collab → ne PAS charger la carte locale, la FullSync
        // de l'hôte va la fournir. Autrement, les tuiles chargées déclencheraient
        // `onFoundItemSnapableTile` qui soumet des CreateItem ops, rebroadcastées
        // par l'hôte à tous les pairs (bug: items du client chez l'hôte).
        if (EditorSession.active && !EditorSession.isHost) {
            Logger.info("Collab client — skip local map load (waiting for FullSync)",
                        "MAP FILE MANAGER")
            // Crée un Map vide côté C++ pour que updateMap/applyRemoteDelta
            // puissent muter m_tiles. Sans ça, `getCurrentMap()` retourne null
            // et toute tentative de pose/déplacement local fait un early-return.
            Game.initEmptyCollabMap()
            stEnableAutoSave.sync()
            return
        }

        // Hôte collab avec instruction de carte initiale — route explicite,
        // distincte du flow mono. Se fait AVANT tout premier Hello pour que
        // _sendFullSyncTo sérialise le bon mapInfo.
        if (EditorSession.active && EditorSession.isHost && hostInitialMap) {
            const sessName    = String(hostInitialMap.sessionName || "")
            const initialMode = hostInitialMap.initialMap ? hostInitialMap.initialMap.mode : "new"
            const initialName = hostInitialMap.initialMap ? hostInitialMap.initialMap.mapName : ""
            // G9 : par défaut on copie en mode existing pour ne pas écraser
            // la carte mono. Le SessionCreation pose le flag explicitement.
            // L'absence du champ est traitée comme `false` (rétro-compat).
            const useCopy     = hostInitialMap.initialMap
                                && hostInitialMap.initialMap.useCopy === true
            Logger.info("Collab host init — mode=" + initialMode
                        + " session=" + sessName
                        + " existingMap=" + initialName
                        + " useCopy=" + useCopy, "MAP FILE MANAGER")
            if (initialMode === "existing" && initialName) {
                if (useCopy && sessName) {
                    // G9 : crée une copie du fichier mono sous le nom de la
                    // session. La session édite <sessName>_map.json ; la
                    // carte d'origine <initialName>_map.json est intacte
                    // même si la sortie collab purge le fichier de session.
                    if (MapFileManager.copyMap(initialName, sessName, MapTypes.CUSTOM)) {
                        Logger.info("Collab host : copie " + initialName + " → " + sessName,
                                    "MAP FILE MANAGER")
                        Game.loadMap(sessName, MapTypes.CUSTOM)
                        mapInfo.mapName = sessName
                    } else {
                        // Fallback : si la copie échoue (collision, lock disque),
                        // on retombe sur le comportement use-as-is plutôt que
                        // de bloquer la création de session.
                        console.warn("[Collab host] copyMap échec, fallback use-as-is sur",
                                     initialName)
                        Game.loadMap(initialName, MapTypes.CUSTOM)
                        mapInfo.mapName = initialName
                    }
                } else {
                    // Carte existante use-as-is : charge le fichier
                    // <initialName>_map.json. Ses tuiles et son mapInfo
                    // sont conservés — la session édite directement ce
                    // fichier (l'utilisateur a décoché "créer une copie"
                    // dans SessionCreation, donc il accepte que la sortie
                    // collab "ne pas conserver" puisse purger le fichier).
                    Game.loadMap(initialName, MapTypes.CUSTOM)
                    mapInfo.mapName = initialName
                }
            } else {
                // Nouvelle carte vide — nom de fichier = nom de session.
                // createMapFile ignore silencieusement s'il existe déjà ;
                // dans ce cas loadMap reprendra son contenu actuel (collision
                // avec une mono précédente — différenciation future).
                if (!MapFileManager.mapExists(sessName, MapTypes.CUSTOM)) {
                    MapFileManager.createMapFile(sessName, MapTypes.CUSTOM)
                }
                Game.loadMap(sessName, MapTypes.CUSTOM)
                mapInfo.mapName = sessName
            }
            stEnableAutoSave.sync()
            return
        }

        if (!MapFileManager.mapExists(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)) {
            Logger.info("Creating autosave map", "MAP FILE MANAGER")
            MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            logic.saveMap(MapTypes.AUTOSAVE)
        } else {
            Logger.info("Autosave map already exists", "MAP FILE MANAGER")
        }

        if (stEnableAutoSave.lastOpenedMap !== mapInfo.autosaveMapName) {
            Logger.info("Loading custom map:" + stEnableAutoSave.lastOpenedMap, "MAP FILE MANAGER")
            if (MapFileManager.mapExists(stEnableAutoSave.lastOpenedMap,
                                         MapTypes.CUSTOM)) {
                Game.loadMap(stEnableAutoSave.lastOpenedMap, MapTypes.CUSTOM)
                mapInfo.mapName = stEnableAutoSave.lastOpenedMap
            } else {
                stEnableAutoSave.setValue("lastOpenedMap", mapInfo.autosaveMapName)
                mapInfo.mapName = mapInfo.autosaveMapName
                Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
            }
        } else {
            console.log("Loading autosave map")
            mapInfo.mapName = mapInfo.autosaveMapName
            Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        }
        stEnableAutoSave.sync()
    }

    // ────────────────────────────────────────────────────────────────────
    // Hooks d'automation (objectName: "editorAutomationHooks")
    // ────────────────────────────────────────────────────────────────────
    // Objet STRICTEMENT passif : aucune logique n'est exécutée tant qu'une
    // de ses fonctions n'est pas appelée explicitement via la commande
    // `invoke` du serveur d'automation (cpp/automation/automation_server.*)
    // ou les tools MCP `editor_*` (automation_mcp/index.js).
    //
    // Toutes les fonctions retournent un objet JS sérialisable en JSON.
    // Convention de retour : { ok: bool, error?: string, ... }. Le ciblage
    // se fait par `find` sur objectName="editorAutomationHooks", puis
    // `invoke` avec method + args.
    //
    // Le chemin de pose réutilise EXACTEMENT celui de l'UI
    // (TileLogic.placeSelectedAsset + Game.updateMap) pour rester compatible
    // EditorOpBus / EditorSession (mode collab).
    //
    // NB : c'est un `Item` (et non un `QtObject`) pour qu'il soit visible dans
    // l'arbre VISUEL parcouru par AutomationServer::findRecursive (qui descend
    // par `childItems()`). `width/height: 0` + `visible: false` → strictement
    // inerte côté rendu et entrées.
    Item {
        id: automationHooks
        objectName: "editorAutomationHooks"
        width: 0
        height: 0
        visible: false
        enabled: false

        // Nombre de tiles actuellement dans la carte de l'éditeur (lecture
        // seule, utile pour vérifier une pose via la commande `get`).
        readonly property int _tileCount: root.snapableTilesList
            ? root.snapableTilesList.length : 0

        // Centre du viewport visible (zone de travail au-dessus du panel
        // d'assets) en coordonnées écran de `root`.
        function _viewportCenterPx() {
            const w = root.width
            const h = root.height - _bottomPanelHeight
            return Qt.point(w / 2.0, h / 2.0)
        }

        // Convertit une position écran (coords `root`) en coords grille réelles
        // (float). cell N apparaît à l'écran à `gameGrid.x + N*gridSize`.
        function _screenToGridReal(screenX, screenY) {
            const gs = gameGrid.gridSize
            if (gs <= 0) return Qt.point(0, 0)
            return Qt.point((screenX - gameGrid.x) / gs,
                            (screenY - gameGrid.y) / gs)
        }

        // ── Thème ───────────────────────────────────────────────────────
        // Change le facteur d'échelle global de l'UI (Theme.uiScale) à chaud.
        // Toute l'interface re-bind ses tailles tokenisées immédiatement.
        function setUiScale(s) {
            const v = Number(s)
            if (!isFinite(v) || v <= 0)
                return { ok: false, error: "uiScale invalide : " + s }
            Theme.uiScale = v
            return { ok: true, uiScale: Theme.uiScale }
        }

        // ── Assets ──────────────────────────────────────────────────────
        // Liste les catégories et, pour chacune, ses types disponibles.
        function listAssetCategories() {
            const cats = AssetManager.getAvailableCategories()
            const out = []
            for (let i = 0; i < cats.length; i++) {
                const c = cats[i]
                out.push({ category: c, types: AssetManager.getAvailableTypes(c) })
            }
            return { ok: true, categories: out }
        }

        // Liste les assets (id, filename, dimensions, ratio) d'une
        // catégorie/type donnés.
        function listAssets(category, type) {
            if (!category || !type)
                return { ok: false, error: "category et type requis" }
            const model = AssetManager.getAssetModel(category, type)
            if (!model)
                return { ok: false, error: "Aucun modèle pour " + category + "/" + type }
            // Rôles de AssetModel (Qt::UserRole+1 = 257). Cf.
            // AssetModel::AssetRoles dans asset_manager.h.
            const PathRole = 257, RatioWidthRole = 260, RatioHeightRole = 261,
                  WidthRole = 262, HeightRole = 263, IdRole = 264,
                  FilenameRole = 265, DescriptionRole = 270
            const n = model.rowCount()
            const assets = []
            for (let i = 0; i < n; i++) {
                const idx = model.index(i, 0)
                assets.push({
                    id: model.data(idx, IdRole),
                    filename: model.data(idx, FilenameRole),
                    path: model.data(idx, PathRole),
                    width: model.data(idx, WidthRole),
                    height: model.data(idx, HeightRole),
                    ratioWidth: model.data(idx, RatioWidthRole),
                    ratioHeight: model.data(idx, RatioHeightRole),
                    description: model.data(idx, DescriptionRole)
                })
            }
            return { ok: true, category: category, type: type, count: n, assets: assets }
        }

        // ── Pose ────────────────────────────────────────────────────────
        // Sérialise les infos utiles d'une tile fraîchement créée.
        function _tileInfo(tile) {
            if (!tile || !tile.snapableParameters) return null
            const sp = tile.snapableParameters
            const dp = sp.displayParameter
            return {
                uuid: sp.uniqueId ? sp.uniqueId.toString() : null,
                gridX: dp.gridRelativePositionX,
                gridY: dp.gridRelativePositionY,
                width: dp.unitSizeWidth,
                height: dp.unitSizeHeight
            }
        }

        // Sélectionne programmatiquement un asset (décoration) et le pose à
        // (gridX, gridY). Réplique le chemin UI complet : sélection →
        // placeSelectedAsset → Game.updateMap(TileAdded). Restaure le mode
        // EM_NORMAL après coup (ne laisse pas EM_POSE armé).
        function placeAsset(assetId, category, type, gridX, gridY) {
            if (!assetId)
                return { ok: false, error: "assetId requis" }
            if (!AssetManager.isAssetValid(category, type, assetId))
                return { ok: false, error: "Asset introuvable: "
                         + category + "/" + type + "/" + assetId }

            // updateSelectedAsset arme la sélection + ajuste le ratio + émet
            // assetSelected → onAssetSelected passe en EM_POSE.
            logic.updateSelectedAsset(category, type, assetId)

            const placed = logic.tileLogic.placeSelectedAsset(gridX, gridY)
            if (placed && placed.snapableParameters)
                Game.updateMap(EditDelta.TileAdded, placed.snapableParameters)

            // Restaurer le mode normal (désarme EM_POSE) sans piétiner un
            // mode spécialisé éventuel.
            logic.clearAssetSelection()
            if (logic.editorMouseMode === EditorEnum.EM_POSE)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)

            const info = _tileInfo(placed)
            if (!info)
                return { ok: false, error: "Échec de la création de la tile" }
            return { ok: true, tile: info }
        }

        // Pose une case typée (caseType = valeur Case::CaseType). TileLogic
        // gère la branche case quand aucun asset n'est sélectionné et que
        // caseTypeSelected != -1.
        function placeCase(caseType, gridX, gridY) {
            if (caseType === undefined || caseType === null || caseType < 0)
                return { ok: false, error: "caseType (>= 0) requis" }
            // Désarmer toute sélection d'asset puis armer le type de case.
            logic.clearAssetSelection()
            logic.caseTypeSelected = caseType  // → armé pour la pose

            const placed = logic.tileLogic.placeSelectedAsset(gridX, gridY)
            if (placed && placed.snapableParameters)
                Game.updateMap(EditDelta.TileAdded, placed.snapableParameters)

            // Restaurer : caseTypeSelected = -1 ramène EM_NORMAL via le handler.
            logic.caseTypeSelected = -1
            if (logic.editorMouseMode === EditorEnum.EM_POSE)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)

            const info = _tileInfo(placed)
            if (!info)
                return { ok: false, error: "Échec de la création de la case" }
            return { ok: true, tile: info }
        }

        // Crée une zone physique polygonale (PhysicZoneTile) à partir d'une
        // liste de points en coordonnées GRILLE ABSOLUES. Réplique
        // MouseLogic_DrawPolygon.createPhysicZone() sans passer par le mode
        // dessin : bounds → origine tile, points relatifs, paramètres
        // physiques, puis createItemSnapableTile + Game.updateMap(TileAdded)
        // (compatible collab/undo).
        //
        // points : [{x, y}, ...] ou liste plate [x1, y1, x2, y2, ...] — au
        //          moins 3 sommets.
        // options (toutes facultatives) :
        //   color (string "#RRGGBB"), name (string), exclusion (bool, défaut
        //   true), velocityX/velocityY/velocityStrength (real),
        //   frictionStrength (real), speedMultiplier (real, défaut 1.0),
        //   accelerationMultiplier (real, défaut 1.0).
        function placeZone(points, options) {
            // Normaliser : accepte [{x,y},...] ou liste plate [x1,y1,...].
            let pts = []
            if (points && points.length && typeof points[0] === "number") {
                if (points.length % 2 !== 0)
                    return { ok: false, error: "Liste plate de coordonnées de longueur impaire" }
                for (let i = 0; i < points.length; i += 2)
                    pts.push({ x: points[i], y: points[i + 1] })
            } else if (points && points.length) {
                for (let j = 0; j < points.length; j++) {
                    const p = points[j]
                    if (!p || p.x === undefined || p.y === undefined)
                        return { ok: false, error: "Point " + j + " invalide (attendu {x, y})" }
                    pts.push({ x: Number(p.x), y: Number(p.y) })
                }
            }
            if (pts.length < 3)
                return { ok: false, error: "Au moins 3 points requis (" + pts.length + " reçus)" }

            const opt = options || {}
            const sp = ItemSnapableFactory.createPhysicZone()

            // Bounds → origine de la tile (même math que MouseLogic_DrawPolygon).
            let minX = pts[0].x, maxX = pts[0].x
            let minY = pts[0].y, maxY = pts[0].y
            for (let k = 1; k < pts.length; k++) {
                minX = Math.min(minX, pts[k].x); maxX = Math.max(maxX, pts[k].x)
                minY = Math.min(minY, pts[k].y); maxY = Math.max(maxY, pts[k].y)
            }
            const gridOriginX = Math.floor(minX)
            const gridOriginY = Math.floor(minY)

            sp.displayParameter.gridRelativePositionX = gridOriginX
            sp.displayParameter.gridRelativePositionY = gridOriginY
            sp.displayParameter.unitSizeWidth = Math.ceil(maxX - minX) + 1
            sp.displayParameter.unitSizeHeight = Math.ceil(maxY - minY) + 1
            sp.displayParameter.zLayer = 1  // Sous les décorations et cases

            // Points RELATIFS à la tile.
            for (let m = 0; m < pts.length; m++)
                sp.zoneParameter.addPoint(pts[m].x - gridOriginX, pts[m].y - gridOriginY)

            sp.zoneParameter.zoneColor = opt.color !== undefined ? opt.color : "#FF5722"
            sp.zoneParameter.zoneName = opt.name !== undefined ? opt.name : ""
            sp.zoneParameter.exclusion = opt.exclusion !== undefined ? opt.exclusion : true
            sp.zoneParameter.velocityDirection = Qt.vector2d(opt.velocityX || 0.0, opt.velocityY || 0.0)
            sp.zoneParameter.velocityStrength = opt.velocityStrength || 0.0
            sp.zoneParameter.frictionStrength = opt.frictionStrength || 0.0
            sp.zoneParameter.speedMultiplier = opt.speedMultiplier !== undefined ? opt.speedMultiplier : 1.0
            sp.zoneParameter.accelerationMultiplier = opt.accelerationMultiplier !== undefined ? opt.accelerationMultiplier : 1.0

            const zone = logic.tileLogic.createItemSnapableTile(sp)
            if (!zone || !zone.snapableParameters)
                return { ok: false, error: "Échec de la création de la zone" }
            zone.updateDisplayBounds()
            Game.updateMap(EditDelta.TileAdded, zone.snapableParameters)

            const info = _tileInfo(zone)
            info.pointCount = pts.length
            info.exclusion = sp.zoneParameter.exclusion
            info.color = String(sp.zoneParameter.zoneColor)
            return { ok: true, tile: info }
        }

        // ── Caméra ──────────────────────────────────────────────────────
        // Retourne l'état caméra : centre du viewport en coords grille,
        // niveau de zoom (scaleLevel/mmSize/gridSize) et taille du viewport.
        function getCamera() {
            const center = _viewportCenterPx()
            const g = _screenToGridReal(center.x, center.y)
            return {
                ok: true,
                centerGridX: g.x,
                centerGridY: g.y,
                scaleLevel: gameGrid.scaleLevel,
                mmSize: gameGrid.mmSize,
                gridSize: gameGrid.gridSize,
                gridOffsetX: gameGrid.x,
                gridOffsetY: gameGrid.y,
                viewportWidth: root.width,
                viewportHeight: root.height - _bottomPanelHeight
            }
        }

        // Centre la vue sur la cellule (gridX, gridY) — pan absolu. Met à
        // jour gameGrid.x/y puis resynchronise la caméra 3D via
        // updateCameraPosition (qui compare grid.x au lastGridPos mémorisé).
        function setCamera(gridX, gridY) {
            const gs = gameGrid.gridSize
            if (gs <= 0) return { ok: false, error: "gridSize nul" }
            const center = _viewportCenterPx()
            // On veut : center = gameGrid.x + gridX*gs  ⇒  gameGrid.x = center - gridX*gs
            if (logic.mouseLogic && logic.mouseLogic.lastGridPos !== undefined)
                logic.mouseLogic.lastGridPos = Qt.point(gameGrid.x, gameGrid.y)
            gameGrid.x = center.x - gridX * gs
            gameGrid.y = center.y - gridY * gs
            if (logic.mouseLogic && logic.mouseLogic.updateCameraPosition)
                logic.mouseLogic.updateCameraPosition()
            return getCamera()
        }

        // Pan relatif de (dGridX, dGridY) cellules.
        function panCamera(dGridX, dGridY) {
            const cam = getCamera()
            return setCamera(cam.centerGridX + dGridX, cam.centerGridY + dGridY)
        }

        // Zoom ±N crans (×1.1 par cran), centré sur le viewport. Réplique la
        // logique de ScrollLogic.scrollGrid (zoom multiplicatif + recentrage
        // du point fixe + sync caméra 3D via prepare/applyZoom) pour rester
        // cohérent avec le zoom molette de l'UI.
        function zoomCamera(steps) {
            steps = Math.trunc(steps || 0)
            if (steps === 0)
                return getCamera()
            const zoomFactor = 1.1
            const minMmSize = 0.5
            const center = _viewportCenterPx()
            const dir = steps > 0 ? 1.0 : -1.0
            const count = Math.abs(steps)

            for (let i = 0; i < count; i++) {
                const oldMmSize = gameGrid.mmSize
                const oldWidth = logic.tileLogic.currentElementWidth
                const oldHeight = logic.tileLogic.currentElementHeight
                const aspectRatio = oldWidth / oldHeight

                const step = dir > 0 ? zoomFactor : 1.0 / zoomFactor
                let newMmSize = oldMmSize * step
                if (newMmSize < minMmSize) newMmSize = minMmSize
                if (newMmSize <= 0) continue

                // Capturer l'état 3D AVANT le changement de magnification.
                if (logic.mouseLogic && logic.mouseLogic.prepareZoom)
                    logic.mouseLogic.prepareZoom(center.x, center.y)
                if (logic.mouseLogic && logic.mouseLogic.lastGridPos !== undefined)
                    logic.mouseLogic.lastGridPos = Qt.point(gameGrid.x, gameGrid.y)

                const ratio = newMmSize / oldMmSize
                // Garder le point sous le centre du viewport fixe.
                const newGridX = center.x - (center.x - gameGrid.x) * ratio
                const newGridY = center.y - (center.y - gameGrid.y) * ratio

                gameGrid.mmSize = newMmSize
                gameGrid.x = newGridX
                gameGrid.y = newGridY

                // Conserver le ratio visuel du sélecteur (comme l'UI).
                const newWidth = oldWidth * oldMmSize / newMmSize
                const newHeight = newWidth / aspectRatio
                logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth))
                logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight))

                if (logic.mouseLogic && logic.mouseLogic.applyZoom)
                    logic.mouseLogic.applyZoom(center.x, center.y)
            }
            return getCamera()
        }
    }

    Component.onDestruction: {
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            logic.mouseLogic.hideLinkPreview()
        }
    }
}
