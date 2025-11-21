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

import Game
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import ItemSnapableFactory
import UndoRedoManager
import AssetManager
import "../ui_item"
import "../test"


import QtQuick3D
import QtQuick3D.Helpers

Rectangle {
    id: root

    color: "lightblue"
    border.width: 0
    focus: true
    property int appPositionX: 0
    property int appPositionY: 0
    property int availableHeight: height - selectionPanel.height


    property real z_BACKGROUND: 3000
    property real z_GRID: 4000
    property real z_3D: 4500
    property real z_WORKAREA: 5000
    property real z_CONFIG_PANEL: 10000
    property real z_HUD: 9000
    property real z_SELECTION_RECT: 8000
    property real z_CURSOR_TRACKER: 7000
    property real z_LINK_TRACKER: 6000
    property real z_GLOBAL_MA: 4750


    property MapInfo mapInfo: MapInfo{
        mapName: autosaveMapName
    }

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    // Asset selection properties
    property alias isAssetSelected: selectionPanel.isAssetSelected
    property alias editorSidePanel: sidePanel

    property alias escMenu:escMenu
    property alias view3D: view3D

    signal updateSettings()
    property alias entity:entity

    Component.onCompleted: {
        stEnableAutoSave.sync()
        initializeEditor()
    }

    onUpdateSettings: {
        console.log("Update setting - stEnableAutoSave.value('saveEvent', '0') " + stEnableAutoSave.value('saveEvent', "1"))
        tmpSaver.interval =  stEnableAutoSave.value("saveEvent", "1") === 2 ? stEnableAutoSave.value("saveInterval", "0") * 1000 * 60: 500
        tmpSaver.running = stEnableAutoSave.value("saveEvent", "1") === 1 ? false : true
    }

    Keys.onPressed: function(event) {
        console.log("event", event.key)
        if (event.key === Qt.Key_Delete) {
            var selectItem = logic.mouseLogic.selectedElements
            if (selectItem.length === 0) {
                event.accepted = true
                return
            }

            // Attendre que toutes les animations de suppression soient terminées avant de sauvegarder
            var pendingDeletions = selectItem.length

            // Handler appelé quand chaque animation de suppression est terminée
            var deletionHandler = function() {
                pendingDeletions--
                if (pendingDeletions === 0) {
                    // Toutes les animations sont terminées, sauvegarder maintenant
                    logic.saveMap(MapTypes.UNDOREDO)
                }
            }

            // Connecter au signal elementDeleted de chaque élément et déclencher la suppression
            for (var i = 0; i < selectItem.length; i++) {
                var element = selectItem[i]
                element.elementDeleted.connect(deletionHandler)
                element.deleteRequest(false)
            }
            event.accepted = true
        }
        else if (event.key === Qt.Key_Escape) {
            if (root.isAssetSelected) {
                selectionPanel.clearAssetSelection()
                event.accepted = true
            } else if (logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK) {
                logic.mouseLogic.unSelectSelectedElements()
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                event.accepted = true
            } else {
                // Afficher le menu d'échappement
                escMenu.show()
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Control) {
            logic.mouseLogic.isControlPressed = true
        }
        else if (event.key === Qt.Key_Y) {
            if (logic.mouseLogic.isControlPressed)
                console.log("Redo requested via Ctrl+Y")
            Game.askNext()
        }
        else if (event.key === Qt.Key_Z) {
            if (logic.mouseLogic.isControlPressed)
                console.log("Undo requested via Ctrl+Z")
            Game.askPreview()
        }
        else if (event.key === 178)
        {
            adminCommandPanel.visible = !adminCommandPanel.visible
        }
    }
    Keys.onReleased:{
        logic.mouseLogic.isControlPressed = false
    }

    Image {
        id: btInfoMap
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        z: z_HUD
        source: AssetManager.getAssetPath("ui", "hud", "0")
        width: Screen.pixelDensity * 24
        height: Screen.pixelDensity * 24
        MouseArea {
            hoverEnabled: true
            anchors.fill:  parent
            onClicked: {
                btInfoMapAnim.start()
                console.log("onClicked Opening global settings")
                panelInfoMap.isOpening = !panelInfoMap.isOpening
                selectionPanel.visible =  selectionPanel.visible ? false: true
            }
        }
        SequentialAnimation {
            id: btInfoMapAnim
            running: false
            ParallelAnimation {
                NumberAnimation {duration: 300; from: Screen.pixelDensity * 30; to: Screen.pixelDensity * 25; target: btInfoMap; property: "height"; easing.type: Easing.InOutQuad }
                NumberAnimation {duration: 300; from: Screen.pixelDensity * 30; to: Screen.pixelDensity * 25; target: btInfoMap; property: "width"; easing.type: Easing.InOutQuad  }
            }
            ParallelAnimation {
                NumberAnimation {duration: 300; from: Screen.pixelDensity * 25; to: Screen.pixelDensity * 30; target: btInfoMap; property: "height"; easing.type: Easing.InOutQuad }
                NumberAnimation {duration: 300; from: Screen.pixelDensity * 25; to: Screen.pixelDensity * 30; target: btInfoMap; property: "width"; easing.type: Easing.InOutQuad  }
            }
        }
    }

    PanelInfoMap {
        id: panelInfoMap
        anchors.top: btInfoMap.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        logic: logic
        selectionPanel: selectionPanel

        z: root.z_CONFIG_PANEL
    }

    AdminCommandPanel{
        id: adminCommandPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
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
            stEnableAutoSave.saveEvent === 2 ? (savingIndicator.running = savingIndicator.running ? false : true) : null
        }
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
                mapInfo.mapName = map.mapInfo.mapName
                mapInfo.mapDescription = map.mapInfo.mapDescription
                mapInfo.mapCreationDate = map.mapInfo.mapCreationDate
                mapInfo.mapLastModified = map.mapInfo.mapLastModified
                mapInfo.version = map.mapInfo.version
                mapInfo.backgroundPath = map.mapInfo.backgroundPath
                mapInfo.backgroundScaling = map.mapInfo.backgroundScaling
                mapInfo.backgroundTileSize = map.mapInfo.backgroundTileSize
                mapInfo.isBackgroundOnGrill = map.mapInfo.isBackgroundOnGrill
                mapInfo.musicPath = map.mapInfo.musicPath
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

    Editor_WheelHandler { }

    EditorLogic {
        id: logic
        workArea: workArea
        editorGrid: editorGrid
        selectionRect:  selectionRect
        mapInfo: root.mapInfo
        selectionPanel: selectionPanel
        editorSidePanel: sidePanel
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        mmSize: logic.mmSize
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        z: z_GRID
    }

    Background {
        id: background
        grid: editorGrid
        visible: false
        z: z_BACKGROUND
        anchors.fill: mapInfo.isBackgroundOnGrill ? editorGrid : parent
    }

    Node {
        id: scene

        DirectionalLight {
            x: 0
            y: 264.806
            z: 1111.39001
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1.0)
            brightness: 1.0
            eulerRotation.x: -25
        }
        PrincessV2{
            id: entity
            x: 0
            y: 0
            z: 0
        }

        // Stationary orthographic camera viewing from the top
        OrthographicCamera {
            id: cameraOrthographic
            x: 0
            y: 1000
            clipNear: -10000
            clipFar: 1000055
            eulerRotation.z: 0
            eulerRotation.y: 0
            pivot.x: 0
            z: 600
            eulerRotation.x: -55
            horizontalMagnification: editorGrid.scaleLevel
            verticalMagnification: editorGrid.scaleLevel
        }
    }

    View3D {
        id: view3D
        anchors.fill: root
        z: z_3D
        camera: cameraOrthographic
        importScene: scene

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
        }

    }
    GlobalMa {
        id: mainMa
        mouseLogic: logic.mouseLogic
        anchors.bottom: selectionPanel.top
        z: z_GLOBAL_MA
    }
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        z: z_WORKAREA
        anchors.fill: editorGrid


        Item {
            id: groupeSelection
            property int gridXPosition:  0
            property int gridYPosition:  0
        }

        Rectangle{
            id: entityRect
            color: "purple"
            width: 50
            height: 50
            radius: width
            z: 1000
            visible: false
            Behavior on x  { SmoothedAnimation { velocity: 350 } }
            Behavior on y { SmoothedAnimation { velocity: 350 } }
        }


        // MouseArea to track cursor position for asset preview
        MouseArea {
            id: cursorTracker
            anchors.fill: parent
            hoverEnabled: true
            enabled: logic.editorMouseMode === EditorEnum.EM_POSE
            acceptedButtons: Qt.NoButton // Don't interfere with clicks
            propagateComposedEvents: true
            preventStealing: true
            z: 50

            onPositionChanged: function(mouse) {
                assetPreview.mouseX = mouse.x
                assetPreview.mouseY = mouse.y
            }
        }


        // MouseArea to track cursor position for link preview
        MouseArea {
            id: linkTracker
            z: z_LINK_TRACKER
            anchors.fill: parent
            hoverEnabled: true
            enabled: logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK
            acceptedButtons: Qt.NoButton // Don't interfere with clicks
            propagateComposedEvents: true
            preventStealing: true


            onPositionChanged: function(mouse) {
                if (logic.mouseLogic && logic.mouseLogic.updateMousePosition) {
                    logic.mouseLogic.updateMousePosition(mouse.x, mouse.y)
                }
            }
        }

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
            gridManager: editorGrid
            editorSidePanel: sidePanel
        }
    }

    // InteractiveUiElement{
    //     z: z_HUD
    //     x:10
    //     y:10
    //     width: Screen.pixelDensity * 30
    //     height: Screen.pixelDensity * 30
    //     contentItem : Player_Profil_Icon{
    //         decorationParameter.decorationCategory: "ui"
    //         decorationParameter.decorationType: "cat"
    //         decorationParameter.decorationId: ""
    //         anchors.fill: parent
    //     }
    // }


    // Rectangle de sélection
    SelectionRect {
        id: selectionRect
        z: z_SELECTION_RECT
    }

    SelectionPanel{
        id: selectionPanel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        // anchors.right: parent.right
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

        //Connect the selected decoration element for effects
        Timer {
            id: saveMapTimer
            interval: 100
            onTriggered: {
                logic.saveMap(MapTypes.UNDOREDO)
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

    EditorSidePanel {
        id: sidePanel
        z: z_HUD
        anchors.bottom: parent.bottom
        x: parent.width
        logic: logic

        onEffectChanged: {
            var effects = root.editorSidePanel.visualEffectsPanel.getCurrentEffects()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyVisualEffects(effects)
            }
            if (saveMapTimer.running)
                saveMapTimer.restart()
            else
                saveMapTimer.start()
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
    }

    MenuMapAtStart {
        z: z_CONFIG_PANEL
        onBackgroundSelected: function() {
        }
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

    Item {
        id: __materialLibrary__
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

    // Function to place the selected asset
    function placeSelectedAsset(gridX, gridY) {
        var snapableParameters
        gridX = gridX - Math.trunc(logic.tileLogic.currentElementWidth/2)
        gridY = gridY - Math.trunc(logic.tileLogic.currentElementHeight/2)
        if (!root.isAssetSelected) {    // place case
            if (selectionPanel.caseTypeSelected == -1){ //no type selected
                return
            }
            snapableParameters = ItemSnapableFactory.createItemSnapable(selectionPanel.caseTypeSelected)
        }
        else    // place decoration
        {
            snapableParameters = ItemSnapableFactory.createItemSnapable()
        }
        snapableParameters.displayParameter.gridRelativePositionX = gridX
        snapableParameters.displayParameter.gridRelativePositionY = gridY
        snapableParameters.displayParameter.unitSizeWidth = logic.tileLogic.currentElementWidth
        snapableParameters.displayParameter.unitSizeHeight = logic.tileLogic.currentElementHeight
        snapableParameters.displayParameter.zLayer = 5
        snapableParameters.decorationParameter.decorationCategory = selectionPanel.currentSelectedAssetCategory
        snapableParameters.decorationParameter.decorationType = selectionPanel.currentSelectedAssetType
        snapableParameters.decorationParameter.decorationId = selectionPanel.currentSelectedAssetId

        var newTile = logic.tileLogic.createItemSnapable(snapableParameters)

        var visualEffectsPanel = editorSidePanel.visualEffectsPanel
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        newTile.applyVisualEffects(currentEffects)
        mainMa.elementClicked(newTile)
    }

    Component.onDestruction: {
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            logic.mouseLogic.hideLinkPreview()
        }
    }

}


/*##^##
Designer {
    D{i:0}D{i:12;invisible:true}D{i:23;cameraSpeed3d:25;cameraSpeed3dMultiplier:1}D{i:44;invisible:true}
D{i:45;invisible:true}
}
##^##*/
