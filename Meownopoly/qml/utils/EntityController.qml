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

    // Vitesse de déplacement en unités par seconde
    property real moveSpeed: 18.0
    property real sprintMultiplier: 2.0

    property real baseSpeed: moveSpeed
    property real baseSpeedMultiplier: isSprinting ? sprintMultiplier : 1.0

    // --- Physique 2D du mouvement ---
    property real acceleration: 30.0  // Accélération en unités de grille par seconde²
    property real friction:  0.0       // Friction au sol (force de décélération)
    
    // Position et vitesse en coordonnées de grille 2D (lecture depuis le moteur C++)
    property vector2d position2D: playerBody ? playerBody.position : Qt.vector2d(0, 0)
    property vector2d velocity: playerBody ? playerBody.velocity : Qt.vector2d(0, 0)
    
    // Paramètres de collision
    property real collisionRadius2D: 0.2  // Rayon de collision en unités de grille
    property real bounceFactor: 0.1          // Coefficient de rebond (0 = pas de rebond, 1 = rebond parfait)
    property real slideFactor: 1        // Conservation du glissement le long du mur
    
    // Référence aux zones d'exclusion (polygones de collision)
    property var exclusionZones: null

    // --- Camera Follow Configuration ---
    // Delegated to CameraController

    // --- État interne ---
    property vector2d inputVector: Qt.vector2d(0, 0)
    property bool isSprinting: false
    property bool freeCamMode: true // Nouveau mode FreeCam
    property real lastTimestamp: 0
    
    // --- Mode du moteur physique ---
    property bool useCppPhysics: true  // Basculer entre C++ et JS
    
    // --- Moteur Physique C++ ---
    PhysicsEngine2D {
        id: physicsEngine
        gridSize: World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
        friction: root.friction
        debugMode: true
    }
    
    // Corps physique du joueur
    property PhysicsBody2D playerBody: null

    // --- API Publique ---

    // Fonction pour définir la cible
    function setTarget(entity, view, grid, logic, zones) {
        targetEntity = entity
        view3D = view
        root.logic = logic
        exclusionZones = zones || null

        console.log("=== EntityController.setTarget ===")

        // Initialiser le CameraController
        CameraController.setTarget(entity, view, grid, logic)
        
        // Initialiser le moteur physique C++
        if (useCppPhysics) {
            initPhysicsEngine(zones)
        }
    }
    
    // Initialisation du moteur physique C++
    function initPhysicsEngine(zones) {
        console.log("[EntityController] Initializing C++ physics engine...")
        
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
            console.log("[EntityController] Loaded", physicsEngine.zoneCount, "zones")
        }
        
        // Initialiser la position depuis l'entité 3D
        if (targetEntity) {
            var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
            playerBody.setPosition3D(targetEntity.x, targetEntity.z, gridSize)
            console.log("[EntityController] Player initial position:", playerBody.position)
        }
        
        // Connecter les signaux
        playerBody.collisionOccurred.connect(onPlayerCollision)
        playerBody.enteredZone.connect(onPlayerEnteredZone)
        playerBody.exitedZone.connect(onPlayerExitedZone)
        
        console.log("[EntityController] C++ physics engine ready")
    }
    
    // Callbacks de collision
    function onPlayerCollision(zone) {
        console.log("[EntityController] Collision with zone:", zone.zoneId)
    }
    
    function onPlayerEnteredZone(zone) {
        console.log("[EntityController] Entered zone:", zone.zoneId, "type:", zone.zoneType)
    }
    
    function onPlayerExitedZone(zone) {
        console.log("[EntityController] Exited zone:", zone.zoneId)
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
                    console.log("[EntityController] FreeCam OFF")
                } else {
                    console.log("[EntityController] FreeCam ON")
                }
                break;
            case Qt.Key_P:
                // Basculer entre moteur C++ et JS (pour debug)
                useCppPhysics = !useCppPhysics
                console.log("[EntityController] Physics engine:", useCppPhysics ? "C++" : "JavaScript")
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
        
        // Appliquer les forces d'entrée
        playerBody.applyForce(inputVector, dt)
        
        // Mettre à jour toute la physique (collision, zones, etc.)
        physicsEngine.updateAll(dt)
        
        // Synchroniser avec l'entité 3D
        var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
        var pos3D = playerBody.getPosition3D(gridSize)
        targetEntity.x = pos3D.x
        targetEntity.z = pos3D.z
        
        // Faire tourner l'entité dans la direction du mouvement
        var vel = playerBody.velocity
        if (vel.length() > 0.1) {
            var dx = vel.x * gridSize * dt
            var dz = vel.y * gridSize * dt
            // rotateEntity(dx, dz, dt)
        }
    }

    // ==================== PHYSIQUE 2D JS (FALLBACK) ====================

    /**
     * Calcule la distance d'un point à un segment
     * @returns {distance, closestPoint, t}
     */
    function pointToSegment(px, py, x1, y1, x2, y2) {
        var dx = x2 - x1
        var dy = y2 - y1
        var lengthSq = dx * dx + dy * dy

        if (lengthSq < 0.0001) {
            var dist = Math.sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1))
            return { distance: dist, closestX: x1, closestY: y1, t: 0 }
        }

        var t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSq))
        var closestX = x1 + t * dx
        var closestY = y1 + t * dy
        var dist = Math.sqrt((px - closestX) * (px - closestX) + (py - closestY) * (py - closestY))

        return { distance: dist, closestX: closestX, closestY: closestY, t: t }
    }

    /**
     * Vérifie si un cercle est en collision avec un polygone
     */
    function checkCirclePolygonCollision(cx, cy, radius, polygon) {
        if (!polygon || polygon.length < 3) return null

        var minDist = Infinity
        var closestX = 0, closestY = 0
        var segmentNormalX = 0, segmentNormalY = 0

        for (var i = 0; i < polygon.length; i++) {
            var j = (i + 1) % polygon.length
            var result = pointToSegment(cx, cy, polygon[i].x, polygon[i].y, polygon[j].x, polygon[j].y)

            if (result.distance < minDist) {
                minDist = result.distance
                closestX = result.closestX
                closestY = result.closestY

                var segDx = polygon[j].x - polygon[i].x
                var segDy = polygon[j].y - polygon[i].y
                var segLen = Math.sqrt(segDx * segDx + segDy * segDy)
                if (segLen > 0.0001) {
                    segmentNormalX = -segDy / segLen
                    segmentNormalY = segDx / segLen
                }
            }
        }

        if (minDist >= radius) return null

        var toCenterX = cx - closestX
        var toCenterY = cy - closestY
        var toCenterLen = Math.sqrt(toCenterX * toCenterX + toCenterY * toCenterY)

        var normalX, normalY
        if (toCenterLen > 0.0001) {
            normalX = toCenterX / toCenterLen
            normalY = toCenterY / toCenterLen
        } else {
            normalX = segmentNormalX
            normalY = segmentNormalY
        }

        return {
            colliding: true,
            distance: minDist,
            normalX: normalX,
            normalY: normalY,
            closestX: closestX,
            closestY: closestY,
            penetration: radius - minDist
        }
    }

    function detectCollisionJS(pos2D) {
        if (!exclusionZones) return null
        
        for (var i = 0; i < exclusionZones.length; i++) {
            var zone = exclusionZones[i]
            if (!zone || !zone.snapableParameters) continue
            
            if (zone.snapableParameters.tileType === ItemSnapable.ExclusionZone) {
                var exclusionParam = zone.snapableParameters.polygonParameter
                if (exclusionParam && exclusionParam.polygonPoints) {
                    var collision = checkCirclePolygonCollision(
                        pos2D.x, pos2D.y, 
                        collisionRadius2D, 
                        exclusionParam.polygonPoints
                    )
                    if (collision) {
                        collision.zone = zone
                        return collision
                    }
                }
            }
        }
        return null
    }

    function applyBounceJS(vel, normalX, normalY) {
        var dot = vel.x * normalX + vel.y * normalY
        if (dot >= 0) return vel
        
        var perpX = dot * normalX
        var perpY = dot * normalY
        var paraX = vel.x - perpX
        var paraY = vel.y - perpY
        
        var newVelX = -perpX * bounceFactor + paraX * slideFactor
        var newVelY = -perpY * bounceFactor + paraY * slideFactor
        
        return Qt.vector2d(newVelX, newVelY)
    }

    // Propriété interne pour le moteur JS
    property vector2d velocityJS: Qt.vector2d(0, 0)
    property vector2d position2DJS: Qt.vector2d(0, 0)

    function updatePhysics2DJS(dt) {
        if (!targetEntity) return
        
        position2DJS = World3DTools.position3dToGridRealPosition(targetEntity.x, 0, targetEntity.z)
        
        var newPos = Qt.vector2d(
            position2DJS.x + velocityJS.x * dt,
            position2DJS.y + velocityJS.y * dt
        )
        
        var collision = detectCollisionJS(newPos)
        if (collision) {
            velocityJS = applyBounceJS(velocityJS, collision.normalX, collision.normalY)
            newPos = Qt.vector2d(
                position2DJS.x + velocityJS.x * dt,
                position2DJS.y + velocityJS.y * dt
            )
        }
        
        var pos3D = World3DTools.gridPositionTo3D(newPos.x, newPos.y)
        targetEntity.x = pos3D.x
        targetEntity.z = pos3D.z
        position2DJS = newPos
    }

    function applyForceJS(inputForce, dt) {
        if (!targetEntity) return

        var targetSpeed = baseSpeed * baseSpeedMultiplier
        var targetVelocity = Qt.vector2d(0, 0)

        if (inputForce.length() > 0) {
            var inputDir = inputForce.normalized()
            targetVelocity = Qt.vector2d(inputDir.x * targetSpeed, inputDir.y * targetSpeed)
        }

        var velocityDiff = Qt.vector2d(targetVelocity.x - velocityJS.x, targetVelocity.y - velocityJS.y)
        var accelForce = Qt.vector2d(
            Math.sign(velocityDiff.x) * Math.min(Math.abs(velocityDiff.x), acceleration * dt),
            Math.sign(velocityDiff.y) * Math.min(Math.abs(velocityDiff.y), acceleration * dt)
        )
        velocityJS = Qt.vector2d(velocityJS.x + accelForce.x, velocityJS.y + accelForce.y)

        if (inputForce.length() == 0) {
            var frictionForce = friction * dt
            var velLen = velocityJS.length()
            if (velLen > 0) {
                var reduction = Math.min(frictionForce, velLen)
                var factor = (velLen - reduction) / velLen
                velocityJS = Qt.vector2d(velocityJS.x * factor, velocityJS.y * factor)
            }
        }

        updatePhysics2DJS(dt)

        if (velocityJS.length() > 0.1) {
            var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
            var dx = velocityJS.x * gridSize * dt
            var dz = velocityJS.y * gridSize * dt
            // rotateEntity(dx, dz, dt)
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
                if (useCppPhysics && playerBody) {
                    updatePhysicsCpp(dt)
                } else {
                    applyForceJS(inputVector, dt)
                }
            }
        }
    }
}
