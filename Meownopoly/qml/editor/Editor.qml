import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore
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

    property alias escMenu:escMenu
    property alias view3D: gameScene.view3D

    signal updateSettings()
    signal openNewMapMenu()
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
        World3DTools.init(view3D, gameGrid, gameScene.camera)
        // EntityEngine.setTarget(entity, view3D, gameGrid, logic, snapableTilesList)
        EntityEngine.setContext(view3D, gameGrid, logic)
        EntityEngine.setZone(snapableTilesList)
        EntityEngine.setCameraTarget(entity)
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
        // Pass to EntityEngine
        EntityEngine.keysHandler.Keys.pressed(event)
    }
    Keys.onReleased: function(event) {
        EntityEngine.keysHandler.Keys.released(event)
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

    Image {
        id: btChat
        anchors.top: btInfoMap.bottom
        anchors.right: parent.right
        anchors.margins: 10
        z: z_HUD
        source: AssetManager.getAssetById("ui", "hud", "0").path
        width: Screen.pixelDensity * 20
        height: Screen.pixelDensity * 20
        
        Rectangle {
            anchors.fill: parent
            color: "#2ecc71"
            opacity: 0.4
            radius: width/2
        }

        Text {
            text: "💬"
            anchors.centerIn: parent
            font.pixelSize: 20
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                chatDrawer.open()
            }
        }
    }

    ChatDrawer {
        id: chatDrawer
        gameId: "Pattoune"/*root.mapInfo.mapName*/
        z: z_CONFIG_PANEL + 100
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
            root.openNewMapMenu()
        }

        Text {
            text: "+"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.centerIn: parent
            width: parent.width
            font.pixelSize: 24
            font.bold: true
            color: addMapButton.hovered ? "#ffffff" : "#1a3a8a"
            
            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
        }
        
        background: Item {
            id: bkContainer
            
            // Glow effect (visible on hover)
            Rectangle {
                id: glowEffect
                anchors.centerIn: parent
                width: parent.width + 12
                height: parent.height + 12
                radius: 35
                opacity: addMapButton.hovered ? 0.6 : 0
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00d4ff" }
                    GradientStop { position: 0.5; color: "#4a90d9" }
                    GradientStop { position: 1.0; color: "#667eea" }
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                }
            }
            
            // Main button background with gradient
            Rectangle {
                id: bkRect
                anchors.fill: parent
                radius: width
                
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: addMapButton.hovered ? "#667eea" : "#7dd3fc"
                        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    }
                    GradientStop {
                        position: 0.5
                        color: addMapButton.hovered ? "#5a67d8" : "#38bdf8"
                        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    }
                    GradientStop {
                        position: 1.0
                        color: addMapButton.hovered ? "#4c51bf" : "#0ea5e9"
                        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    }
                }
                
                border.color: addMapButton.hovered ? "#818cf8" : "#0284c7"
                border.width: addMapButton.hovered ? 2 : 1
                
                Behavior on border.color {
                    ColorAnimation { duration: 250; easing.type: Easing.InOutQuad }
                }
                Behavior on border.width {
                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                }
                
                // Inner highlight shine
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    height: parent.height * 0.4
                    radius: 28
                    opacity: addMapButton.hovered ? 0.4 : 0.25
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }
                }
            }
            
            // Scale animation on hover
            transform: Scale {
                id: hoverScale
                origin.x: bkContainer.width / 2
                origin.y: bkContainer.height / 2
                xScale: addMapButton.hovered ? 1.08 : 1.0
                yScale: addMapButton.hovered ? 1.08 : 1.0
                
                Behavior on xScale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                }
                Behavior on yScale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
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
            // EntityEngine.setTarget(sphere, view3D, gameGrid, logic, snapableTilesList)
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

    BottomSidePanel {
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
        id: newMapMenu
        z: z_CONFIG_PANEL
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
            mapInfo.mapName = mapInfo.autosaveMapName
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

