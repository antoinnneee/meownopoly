import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import Game
import Case
import ItemSnapable
import "../component"
import "../component/grid"
import "../component/preview"
import "../component/snapable"
import "panel"
import "panel/assetSelectionPanel"
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import ItemSnapableFactory
import UndoRedoManager
import "../ui_item"

Rectangle {
    id: root

    color: "lightblue"
    border.width: 0
    property int appPositionX: 0
    property int appPositionY: 0
    property int availableHeight: height - selectionPanel.height

    AdminCommandPanel{
        id: adminCommandPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        visible: false

        height: Screen.pixelDensity * 100
        z: 120
        
    }

    Player_Profil_Icon{
        x:10
        y:10
        decorationParameter.decorationCategory: "ui"
        decorationParameter.decorationType: "cat"
        decorationParameter.decorationId: ""
    }

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    // Asset selection properties

    property alias isAssetSelected: selectionPanel.isAssetSelected

    property alias escMenu:escMenu

    Component.onCompleted: {
        editorGrid.mmSize = 8
        if (!MapFileManager.mapExists(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)){
            console.log("Creating autosave map")
            MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            logic.saveMap(MapTypes.AUTOSAVE)
        }
        else {
            console.log("Autosave map already exists")
        }

        Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
    }


    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true

    function regainFocus() {
        forceActiveFocus()
    }

    Keys.onPressed: function(event) {
        console.log("event", event.key)
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
        else if (event.key == 178)
        {
            adminCommandPanel.visible = !adminCommandPanel.visible

        }
    }
    Keys.onReleased:{
        logic.mouseLogic.isControlPressed = false
    }


    property MapInfo mapInfo: MapInfo{
        mapName: autosaveMapName
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
            
            // Sauvegarder l'état initial pour undo/redo
            logic.saveMap(MapTypes.UNDOREDO)
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
    }


    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        mmSize: logic.mmSize
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
    }

    Background {
        id: background
        grid: editorGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? editorGrid : parent
    }

    GlobalMa {
        id: mainMa
        mouseLogic: logic.mouseLogic
        anchors.bottom: selectionPanel.top
    }
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid
        Item {
            id: groupeSelection
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
            assetCategory: selectionPanel.currentSelectedAssetCategory
            assetType: selectionPanel.currentSelectedAssetType
            assetId: selectionPanel.currentSelectedAssetId
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
        onEffectChanged: {
            var effects = selectionPanel.assetPanel.visualEffectsPanel.getCurrentEffects()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyVisualEffects(effects)
            }
            if (saveMapTimer.running)
                saveMapTimer.restart()
            else
                saveMapTimer.start()
        }
        onCaseTypeSelectedChanged: {
            if (selectionPanel.caseTypeSelected !== -1)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
            else
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
        onConnectionRequested:  function (kind) {
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

    MenuMapAtStart {
        onBackgroundSelected: function() {
        }
    }


    
    // Fonction pour nettoyer les ressources lors de la fermeture
    Component.onDestruction: {
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            logic.mouseLogic.hideLinkPreview()
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

        var visualEffectsPanel = selectionPanel.assetPanel.visualEffectsPanel
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        newTile.applyVisualEffects(currentEffects)
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

