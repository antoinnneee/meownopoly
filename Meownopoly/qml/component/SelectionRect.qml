import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: selectionRect
    parent: workArea
    visible: false
    color: "#C7E8FF" // Bleu semi-transparent
    border.width: 2
    border.color: "#3498db"
    opacity: 0.7
    z: 100 // S'assurer qu'il est au-dessus des autres éléments
    
    // Propriétés pour la logique
    property point startPoint: Qt.point(0, 0)
    property point currentPoint: Qt.point(0, 0)
    property bool isActive: false
    
    // Fonctions utilitaires
    function show() { 
        visible = true
        isActive = true 
    }
    
    function hide() { 
        visible = false
        isActive = false 
    }
    
    function updateGeometry(start, current) {
        startPoint = start
        currentPoint = current
        
        var x = Math.min(start.x, current.x)
        var y = Math.min(start.y, current.y)
        var width = Math.abs(current.x - start.x)
        var height = Math.abs(current.y - start.y)
        
        selectionRect.x = x
        selectionRect.y = y
        selectionRect.width = width
        selectionRect.height = height
    }
    
    function updateGeometryFromGrid(start, current, gridSize) {
        startPoint = start
        currentPoint = current
        
        // Convertir les coordonnées de grille en pixels
        var startX = start.x * gridSize
        var startY = start.y * gridSize
        var currentX = current.x * gridSize
        var currentY = current.y * gridSize
        
        var x = Math.min(startX, currentX)
        var y = Math.min(startY, currentY)
        var width = Math.abs(currentX - startX)
        var height = Math.abs(currentY - startY)
        
        selectionRect.x = x
        selectionRect.y = y
        selectionRect.width = width
        selectionRect.height = height
    }
}
