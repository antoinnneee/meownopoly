import QtQuick 2.15
import QtQuick.Controls

Item {
    id: selectionRect
    parent: workArea
    visible: false
    z: 100 // S'assurer qu'il est au-dessus des autres éléments
    
    // Canvas pour le fond hachuré
    Canvas {
        id: hatchCanvas
        anchors.fill: parent
        opacity: 0.4
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            
            var w = width
            var h = height
            
            if (w <= 0 || h <= 0) return
            
            // Fond semi-transparent
            ctx.fillStyle = '#cfe8fa'
            ctx.fillRect(0, 0, w, h)
            
            // Hachures diagonales
            ctx.strokeStyle = "#3498db"
            ctx.lineWidth = 1.5
            ctx.setLineDash([Screen.pixelDensity * 2, Screen.pixelDensity * 4]);
            
            var spacing = Screen.pixelDensity * 8 // Espacement entre les lignes
            var maxDist = w + h
            
            ctx.beginPath()
            for (var i = -h; i < maxDist; i += spacing) {
                ctx.moveTo(i, 0)
                ctx.lineTo(i + h, h)
            }
            ctx.stroke()
        }
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    
    // Canvas pour la bordure bleue avec liseré blanc
    Canvas {
        id: borderCanvas
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            
            var w = width
            var h = height
            
            if (w <= 0 || h <= 0) return
            
            // Liseré blanc (extérieur)
            ctx.strokeStyle = "#ffffff"
            ctx.lineWidth = 4
            ctx.setLineDash([])
            ctx.beginPath()
            ctx.rect(2, 2, w - 4, h - 4)
            ctx.stroke()
            
            // Bordure bleue principale
            ctx.strokeStyle = '#309ce4'
            ctx.lineWidth = 2.5
            ctx.setLineDash([])
            ctx.beginPath()
            ctx.rect(2, 2, w - 4, h - 4)
            ctx.stroke()
        }
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    
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
