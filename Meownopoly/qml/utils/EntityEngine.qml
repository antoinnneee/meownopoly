pragma Singleton
import QtQuick
import ItemSnapable
import PhysicsEngine 1.0

Item {
    id: root

    // --- Configuration ---
    property var targetEntity: null
    property var logic: null
    property var view3D: null
    property var grid: null

    // Vitesse de déplacement en unités par seconde
    property real moveSpeed: 30.0
    property real sprintMultiplier: 2.0

    property real baseSpeed: moveSpeed
    property real baseSpeedMultiplier: isSprinting ? sprintMultiplier : 1.0

    // --- Physique 2D du mouvement ---
    property real acceleration: 2.0  // Accélération en unités de grille par seconde²
    
    // Position et vitesse en coordonnées de grille 2D (lecture depuis le moteur C++)
    property vector2d position2D: playerBody ? playerBody.position : Qt.vector2d(0, 0)
    property vector2d velocity: playerBody ? playerBody.velocity : Qt.vector2d(0, 0)
    
    // Paramètres de collision
    property real collisionRadius2D: 0.2  // Rayon de collision en unités de grille
    property real bounceFactor: 0.4          // Coefficient de rebond (0 = pas de rebond, 1 = rebond parfait)
    property real slideFactor: 1        // Conservation du glissement le long du mur
    
    // Référence aux zones d'exclusion (polygones de collision)
    property var physicZones: null

    // --- Camera Follow Configuration ---
    // Delegated to CameraController

    // --- État interne ---
    property vector2d inputVector: Qt.vector2d(0, 0)
    property bool isSprinting: false
    property bool freeCamMode: true // Nouveau mode FreeCam

    
    // --- Moteur Physique C++ ---
    PhysicsEngine2D {
        id: physicsEngine
        debugMode: true
    }
    
    // Corps physique du joueur
    property PhysicsBody2D playerBody: null

    // --- API Publique ---

    // Fonction pour définir le context
    function setContext(view3D, grid, logic) {
        root.view3D = view3D
        root.logic = logic

    }

    // Fonction pour définir la zone
    function setZone(zones) {
        root.physicZones = zones || null

        // Initialiser le moteur physique C++
        initPhysicsEngine(physicZones)
    }

    // Fonction pour définir la cible
    function setTarget(entity, view, grid, logic, zones) {
        targetEntity = entity
        view3D = view
        root.logic = logic
        physicZones = zones || null

        console.log("=== EntityEngine.setTarget ===")

        // Initialiser le CameraController
        CameraController.setTarget(entity, view3D, World3DTools.gridManager, logic)

        // Initialiser le moteur physique C++
            initPhysicsEngine(zones)
    }
    // Fonction pour définir la cible
    function setCameraTarget(entity) {
        targetEntity = entity
        CameraController.setTarget(entity, view3D, World3DTools.gridManager, logic)
        // Initialiser la position depuis l'entité 3D
        if (targetEntity) {
            var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
            var pos = World3DTools.position3dToGridRealPosition(targetEntity.x, 0, targetEntity.z)
            playerBody.position = pos
            console.log("[EntityEngine] Player initial position:", playerBody.position)
        }
    }

    // Initialisation du moteur physique C++
    function initPhysicsEngine(zones) {
        console.log("[EntityEngine] Initializing C++ physics engine...")
        
        // Créer le corps physique pour le joueur
        playerBody = physicsEngine.createBody("player")
        playerBody.collisionRadius = collisionRadius2D
        playerBody.bounceFactor = bounceFactor
        playerBody.slideFactor = slideFactor
        playerBody.acceleration = acceleration
        playerBody.maxSpeed = moveSpeed * sprintMultiplier
        
        // Configurer les zones depuis les snapables
        if (zones && zones.length > 0) {
            // Convertir en liste de QObject pour le moteur C++
            var snapablesList = []
            for (var i = 0; i < zones.length; i++) {
                if (zones[i] && zones[i].snapableParameters) {
                    snapablesList.push(zones[i].snapableParameters)
                }
            }
            physicsEngine.setZonesFromSnapables(snapablesList)
            console.log("[EntityEngine] Loaded", physicsEngine.zoneCount, "zones")
        }
        
        // Initialiser la position depuis l'entité 3D
        if (targetEntity) {
            var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
            var pos = World3DTools.position3dToGridRealPosition(targetEntity.x, 0, targetEntity.z)
            playerBody.position = pos
            console.log("[EntityEngine] Player initial position:", playerBody.position)
        }
        
        // Connecter les signaux
        playerBody.collisionOccurred.connect(onPlayerCollision)
        playerBody.enteredZone.connect(onPlayerEnteredZone)
        playerBody.exitedZone.connect(onPlayerExitedZone)
        
        console.log("[EntityEngine] C++ physics engine ready")
    }
    
    // Helper pour le timestamp
    function getTimestamp() {
        var now = new Date();
        var ms = now.getMilliseconds().toString().padStart(3, '0');
        return "[" + now.toLocaleTimeString(Qt.locale(), "HH:mm:ss") + "." + ms + "]";
    }
    
    // Callbacks de collision
    function onPlayerCollision(zone) {
        console.log(getTimestamp(), "[EntityEngine] Collision with zone:", zone.zoneId)
    }
    
    function onPlayerEnteredZone(zone) {
        console.log(getTimestamp(), "[EntityEngine] Entered zone:", zone.zoneId, "type:", zone.zoneType)
    }
    
    function onPlayerExitedZone(zone) {
        console.log(getTimestamp(), "[EntityEngine] Exited zone:", zone.zoneId)
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
            case Qt.Key_F:
                // Basculer le mode FreeCam
                freeCamMode = !freeCamMode
                CameraController.isFollowing = !freeCamMode // Si freeCam, on arrête de suivre
                if (!freeCamMode) {
                    console.log("[EntityEngine] FreeCam OFF")
                } else {
                    console.log("[EntityEngine] FreeCam ON")
                }
                break;
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

    function rotateEntity(dx, dz, dt) {
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
        var rotationSpeed = 50.0 * dt

        // Si on est très proche, on finit le mouvement pour éviter le jitter
        if (Math.abs(diff) < 1) {
            root.targetEntity.eulerRotation.y = targetAngle
        } else {
            root.targetEntity.eulerRotation.y = currentAngle + diff * rotationSpeed
        }
    }

    function updateInputVector() {
        var x = 0
        var y = 0
        if (keyLeft) x -= 1
        if (keyRight) x += 1
        if (keyUp) y -= 1
        if (keyDown) y += 1

        inputVector = Qt.vector2d(x, y)
        if (inputVector.length() > 1) {
            inputVector = inputVector.normalized()
        }
        playerBody.inputVector = inputVector
    }

    // ==================== PHYSIQUE C++ ====================
    
    /**
     * Met à jour la physique via le moteur C++
     * @param dt Delta time en secondes
     */
    function updatePhysicsCpp(dt) {
        if (!targetEntity || !playerBody) return
        
        // Mettre à jour la vitesse max selon le sprint
        playerBody.maxSpeed = baseSpeed * baseSpeedMultiplier
        
        // Mettre à jour toute la physique (collision, zones, etc.)
        physicsEngine.updateAll(dt)
        
        // Synchroniser avec l'entité 3D
        var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
        var pos3D =  World3DTools.gridPositionTo3D(playerBody.position.x, playerBody.position.y)//playerBody.getPosition3D(gridSize)
        targetEntity.x = pos3D.x
        targetEntity.z = pos3D.z
        
        // Faire tourner l'entité dans la direction du mouvement
        var vel = playerBody.velocity
        if (vel.length() > 0.1) {
            var dx = vel.x * gridSize * dt
            var dz = vel.y * gridSize * dt
            rotateEntity(dx, dz, dt)
        }
    }


    // --- Boucle de Mouvement ---
    FrameAnimation {
        id: movementLoop

        running: root.targetEntity !== null

        onTriggered: {
            if (!root.targetEntity) return

            var dt = frameTime

            if (root.freeCamMode) {
                CameraController.moveManual(inputVector.x, inputVector.y, baseSpeed * 10, dt)
            }
            else {
                // Utiliser le moteur C++ ou JS selon le flag
               if (playerBody)
                    updatePhysicsCpp(dt)
            }
        }
    }
}
