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

    property bool isEdit: false
    property int currentPlan: 5
    property bool isSelectionActive: false
    
    // Signal émis quand les paramètres changent
    signal gridSettingsChanged()
    signal gridPressed(var position)
    signal gridClicked(var position)

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
    
    // Fonction alternative qui snap directement un élément (plus pratique)
    function snapElement2(element) {
        if (!snapToGrid) return
        var posGridX = element.gridRelativePositionX * gridSize
        var posGridY = element.gridRelativePositionY * gridSize
        var elementWidth = element.unitSizeWidth * gridSize 
        var elementHeight = element.unitSizeHeight * gridSize
        element.x = posGridX
        element.y =posGridY
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

    // Fonction pour centrer la vue sur un élément donné
    function centeredOnElement(element) {
        if (!element) return

        // Calculer la position centrale de l'élément
        var elementCenterX = element.x + element.width / 2
        var elementCenterY = element.y + element.height / 2

        // Calculer la position du GridManager pour centrer l'élément dans la vue
        // Supposer que la vue parent a une taille connue (peut être ajustée selon le contexte)
        var parentCenterX = parent ? parent.width / 2 : width / 2
        var parentCenterY = parent ? parent.height / 2 : height / 2

        // Calculer le décalage nécessaire pour centrer l'élément
        var offsetX = parentCenterX - elementCenterX
        var offsetY = parentCenterY - elementCenterY

        // Appliquer le décalage au GridManager
        gridManager.x = offsetX
        gridManager.y = offsetY

        console.log("GridManager moved to:", gridManager.x, gridManager.y)
    }

    // Fonction pour centrer la vue sur un élément donné
    function moveToConfigElement(element) {
        if (!element) return

        // Calculer la position centrale de l'élément
        var elementCenterX = element.x + element.width / 2
        var elementCenterY = element.y + element.height / 2

        // Calculer la position du GridManager pour centrer l'élément dans la vue
        // Supposer que la vue parent a une taille connue (peut être ajustée selon le contexte)
        var parentCenterX = parent ? parent.width * 0.75 : width / 2
        var parentCenterY = parent ? parent.height / 2 : height / 2

        // Calculer le décalage nécessaire pour centrer l'élément
        var offsetX = parentCenterX - elementCenterX
        var offsetY = parentCenterY - elementCenterY

        // Appliquer le décalage au GridManager
        gridManager.x = offsetX
        gridManager.y = offsetY

        console.log("GridManager moved to:", gridManager.x, gridManager.y)
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
        drag.target: isEdit ? null : gridManager
        pressAndHoldInterval: 150
        onClicked: {
            console.log("click location : ", mouseX, mouseY)
            console.log("grid location : ", gridManager.getGridPosition(mouseX, mouseY))
            gridManager.gridClicked(gridManager.getGridPosition(mouseX, mouseY))
        }

        onPressAndHold: {
            console.log("click location : ", mouseX, mouseY)
            console.log("grid location : ", gridManager.getGridPosition(mouseX, mouseY))
            gridManager.gridPressed(gridManager.getGridPosition(mouseX, mouseY))
        }
    }

} 
