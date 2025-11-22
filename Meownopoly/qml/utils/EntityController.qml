pragma Singleton
import QtQuick

Item {
    id: root

    // --- Configuration ---
    property var targetEntity: null
    property var logic: null
    property var view3D: null

    // Vitesse de déplacement en unités par seconde
    property real moveSpeed: 500.0
    property real sprintMultiplier: 2.0

    // --- Camera Follow Configuration ---
    property real cameraSmoothSpeed: 2.0
    property vector3d cameraOffset: Qt.vector3d(0, 0, 0)
    property Item grid2D: null

    // --- État interne ---
    property vector2d inputVector: Qt.vector2d(0, 0)
    property bool isSprinting: false
    property real lastTimestamp: 0

    // --- API Publique ---

    // Fonction pour définir la cible
    function setTarget(entity, view, grid, logic) {
        targetEntity = entity
        view3D = view
        grid2D = grid
        root.logic = logic
        
        // Initialiser l'offset de la caméra par rapport à l'entité
        if (targetEntity && view3D && view3D.camera) {
            cameraOffset = Qt.vector3d(
                view3D.camera.x - targetEntity.x,
                view3D.camera.y - targetEntity.y,
                view3D.camera.z - targetEntity.z
            )
        }
    }

    // --- Gestion Clavier ---
    // Cette propriété doit recevoir le focus ou être appelée depuis un Item focusable
    property Item keysHandler: Item {
        focus: true
        Keys.onPressed: (event) => { root.handleKeyPress(event) }
        Keys.onReleased: (event) => { root.handleKeyRelease(event) }
    }

    // État des touches
    property bool keyUp: false
    property bool keyDown: false
    property bool keyLeft: false
    property bool keyRight: false

    function handleKeyPress(event) {
        if (event.isAutoRepeat) return

        switch(event.key) {
            case Qt.Key_Z:
            case Qt.Key_Up:
                keyUp = true; break;
            case Qt.Key_S:
            case Qt.Key_Down:
                keyDown = true; break;
            case Qt.Key_Q:
            case Qt.Key_Left:
                keyLeft = true; break;
            case Qt.Key_D:
            case Qt.Key_Right:
                keyRight = true; break;
            case Qt.Key_Shift:
                isSprinting = true; break;
        }
        updateInputVector()
    }

    function handleKeyRelease(event) {
        if (event.isAutoRepeat) return

        switch(event.key) {
            case Qt.Key_Z:
            case Qt.Key_Up:
                keyUp = false; break;
            case Qt.Key_S:
            case Qt.Key_Down:
                keyDown = false; break;
            case Qt.Key_Q:
            case Qt.Key_Left:
                keyLeft = false; break;
            case Qt.Key_D:
            case Qt.Key_Right:
                keyRight = false; break;
            case Qt.Key_Shift:
                isSprinting = false; break;
        }
        updateInputVector()
    }

    function updateInputVector() {
        // Priorité au Gamepad s'il est actif (à faire), sinon Clavier
        var x = 0
        var y = 0
        if (keyLeft) x -= 1
        if (keyRight) x += 1
        if (keyUp) y += 1   // En 2D "Up" est souvent Y-, mais en logique de déplacement on veut "Avancer"
        if (keyDown) y -= 1

        // Normalisation pour éviter d'aller plus vite en diagonale
        inputVector = Qt.vector2d(x, y)
        if (inputVector.length() > 1) {
            inputVector = inputVector.normalized()
        }
    }


    // --- Boucle de Mouvement ---
    FrameAnimation {
        id: movementLoop
        running: root.targetEntity !== null

        onTriggered: {
            if (!root.targetEntity) return

            var dt = frameTime

            // --- 1. Déplacement du Personnage ---
            if (inputVector.length() > 0) {
                // Vitesse actuelle
                var speed = root.moveSpeed * (root.isSprinting ? root.sprintMultiplier : 1.0)

                // Calcul du déplacement local (X = droite, Y = avant)
                // Mais attention, dans le monde 3D QtQuick3D:
                // X = Droite
                // Y = Haut (Ciel)
                // Z = Profondeur (Sort de l'écran) -> -Z est "Avant"

                // Simplification pour vue Top-Down :
                // Input X -> World X
                // Input Y -> World -Z (Avancer vers le fond)

                var dx = inputVector.x * speed * dt
                var dz = -inputVector.y * speed * dt // Avancer (Y+) = aller vers Z négatif

                // Appliquer le déplacement
                root.targetEntity.x += dx
                root.targetEntity.z += dz

                // Rotation du personnage vers la direction du mouvement (optionnel mais cool)
                if (dx !== 0 || dz !== 0) {
                    // 1. Calcul de l'angle cible en degrés
                    // atan2(x, z) donne l'angle par rapport au Nord (Z)
                    var targetAngle = Math.atan2(dx, dz) * 180 / Math.PI
                    
                    // 2. Récupérer l'angle actuel
                    var currentAngle = root.targetEntity.eulerRotation.y
                    
                    // 3. Calculer la différence la plus courte (Shortest path interpolation)
                    var diff = targetAngle - currentAngle
                    
                    // Normaliser la différence entre -180 et 180 pour éviter les tours complets inutiles
                    while (diff < -180) diff += 360
                    while (diff > 180) diff -= 360
                    
                    // 4. Appliquer le lissage (Lerp)
                    // Le facteur 10.0 * dt donne une rotation rapide mais fluide
                    var rotationSpeed = 15.0 * dt 
                    
                    // Si on est très proche, on finit le mouvement pour éviter le jitter
                    if (Math.abs(diff) < 1) {
                        root.targetEntity.eulerRotation.y = targetAngle
                    } else {
                        root.targetEntity.eulerRotation.y = currentAngle + diff * rotationSpeed
                    }
                }
            }

            // --- 2. Camera Follow Logic (Smooth) ---
            if (root.view3D && root.view3D.camera) {
                var cam = root.view3D.camera
                
                // Pour synchroniser la grille 2D, on calcule le déplacement écran
                // On regarde où se trouve la cible à l'écran AVANT de bouger la caméra
                var screenPosPre = root.view3D.mapFrom3DScene(root.targetEntity.position)

                // Position idéale de la caméra (Target + Offset initial)
                var targetCamX = root.targetEntity.x + root.cameraOffset.x
                var targetCamZ = root.targetEntity.z + root.cameraOffset.z
                
                // Facteur de lissage (Lerp indépendant du framerate)
                var t = 1.0 - Math.exp(-root.cameraSmoothSpeed * dt)
                
                // Appliquer le mouvement à la caméra
                cam.x += (targetCamX - cam.x) * t
                cam.z += (targetCamZ - cam.z) * t
                
                // Synchronisation de la grille 2D (Grid/Map)
                if (root.grid2D) {
                    // On regarde où se trouve la cible à l'écran APRÈS avoir bougé la caméra
                    var screenPosPost = root.view3D.mapFrom3DScene(root.targetEntity.position)
                    
                    // La différence correspond au déplacement visuel des objets dans la vue
                    // La grille doit suivre ce même déplacement pour rester calée
                    var dxScreen = screenPosPost.x - screenPosPre.x
                    var dyScreen = screenPosPost.y - screenPosPre.y
                    
                    root.grid2D.x += dxScreen
                    root.grid2D.y += dyScreen

                    // IMPORTANT : Mettre à jour le lastGridPos du MouseLogic
                    if ( root.logic && root.logic.mouseLogic) {
                         root.logic.mouseLogic.lastGridPos = Qt.point(root.grid2D.x, root.grid2D.y)
                    }
                }
            }
        }
    }
}

