import QtQuick 2.15

MouseLogic_Base {
    id: mouseLogic
    property var targetEntity
    property var view3D
    property var editorGrid

    function pressedLeft(mouse, drag)
    {
        positionChanged(mouse, drag)
        targetEntity.visible = true
        // Map coordinates from MouseArea to View3D local coordinates
        var pointInView = mainMa.mapToItem(view3D, mouse.x, mouse.y)

        // Calculate 3D position
        var pos3D = getGroundIntersection(pointInView.x, pointInView.y)

        // Apply position
        updateEntityPosition(pos3D)
    }

    function positionChanged(mouse, drag)
    {
        if (!view3D || !targetEntity) return

        // Map coordinates from MouseArea to View3D local coordinates
        var pointInView = mainMa.mapToItem(view3D, mouse.x, mouse.y)

        // Calculate 3D position
        //var pos3D = getGroundIntersection(pointInView.x, pointInView.y)
        
        // Apply position
        //updateEntityPosition(pos3D)
    }

    // Fonction utilitaire pour déplacer l'entité à une position spécifique de la grille (en pixels)
    function moveEntityToGridPosition(gridX, gridY) {
        if (!view3D || !targetEntity || !editorGrid) return

        var gridPos = editorGrid.getGridPixelPosition(gridX, gridY)
        // Convertir les coordonnées de la grille vers la vue 3D
        var pointInView = editorGrid.mapToItem(view3D, gridPos.x, gridPos.y)

        // Calculer la position 3D correspondante
        var pos3D = getGroundIntersection(pointInView.x, pointInView.y)
        console.log(pos3D)

        // Appliquer la position
        updateEntityPosition(pos3D)
    }

    // Fonction utilitaire pour déplacer l'entité à une position spécifique de la grille (en pixels)
    function moveEntityToGridPixelPosition(gridX, gridY) {
        if (!view3D || !targetEntity || !editorGrid) return

        // Convertir les coordonnées de la grille vers la vue 3D
        var pointInView = editorGrid.mapToItem(view3D, gridX, gridY)
        
        // Calculer la position 3D correspondante
        var pos3D = getGroundIntersection(pointInView.x, pointInView.y)
        
        // Appliquer la position
        updateEntityPosition(pos3D)
    }

    // Calcule l'intersection avec le sol (Y=0) depuis un point de la vue
    function getGroundIntersection(viewX, viewY) {
        // Get point in 3D scene (on camera near plane)
        var scenePos = view3D.mapTo3DScene(Qt.point(viewX, viewY))

        // Ray-Plane Intersection Calculation for camera rotated -55 degrees around X
        var angleDeg = -55
        var rad = angleDeg * Math.PI / 180

        var fx = 0
        var fy = Math.sin(rad)
        var fz = -Math.cos(rad)

        var targetX = scenePos.x
        var targetZ = scenePos.z

        if (Math.abs(fy) > 0.0001) {
            var t = -scenePos.y / fy
            targetX = scenePos.x + t * fx
            targetZ = scenePos.z + t * fz
        }
        
        return Qt.vector3d(targetX, 0, targetZ)
    }

    function updateEntityPosition(pos3D) {
        targetEntity.x = pos3D.x
        targetEntity.y = pos3D.y
        targetEntity.z = pos3D.z
    }

    Component.onCompleted: {
        targetEntity = logic.parent.entity
        view3D = logic.parent.view3D
        editorGrid = logic.editorGrid
    }
}
