import QtQuick 2.15
import MapTypes
import EditorEnum
import ItemSnapableFactory

/**
 * Logique de souris pour le mode dessin de polygone (zones d'exclusion)
 * - Clic gauche : ajouter un point
 * - Clic droit ou double-clic : fermer le polygone et créer la zone
 * - Escape : annuler le dessin en cours
 */
MouseLogic_Base {
    id: mouseLogic

    // Points du polygone en cours de dessin (coordonnées de grille)
    property var currentPolygonPoints: []
    
    // Indique si on est en train de dessiner
    property bool isDrawing: false
    
    // Couleur de la zone en cours
    property string currentZoneColor: "#FF5722"
    
    // Référence au composant de prévisualisation (défini dans Editor.qml)
    property var polygonPreviewComponent: null
    
    // Signal pour notifier la création d'une zone
    signal exclusionZoneCreated(var snapableParameters)

    function pressedLeft(mouse, drag) {
        mouse.accepted = true
    }

    function pressedRight(mouse, drag) {
        mouse.accepted = true
    }

    function positionChanged(mouse, drag) {
        // Logique de base : mise à jour de la caméra
        updateCameraPosition()
        
        // Mettre à jour la position de la souris pour la prévisualisation
        var realPos = mainMa.mapToItem(grid, mouse.x, mouse.y)
        var gridPos = grid.getGridRealPosition(realPos.x, realPos.y)
        
        if (polygonPreviewComponent) {
            polygonPreviewComponent.mouseGridX = gridPos.x
            polygonPreviewComponent.mouseGridY = gridPos.y
        }
    }

    function clickedLeft(mouse, drag) {
        var realPos = mainMa.mapToItem(grid, mouse.x, mouse.y)
        var gridPos = grid.getGridRealPosition(realPos.x, realPos.y)
        
        // Ajouter le point au polygone
        currentPolygonPoints.push({ x: gridPos.x, y: gridPos.y })
        isDrawing = true
        
        console.log("Point ajouté:", gridPos.x, gridPos.y, "Total points:", currentPolygonPoints.length)
        
        // Mettre à jour la prévisualisation
        updatePolygonPreview()
        
        mouse.accepted = true
    }

    function clickedRight(mouse, drag) {
        // Fermer le polygone si on a au moins 3 points
        if (currentPolygonPoints.length >= 3) {
            createExclusionZone()
        } else {
            // Annuler le dessin
            cancelDrawing()
        }
        mouse.accepted = true
    }

    // Double-clic pour fermer le polygone
    function doubleClicked(mouse, drag) {
        if (currentPolygonPoints.length >= 3) {
            createExclusionZone()
        }
        mouse.accepted = true
    }

    function release(mouse, drag) {
        drag.target = null
    }

    function pressAndHold(mouse, drag) {
        mouse.accepted = true
    }

    function changeMouseMode(mode) {
        // Annuler le dessin en cours si on change de mode
        if (isDrawing) {
            cancelDrawing()
        }
        unselectSelectedElements()
        logic.editorMouseMode = mode
    }

    // Créer la zone d'exclusion avec les points actuels
    function createExclusionZone() {
        if (currentPolygonPoints.length < 3) {
            console.log("Pas assez de points pour créer une zone d'exclusion")
            return
        }
        
        console.log("Création de la zone d'exclusion avec", currentPolygonPoints.length, "points")
        
        // Créer l'ItemSnapable pour la zone d'exclusion
        var snapableParameters = ItemSnapableFactory.createExclusionZone()
        
        // Copier les points dans l'polygonParameter
        for (var i = 0; i < currentPolygonPoints.length; i++) {
            snapableParameters.polygonParameter.addPoint(
                currentPolygonPoints[i].x, 
                currentPolygonPoints[i].y
            )
        }
        
        // Définir la couleur (utiliser l'assignation de propriété, pas le setter)
        snapableParameters.polygonParameter.zoneColor = currentZoneColor
        
        // Calculer les bounds pour le displayParameter
        var bounds = calculateBounds(currentPolygonPoints)
        snapableParameters.displayParameter.gridRelativePositionX = Math.floor(bounds.minX)
        snapableParameters.displayParameter.gridRelativePositionY = Math.floor(bounds.minY)
        snapableParameters.displayParameter.unitSizeWidth = Math.ceil(bounds.maxX - bounds.minX) + 1
        snapableParameters.displayParameter.unitSizeHeight = Math.ceil(bounds.maxY - bounds.minY) + 1
        snapableParameters.displayParameter.zLayer = 1  // Sous les décorations et cases
        
        // Créer l'élément via TileLogic
        logic.tileLogic.createExclusionZone(snapableParameters)
        
        // Réinitialiser le dessin
        resetDrawing()
        
        // Sauvegarder
        logic.saveMap(MapTypes.UNDOREDO)
    }
    
    function calculateBounds(points) {
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
    
    // Annuler le dessin en cours
    function cancelDrawing() {
        console.log("Dessin annulé")
        resetDrawing()
        
        // Revenir au mode normal
        logic.editorMouseMode = EditorEnum.EM_NORMAL
    }
    
    // Réinitialiser l'état du dessin
    function resetDrawing() {
        currentPolygonPoints = []
        isDrawing = false
        hidePolygonPreview()
    }
    
    // Supprimer le dernier point (Ctrl+Z pendant le dessin)
    function undoLastPoint() {
        if (currentPolygonPoints.length > 0) {
            currentPolygonPoints.pop()
            updatePolygonPreview()
            
            if (currentPolygonPoints.length === 0) {
                isDrawing = false
            }
        }
    }
    
    // Mettre à jour la prévisualisation du polygone
    function updatePolygonPreview() {
        if (polygonPreviewComponent) {
            // Utiliser setPoints pour forcer le rafraîchissement
            if (polygonPreviewComponent.setPoints) {
                polygonPreviewComponent.setPoints(currentPolygonPoints.slice())
            } else {
                polygonPreviewComponent.points = currentPolygonPoints.slice()
            }
            polygonPreviewComponent.zoneColor = currentZoneColor
            polygonPreviewComponent.pointsVersion++
        }
    }
    
    // Masquer la prévisualisation
    function hidePolygonPreview() {
        if (polygonPreviewComponent) {
            if (polygonPreviewComponent.setPoints) {
                polygonPreviewComponent.setPoints([])
            } else {
                polygonPreviewComponent.points = []
            }
        }
    }
    
    // Définir la couleur de la zone
    function setZoneColor(color) {
        currentZoneColor = color
    }
}

