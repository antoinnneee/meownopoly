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
import UndoRedoManager
import AssetManager
import ItemSnapableFactory
import ui_item

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
    property int availableHeight: height - selectionPanel.height
    property alias groupeSelection: workArea.groupeSelection

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    // Asset selection properties
    property alias isAssetSelected: selectionPanel.isAssetSelected
    property alias editorSidePanel: sidePanel

    property alias escMenu: escMenu
    property alias view3D: gameScene.view3D

    signal updateSettings
    signal openNewMapMenu
    property alias entity: gameScene.entity

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

        console.log("UiStyle.z_CONFIG_PANEL !!! ", UiStyle.z_CONFIG_PANEL)
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

        MouseArea {
            id: btSelMouseArea
            propagateComposedEvents: true
            hoverEnabled: true

            Component.onCompleted:{
                width = parent.width
                height = parent.height
            }

            onEntered: {
                height = (btSelection.height * 3) + 10
                btInfoMap.y =   (Screen.pixelDensity * 20)  + 10
                btChat.y =      (Screen.pixelDensity * 20) * 2  + 10
            }
            onExited: {
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
            fullScreenMsgPopup.currentMessage = modelMsg
            fullScreenMsgPopup.open()
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
        target: UndoRedoManager
        function onForceUnSelectAllElement() {
            logic.mouseLogic.unselectSelectedElements()
        }
    }

    Connections {
        target: Game

        function onFoundItemSnapableTile(itemSnapableData) {
            Logger.info("Found itemSnapable tile:" + itemSnapableData,
                        "MAP_LOADING")
            logic.tileLogic.createItemSnapable(itemSnapableData)
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

            // Check if we're restoring from undo/redo
            if (UndoRedoManager.isRestoringState) {
                Logger.info("Map loaded during restoration - NOT saving",
                            "UNDO - RESTORE")
                // Clear the restoration flag now that loading is complete
                UndoRedoManager.clearRestorationFlag()
            } else {
                // Only save initial state if not restoring
                Logger.info("Map loaded normally - saving initial state",
                            "UNDO - SAVE")
                logic.saveMap(MapTypes.UNDOREDO)
            }
        }

        function onClearCurrentMap() {
            logic.removeCurrentMap()
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

    // Zone de travail de l'éditeur (par-dessus la grille)
    Base_WorkArea {
        id: workArea
        z: UiStyle.z_WORKAREA
        anchors.fill: gameGrid
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
            EditorController.init(logic, selectionPanel, escMenu,
                                  adminCommandPanel)
        }
    }

    // Popup plein écran pour afficher un message agrandi
    Popup {
        id: fullScreenMsgPopup

        property var currentMessage: null

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
            onTriggered: {
                logic.saveMap(MapTypes.UNDOREDO)
            }
        }

        onFocusReleased: root.focusReleased()

        onEffectChanged: {
            var effects = root.editorSidePanel.visualEffectsPanel.getCurrentEffects()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyVisualEffects(effects)
            }
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
            if (saveMapDelayer.running)
                saveMapDelayer.restart()
            else
                saveMapDelayer.start()
        }
    }

    Timer {
        id: tmpSaver
        repeat: true
        property bool isMapCustom: mapInfo.mapName !== mapInfo.autosaveMapName
        function setSaveTimer() {
            stEnableAutoSave.sync()
            tmpSaver.interval = stEnableAutoSave.value(
                        "saveEvent", "1") == 3 ? 500 : stEnableAutoSave.value(
                                                     "saveInterval",
                                                     "0") * 1000 * 60
            tmpSaver.running = stEnableAutoSave.value("saveEvent",
                                                      "1") == 1 ? false : true
        }
        onTriggered: {
            console.log("Auto-saving map:", mapInfo.mapName)
            if (isMapCustom)
                logic.saveMap(MapTypes.CUSTOM)
            else
                logic.saveMap(MapTypes.AUTOSAVE)

            busyTimer.start()
        }
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
        if (!MapFileManager.mapExists(mapInfo.autosaveMapName,
                                      MapTypes.AUTOSAVE)) {
            Logger.info("Creating autosave map", "MAP FILE MANAGER")
            MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            logic.saveMap(MapTypes.AUTOSAVE)
        } else {
            Logger.info("Autosave map already exists", "MAP FILE MANAGER")
        }

        if (stEnableAutoSave.currentMap !== mapInfo.autosaveMapName) {
            Logger.info("Loading custom map:" + stEnableAutoSave.currentMap,
                        "MAP FILE MANAGER")
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

