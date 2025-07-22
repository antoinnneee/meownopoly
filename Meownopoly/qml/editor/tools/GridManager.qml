import QtQuick 2.15
import QtQuick.Controls

Item {
    id: gridManager
    
    // Propriétés configurables
    property int mmSize: 20
    property int gridSize: Screen.pixelDensity * mmSize
    property color gridColor: "#40808080"
    property real gridOpacity: 0.5
    property bool showGrid: true
    property bool snapToGrid: true
    property int lineWidth: 1
    
    // Propriétés en lecture seule pour accès externe
    readonly property int snapSize: gridSize
    
    // Signal émis quand les paramètres changent
    signal gridSettingsChanged()
    
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
    
    // Canvas pour dessiner la grille
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: showGrid
        opacity: gridOpacity
        
        onPaint: {
            if (!showGrid) return
            
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            ctx.strokeStyle = gridColor
            ctx.lineWidth = lineWidth
            
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
            function onGridSizeChanged() { gridCanvas.requestPaint() }
            function onGridColorChanged() { gridCanvas.requestPaint() }
            function onShowGridChanged() { gridCanvas.requestPaint() }
            function onLineWidthChanged() { gridCanvas.requestPaint() }
        }
    }
    
    // Panneau de contrôle de la grille (optionnel, peut être masqué)
    Rectangle {
        id: gridControlPanel
        width: 200
        height: 150
        color: "#f0f0f0"
        border.color: "#cccccc"
        border.width: 1
        radius: 5
        visible: false
        
        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            Text {
                text: "Paramètres de grille"
                font.bold: true
            }
            
            Row {
                spacing: 10
                Text { text: "Taille:" }
                SpinBox {
                    from: 5
                    to: 100
                    stepSize: 5
                    value: gridManager.mmSize
                    onValueChanged: mmSize = value
                }
            }
            
            Row {
                spacing: 10
                Text { text: "Afficher grille:" }
                CheckBox {
                    checked: gridManager.showGrid
                    onCheckedChanged: showGrid = checked
                }
            }
            
            Row {
                spacing: 10
                Text { text: "Snap à la grille:" }
                CheckBox {
                    checked: gridManager.snapToGrid
                    onCheckedChanged: snapToGrid = checked
                }
            }
            
            Row {
                spacing: 10
                Text { text: "Opacité:" }
                Slider {
                    from: 0.1
                    to: 1.0
                    value: gridManager.gridOpacity
                    onValueChanged: gridOpacity = value
                }
            }
        }
    }
    
    // Fonction pour afficher/masquer le panneau de contrôle
    function toggleControlPanel() {
        gridControlPanel.visible = !gridControlPanel.visible
    }
} 
