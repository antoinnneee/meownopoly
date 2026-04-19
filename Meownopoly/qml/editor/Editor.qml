import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore

import UiStyle

import Case
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

import utils
import chat

import QtQuick3D
import QtQuick3D.Helpers

import editor
import "."

Base_Board {
    id: root

    color: "lightblue"
    border.width: 0
    focus: true

    property int appPositionX: 0
    property int appPositionY: 0

    // Mode collaboratif : tant que false, l'éditeur reste strictement monoposte.
    // Les interceptions réseau ultérieures checkeront ce flag avant d'agir.
    readonly property bool collaborative: EditorSession.active

    property int availableHeight: height - selectionPanel.height
    property alias groupeSelection: workArea.groupeSelection

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    // Asset selection properties
    property alias isAssetSelected: selectionPanel.isAssetSelected
    property alias editorSidePanel: sidePanel

    property alias escMenu: escMenu
    property alias fullScreenMsgPopup: fullScreenMsgPopup
    property alias view3D: gameScene.view3D

    signal updateSettings
    signal openNewMapMenu
    property alias entity: gameScene.entity

    // la reconnexion auto après host migration est pilotée par main.qml
    // (qui possède le p2pStateMachine). Émis depuis `onHostLost` quand le pair
    // local n'est pas élu — la session de chat reste la MÊME (le nouvel hôte
    // l'a juste renommée côté serveur), donc pas de re-join chat nécessaire.
    signal reconnectRequested(string sessionId, string hostId)

    // MapInfo est déjà défini dans Base_Board, on met juste à jour le nom ici
    Component.onCompleted: {
        initializeEditor()

        // Initialize Entity Controller (avec la liste des tiles pour la collision)
        World3DTools.init(view3D, gameGrid, gameScene.camera)
        // EntityEngine.setTarget(entity, view3D, gameGrid, logic, snapableTilesList)
        EntityEngine.setContext(view3D, gameGrid, logic)
        EntityEngine.setZone(snapableTilesList)
        EntityEngine.setCameraTarget(entity)
        // EditorController.init(logic, selectionPanel, escMenu, adminCommandPanel)

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

    onUpdateSettings: {
        tmpSaver.setSaveTimer()
    }

    Keys.onPressed: function (event) {
        // Pass to EntityEngine
        EntityEngine.keysHandler.Keys.pressed(event)
        // Pass to EditorController
        EditorController.keysHandler.Keys.pressed(event)
    }
    Keys.onReleased: function (event) {
        EntityEngine.keysHandler.Keys.released(event)
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
        onIndexSaveEvent: {
            stEnableAutoSave.sync()
            root.updateSettings()
        }
    }

    BtSideMenu {
        id: btSelection
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 10
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
                height = (btSelection.height * 3) + 10
                btInfoMap.y =   (Screen.pixelDensity * 20)  + 10
                btChat.y =      (Screen.pixelDensity * 20) * 2  + 10
            }
             function retract() {
                 if (btSelection.fixExtand) return
                btInfoMap.x = btSelection.xOrigin; btInfoMap.y = btSelection.yOrigin
                btChat.x = btSelection.xOrigin; btChat.y = btSelection.yOrigin
            }
        }
    }
    BtSideMenu {
        id: btInfoMap
        emojiBt: "ℹ️"
        colorBt: "#3498db"
        onBtClicked: mapInfoPanel.openDrawer()
        Behavior on y {SmoothedAnimation { velocity : 500}}
    }

    BtSideMenu {
        id: btChat
        emojiBt: "💬"
        colorBt: "#2ecc71"
        onBtClicked: chatDrawer.open()
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
            logic.createMap(newMapInfo.mapName, MapTypes.CUSTOM)
            console.log("New map created:", newMapInfo.mapName)
            mapInfo.setMapInfo(newMapInfo)
            logic.saveMap(MapTypes.CUSTOM)
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
        selectionPanel: selectionPanel
        sidePanel: sidePanel

        z: UiStyle.z_HUD
    }

    // Connexion pour écouter les changements de carte et mettre à jour les infos
    Connections {
        target: MapFileManager.currentMap
        function onMapInfoChanged() {
            var cMap = MapFileManager.currentMap
            if (cMap && cMap.mapInfo)
                mapInfo.setMapInfo(cMap.mapInfo)
        }
    }

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
        property var currentMap: value("currentMap", mapInfo.autosaveMapName)
        property int saveEvent: value("saveEvent", "1")
        Component.onCompleted: sync()
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
                    // cassé par un drag local). _rebindTileIfSelected d'Antoine ;
                    // fallback snapToGridFromGridPos si non défini.
                    if (typeof _rebindTileIfSelected === "function") {
                        _rebindTileIfSelected(sub.tileId)
                    } else {
                        const target = findByUuid(String(sub.tileId))
                        if (target && target.snapToGridFromGridPos)
                            target.snapToGridFromGridPos()
                    }
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

    function _sendFullSyncTo(senderId) {
        // Sérialise la liste des tuiles courante. On passe par snapableTiles
        // comme format (cohérent avec MapFileManager), mais sans mapInfo
        // car le client conserve son propre mapInfo courant.
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
        const payload = JSON.stringify({ snapableTiles: tiles })
        const CHUNK = _fullSyncChunkSize()
        const count = Math.max(1, Math.ceil(payload.length / CHUNK))
        console.log("[FullSync] host → " + senderId
                    + " : " + tiles.length + " tuiles sérialisées, "
                    + payload.length + " octets, " + count + " chunks")
        for (let c = 0; c < count; c++) {
            EditorSession.sendEventTo(senderId, EditorMessageType.FullSync, {
                "chunkIndex": c,
                "chunkCount": count,
                "payload":    payload.substr(c * CHUNK, CHUNK)
            })
        }
    }

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
        const tiles = (snapshot && snapshot.snapableTiles) || []
        console.log("[FullSync] applying snapshot —", tiles.length, "tuiles reçues")
        if (tiles.length > 0) {
            console.log("[FullSync] sample incoming tile[0]:",
                        JSON.stringify(tiles[0]).substring(0, 300))
        }

        EditorOpBus.beginApplyRemote()
        try {
            // 1) Wipe local (QML) — les tiles reconstruites ci-dessous sont
            //    de toute façon de nouvelles instances.
            const toDelete = snapableTilesList.slice()
            console.log("[FullSync] wiping", toDelete.length, "tuiles locales")
            for (let i = 0; i < toDelete.length; i++) {
                if (toDelete[i]) logic.tileLogic.deleteElement(toDelete[i])
            }
            // 2) Reconstruit via Game.applyRemoteDelta(TileAdded) — ajoute au
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
            // 3) Rétablit les connexions (next/prev) depuis les JSON.
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
            Logger.info("Found itemSnapable tile:" + itemSnapableData,
                        "MAP_LOADING")
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

            // Copy properties from loaded map to preserve bindings
            if (map.mapInfo) {
                mapInfo.setMapInfo(map.mapInfo)
            }

            if (mapInfo.mapName !== stEnableAutoSave.currentMap)
                stEnableAutoSave.setValue("currentMap", mapInfo.mapName)

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
        selectionPanel: selectionPanel
        editorSidePanel: sidePanel
    }

    mainMa.anchors.bottomMargin: mapInfoPanel.x > height ? 0 : selectionPanel.height

    // Badge de statut collaboratif. Visible uniquement quand EditorSession.active.
    // Sert de confirmation visuelle à côté des logs console pendant les tests.
    Rectangle {
        id: collabBadge
        visible: EditorSession.active
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        z: 10000
        width: badgeRow.implicitWidth + 20
        height: badgeRow.implicitHeight + 10
        radius: 6
        color: EditorSession.isHost ? "#1e4d3a" : "#1e3a5f"
        border.color: EditorSession.isHost ? "#22c55e" : "#3b82f6"
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: EditorSession.isHost ? "#22c55e" : "#3b82f6"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (EditorSession.isHost ? "Collab · Hôte" : "Collab · Client")
                      + (EditorSession.sessionId ? "  (" + EditorSession.sessionId + ")" : "")
                color: "#f4f4f5"
                font.pixelSize: 12
                font.bold: true
            }
        }

        // Click sur le badge → toggle du panneau de stats réseau.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: netStatsPanel.open = !netStatsPanel.open
            acceptedButtons: Qt.LeftButton
        }
    }

    // panneau de stats de transmission (reliable.io par pair).
    // Toggle via clic sur le badge collab. Poll @ 2 Hz.
    Rectangle {
        id: netStatsPanel
        property bool open: false
        visible: EditorSession.active && open
        anchors.top: collabBadge.bottom
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 12
        z: 10000
        width: Math.max(320, statsCol.implicitWidth + 20)
        height: statsCol.implicitHeight + 16
        radius: 8
        color: "#0f172a"
        border.color: "#334155"
        border.width: 1
        opacity: 0.95

        // Snapshot rafraîchi par le timer. Clé = playerId, valeur = map stats.
        property var snapshots: ({})
        // Incrémenté à chaque poll ; utilisé comme dépendance explicite des
        // bindings de delegate pour forcer la ré-évaluation. Sans ça, le
        // binding `snapshots[modelData]` ne se re-déclenche pas de manière
        // fiable quand le Repeater garde ses delegates (model inchangé) et
        // que seule la valeur mappée change — les RTT/bandwidth/loss qui
        // évoluent peu paraissent figées alors que les counters monotones
        // semblent bouger par effet de bord des re-évaluations partielles.
        property int tick: 0

        Timer {
            interval: 250
            repeat: true
            running: netStatsPanel.visible
            onTriggered: {
                const snap = {}
                const n = Catway.playersCount()
                for (let i = 0; i < n; ++i) {
                    const p = Catway.playerAt(i)
                    if (p && p.p2pConnected && p.playerId)
                        snap[p.playerId] = p.stats()
                }
                netStatsPanel.snapshots = snap
                netStatsPanel.tick += 1
            }
        }

        function _fmt(n, digits) {
            if (n === undefined || n === null) return "—"
            return Number(n).toFixed(digits === undefined ? 1 : digits)
        }

        function _playerIds() {
            const k = []
            for (const id in netStatsPanel.snapshots) k.push(id)
            k.sort()
            return k
        }

        Column {
            id: statsCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                spacing: 6
                Text {
                    text: "📊 Réseau (reliable.io)"
                    color: "#f1f5f9"
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "pairs: " + Object.keys(netStatsPanel.snapshots).length
                    color: "#94a3b8"
                    font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#1e293b" }

            Repeater {
                model: (netStatsPanel.tick, netStatsPanel._playerIds())
                delegate: Column {
                    width: statsCol.width
                    spacing: 3
                    // `tick` est invoqué via l'opérateur virgule pour forcer
                    // une dépendance : sans ça, Qt 6 ne re-déclenche pas
                    // toujours le binding `snapshots[modelData]` quand la
                    // valeur change mais la clé reste la même.
                    readonly property var s: (netStatsPanel.tick,
                                              netStatsPanel.snapshots[modelData] || ({}))

                    Text {
                        text: modelData.substring(0, 12)
                              + (EditorSession.hostPlayerId === modelData ? "  🛡️ hôte" : "")
                        color: "#cbd5e1"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Consolas, Monaco, monospace"
                    }
                    Grid {
                        columns: 4
                        columnSpacing: 10
                        rowSpacing: 2
                        Text { text: "RTT";    color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.rtt) + " ms";    color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "loss";   color: "#64748b"; font.pixelSize: 10 }
                        Text {
                            text: netStatsPanel._fmt((s.packetLoss || 0) * 100) + " %"
                            color: (s.packetLoss || 0) > 0.05 ? "#f87171" : "#e2e8f0"
                            font.pixelSize: 10
                            font.family: "Consolas, Monaco, monospace"
                        }
                        Text { text: "sent";   color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.sentBwKbps) + " kbps"; color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "recv";   color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.recvBwKbps) + " kbps"; color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "acked";  color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.ackedBwKbps) + " kbps"; color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "pkts";   color: "#64748b"; font.pixelSize: 10 }
                        Text {
                            text: (s.packetsSent || 0) + "↑ / " + (s.packetsAcked || 0) + "✓"
                            color: "#e2e8f0"
                            font.pixelSize: 10
                            font.family: "Consolas, Monaco, monospace"
                        }
                        Text { text: "frag";   color: "#64748b"; font.pixelSize: 10 }
                        Text {
                            text: (s.fragmentsSent || 0) + "↑ / " + (s.fragmentsReceived || 0) + "↓"
                            color: "#e2e8f0"
                            font.pixelSize: 10
                            font.family: "Consolas, Monaco, monospace"
                        }
                    }
                }
            }

            Text {
                visible: Object.keys(netStatsPanel.snapshots).length === 0
                text: "Aucun pair P2P connecté."
                color: "#64748b"
                font.pixelSize: 10
                font.italic: true
            }
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

        GameScene {
            id: gameScene
            x: -gameGrid.x
            y: -gameGrid.y
            width: root.width
            height: root.height
            z: 5.99 // Z-index relatif à workArea (au milieu des plans 2D)

            // Bind camera magnification to grid scale level
            cameraMagnification: gameGrid.scaleLevel
            gridManager: gameGrid
        }
        Component.onCompleted: {
            // EntityEngine.setTarget(sphere, view3D, gameGrid, logic, snapableTilesList)
            EditorController.init(logic, selectionPanel, escMenu, fullScreenMsgPopup,
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
                        radius: 3
                        color: parent._color
                        width: label.implicitWidth + 10
                        height: label.implicitHeight + 4
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.length > 8 ? modelData.substring(0, 8) : modelData
                            color: "white"
                            font.pixelSize: 10
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
            color: "#2b2b2b"
            radius: 12
            border.color: "#444444"
            border.width: 1

            // Barre de titre
            Rectangle {
                id: popupHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 40
                color: "#333333"
                radius: 12

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.radius
                    color: parent.color
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Message"
                    color: "#cccccc"
                    font.pointSize: 11
                    font.bold: true
                }

                Rectangle {
                    id: closeBt
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: closeBtArea.containsMouse ? "#c0392b" : "#444444"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#cccccc"
                        font.pointSize: 10
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
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; from: 1; to: 0.92; duration: 150; easing.type: Easing.InCubic }
        }
    }

    // cursor and link trakers
    Trackers {}

    // Asset preview cursor
    AssetPreviewCursor {
        id: assetPreview
        parent: workArea
        assetCategory: selectionPanel.currentSelectedAssetCategory
        assetType: selectionPanel.currentSelectedAssetType
        assetId: selectionPanel.currentSelectedAssetId
        caseType: selectionPanel.caseTypeSelected
        isCasePreview: selectionPanel.caseTypeSelected !== -1
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
        mouseX: 0
        mouseY: 0
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

    SelectionPanel {
        id: selectionPanel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left

        onFocusReleased: {
            root.focus = true
        }
        z: UiStyle.z_HUD

        // Connexion à la logique
        logic: logic

        // Définir la valeur d'expansion par défaut
        isExpanded: true

        onIsSidePanelExpandedChanged: {
            console.log("SelectionPanel: Side panel expanded state changed to",
                        isSidePanelExpanded, " x ", sidePanel.x)
            if (isSidePanelExpanded) {
                sidePanel.x = parent.width - sidePanel.width
            } else {
                sidePanel.x = parent.width
            }
        }
        onIsExpandedChanged: {
            console.log("SelectionPanel: Side panel expanded state changed to",
                        isSidePanelExpanded, " x ", sidePanel.x)
            if (isExpanded) {
                sidePanel.height = Qt.binding(function () {
                    return selectionPanel.height
                })
            } else {
                sidePanel.height = 0
            }
        }

        onAssetSelected: function (category, type, id) {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
        }

        onAssetCleared: function () {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }

        onCaseTypeSelectedChanged: {
            if (selectionPanel.caseTypeSelected !== -1)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
            else
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
    }

    BottomSidePanel {
        id: sidePanel
        z: UiStyle.z_HUD
        anchors.bottom: parent.bottom
        x: parent.width
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
            var effects = root.editorSidePanel.visualEffectsPanel.getCurrentEffects()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyVisualEffects(effects)
            }
            saveMapDelayer.pendingOpKind = "display"
            if (saveMapDelayer.running)
                saveMapDelayer.restart()
            else
                saveMapDelayer.start()
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
            var physicSettings = root.editorSidePanel.zoneConfigurationPanel.getCurrentPhysicSettings()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyPhysicSettings(
                            physicSettings)
            }
            saveMapDelayer.pendingOpKind = "zone"
            if (saveMapDelayer.running)
                saveMapDelayer.restart()
            else
                saveMapDelayer.start()
        }
    }

    Timer {
        id: tmpSaver
        // repeat: true
        // property bool isMapCustom: mapInfo.mapName !== mapInfo.autosaveMapName
        function setSaveTimer() {
            stEnableAutoSave.sync()
            // tmpSaver.interval = stEnableAutoSave.value(
            //             "saveEvent", "1") == 3 ? 500 : stEnableAutoSave.value(
            //                                          "saveInterval",
            //                                          "0") * 1000 * 60
            // tmpSaver.running = stEnableAutoSave.value("saveEvent",
            //                                           "1") == 1 ? false : true
        }
        // onTriggered: {
        //     console.log("Auto-saving map:", mapInfo.mapName)
        //     if (isMapCustom)
        //         logic.saveMap(MapTypes.CUSTOM)
        //     else
        //         logic.saveMap(MapTypes.AUTOSAVE)

        //     busyTimer.start()
        // }
    }

    Timer {
        id: busyTimer
        interval: 1500
        repeat: false
        running: false
        triggeredOnStart: true
        onTriggered: {
            stEnableAutoSave.saveEvent === 2 ? (savingIndicator.running
                                                == savingIndicator.running ? false : true) : null
        }
    }

    function initializeEditor() {
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
            tmpSaver.setSaveTimer()
            return
        }

        if (!MapFileManager.mapExists(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)) {
            Logger.info("Creating autosave map", "MAP FILE MANAGER")
            MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            logic.saveMap(MapTypes.AUTOSAVE)
        } else {
            Logger.info("Autosave map already exists", "MAP FILE MANAGER")
        }

        if (stEnableAutoSave.currentMap !== mapInfo.autosaveMapName) {
            Logger.info("Loading custom map:" + stEnableAutoSave.currentMap, "MAP FILE MANAGER")
            if (MapFileManager.mapExists(stEnableAutoSave.currentMap,
                                         MapTypes.CUSTOM)) {
                Game.loadMap(stEnableAutoSave.currentMap, MapTypes.CUSTOM)
                mapInfo.mapName = stEnableAutoSave.currentMap
            } else {
                stEnableAutoSave.setValue("currentMap", mapInfo.autosaveMapName)
                mapInfo.mapName = mapInfo.autosaveMapName
                Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
            }
        } else {
            console.log("Loading autosave map")
            mapInfo.mapName = mapInfo.autosaveMapName
            Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        }
        tmpSaver.setSaveTimer()
    }

    Component.onDestruction: {
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            logic.mouseLogic.hideLinkPreview()
        }
    }
}

/*##^##
Designer {
    D{i:0}D{i:12;invisible:true}D{i:23;cameraSpeed3d:25;cameraSpeed3dMultiplier:1}D{i:28;cameraSpeed3d:25;cameraSpeed3dMultiplier:1}
D{i:45;invisible:true}D{i:46;invisible:true}
}
##^##*/

