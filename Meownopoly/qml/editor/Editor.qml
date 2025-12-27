import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore
import Case
import ItemSnapable
import "../component"
import "../component/grid"
import "../component/preview"
import "../component/snapable"
import "panel"
import "panel/assetSelectionPanel"
import "panel/sidePanel"
import "panel/mapInfoPanel"


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
import "../ui_item"
import "../test"
import "../utils"

import QtQuick3D
import QtQuick3D.Helpers

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

    property alias escMenu:escMenu
    property alias view3D: gameScene.view3D

    signal updateSettings()
    property alias entity:gameScene.entity

    property real z_CONFIG_PANEL: 10000
    property real z_HUD: 9000
    property real z_SELECTION_RECT: 8000
    property real z_CURSOR_TRACKER: 7000
    property real z_LINK_TRACKER: 6000
    property real z_WORKAREA: 5000

    // MapInfo est déjà défini dans Base_Board, on met juste à jour le nom ici
    Component.onCompleted: {
        stEnableAutoSave.sync()
        initializeEditor()

        // Initialize Entity Controller (avec la liste des tiles pour la collision)
        EntityController.snapableTilesList = snapableTilesList
        World3DTools.init(view3D, gameGrid, gameScene.camera)
        EntityController.setTarget(entity, view3D, gameGrid, logic, snapableTilesList)
        // EditorController.init(logic, selectionPanel, escMenu, adminCommandPanel)
        
        // Activer le mode édition pour les zones d'exclusion
        gameGrid.isEdit = true
    }

    mapInfo.mapName: autosaveMapName

    onUpdateSettings: {
        console.log("Update setting - stEnableAutoSave.value('saveEvent', '0') " + stEnableAutoSave.value('saveEvent', "1"))
        tmpSaver.interval =  stEnableAutoSave.value("saveEvent", "1") === 2 ? stEnableAutoSave.value("saveInterval", "0") * 1000 * 60: 500
        tmpSaver.running = stEnableAutoSave.value("saveEvent", "1") === 1 ? false : true
    }

    Keys.onPressed: function(event) {
        // Pass to EntityController
        EntityController.keysHandler.Keys.pressed(event)
        EditorController.keysHandler.Keys.pressed(event)
    }
    Keys.onReleased: function(event) {
        EntityController.keysHandler.Keys.released(event)
        EditorController.keysHandler.Keys.released(event)
        logic.mouseLogic.isControlPressed = false
    }



    // Menu d'échappement
    EditorEscMenu {
        id: escMenu
        z: z_CONFIG_PANEL
        onVisibleChanged: {
            console.log("EscMenu visibility changed:", visible)
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


    Image {
        id: btInfoMap
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        z: z_HUD
        source: AssetManager.getAssetById("ui", "hud", "0").path
        width: Screen.pixelDensity * 20
        height: Screen.pixelDensity * 20

        MouseArea {
            hoverEnabled: true
            anchors.fill:  parent
            onClicked: {
                btInfoMapAnim.stop()
                btInfoMapAnim.start()
                console.log("onClicked Opening global settings")
                mapInfoPanel.isOpening = !mapInfoPanel.isOpening
                selectionPanel.visible =  selectionPanel.visible ? false: true
                sidePanel.visible = sidePanel.visible ? false: true
                addMapButton.x = (addMapButton.x ===  btInfoMap.x) ? btInfoMap.x - (btInfoMap.width * 1.5) : btInfoMap.x
            }
        }

        SequentialAnimation {
            id: btInfoMapAnim
            running: false
            SmoothedAnimation {velocity: 0.9; to: 1.2; target: btInfoMap; property: "scale"; easing.type: Easing.InOutQuad }
            SmoothedAnimation {velocity: 1.1; to: 1; target: btInfoMap; property: "scale"; easing.type: Easing.InOutQuad }
        }
    }

    Button {
        id: addMapButton
        x: btInfoMap.x
        y: btInfoMap.y + addMapButton.height/2

        z: z_HUD

        width: btInfoMap.width * 0.5
        height: btInfoMap.height * 0.5

        enabled: x == btInfoMap.x ? false : true
        visible: enabled

        onClicked: {
            logic.createNewMap()
        }
        onHoveredChanged: {
            if (hovered)
                bkRect.color = "#413be3"
            else
                bkRect.color = "#88CCFF"
        }

        Text {
            text: "+"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            font.pixelSize: 24
            font.bold: true
            color: "blue"
        }
        background: Rectangle {
            id: bkRect
            anchors.fill: parent
            color: "#88CCFF"

            radius: 30
            border.color: "blue"
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 500
                easing.type: Easing.InOutQuad
                onFinished: {
                }
            }
        }
    }



    MapInfoPanel {
        id: mapInfoPanel
        anchors.top: btInfoMap.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        logic: logic
        selectionPanel: selectionPanel
        sidePanel: sidePanel

        z: root.z_CONFIG_PANEL
    }

    AdminCommandPanel{
        id: adminCommandPanel
        visible: false
        enabled: visible

        height: Screen.pixelDensity * 100
        z: z_CONFIG_PANEL
    }

    Settings {
        id: stEnableAutoSave
        category: "Editor/SaveConfig"
        property var currentMap : value("currentMap", mapInfo.autosaveMapName)
        property int saveEvent: value("saveEvent", "1")
    }


    BusyIndicator {
        id: savingIndicator
        z: z_HUD
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
    Connections{
        target: Game

        function onFoundItemSnapableTile(itemSnapableData){
            Logger.info("Found itemSnapableData tile:" + itemSnapableData, "MAP_LOADING")
            logic.tileLogic.createItemSnapable(itemSnapableData);
        }

        function onMapLoaded(map)
        {
            Logger.success("Map loaded", "MAP_LOADING")
            logic.tileLogic.builtConnections();

            // Copy properties from loaded map to preserve bindings
            if (map.mapInfo) {
                mapInfo.setMapInfo(map.mapInfo)
            }

            if (mapInfo.mapName !== stEnableAutoSave.currentMap)
                stEnableAutoSave.setValue("currentMap", mapInfo.mapName)

            // Check if we're restoring from undo/redo
            if (UndoRedoManager.isRestoringState) {
                console.log("[UNDO][RESTORE] Map loaded during restoration - NOT saving")
                // Clear the restoration flag now that loading is complete
                UndoRedoManager.clearRestorationFlag()
            } else {
                // Only save initial state if not restoring
                console.log("[UNDO][SAVE] Map loaded normally - saving initial state")
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

    logic : EditorLogic {
        id: logic
        parent: root
        workArea: workArea
        editorGrid: gameGrid
        selectionRect:  selectionRect
        mapInfo: root.mapInfo
        selectionPanel: selectionPanel
        editorSidePanel: sidePanel
    }

    mainMa.anchors.bottomMargin: mapInfoPanel.x < parent.width ? 0 : selectionPanel.height

    // Zone de travail de l'éditeur (par-dessus la grille)
    Base_WorkArea {
        id: workArea
        z: z_WORKAREA
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
            var sphere = gameScene.generateSphere(0, 0, 0, 10, "red")           
            gameScene.moveEntityToGridPosition(sphere, 0, 0)
            // EntityController.setTarget(sphere, view3D, gameGrid, logic, snapableTilesList)
            EditorController.init(logic, selectionPanel, escMenu, adminCommandPanel)

            sphere = gameScene.generateSphere(0, 0, 0, 10, "blue")
            gameScene.moveEntityToGridPosition(sphere, 2, 2)
        }
    }

    // cursor and link trakers
    Trackers{}

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

    // Prévisualisation du polygone pendant le dessin
    PolygonPreviewCursor {
        id: polygonPreview
        parent: workArea
        gridManager: gameGrid
        visible: logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON && points.length > 0
        zoneColor: logic.mouseLogic && logic.mouseLogic.currentZoneColor ? 
                   logic.mouseLogic.currentZoneColor : "#FF5722"
        
        Component.onCompleted: {
            logic.polygonPreview = polygonPreview
        }
    }

    // Rectangle de sélection
    SelectionRect {
        id: selectionRect
        z: z_SELECTION_RECT
    }

    SelectionPanel{
        id: selectionPanel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: sidePanel.left

        z: z_HUD

        // Connexion à la logique
        logic: logic

        // Définir la valeur d'expansion par défaut
        isExpanded: true

        onIsSidePanelExpandedChanged: {
            console.log("SelectionPanel: Side panel expanded state changed to", isSidePanelExpanded, " x ", sidePanel.x)
            if (isSidePanelExpanded) {
                sidePanel.x = parent.width - sidePanel.width
            } else {
                sidePanel.x = parent.width
            }
        }
        onIsExpandedChanged: {
            console.log("SelectionPanel: Side panel expanded state changed to", isSidePanelExpanded, " x ", sidePanel.x)
            if (isExpanded) {
                sidePanel.height = Qt.binding(function() {
                    return selectionPanel.height
                })
            } else {
                sidePanel.height = 0
            }
        }

        onAssetSelected: function(category, type, id) {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
        }

        onAssetCleared: function() {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }

        onCaseTypeSelectedChanged: {
            if (selectionPanel.caseTypeSelected !== -1)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
            else
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
    }

    SidePanel {
        id: sidePanel
        z: z_HUD
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

        onConnectionRequested:  function (kind) {
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

        onModelSelected: function(name) {
            gameScene.modelName = name
        }
    }

    MenuMapAtStart {
        z: z_HUD
    }


    Timer {
        id: tmpSaver
        repeat: true
        interval : stEnableAutoSave.value("saveEvent", "1") === 2 ? stEnableAutoSave.value("saveInterval", "0") * 1000 * 60 : 500
        running: stEnableAutoSave.value("saveEvent", "1") === 1 ? false : true
        property bool isMapCustom : mapInfo.mapName !== mapInfo.autosaveMapName
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
            stEnableAutoSave.saveEvent === 2 ? (savingIndicator.running == savingIndicator.running ? false : true) : null
        }
    }

    function regainFocus() {
        forceActiveFocus()
    }

    function initializeEditor() {
        if (!MapFileManager.mapExists(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)){
            console.log("Creating autosave map")
            MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            logic.saveMap(MapTypes.AUTOSAVE)
        }
        else {
            console.log("Autosave map already exists")
        }
        if (stEnableAutoSave.currentMap !== mapInfo.autosaveMapName) {
            console.log("Loading custom map:", stEnableAutoSave.currentMap)
            if (MapFileManager.mapExists(stEnableAutoSave.currentMap, MapTypes.CUSTOM)){
                Game.loadMap(stEnableAutoSave.currentMap, MapTypes.CUSTOM)
                mapInfo.mapName = stEnableAutoSave.currentMap
            }
            else {
                stEnableAutoSave.setValue("currentMap", mapInfo.autosaveMapName)
                mapInfo.mapName = mapInfo.autosaveMapName
                Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
            }
        }
        else  {
            console.log("Loading autosave map")
            Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        }
        if (stEnableAutoSave.value("saveEvent", "1") === 2) {
            tmpSaver.start()
        }
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

