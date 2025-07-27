import QtQuick 2.15
import QtQuick.Controls

/**
 * GridManager simple et réactif pour l'éditeur
 */
Item {
    id: gridManager
    
    // Propriétés configurables
    property int mmSize: 20
    onMmSizeChanged: {
        console.log("mmSize changed:", mmSize)
        gridSize = Screen.pixelDensity * mmSize
    }
    
    function updateSize(mm) {
        mmSize = mm
    }

    property int gridSize: Screen.pixelDensity * mmSize
    onGridSizeChanged: {
        console.log("gridSize changed:", gridSize)
        gridCanvas.requestPaint()
    }

    property int boardSize:  Screen.pixelDensity * 700
    property color gridColor: "#40808080"
    property real gridOpacity: 0.5
    property bool showGrid: true
    property bool snapToGrid: true
    property int lineWidth: 1
    
    // Propriété pour intensifier la grille pendant le redimensionnement
    property bool resizeMode: false
    
    // Propriétés en lecture seule pour accès externe
    readonly property int snapSize: gridSize
    
    // Signal émis quand les paramètres changent
    signal gridSettingsChanged()

    width: boardSize
    height: boardSize
    
    // Fonction pour snapper une coordonnée à la grille
    function snapToGridCoord(value) {
        if (!snapToGrid) return value
        return Math.round(value / gridSize) * gridSize
    }
    
    // Fonction pour snapper un point (x, y) à la grille
    function snapPoint(x, y) {
        return Qt.point(snapToGridCoord(x), snapToGridCoord(y))
    }
    
    // Fonction pour snapper un point en centrant l'élément sur la grille
    function snapPointCentered(x, y, elementWidth, elementHeight) {
        if (!snapToGrid) return Qt.point(x, y)
        
        // Calculer la position du centre de l'élément
        var centerX = x + elementWidth / 2
        var centerY = y + elementHeight / 2
        
        // Snapper le centre à la grille
        var snappedCenterX = snapToGridCoord(centerX)
        var snappedCenterY = snapToGridCoord(centerY)
        
        // Retourner la position de l'élément pour que son centre soit sur la grille
        return Qt.point(
            snappedCenterX - elementWidth / 2,
            snappedCenterY - elementHeight / 2
        )
    }
    // Fonction alternative qui snap directement un élément (plus pratique)
    function snapElement2(element) {
        if (!snapToGrid) return
        var posGridX = element.gridRelativePositionX * gridSize
        var posGridY = element.gridRelativePositionY * gridSize
        var elementWidth = element.unitSizeWidth * gridSize 
        var elementHeight = element.unitSizeHeight * gridSize
        //var snappedPoint = snapPointCentered(posGridX, posGridY, elementWidth, elementHeight)
        element.x = posGridX
        element.y =posGridY
    }

    
    // Fonction alternative qui snap directement un élément (plus pratique)
    function snapElement(element) {
        if (!snapToGrid) return
        
        var snappedPoint = snapPointCentered(element.x, element.y, element.width, element.height)
        element.x = snappedPoint.x
        element.y = snappedPoint.y
    }
    
    // Fonction pour obtenir la position de grille la plus proche
    function getGridPosition(x, y) {
        return Qt.point(
            Math.floor(x / gridSize),
            Math.floor(y / gridSize)
        )
    }
    
    // Fonctions pour activer/désactiver le mode redimensionnement
    function enterResizeMode() {
        resizeMode = true
    }
    
    function exitResizeMode() {
        resizeMode = false
    }
    

    
    // Canvas pour dessiner la grille
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: showGrid
        opacity: resizeMode ? Math.min(1.0, gridOpacity + 0.3) : gridOpacity
        renderStrategy: Canvas.Threaded
        onPaint: {
            if (!showGrid) return
            
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            // Couleur plus intense en mode redimensionnement
            ctx.strokeStyle = resizeMode ? Qt.lighter(gridColor, 1.2) : gridColor
            ctx.lineWidth = resizeMode ? lineWidth + 1 : lineWidth
            
            // Dessiner les lignes verticales
            for (var x = 0; x <= width; x += gridSize) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
            
            // Dessiner les lignes horizontales
            for (var y = 0; y <= height; y += gridSize) {
                ctx.beginPath()
                ctx.moveTo(0, y)
                ctx.lineTo(width, y)
                ctx.stroke()
            }
        }
        
        // Redessiner quand les propriétés changent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        
        Connections {
            target: gridManager
            function onGridColorChanged() { gridCanvas.requestPaint() }
            function onShowGridChanged() { gridCanvas.requestPaint() }
            function onLineWidthChanged() { gridCanvas.requestPaint() }
            function onResizeModeChanged() { gridCanvas.requestPaint() }
        }
    }
    MouseArea{
        anchors.fill: parent
        drag.target: gridManager

    }

} 
