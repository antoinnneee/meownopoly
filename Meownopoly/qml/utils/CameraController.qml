pragma Singleton
import QtQuick
import QtQuick3D

Item {
    id: root

    // --- References ---
    property Node camera: null
    property Node target: null
    property Item grid2D: null
    property var view3D: null
    property var logic: null

    // --- Configuration ---
    property real smoothSpeed: 2.0
    property vector3d offset: Qt.vector3d(0, 0, 0)
    property bool isFollowing: false

    // --- Initialization ---
    function setTarget(newTarget, newView3D, newGrid2D, newLogic) {
        target = newTarget
        view3D = newView3D
        grid2D = newGrid2D
        logic = newLogic
        
        if (view3D && view3D.camera) {
            camera = view3D.camera
        }

        if (target && camera) {
            // Calculer l'offset pour centrer l'entité dans la vue
            // Pour une caméra orthographique inclinée, on doit compenser l'angle
            
            // Hauteur de la caméra (Y)
            var cameraHeight = camera.y
            
            // Angle de la caméra en radians (eulerRotation.x)
            var angleDeg = camera.eulerRotation.x // ex: -55
            var angleRad = angleDeg * Math.PI / 180
            
            // Calcul du décalage Z pour centrer l'entité
            // Le rayon de vue part de la caméra avec direction (0, sin(angle), -cos(angle))
            // Pour toucher Y=0: t = -cameraHeight / sin(angle)
            // Z_offset = t * (-cos(angle)) = cameraHeight * cos(angle) / sin(angle) = cameraHeight / tan(angle)
            var zOffset = -cameraHeight / Math.tan(angleRad)
            
            offset = Qt.vector3d(
                0,                  // X: caméra centrée horizontalement sur la cible
                cameraHeight,       // Y: hauteur de la caméra
                zOffset             // Z: décalage pour compenser l'angle et centrer la vue
            )
        }
    }

    // --- API de Contrôle ---
    function setSmoothSpeed(speed) {
        smoothSpeed = speed
    }

    function snapCameraToTarget() {
        if (target && camera) {
            camera.x = target.x + offset.x
            camera.y = target.y + offset.y
            camera.z = target.z + offset.z
        }
    }

    // Fonction pour déplacer manuellement la caméra (FreeCam)
    function moveManual(inputX, inputY, speed, dt) {
        if (!camera || !view3D || !grid2D) return
        
        // Calcul du déplacement monde (input Y -> -Z)
        var dx = inputX * speed * dt
        var dz = inputY * speed * dt
        
        if (dx === 0 && dz === 0) return

        // 1. Point de référence au sol (avant mouvement) pour sync grille
        // On projette la position actuelle de la caméra sur le plan Y=0 (approximatif)
        // Ou plus simple: on utilise le centre de l'écran projeté
        var centerScreen = Qt.point(view3D.width / 2, view3D.height / 2)
        
        // Calcul de la projection avant mouvement
        // Note: Pour une sync parfaite, il vaut mieux utiliser mapFrom3DScene d'un point fixe 3D
        // Prenons le point au sol devant la caméra
        var refPoint3D = Qt.vector3d(camera.x, 0, camera.z - 600) 
        var screenPosPre = view3D.mapFrom3DScene(refPoint3D)
        
        // 2. Déplacer la caméra
        camera.x += dx
        camera.z += dz
        
        // 3. Calcul de la projection après mouvement
        var screenPosPost = view3D.mapFrom3DScene(refPoint3D)
        
        // 4. Sync Grid 2D (Différence écran)
        var dxScreen = screenPosPost.x - screenPosPre.x
        var dyScreen = screenPosPost.y - screenPosPre.y
        
        grid2D.x += dxScreen
        grid2D.y += dyScreen
        
        // 5. Update MouseLogic
        if (root.logic && root.logic.mouseLogic) {
             root.logic.mouseLogic.lastGridPos = Qt.point(root.grid2D.x, root.grid2D.y)
        }
    }

    // --- Update Loop ---
    FrameAnimation {
        running: root.isFollowing && root.target !== null && root.camera !== null
        
        onTriggered: {
            var dt = frameTime
            
            // 1. Calculate screen movement for grid sync (Before camera move)
            var screenPosPre = Qt.point(0,0)
            // On a besoin de view3D pour faire les projections
            if (root.grid2D && root.view3D) {
                 screenPosPre = root.view3D.mapFrom3DScene(root.target.position)
            }

            // 2. Calculate Target Position
            var targetCamX = root.target.x + root.offset.x
            var targetCamY = root.target.y + root.offset.y
            var targetCamZ = root.target.z + root.offset.z
            
            // 3. Apply Smoothing (Lerp frame-rate independent)
            // Formule: value += (target - value) * (1 - exp(-speed * dt))
            var t = 1.0 - Math.exp(-root.smoothSpeed * dt)
            
            root.camera.x += (targetCamX - root.camera.x) * t
            root.camera.y += (targetCamY - root.camera.y) * t
            root.camera.z += (targetCamZ - root.camera.z) * t
            
            // 4. Sync Grid 2D
            if (root.grid2D && root.view3D) {
                // On regarde où se trouve la cible à l'écran APRÈS avoir bougé la caméra
                var screenPosPost = root.view3D.mapFrom3DScene(root.target.position)
                
                // La différence correspond au déplacement visuel des objets dans la vue
                var dxScreen = screenPosPost.x - screenPosPre.x
                var dyScreen = screenPosPost.y - screenPosPre.y
                
                root.grid2D.x += dxScreen
                root.grid2D.y += dyScreen

                // IMPORTANT : Mettre à jour le lastGridPos du MouseLogic pour éviter les conflits
                if (root.logic && root.logic.mouseLogic) {
                     root.logic.mouseLogic.lastGridPos = Qt.point(root.grid2D.x, root.grid2D.y)
                }
            }
        }
    }
}
