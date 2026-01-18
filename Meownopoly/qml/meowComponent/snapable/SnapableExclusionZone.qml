import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Shapes
import "../grid"

import ItemSnapable
import ZoneParameter

/**
 * Zone d'exclusion polygonale avec hachures
 * Visible uniquement en mode édition
 * Hérite de SnapableElement pour être compatible avec snapableTilesList
 */
SnapableElement {
    id: root

    // Désactiver le redimensionnement classique (on utilise les points du polygone)
    isResizable: false
    autoSnap: false
    
    // Visibilité conditionnelle : uniquement en mode édition
    visible: gridManager.isEdit
    opacity: isSelected ? 1.0 : 0.7
    
    // Couleur transparente pour le rectangle de base
    elementColor: "transparent"
    borderWidth: 0
    
    // Propriétés de style
    property color zoneColor: snapableParameters.zoneParameter ?
                              snapableParameters.zoneParameter.zoneColor : "#FF5722"
    property color strokeColor: Qt.darker(zoneColor, 1.3)
    property int zoneStrokeWidth: isSelected ? 3 : 2
    property real hatchSpacing: 12
    
    // Offset de l'élément en pixels (position de l'élément dans la grille)
    property real offsetX: snapableParameters.displayParameter.gridRelativePositionX * gridManager.gridSize
    property real offsetY: snapableParameters.displayParameter.gridRelativePositionY * gridManager.gridSize
    
    // Position de grille de l'élément (pour détecter les vrais déplacements, pas le zoom)
    property real gridPosX: snapableParameters.displayParameter.gridRelativePositionX
    property real gridPosY: snapableParameters.displayParameter.gridRelativePositionY
    
    // Stocker l'ancienne position de grille pour détecter les déplacements
    property real previousGridPosX: gridPosX
    property real previousGridPosY: gridPosY
    
    // Détecter les changements de position de grille (pas de zoom !)
    onGridPosXChanged: {
        if (Math.abs(gridPosX - previousGridPosX) > 0.001) {
            updatePolygonPointsAfterMove()
            previousGridPosX = gridPosX
        }
    }
    onGridPosYChanged: {
        if (Math.abs(gridPosY - previousGridPosY) > 0.001) {
            updatePolygonPointsAfterMove()
            previousGridPosY = gridPosY
        }
    }
    
    // Mettre à jour les points du polygone quand l'élément est déplacé
    function updatePolygonPointsAfterMove() {
        if (!snapableParameters.zoneParameter) return
        
        // Delta en coordonnées de grille (pas en pixels)
        var deltaGridX = gridPosX - previousGridPosX
        var deltaGridY = gridPosY - previousGridPosY
        
        if (Math.abs(deltaGridX) < 0.001 && Math.abs(deltaGridY) < 0.001) return
        
        var points = snapableParameters.zoneParameter.polygonPoints
        var newPoints = []
        for (var i = 0; i < points.length; i++) {
            newPoints.push({
                x: points[i].x + deltaGridX,
                y: points[i].y + deltaGridY
            })
        }
        snapableParameters.zoneParameter.polygonPoints = newPoints
    }
    
    // Calcul des bounds du polygone (en coordonnées locales)
    property var polygonBounds: ({ minX: 0, minY: 0, maxX: 100, maxY: 100 })
    
    // Bounds en coordonnées de grille (caching pour éviter de recalculer à chaque zoom/scroll)
    property var gridBounds: ({ minX: 0, minY: 0, maxX: 0, maxY: 0 })
    
    // Cache pour les points locaux en pixels
    property var localPointsCache: []
    
    // Forcer le redraw au chargement
    Component.onCompleted: {
        root.gridBounds = root.calculateGridBounds()
        root.updateRecalculate()
        hatchCanvas.requestPaint()
    }
    
    function calculateGridBounds() {
        if (!snapableParameters.zoneParameter) return { minX: 0, minY: 0, maxX: 0, maxY: 0 }
        var points = snapableParameters.zoneParameter.polygonPoints
        if (points.length === 0) return { minX: 0, minY: 0, maxX: 0, maxY: 0 }
        
        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y
        
        for (var i = 1; i < points.length; i++) {
            minX = Math.min(minX, points[i].x)
            maxX = Math.max(maxX, points[i].x)
            minY = Math.min(minY, points[i].y)
            maxY = Math.max(maxY, points[i].y)
        }
        
        return { minX: minX, minY: minY, maxX: maxX, maxY: maxY }
    }
    
    function updatePixelBounds() {
        var gs = gridManager.gridSize
        var ox = offsetX
        var oy = offsetY
        root.polygonBounds = {
            minX: gridBounds.minX * gs - ox,
            minY: gridBounds.minY * gs - oy,
            maxX: gridBounds.maxX * gs - ox,
            maxY: gridBounds.maxY * gs - oy
        }
    }
    
    // Convertir les points de grille en pixels LOCAUX (relatifs à l'élément)
    function getPolygonPointsLocal() {
        var points = []
        if (!snapableParameters.zoneParameter) return points
        
        var gridPoints = snapableParameters.zoneParameter.polygonPoints
        for (var i = 0; i < gridPoints.length; i++) {
            var pt = gridPoints[i]
            // Convertir en pixels et soustraire l'offset de l'élément
            var px = pt.x * gridManager.gridSize - offsetX
            var py = pt.y * gridManager.gridSize - offsetY
            points.push(Qt.point(px, py))
        }
        return points
    }
    
    // Obtenir les points pour le ShapePath (fermé)
    function getClosedPolygonPoints() {
        var points = localPointsCache
        if (points.length > 0) {
            // Créer une copie pour ne pas corrompre le cache si on ajoute un point
            var closed = points.slice()
            closed.push(points[0]) 
            return closed
        }
        return points
    }
    
    // Override isTransparent pour utiliser la détection polygonale
    function isTransparent(mouse) {
        return !isPointInPolygon(mouse.x, mouse.y)
    }
    
    // Fonction pour vérifier si un point est dans le polygone (ray casting)
    function isPointInPolygon(px, py) {
        var points = localPointsCache
        if (points.length < 3) return false
        
        var inside = false
        var j = points.length - 1
        
        for (var i = 0; i < points.length; i++) {
            var xi = points[i].x, yi = points[i].y
            var xj = points[j].x, yj = points[j].y
            
            if (((yi > py) !== (yj > py)) && 
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    // Compteur pour forcer la mise à jour de la Shape
    property int shapeUpdateTrigger: 0
    
    // Fonction pour regrouper le recalcul et le trigger de mise à jour
    function updateRecalculate() {
        // Mettre à jour les points locaux et les pixel bounds (O(1) transformation)
        root.localPointsCache = root.getPolygonPointsLocal()
        root.updatePixelBounds()
        root.shapeUpdateTrigger++
    }

    // Timer pour débouncer le recalcul et le repaint
    Timer {
        id: redrawTimer
        interval: 10
        repeat: false
        
        onTriggered: {
            root.updateRecalculate()
            hatchCanvas.requestPaint()
        }
    }
    
    // Shape pour le polygone
    Shape {
        id: polygonShape
        anchors.fill: parent
        z: 1
        
        // Propriété pour forcer la mise à jour
        property int updateTrigger: root.shapeUpdateTrigger
        
        // Contour du polygone
        ShapePath {
            id: outlinePath
            strokeColor: root.strokeColor
            strokeWidth: root.zoneStrokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            PathPolyline {
                path: {
                    // Dépendance explicite pour forcer le recalcul
                    var trigger = polygonShape.updateTrigger
                    var gs = root.gridManager.gridSize
                    var ox = root.offsetX
                    var oy = root.offsetY
                    return root.getClosedPolygonPoints()
                }
            }
        }
    }
    
    // Canvas pour les hachures diagonales
    Canvas {
        id: hatchCanvas
        anchors.fill: parent
        z: 0
        
        onPaint: {
            // Si le timer est en cours, on le stoppe et on fait le calcul maintenant
            // car on est déjà en train de peindre (probablement dû à un resize système)
            if (redrawTimer.running) {
                root.updateRecalculate()
                redrawTimer.stop()
            }
            
            var ctx = getContext("2d")
            ctx.reset()
            
            var points = root.getPolygonPointsLocal()
            if (points.length < 3) return
            
            // Créer le chemin du polygone pour le clipping
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)
            for (var i = 1; i < points.length; i++) {
                ctx.lineTo(points[i].x, points[i].y)
            }
            ctx.closePath()
            
            // Remplissage semi-transparent
            ctx.fillStyle = Qt.rgba(
                root.zoneColor.r, 
                root.zoneColor.g, 
                root.zoneColor.b, 
                0.15
            )
            ctx.fill()
            
            // Appliquer le clip pour les hachures
            ctx.save()
            ctx.clip()
            
            // Dessiner les hachures diagonales (batching)
            ctx.strokeStyle = root.zoneColor
            ctx.lineWidth = 1.5
            ctx.globalAlpha = 0.6
            
            var bounds = root.polygonBounds
            var diagonal = Math.sqrt(Math.pow(bounds.maxX - bounds.minX, 2) + 
                                    Math.pow(bounds.maxY - bounds.minY, 2))
            var spacing = root.hatchSpacing
            
            ctx.beginPath()
            // Hachures de gauche à droite (/)
            for (var offset = -diagonal; offset < diagonal * 2; offset += spacing) {
                ctx.moveTo(bounds.minX + offset, bounds.minY)
                ctx.lineTo(bounds.minX + offset - diagonal, bounds.minY + diagonal)
            }
            ctx.stroke()
            
            ctx.restore()
        }
        
        // Redessiner quand les points changent
        Connections {
            target: root.snapableParameters.zoneParameter
            function onPolygonPointsChanged() {
                root.gridBounds = root.calculateGridBounds()
                root.updateRecalculate()
                hatchCanvas.requestPaint()
            }
        }
        
        // Redessiner quand la couleur change
        Connections {
            target: root.snapableParameters.zoneParameter
            function onZoneColorChanged() {
                hatchCanvas.requestPaint()
            }
        }
        
        // Redessiner quand la grille change (taille ou scale)
        Connections {
            target: root.gridManager
            function onGridSizeChanged() {
                redrawTimer.restart()
            }
            function onScaleLevelChanged() {
                redrawTimer.restart()
            }
        }
        
        // Redessiner quand l'offset change (scroll/déplacement)
        Connections {
            target: root
            function onOffsetXChanged() {
                redrawTimer.restart()
            }
            function onOffsetYChanged() {
                redrawTimer.restart()
            }
        }
    }
    
    // Points de contrôle pour l'édition (visibles quand sélectionné)
    // Utiliser un modèle basé sur le nombre de points pour éviter la recréation pendant le drag
    Repeater {
        id: controlPointsRepeater
        model: root.isSelected ? root.getPointCount() : 0
        
        delegate: Rectangle {
            id: controlPoint
            
            // Index du point
            readonly property int pointIndex: index
            
            // Position du point (relue à chaque changement)
            property real pointGridX: root.getPointX(pointIndex)
            property real pointGridY: root.getPointY(pointIndex)
            
            // Position initiale pour le drag
            property real dragStartX: 0
            property real dragStartY: 0
            property real dragStartGridX: 0
            property real dragStartGridY: 0
            property bool isDragging: false
            
            width: 12
            height: 12
            radius: 6
            color: isDragging ? Qt.lighter(root.zoneColor, 1.3) : root.zoneColor
            border.color: "white"
            border.width: 2
            z: 100
            
            // Position en coordonnées locales (relative à l'élément)
            // Pendant le drag, on utilise la position visuelle directe
            x: isDragging ? x : (pointGridX * root.gridManager.gridSize - root.offsetX - width / 2)
            y: isDragging ? y : (pointGridY * root.gridManager.gridSize - root.offsetY - height / 2)
            
            Drag.active: dragArea.drag.active
            
            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                drag.target: parent
                drag.threshold: 0
                
                onPressed: function(mouse) {
                    controlPoint.isDragging = true
                    controlPoint.dragStartX = controlPoint.x
                    controlPoint.dragStartY = controlPoint.y
                    controlPoint.dragStartGridX = controlPoint.pointGridX
                    controlPoint.dragStartGridY = controlPoint.pointGridY
                    mouse.accepted = true
                }
                
                onReleased: function(mouse) {
                    if (controlPoint.isDragging) {
                        // Calculer la nouvelle position en coordonnées de grille
                        var newLocalX = controlPoint.x + controlPoint.width / 2
                        var newLocalY = controlPoint.y + controlPoint.height / 2
                        var newGridX = (newLocalX + root.offsetX) / root.gridManager.gridSize
                        var newGridY = (newLocalY + root.offsetY) / root.gridManager.gridSize
                        /*
                        if (newLocalX < 0) {
                            var xoffset = Math.floor(-newLocalX / root.gridManager.gridSize) +1
                            newGridX = newGridX - xoffset
                            console.log("xoffset : " + xoffset + "gridSize : " + root.gridManager.gridSize)
                        }
                        if (newLocalY < 0) {
                            var yoffset = Math.floor(-newLocalY / root.gridManager.gridSize) +1
                            newGridY = newGridY - yoffset
                            console.log("yoffset : " + yoffset)
                        }
                        */
                        
                        console.log("newLocalX : " + newLocalX + " : " + newLocalY)
                        console.log("newGridX : " + newGridX + " : " + newGridY)

                        
                        // Mettre à jour le point dans les données
                        root.updatePointPosition(controlPoint.pointIndex, newGridX, newGridY)
                        
                        controlPoint.isDragging = false
                    }
                }
            }
        }
    }
    
    // Fonctions helper pour accéder aux points sans déclencher de binding loops
    function getPointCount() {
        if (!snapableParameters.zoneParameter) return 0
        return snapableParameters.zoneParameter.polygonPoints.length
    }
    
    function getPointX(idx) {
        if (!snapableParameters.zoneParameter) return 0
        var points = snapableParameters.zoneParameter.polygonPoints
        if (idx >= 0 && idx < points.length) {
            return points[idx].x
        }
        return 0
    }
    
    function getPointY(idx) {
        if (!snapableParameters.zoneParameter) return 0
        var points = snapableParameters.zoneParameter.polygonPoints
        if (idx >= 0 && idx < points.length) {
            return points[idx].y
        }
        return 0
    }
    
    function updatePointPosition(idx, newX, newY) {
        console.log("updatePointPosition : " + idx + " : " + newX + ", " + newY)
        if (!snapableParameters.zoneParameter) return
        var points = snapableParameters.zoneParameter.polygonPoints
        if (idx >= 0 && idx < points.length) {
            var newPoints = []
            for (var i = 0; i < points.length; i++) {
                if (i === idx) {
                    newPoints.push({ x: newX, y: newY })
                } else {
                    newPoints.push({ x: points[i].x, y: points[i].y })
                }
            }
            snapableParameters.zoneParameter.polygonPoints = newPoints
            
            // Recalculer les grid bounds
            root.gridBounds = root.calculateGridBounds()
            
            // Recalculer la bounding box de l'élément
            updateDisplayBounds()
        }
    }
    
    // Mettre à jour les bounds du displayParameter après modification des points
    function updateDisplayBounds() {
        if (!snapableParameters.zoneParameter) return
        var points = snapableParameters.zoneParameter.polygonPoints
        if (points.length === 0) return
        
        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y
        
        for (var i = 1; i < points.length; i++) {
            minX = Math.min(minX, points[i].x)
            maxX = Math.max(maxX, points[i].x)
            minY = Math.min(minY, points[i].y)
            maxY = Math.max(maxY, points[i].y)
        }
        console.log("updateDisplayBounds : " + minX + ", " + minY + " : " + maxX + ", " + maxY)
        console.log("ceil x : " + Math.ceil(maxX - minX) + " y : " + Math.ceil(maxY - minY))
        // Mettre à jour les previous positions de grille AVANT de changer le displayParameter
        // pour éviter que onGridPosXChanged/onGridPosYChanged ne déplace les points
        var newGridPosX = Math.floor(minX)
        var newGridPosY = Math.floor(minY)
        previousGridPosX = newGridPosX
        previousGridPosY = newGridPosY
        
        // Mettre à jour le displayParameter
        snapableParameters.displayParameter.gridRelativePositionX = newGridPosX
        snapableParameters.displayParameter.gridRelativePositionY = newGridPosY
        snapableParameters.displayParameter.unitSizeWidth = Math.ceil(maxX) - newGridPosX
        snapableParameters.displayParameter.unitSizeHeight = Math.ceil(maxY) - newGridPosY
    }
    
    // Indicateur de nom de zone (optionnel)
    Text {
        id: zoneLabel
        visible: root.isSelected && root.snapableParameters.zoneParameter &&
                 root.snapableParameters.zoneParameter.zoneName !== ""
        text: root.snapableParameters.zoneParameter ? root.snapableParameters.zoneParameter.zoneName : ""
        color: "white"
        font.pixelSize: 14
        font.bold: true
        z: 101
        
        x: root.polygonBounds.minX + 5
        y: root.polygonBounds.minY + 5
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            color: Qt.rgba(0, 0, 0, 0.6)
            radius: 3
            z: -1
        }
    }
}
