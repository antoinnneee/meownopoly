import QtQuick 2.15
import QtQuick.Controls
import "."
import "../"

import ItemSnapable
import TileType
import DisplayParameter

Rectangle {
    id: snapableElement
    
    // Propriétés configurables
    // Connexion au GridManager du parent (Editor)
    required property GridManager gridManager
    property bool isDraggable: !isAssetSelected
    property bool isResizable: true
    property bool blockConnections: false
    property bool autoSnap: true
    property color elementColor: "transparent"
    property color borderColor: "gray"
    property int borderWidth: 0
    
    // Propriétés d'état
    property bool isDragging: false
    property bool isResizing: false
    property bool isSelected: false

    // Propriété pour stocker la valeur z originale
    property DisplayParameter displaySettings : DisplayParameter {

    }

    z: displaySettings.zLayer

    property TileType type
    // : 0 // 0: case, 1: personnage, 2: decoration
    
    // Positions calculées à partir des coordonnées relatives
    x: displaySettings.gridRelativePositionX * gridManager.gridSize
    y: displaySettings.gridRelativePositionY * gridManager.gridSize

    width:  gridManager.gridSize * displaySettings.unitSizeWidth
    height:  gridManager.gridSize * displaySettings.unitSizeHeight

    readonly property int globalCenterX: snapableElement.x + snapableElement.width / 2
    readonly property int globalCenterY: snapableElement.y + snapableElement.height / 2


    // Mettre à jour les positions relatives quand les positions absolues changent (drag)
    property bool updatingFromRelative: false

    property alias connectionManager: connectionManager
    // Expose le point central en coordonnées locales et scène
    readonly property point centerLocal: Qt.point(width / 2, height / 2)
    function centerInScene() {
        var p = mapToItem(null, width / 2, height / 2)
        return Qt.point(p.x, p.y)
    }
    
    SnapableElementConnections {
        id: connectionManager
        parentElement: snapableElement
        anchors.fill: snapableElement
        z: 40
        parent: snapableElement.parent
    }
    
    // Signaux
    signal elementClicked(var element)
    signal elementPressed(var element)
    signal elementReleased(var element)
    signal elementResized(var element, real newWidth, real newHeight)
    signal snapCompleted(var element)
    signal elementDeleted(var element)
    signal elementConfigurationRequested(var element)
    signal elementConnectionsConfigurationRequested(var element)
    
    SnapableElementDeleteAnimation {
        id: deleteAnimation
        onFinished: {
            elementDeleted(snapableElement)
        }
    }
    SnapableElementCreateAnimation {
        id: createAnimation

    }

    color: elementColor
    border.color: isSelected ? Qt.lighter(borderColor, 1.5) : borderColor
    border.width: isSelected ? borderWidth + 2 : borderWidth
    
    // Z-order: valeur élevée si sélectionné
    onIsSelectedChanged: {
        if (isSelected) {
            displaySettings.zLayer = z
            z = 11
        } else {
            z = displaySettings.zLayer
        }
    }
    
    // Effet de survol avec transition optimisée
    scale: isDragging ? 1.05 : 1.0
    
    Component.onCompleted: {
        snapToGrid()
        createAnimation.start()
    }
    // Zone de drag & drop
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: isDraggable && !isResizing
        
        drag.target: isDraggable ? parent : null
        drag.axis: Drag.XAndYAxis

        propagateComposedEvents: true
        preventStealing: true

        z: 50  // Au-dessus du contenu mais sous les poignées
        
        onPressed: {
            isDragging = true
            isSelected = true
            elementPressed(snapableElement)
        }
        
        onReleased: {
            isDragging = false
            
            // Mettre à jour les positions relatives après le drag
            updateRelativePosition()
            
            // Auto-snap si activé et gridManager disponible
            if (autoSnap && gridManager && gridManager.snapToGrid) {
                snapToGrid()
            }
            
            elementReleased(snapableElement)
        }
        
        onClicked: {
            isSelected = true
            elementClicked(snapableElement)
        }
        
        onPositionChanged: {
//           assetPreview.mouseX = drag.target.x + mouse.x
//            assetPreview.mouseY = drag.target.y + mouse.y
            if (isDragging) {
            }
//            mouse.accepted = false

        }
    }
    
    // Contrôles de l'élément (boutons de plan et suppression)
    SnapableElementControl {
        id: elementControls
        targetElement: snapableElement
        isVisible: isSelected
        zLayer: displaySettings.zLayer
        onLayerChanged: function(newLayer) {displaySettings.zLayer = newLayer}
                
        onDeleteRequested: {
//            elementDeleted(snapableElement)
            deleteAnimation.start()
        }
        
        onConfigurationRequested: {
            elementConfigurationRequested(snapableElement)
        }

        onConnectionsConfigurationRequested: {
            elementConnectionsConfigurationRequested(snapableElement)
        }
    }

    // Poignées de redimensionnement
    SnapableElementResizeHandles {
        id: resizeHandles
        anchors.fill: parent
        z: 100
    }
    
    // Fonctions utilitaires améliorées
    function updateRelativePosition() {
        if (!gridManager || gridManager.gridSize === 0) return
        
        updatingFromRelative = true
        
        // Calculer les nouvelles positions relatives basées sur les positions absolues
        displaySettings.gridRelativePositionX = Math.round(x / gridManager.gridSize)
        displaySettings.gridRelativePositionY = Math.round(y / gridManager.gridSize)

        updatingFromRelative = false
    }

    function snapToGrid() {
        if (!gridManager || !gridManager.snapToGrid) return

        updatingFromRelative = true

        // Calculer les positions snappées en unités de grille
        var snappedGridX = Math.round(x / gridManager.gridSize)
        var snappedGridY = Math.round(y / gridManager.gridSize)

        // Mettre à jour les positions relatives (qui vont automatiquement mettre à jour x et y)
        displaySettings.gridRelativePositionX = snappedGridX
        displaySettings.gridRelativePositionY = snappedGridY


        updatingFromRelative = false
        gridManager.snapElement2(snapableElement)
        snapCompleted(snapableElement)
    }

    function snapToGridFromGrid() {
        if (!gridManager || !gridManager.snapToGrid) return

        updatingFromRelative = false
        gridManager.snapElement2(snapableElement)
        snapCompleted(snapableElement)
    }

    // selection tools
    function select() { isSelected = true }
    function deselect() { isSelected = false }
    function toggleSelection() { isSelected = !isSelected }


} 
