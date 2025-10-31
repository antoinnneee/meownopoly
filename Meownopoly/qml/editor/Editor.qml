import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore

import "tools"
import "tools/grid"
import "tools/preview"
import "tools/snapable"
import "panel"
import "panel/assetSelectionPanel"

import Game
import Case
import ItemSnapable
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import ItemSnapableFactory
import UndoRedoManager

Rectangle {
    id: root

    color: "lightblue"
    border.width: 0

    // Player_Profil_Icon{
    //     x:100
    //     y:100
    //     decorationParameter.decorationCategory: "ui"
    //     decorationParameter.decorationType: "cat"
    //     decorationParameter.decorationId: "cat"
    // }

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    property alias isSelectionActive: logic.isSelectionActive
    property alias selectionStart: logic.selectionStart
    property alias selectionCurrent: logic.selectionCurrent
    property alias isSelectingArea: logic.isSelectingArea
    property alias defaultCaseType: logic.defaultCaseType
    // Asset selection properties
    property alias selectedAssetCategory: selectionPanel.currentSelectedAssetCategory
    property alias selectedAssetType: selectionPanel.currentSelectedAssetType
    property alias selectedAssetId: selectionPanel.currentSelectedAssetId
    property alias isAssetSelected: selectionPanel.isAssetSelected

    property alias escMenu:escMenu

    Component.onCompleted: {
        initializeEditor()
    }

    Settings {
        id: stEnableAutoSave
        category: "Editor/SaveConfig"
        property var currentMap : value("currentMap", mapInfo.autosaveMapName)
        property var enableAutoSave: value("enableAutoSave", 0)
    }

    Timer {
        id: tmpSaver
        interval: 1000*10  // 1 minute
        repeat: true
        running: false
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
        interval: 2500
        repeat: false
        running: false
        triggeredOnStart: true
        onTriggered: {
            savingIndicator.running = savingIndicator.running ? false : true
        }
    }

    BusyIndicator {
        id: savingIndicator
        anchors.right: parent.right
        anchors.top: parent.top
        width: Screen.pixelDensity * 10
        height: width
        running: false
    }

    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true

    function regainFocus() {
        forceActiveFocus()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Delete) {
            var selectItem = logic.mouseLogic.selectedElements
            for (var i = 0; i < selectItem.length; i++) {
                selectItem[i].deleteRequest(false)
            }
            // Sauvegarder une seule fois après toutes les suppressions
            if (selectItem.length > 0) {
                logic.saveMap(MapTypes.UNDOREDO)
            }
            event.accepted = true
        }
        else if (event.key === Qt.Key_Escape) {
            if (root.isAssetSelected) {
                selectionPanel.clearAssetSelection()
                event.accepted = true
            } else if (logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK) {
                logic.mouseLogic.unselectAllElements()
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
    }
    Keys.onReleased:{
        logic.mouseLogic.isControlPressed = false
    }


    property MapInfo mapInfo: MapInfo{
        mapName: autosaveMapName
        // mapDescription: ""
        // mapCreationDate: ""
        // mapLastModified: ""
        // backgroundPath: ""
        // backgroundScaling: "Fit"
        // isBackgroundOnGrill: false
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

            // Sauvegarder l'état initial pour undo/redo
            logic.saveMap(MapTypes.UNDOREDO)
        }
    }

    Editor_WheelHandler { }

    EditorLogic {
        id: logic
        workArea: workArea
        editorGrid: editorGrid
        editorDynamicComponent: editorDynamicComponent
        selectionRect:  selectionRect
        mapInfo: root.mapInfo
        selectionPanel: selectionPanel
    }

    EditorDynamicComponent {
        id: editorDynamicComponent
        editorGrid: editorGrid
        logic: logic
        workArea: workArea
        // caseConfigPanel: caseConfigPanel
        selectionPanel: selectionPanel
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        logic: logic
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
    }

    Background {
        id: background
        anchors.fill: mapInfo.isBackgroundOnGrill ? editorGrid : parent
    }

    MouseArea{
        id: mainMa
        z:0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: selectionPanel.top
        pressAndHoldInterval: 300
        drag.target: null
        drag.axis: Drag.XAndYAxis
        drag.smoothed: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property list<SnapableElement> clickElement:[]
        property list<var> elementInitialPosition:[]
        property point dragStartPos: Qt.point(0, 0)
        property point targetStartPos: Qt.point(0, 0)
        
        drag.onActiveChanged: {
            // console.log("drag changed", drag.active);
            if (drag.active && drag.target) {
                // Sauvegarder les positions de départ
                dragStartPos = Qt.point(mouseX, mouseY)
                targetStartPos = Qt.point(drag.target.x, drag.target.y)
            }
            logic.mouseLogic.dragChanged(drag)
        }

        function elementClicked(tile)
        {
            logic.mouseLogic.elementClicked(tile, drag)
        }

        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton) {
                logic.mouseLogic.pressedLeft(mouse, drag)
            }
            else if (mouse.button === Qt.MiddleButton) {
                logic.mouseLogic.pressedMiddle(mouse, drag)
            }
            else if (mouse.button === Qt.RightButton) {
                logic.mouseLogic.pressedRight(mouse, drag)
            }
        }

        onReleased: function(mouse) {
            logic.mouseLogic.release(mouse, drag)
        }

        onPositionChanged: function(mouse) {
            // Mettre à jour la sélection par rectangle si active
            if (logic.mouseLogic.isRectangleSelecting) {
                logic.mouseLogic.updateRectangleSelection(mouse.x, mouse.y)
            }
            
            // Gérer le snap pendant le drag
            if (drag.active && drag.target && editorGrid.snapToGrid) {
                var deltaX = mouse.x - dragStartPos.x
                var deltaY = mouse.y - dragStartPos.y
                
                var newX = targetStartPos.x + deltaX
                var newY = targetStartPos.y + deltaY
                if (drag.target == groupeSelection)
                {
                    // Snapper aux positions de la grille
                    var snappedX = Math.round(newX / editorGrid.gridSize) * editorGrid.gridSize
                    var snappedY = Math.round(newY / editorGrid.gridSize) * editorGrid.gridSize

                    drag.target.x = snappedX
                    drag.target.y = snappedY
                }
            }
        }

        onPressAndHold: function (mouse) {
            logic.mouseLogic.pressedAndHold(mouse)

        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                logic.mouseLogic.clickedLeft(mouse, drag)
            }
            else if (mouse.button === Qt.RightButton) {
                logic.mouseLogic.clickedRight(mouse, drag)
            }
            else if (mouse.button === Qt.MiddleButton) {
                logic.mouseLogic.clickedMiddle(mouse, drag)
            }
            return;
        }
    }
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid
        Item { id: groupeSelection
            property int gridXPosition:  0
            property int gridYPosition:  0
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
            anchors.fill: parent
            hoverEnabled: true
            enabled: logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK
            acceptedButtons: Qt.NoButton // Don't interfere with clicks
            propagateComposedEvents: true
            preventStealing: true
            z: 50
            

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
            assetCategory: root.selectedAssetCategory
            assetType: root.selectedAssetType
            assetId: root.selectedAssetId
            caseType: selectionPanel.caseTypeSelected
            isCasePreview: selectionPanel.caseTypeSelected !== -1
            unitSizeWidth: logic.tileLogic.currentElementWidth
            unitSizeHeight: logic.tileLogic.currentElementHeight
            gridManager: editorGrid
            selectionPanel: selectionPanel
        }
    }

    // Rectangle de sélection
    SelectionRect {
        id: selectionRect
    }

    SelectionPanel{
        id: selectionPanel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Connexion à la logique
        logic: logic

        // Définir la valeur d'expansion par défaut
        isExpanded: true

        //Connect the selected decoration element for effects

        onAssetSelected: function(category, type, id) {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
        }
        onAssetCleared: function() {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
        onEffectChanged: {
            var effects = selectionPanel.assetPanel.visualEffectsPanel.getCurrentEffects()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyVisualEffects(effects)
            }
            logic.saveMap(MapTypes.UNDOREDO)
        }
        onCaseTypeSelectedChanged: {
            if (selectionPanel.caseTypeSelected !== -1)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
            else
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }

    }

    MenuMapAtStart {
        onBackgroundSelected: function() {
            infoPanel.visible = true
        }
    }



    // Panneau d'information sur l'élément sélectionné
    InfoPanel {
        id: infoPanel
        visible: false  // Hidden by default

        anchors {
            top: parent.top
            left: parent.left
            margins: 10
        }

        gridManager: editorGrid
        totalTilesCount: snapableTilesList.length
    }

    Connections {
        target: Game
        function onClearCurrentMap() {
            logic.removeCurrentMap()
        }
    }

    // Gestion des connexions via le SelectionPanel
    Connections {
        target: selectionPanel
        function onConnectionRequested(kind) {

            var targetElement = selectionPanel.connectionsPanel.targetSnapableElement

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

    // Function to apply visual effects to a new decoration tile
    function applyVisualEffectsToNewTile(newTile) {
        if (!newTile || !newTile.snapableParameters.displayParameter) return

        // Get current effects from the visual effects panel
        // if (!selectionPanel.selectedDecoration) return

        var visualEffectsPanel = selectionPanel.assetPanel.visualEffectsPanel
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        if (!currentEffects) return

        newTile.applyVisualEffects(currentEffects)
    }
    
    // Fonction pour nettoyer les ressources lors de la fermeture
    Component.onDestruction: {
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            logic.mouseLogic.hideLinkPreview()
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
            Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        }
        tmpSaver.running = true
    }

    // Function to place the selected asset
    function placeSelectedAsset(gridX, gridY) {
        gridX = gridX - Math.trunc(logic.tileLogic.currentElementWidth/2)
        gridY = gridY - Math.trunc(logic.tileLogic.currentElementHeight/2)
        if (!root.isAssetSelected) {    // place case
            if (!selectionPanel.caseTypeSelected !== -1)
            {
                var snapableParameters = ItemSnapableFactory.createItemSnapable(selectionPanel.caseTypeSelected)

                snapableParameters.displayParameter.gridRelativePositionX = gridX
                snapableParameters.displayParameter.gridRelativePositionY = gridY
                snapableParameters.displayParameter.unitSizeWidth = logic.tileLogic.currentElementWidth
                snapableParameters.displayParameter.unitSizeHeight = logic.tileLogic.currentElementHeight
                snapableParameters.displayParameter.zLayer = 5
                snapableParameters.decorationParameter.decorationCategory = root.selectedAssetCategory
                snapableParameters.decorationParameter.decorationType = root.selectedAssetType
                snapableParameters.decorationParameter.decorationId = root.selectedAssetId
                var newTile = logic.tileLogic.createItemSnapable(snapableParameters)
            }
            return;
        }

        console.log("Placing asset:", root.selectedAssetCategory, root.selectedAssetType, root.selectedAssetId, "at", gridX, gridY)

        // Create appropriate element based on category
        var snapableParameters = ItemSnapableFactory.createItemSnapable()

        snapableParameters.displayParameter.gridRelativePositionX = gridX
        snapableParameters.displayParameter.gridRelativePositionY = gridY
        snapableParameters.displayParameter.unitSizeWidth = logic.tileLogic.currentElementWidth
        snapableParameters.displayParameter.unitSizeHeight = logic.tileLogic.currentElementHeight
        snapableParameters.displayParameter.zLayer = 5
        snapableParameters.decorationParameter.decorationCategory = root.selectedAssetCategory
        snapableParameters.decorationParameter.decorationType = root.selectedAssetType
        snapableParameters.decorationParameter.decorationId = root.selectedAssetId

        var newTile = logic.tileLogic.createItemSnapable(snapableParameters)
        root.applyVisualEffectsToNewTile(newTile)
        mainMa.elementClicked(newTile)
    }

    // Menu d'échappement
    EditorEscMenu {
        id: escMenu
        onVisibleChanged: {
            if (!visible) {
                // Redonner le focus à l'éditeur quand le menu se ferme
                root.forceActiveFocus()
            }
        }
    }
}

