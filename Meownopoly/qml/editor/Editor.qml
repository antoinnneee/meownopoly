import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import Game
import Case
import ItemSnapable
import "tools"
import "tools/snapable"
import "panel"
import "panel/assetSelectionPanel"
import MapLoader
import MapInfo
import EditorEnum

Rectangle {
    id: root

    color: logic.isEditing ? "#B3B3D0D8" : "lightblue"
    border.width: 0

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList
    property alias isEditing: logic.isEditing

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

    property MapInfo mapInfo: MapInfo{
        mapName: "no_name"
        mapDescription: "no_description"
        mapLastModified: "no_last_modified"
        version: 0
    }

    Connections{
        target: MapLoader
        function onFoundCaseTile(dp, caseData){
            console.log("Found case tile:", dp, caseData)
            logic.tileLogic.createCaseTile(dp, caseData);
        }
        function onFoundDecorationTile(dp, decorationParameter){
            console.log("Found decoration tile:", dp, decorationParameter)
            logic.tileLogic.createDecorationTile(dp, decorationParameter);
        }
        function onMapLoaded(map, mapInfo)
        {
            console.log("Map loaded")
            logic.tileLogic.builtConnections();
            root.mapInfo = mapInfo;
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
    }

    EditorDynamicComponent {
        id: editorDynamicComponent
        editorGrid: editorGrid
        logic: logic
        workArea: workArea
        // caseConfigPanel: caseConfigPanel
        connectionsPanel: connectionsPanel
    }

    LoadMapButton {
        id: loadMapButton

        onClicked: {
            console.log("Opening map selection panel")
            mapSelectionPanel.isVisible = true
        }
    }


    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        logic: logic
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        

        onGridPressed : function(position) {
            // moved to main MA
        }
        onGridClicked:  function(position) {
            if (root.isAssetSelected) {
                console.log("Placing selected asset at:", position)
                placeSelectedAsset(position.x, position.y)
            }
            if (!root.isAssetSelected) {
                logic.tileLogic.deselectAllTiles()
            }
        }
        onGridRightClicked: {
            selectionPanel.clearAssetSelection()
        }
    }

    MouseArea{
        id: mainMa
        z:0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: selectionPanel.top
        pressAndHoldInterval: 350
        drag.target: null
        drag.axis: Drag.XAndYAxis
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property list<SnapableElement> clickElement:[]
        property list<var> elementInitialPosition:[]
        drag.onActiveChanged: {
            console.log("drag changed", drag.active);
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
        Item { id: groupeSelection}

        // MouseArea pour gérer la sélection par rectangle
        MouseArea {
            id: selectionMouseArea
            anchors.fill: parent
            enabled: isEditing && isSelectionActive
            hoverEnabled: true
            z: 99 // Juste en-dessous du rectangle de sélection
            preventStealing: true // Empêche le vol d'événements par d'autres MouseArea

            onPressed:function(mouse) {
                logic.startSelection(mouse)

            }

            onPositionChanged:function(mouse) {
                logic.updateSelection(mouse.x, mouse.y)
                mouse.accepted = true
            }

            onReleased: function(mouse){
                console.log("Finalisation de la sélection")
                logic.finishSelection()
                mouse.accepted = true
            }

            onCanceled: {
                console.log("Annulation de la sélection")
                logic.cancelSelection()
            }
        }
        
        // MouseArea to track cursor position for asset preview
        MouseArea {
            id: cursorTracker
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.isAssetSelected && !isSelectionActive
            acceptedButtons: Qt.NoButton // Don't interfere with clicks
            propagateComposedEvents: true
            preventStealing: true
            z: 50
            
            onPositionChanged: function(mouse) {
                assetPreview.mouseX = mouse.x
                assetPreview.mouseY = mouse.y
            }
        }
        // Asset preview cursor
        AssetPreviewCursor {
            id: assetPreview
            parent: workArea
            assetCategory: root.selectedAssetCategory
            assetType: root.selectedAssetType
            assetId: root.selectedAssetId
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
    
    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true
    
    // Keyboard shortcuts
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.isAssetSelected) {
                selectionPanel.assetManagerSettings.clearAssetSelection()
                event.accepted = true
            }
        }
    }


    // Menu contextuel pour la création d'éléments
    Menu {
        id: contextMenu

        property var clickGridCoord: Qt.point(0, 0)
        
        MenuItem {
            text: "Créer une Case"
            onTriggered: {
                console.log(contextMenu.clickGridCoord)
                logic.tileLogic.createNewTileAtPosition(Case.CS_RestArea, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, ItemSnapable.CaseTile)
            }
        }

        MenuItem {
            text: "Créer une Décoration"
            onTriggered: {
                logic.tileLogic.createNewTileAtPosition(Case.CS_Unknow, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, ItemSnapable.DecorationTile)
            }
        }
    }


    // Panneau d'information sur l'élément sélectionné
    InfoPanel {
        id: infoPanel

        anchors {
            top: parent.top
            left: parent.left
            margins: 10
        }

        gridManager: editorGrid
        totalTilesCount: snapableTilesList.length
    }


    // Panneau de configuration des connexions
    ConnectionsConfigurationPanel {
        id: connectionsPanel

        height: parent.height
        width: parent.width/2

        /*
        function selectElementToConnect(kind) {
            // Simple stratégie: utiliser l'élément actuellement sélectionné dans l'éditeur
            if (!currentSelectedElement || !connectionsPanel.targetElement) return
            if (currentSelectedElement === connectionsPanel.targetElement) return

            if (kind === "previous") {
                connectionsPanel.targetElement.connectionManager.addPreviousElement(currentSelectedElement)
            } else if (kind === "next") {
                connectionsPanel.targetElement.connectionManager.addNextElement(currentSelectedElement)
            }
        }
    */
    }

    // Function to apply visual effects to a new decoration tile
    function applyVisualEffectsToNewTile(newTile) {
        if (!newTile || !newTile.displaySettings) return

        // Get current effects from the visual effects panel
        // if (!selectionPanel.selectedDecoration) return

        var visualEffectsPanel = selectionPanel.assetPanel.visualEffectsPanel
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        if (!currentEffects) return

        newTile.applyVisualEffects(currentEffects)
    }

    // Function to place the selected asset
    function placeSelectedAsset(gridX, gridY) {
        if (!root.isAssetSelected) return

        console.log("Placing asset:", root.selectedAssetCategory, root.selectedAssetType, root.selectedAssetId, "at", gridX, gridY)
        gridX = gridX - Math.trunc(logic.tileLogic.currentElementWidth/2)
        gridY = gridY - Math.trunc(logic.tileLogic.currentElementHeight/2)
        // Create appropriate element based on category
        var newTile = logic.tileLogic.createNewTileAtPosition(Case.CS_Unknow, gridX, gridY, ItemSnapable.DecorationTile)
        // Set decoration properties if needed
        if (newTile && newTile.decorationSettings.decorationType !== undefined) {
            console.log("Setting decoration properties for new tile")
            newTile.decorationSettings.decorationCategory = root.selectedAssetCategory
            newTile.decorationSettings.decorationType = root.selectedAssetType
            newTile.decorationSettings.decorationId = root.selectedAssetId

            // Apply visual effects to the new tile (only if effects are not locked)
            applyVisualEffectsToNewTile(newTile)
        }
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
        }
    }

}
