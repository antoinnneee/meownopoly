import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: snapableElement
    
    // Propriétés configurables
    property var gridManager: null
    property bool isDraggable: true
    property bool autoSnap: true
    property color elementColor: "lightgray"
    property color borderColor: "gray"
    property int borderWidth: 1
    property real elementOpacity: 1.0
    
    // Propriétés d'état
    property bool isDragging: false
    property bool isSelected: false
    
    // Signaux
    signal elementClicked(var element)
    signal elementPressed(var element)
    signal elementReleased(var element)
    signal elementMoved(var element, real newX, real newY)
    signal snapCompleted(var element)
    
    // Apparence par défaut
    color: elementColor
    border.color: isSelected ? Qt.lighter(borderColor, 1.5) : borderColor
    border.width: isSelected ? borderWidth + 1 : borderWidth
    opacity: elementOpacity
    
    // Effet de survol
    scale: isDragging ? 1.05 : 1.0
    
    Behavior on scale {
        NumberAnimation { duration: 150 }
    }
    
    Behavior on border.width {
        NumberAnimation { duration: 100 }
    }
    
    // Zone de drag & drop
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: isDraggable
        
        drag.target: isDraggable ? parent : null
        drag.axis: Drag.XAndYAxis
        
        onPressed: {
            isDragging = true
            isSelected = true
            elementPressed(snapableElement)
        }
        
        onReleased: {
            isDragging = false
            
            // Auto-snap si activé et gridManager disponible
            if (autoSnap && gridManager && gridManager.snapToGrid) {
                gridManager.snapElement(snapableElement)
                snapCompleted(snapableElement)
            }
            
            elementReleased(snapableElement)
            elementMoved(snapableElement, snapableElement.x, snapableElement.y)
        }
        
        onClicked: {
            isSelected = !isSelected
            elementClicked(snapableElement)
        }
        
        onPositionChanged: {
            if (drag.active) {
                elementMoved(snapableElement, snapableElement.x, snapableElement.y)
            }
        }
    }
    
    // Indicateur de sélection (coins)
    Rectangle {
        width: 6
        height: 6
        color: "orange"
        visible: isSelected
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: -3
    }
    
    Rectangle {
        width: 6
        height: 6
        color: "orange"
        visible: isSelected
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -3
    }
    
    Rectangle {
        width: 6
        height: 6
        color: "orange"
        visible: isSelected
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: -3
    }
    
    Rectangle {
        width: 6
        height: 6
        color: "orange"
        visible: isSelected
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: -3
    }
    
    // Fonctions utilitaires
    function snapToGrid() {
        if (gridManager && gridManager.snapToGrid) {
            gridManager.snapElement(snapableElement)
            snapCompleted(snapableElement)
        }
    }
    
    function select() {
        isSelected = true
    }
    
    function deselect() {
        isSelected = false
    }
    
    function toggleSelection() {
        isSelected = !isSelected
    }
    
    // Position initiale aléatoire (pour les tests)
    function randomizePosition() {
        if (parent) {
            x = Math.random() * (parent.width - width)
            y = Math.random() * (parent.height - height)
            if (autoSnap) {
                snapToGrid()
            }
        }
    }
} 