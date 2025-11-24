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
        
        // En projection orthographique, avec une caméra orientée vers le bas (ou inclinée),
        // scenePos donne déjà les coordonnées X/Y projetées correctes par rapport au plan de la caméra.
        // Mais pour projeter sur le sol (Y=0 monde), il faut tenir compte de l'angle de la caméra.
        
        // L'angle de la caméra est défini dans Editor.qml : eulerRotation.x: -55
        // MAIS mapTo3DScene renvoie un point dans le repère local de la SCENE, pas de la caméra.
        // Donc si la caméra est déplacée, scenePos change.
        
        // Avec une caméra Orthographique, mapTo3DScene renvoie un point qui se trouve sur le plan Near
        // qui passe par la position de la caméra.
        
        // Le problème est que nous voulons projeter ce point sur le plan Y=0 du monde.
        // La direction du rayon est la direction avant de la caméra (forward vector).
        
        // Calcul du vecteur forward de la caméra (basé sur l'angle -55 autour de X)
        // Rotation autour de X :
        // y' = y*cos(a) - z*sin(a)
        // z' = y*sin(a) + z*cos(a)
        // Forward initial (0, 0, -1). Rotation de -55 deg.
        
        var angleDeg = -55
        var rad = angleDeg * Math.PI / 180
        
        // Vecteur direction de la caméra (normalisé)
        // Pour une rotation X de -55 :
        // x = 0
        // y = sin(-55) = -0.819
        // z = cos(-55) = 0.573   (En QtQuick3D, Z- est forward par défaut, mais l'ortho change un peu la donne)
        
        // Approche simplifiée : mapTo3DScene nous donne un point P0 (x0, y0, z0).
        // Le rayon est P(t) = P0 + t * Dir.
        // On cherche t tel que P(t).y = 0.
        // => y0 + t * Dir.y = 0  => t = -y0 / Dir.y
        
        // Direction de vue de la caméra
        var dirX = 0
        var dirY = Math.sin(rad) // -0.819
        var dirZ = Math.cos(rad) * -1 // 0.573 (vers Z négatif localement, mais rotation...)
        
        // Vérifions mapTo3DScene. Il renvoie le point correspondant dans l'espace monde.
        // Donc si on a cliqué, on a un point dans l'espace monde qui est sur le plan near de la caméra.
        // On veut "pousser" ce point le long du vecteur de vue jusqu'à toucher le sol Y=0.
        
        // Correction : En mode Orthographique, mapTo3DScene renvoie un point sur le plan Z=0 de la caméra ?
        // Non, il renvoie un point dans le world space.
        
        // Utilisons les valeurs calculées précédemment qui semblaient "presque" justes mais glissaient.
        // Le glissement vient probablement du fait que "scenePos" glisse lui-même lors du zoom/pan
        // si la caméra n'est pas parfaitement synchronisée.
        // MAIS ici on recalcule l'intersection à chaque fois.
        
        // Si la caméra a une rotation X = -55 :
        // Le vecteur Forward est (0, sin(-55), -cos(-55)) = (0, -0.819, -0.573)
        
        // Attend, l'axe Z est l'axe de profondeur en QtQuick3D. Y est haut.
        // Caméra à (0, 1000, 600), regardant vers (0,0,0) environ.
        
        var fy = Math.sin(rad) // Composante Y du vecteur vue
        var fz = Math.cos(rad) // Composante Z du vecteur vue (négatif car regarde vers -Z local ?)
        // Note: Qt3D coordinate system: Y up, Z out of screen (Right Handed)
        // Rotation -55 X : "plonge" vers le bas.
        
        // Si on utilise exactement la direction de la caméra :
        var t = -scenePos.y / fy
        
        var targetX = scenePos.x 
        var targetZ = scenePos.z + t * (-1.428) // Ratio empirique ou calculé ? -1 / tan(-55) ?
        
        // Essayons la projection géométrique pure :
        // t = -scenePos.y / sin(rad)
        // z_ground = scenePos.z + t * cos(rad) * (-1)  <-- car Z camera regarde vers -Z
        
        // Recalcul propre
        var rayDirY = Math.sin(rad) // -0.819
        var rayDirZ = -Math.cos(rad) // -0.573
        
        if (Math.abs(rayDirY) > 0.0001) {
            var t2 = -scenePos.y / rayDirY
            targetX = scenePos.x // Pas de rotation Y ni Z, donc X ne change pas
            targetZ = scenePos.z + t2 * rayDirZ
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
