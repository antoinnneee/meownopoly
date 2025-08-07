import QtQuick 2.15
import QtQuick.Controls
import "."

Rectangle {
    id: snapableElement
    
    // Propriétés configurables
    // Connexion au GridManager du parent (Editor)
    required property GridManager gridManager
    property bool isDraggable: true
    property bool isResizable: true
    property bool autoSnap: true
    property color elementColor: "transparent"
    property color borderColor: "gray"
    property int borderWidth: 1
    
    // Propriétés d'état
    property bool isDragging: false
    property bool isResizing: false
    property bool isSelected: false

    // Système de plans (Z-layers)
    property int zLayer: zLayers.middle
    property int zLayerBase: zLayer * 1000  // Multiplier par 1000 pour espacer les plans
    
    // Constantes pour les plans
    readonly property QtObject zLayers: QtObject {
        readonly property int background: 0
        readonly property int middle: 1
        readonly property int foreground: 2
        
        readonly property var names: ["Background", "Middle", "Foreground"]
        readonly property var colors: ["#FF6B6B", "#4ECDC4", "#45B7D1"]
    }

    property int unitSizeWidth: 3
    property int unitSizeHeight: 3


    property int gridRelativePositionX: 3
    property int gridRelativePositionY: 3

    
    // Positions calculées à partir des coordonnées relatives
    x: gridRelativePositionX * gridManager.gridSize
    y: gridRelativePositionY * gridManager.gridSize

    width:  gridManager.gridSize * unitSizeWidth
    height:  gridManager.gridSize * unitSizeHeight

    // Mettre à jour les positions relatives quand les positions absolues changent (drag)
    property bool updatingFromRelative: false

    property alias connections: connectionManager
    
    SnapableElementConnections {
        id: connectionManager
        targetElement: snapableElement
    }
    
    // Signaux
    signal elementClicked(var element)
    signal elementPressed(var element)
    signal elementReleased(var element)
    signal elementMoved(var element, real newX, real newY)
    signal elementResized(var element, real newWidth, real newHeight)
    signal snapCompleted(var element)
    signal elementDeleted(var element)
    signal elementConfigurationRequested(var element)
    
    SequentialAnimation {
        id: deleteAnimation
        running: false
        onFinished: {
            elementDeleted(snapableElement)
        }
        NumberAnimation {
            target: snapableElement
            property: "scale"
            easing.bezierCurve: [0.612,0.0516,0.544,0.917,1,1]
            to: 0.1
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }
    SequentialAnimation {
        id: createAnimation
        running: false
        onFinished: {
        }
        NumberAnimation {
            target: snapableElement
            property: "scale"
            easing.bezierCurve: [0.612,0.0516,0.544,0.917,1,1]
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.InOutQuad
        }
    }

    color: elementColor
    border.color: isSelected ? Qt.lighter(borderColor, 1.5) : borderColor
    border.width: isSelected ? borderWidth + 1 : borderWidth
    
    // Z-order basé sur le plan
    z: zLayerBase + 1
    
    // Effet de survol avec transition optimisée
    scale: isDragging ? 1.05 : 1.0
    
    Behavior on border.width { NumberAnimation { duration: 80  } }

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
            elementMoved(snapableElement, snapableElement.x, snapableElement.y)
        }
        
        onClicked: {
            isSelected = true
            elementClicked(snapableElement)
        }
        
        onPositionChanged: {
        }
    }
    
    // Contrôles de l'élément (boutons de plan et suppression)
    SnapableElementControl {
        id: elementControls
        targetElement: snapableElement
        isVisible: isSelected
        
        onLayerChanged: function(newLayer) {
            zLayer = newLayer
        }
        
        onDeleteRequested: {
//            elementDeleted(snapableElement)
            deleteAnimation.start()
        }
        
        onConfigurationRequested: {
            elementConfigurationRequested(snapableElement)
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
        gridRelativePositionX = Math.round(x / gridManager.gridSize)
        gridRelativePositionY = Math.round(y / gridManager.gridSize)

        updatingFromRelative = false
    }

    function snapToGrid() {
        if (!gridManager || !gridManager.snapToGrid) return

        updatingFromRelative = true

        // Calculer les positions snappées en unités de grille
        var snappedGridX = Math.round(x / gridManager.gridSize)
        var snappedGridY = Math.round(y / gridManager.gridSize)

        // Mettre à jour les positions relatives (qui vont automatiquement mettre à jour x et y)
        gridRelativePositionX = snappedGridX
        gridRelativePositionY = snappedGridY


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
    
    // Fonctions pour gérer les plans
    function changeToLayer(layer) {
        if (layer >= zLayers.BACKGROUND && layer <= zLayers.FOREGROUND) {
            zLayer = layer
            console.log("Plan changé vers:", zLayers.names[zLayer], "Z:", zLayerBase)
        }
    }
    
    function moveToForeground() { changeToLayer(zLayers.FOREGROUND) }
    function moveToMiddle() { changeToLayer(zLayers.MIDDLE)}
    function moveToBackground() { changeToLayer(zLayers.BACKGROUND) }

    

} 
