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
import "panel/caseConfigPanel"
import "panel/assetSelectionPanel"
import MapLoader

Rectangle {
    id: root

    color: logic.isEditing ? "#B3B3D0D8" : "lightblue"
    border.width: 0

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList
    property alias currentSelectedElement: logic.currentSelectedElement
    property alias isEditing: logic.isEditing

    property alias isSelectionActive: logic.isSelectionActive
    property alias selectionStart: logic.selectionStart
    property alias selectionCurrent: logic.selectionCurrent
    property alias isSelectingArea: logic.isSelectingArea
    property alias defaultCaseType: logic.defaultCaseType

    property alias currentElementWidth: logic.currentElementWidth
    property alias currentElementHeight: logic.currentElementHeight
    
    // Plan range properties
    property alias minPlanDisplayed: logic.minPlanDisplayed
    property alias maxPlanDisplayed: logic.maxPlanDisplayed
    
    // Asset selection properties
    property alias selectedAssetCategory: assetPanel.currentSelectedCategory
    property alias selectedAssetType: assetPanel.currentSelectedType
    property alias selectedAssetId: assetPanel.currentSelectedId
    property alias isAssetSelected: assetPanel.isAssetSelected

    Connections{
        target: MapLoader
        function onFoundCaseTile(dp, caseData){
            console.log("Found case tile:", dp, caseData)
            logic.createCaseTile(dp, caseData);
        }
        function onMapLoaded(map)
        {
            console.log("Map loaded")
            logic.builtConnections();
        }
    }

    Button{
        text: "try load"
        onClicked: {
            console.log("load")
            MapLoader.loadMap("test")
        }
        z:1000
    }

    EditorLogic {
        id: logic
        workArea: workArea
        editorGrid: editorGrid
        editorDynamicComponent: editorDynamicComponent
        selectionRect:  selectionRect
    }
    EditorDynamicComponent {
        id: editorDynamicComponent
        editorGrid: editorGrid
        logic: logic
        workArea: workArea
        caseConfigPanel: caseConfigPanel
        connectionsPanel: connectionsPanel
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        logic: logic
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        
        // Test de l'animation au démarrage
        Component.onCompleted: {
        }

        onGridPressed : function(position) {
            // Si un asset est sélectionné, le placer directement
            if (root.isAssetSelected) {
            } else {
                // Sinon, afficher le menu contextuel
                contextMenu.clickGridCoord = position
                contextMenu.popup()
            }
        }
        onGridClicked:  function(position) {
            if (root.isAssetSelected) {
                console.log("Placing selected asset at:", position)
                placeSelectedAsset(position.x, position.y)
            }
            if (!root.isAssetSelected) {
                logic.deselectAllTiles()
            }
        }
        onGridRightClicked: {
            assetPanel.clearAssetSelection()
        }
    }

    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid

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
        }
    }

    // Rectangle de sélection
    Rectangle {
        id: selectionRect
        parent: workArea
        visible: false
        color: "#C7E8FF" // Bleu semi-transparent
        border.width: 2
        border.color: "#3498db"
        opacity: 0.7
        z: 100 // S'assurer qu'il est au-dessus des autres éléments
    }
    
    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true
    
    // Keyboard shortcuts
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.isAssetSelected) {
                clearAssetSelection()
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
                logic.createNewTileAtPosition(Case.CS_RestArea, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, ItemSnapable.CaseTile)
            }
        }

        MenuItem {
            text: "Créer une Décoration"
            onTriggered: {
                logic.createNewTileAtPosition(Case.CS_Unknow, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, ItemSnapable.DecorationTile)
            }
        }
    }


    // Panneau d'information sur l'élément sélectionné (nouveau composant)
    InfoPanel {
        id: infoPanel

        anchors {
            top: parent.top
            left: parent.left
            margins: 10
        }

        selectedElement: currentSelectedElement
        gridManager: editorGrid
        totalTilesCount: snapableTilesList.length
    }

    // Panneau de contrôle de la grille (composant séparé)
    GridControlPanel {
        id: gridControls
        anchors.fill: parent
        gridManager: editorGrid
        showControlPanel: true
        showInfoPanel: true
        logic: logic
        property alias isEdit : root.isEditing
        property alias currentWidth: root.currentElementWidth
        property alias currentHeight: root.currentElementHeight

        onCancelSelectionRequested: {
            logic.cancelSelection()
        }
    }


    // Panneau de configuration des cases
    CaseConfigurationPanel {
        id: caseConfigPanel
        height: parent.height
        width: parent.width/2

        onConfigurationClosed: {

        }

        onRequestChangeType: function(newType)  {
            logic.changeCaseType(caseConfigPanel.targetSnapableCase, newType)
        }
    }

    // Panneau de configuration des connexions
    ConnectionsConfigurationPanel {
        id: connectionsPanel
        height: parent.height
        width: parent.width/2

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
    }


    // Function to place the selected asset
    function placeSelectedAsset(gridX, gridY) {
        if (!root.isAssetSelected) return
        
        console.log("Placing asset:", root.selectedAssetCategory, root.selectedAssetType, root.selectedAssetId, "at", gridX, gridY)
        gridX = gridX - logic.currentElementWidth/2
        gridY = gridY - logic.currentElementHeight/2
        // Create appropriate element based on category
        if (root.selectedAssetCategory === "decoration") {
            var newTile = logic.createNewTileAtPosition(Case.CS_Unknow, gridX, gridY, ItemSnapable.DecorationTile)
            // Set decoration properties if needed
            if (newTile && newTile.decorationType !== undefined) {
                newTile.decorationType = root.selectedAssetType
                newTile.decorationId = root.selectedAssetId
            }
        } else if (root.selectedAssetCategory === "avatar") {
            logic.createNewTileAtPosition(Case.CS_Unknow, gridX, gridY, ItemSnapable.CaseTile)
        }
        
        // Clear selection after placing (optional - you might want to keep it selected)
        // clearAssetSelection()
    }


    // Asset Selection Panel
    AssetSelectionPanel {
        id: assetPanel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        // Connect the selected decoration element for effects
        selectedDecoration: {
            if (currentSelectedElement && currentSelectedElement.type === ItemSnapable.DecorationTile) {
                return currentSelectedElement
            }
            return null
        }
        logic: logic
    }

    WheelHandler {
        onWheel: (wheel)=> {
             if (wheel.modifiers & Qt.ControlModifier) {
                 console.log(wheel.angleDelta)
                 if (wheel.angleDelta.y > 0)
                    editorGrid.updateSize(editorGrid.mmSize + 1)
                 else if (editorGrid.mmSize > 1)
                     editorGrid.updateSize(editorGrid.mmSize - 1)
                 for (var i = 0; i < root.snapableTilesList.length; i++) {
                     if (root.snapableTilesList[i]) {
                         root.snapableTilesList[i].isSelected = false
                         root.snapableTilesList[i].snapToGridFromGrid()
                     }
                 }
             }
         }
    }

}
