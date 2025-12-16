pragma Singleton
import QtQuick
import ItemSnapable

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
    property real friction: 12.0       // Friction au sol (force de décélération)
    
    // Position et vitesse en coordonnées de grille 2D
    property vector2d position2D: Qt.vector2d(0, 0)  // Position en unités de grille
    property vector2d velocity: Qt.vector2d(0, 0)    // Vitesse en unités de grille/s
    
    // Paramètres de collision
    property real collisionRadius2D: 0.25  // Rayon de collision en unités de grille
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
                    // Quand on quitte le freeCam, on peut vouloir "snap" la caméra
                    // ou laisser le smooth follow rattraper le joueur (ce qui est le cas par défaut)
                    console.log("[EntityController] FreeCam OFF")
                } else {
                    console.log("[EntityController] FreeCam ON")
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
        var rotationSpeed = 25.0 * dt

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
        if (keyUp) y += 1
        if (keyDown) y -= 1

        inputVector = Qt.vector2d(x, y)
        if (inputVector.length() > 1) {
            inputVector = inputVector.normalized()
        }
    }

    // ==================== PHYSIQUE 2D ====================

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
     * @param cx, cy Centre du cercle en coordonnées de grille
     * @param radius Rayon du cercle
     * @param polygon Liste de points [{x, y}, ...]
     * @returns {colliding, distance, normalX, normalY, closestX, closestY} ou null
     */
    function checkCirclePolygonCollision(cx, cy, radius, polygon) {
        if (!polygon || polygon.length < 3) return null
        
        var minDist = Infinity
        var closestX = 0, closestY = 0
        var segmentNormalX = 0, segmentNormalY = 0
        
        // Trouver le segment le plus proche
        for (var i = 0; i < polygon.length; i++) {
            var j = (i + 1) % polygon.length
            var result = pointToSegment(cx, cy, polygon[i].x, polygon[i].y, polygon[j].x, polygon[j].y)
            
            if (result.distance < minDist) {
                minDist = result.distance
                closestX = result.closestX
                closestY = result.closestY
                
                // Calculer la normale du segment (perpendiculaire)
                var segDx = polygon[j].x - polygon[i].x
                var segDy = polygon[j].y - polygon[i].y
                var segLen = Math.sqrt(segDx * segDx + segDy * segDy)
                if (segLen > 0.0001) {
                    // Normale perpendiculaire au segment
                    segmentNormalX = -segDy / segLen
                    segmentNormalY = segDx / segLen
                }
            }
        }
        
        // Pas de collision si la distance est supérieure au rayon
        if (minDist >= radius) return null
        
        // Calculer la normale qui pointe du mur vers le cercle
        var toCenterX = cx - closestX
        var toCenterY = cy - closestY
        var toCenterLen = Math.sqrt(toCenterX * toCenterX + toCenterY * toCenterY)
        
        var normalX, normalY
        if (toCenterLen > 0.0001) {
            normalX = toCenterX / toCenterLen
            normalY = toCenterY / toCenterLen
        } else {
            // Si le centre est exactement sur le segment, utiliser la normale du segment
            normalX = segmentNormalX
            normalY = segmentNormalY
        }
        
        return {
            colliding: true,
            distance: minDist,
            normalX: normalX,
            normalY: -normalY,
            closestX: closestX,
            closestY: closestY,
            penetration: radius - minDist
        }
    }

    /**
     * Détecte les collisions avec toutes les zones d'exclusion
     * @param pos2D Position en coordonnées de grille (vector2d)
     * @returns Objet collision ou null
     */
    function detectCollision(pos2D) {
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

    /**
     * Applique un rebond à la vitesse en fonction de la normale de collision
     * @param vel Vitesse actuelle (vector2d)
     * @param normalX, normalY Normale de la surface (pointant vers l'extérieur)
     * @returns Nouvelle vitesse après rebond (vector2d)
     */
    function applyBounce(vel, normalX, normalY) {
        // Produit scalaire vitesse . normale
        var dot = vel.x * normalX + vel.y * normalY
        
        // Si la vitesse va déjà vers l'extérieur, pas de rebond
        if (dot >= 0) return vel
        
        // Composante perpendiculaire (vers le mur)
        var perpX = dot * normalX
        var perpY = dot * normalY
        
        // Composante parallèle (le long du mur)
        var paraX = vel.x - perpX
        var paraY = vel.y - perpY
        
        // Nouvelle vitesse : rebond de la composante perpendiculaire + glissement
        var newVelX = -perpX * bounceFactor + paraX * slideFactor
        var newVelY = -perpY * bounceFactor + paraY * slideFactor
        
        return Qt.vector2d(newVelX, newVelY)
    }

    /**
     * Met à jour la physique 2D : position, collision, rebond
     * Utilise les fonctions symétriques world3DToGrid2D / grid2DToWorld3D
     * @param dt Delta time en secondes
     */
    function updatePhysics2D(dt) {
        if (!targetEntity) return
        
        // Obtenir la position 2D actuelle depuis la position 3D (conversion directe)

        position2D = World3DTools.position3dToGridRealPosition(targetEntity.x, 0, targetEntity.z)
        
        // Calculer la nouvelle position proposée
        var newPos = Qt.vector2d(
            position2D.x + velocity.x * dt,
            position2D.y + -velocity.y * dt
        )
        
        // Détecter les collisions
        var collision = detectCollision(newPos)
        if (collision) {
            console.log("[updatePhysics2D] COLILDE!")
            // Appliquer le rebond
            velocity = applyBounce(velocity, collision.normalX, collision.normalY)
            
            // Repousser hors de la collision (correction de pénétration)
            if (collision.penetration > 0) {
                newPos = Qt.vector2d(
                    newPos.x + collision.normalX * collision.penetration,
                    newPos.y + collision.normalY * collision.penetration
                )
            }
            
            // Recalculer la position avec la nouvelle vitesse
            newPos = Qt.vector2d(
                position2D.x + velocity.x * dt,
                position2D.y + -velocity.y * dt
            )
            
            // Vérifier si toujours en collision après correction
            var stillColliding = detectCollision(newPos)
            if (stillColliding) {
                // Bloquer le mouvement, garder la position actuelle
                newPos = position2D
            }
        }
        
        // Convertir la position 2D en 3D et appliquer (conversion directe)
        var pos3D = World3DTools.gridPositionTo3D(newPos.x, newPos.y)
        console.log("[updatePhysics2D] pos3D (x, y, z)", pos3D.x.toFixed(2), pos3D.y.toFixed(2), pos3D.z.toFixed(2));

        targetEntity.x = pos3D.x
        targetEntity.z = pos3D.z

        // Mettre à jour position2D
        position2D = newPos
    }

    /**
     * Applique les forces d'entrée et met à jour la physique
     * Toute la physique est calculée en coordonnées de grille 2D
     * @param inputForce Vecteur d'entrée (direction)
     * @param dt Delta time en secondes
     */
    function applyForce(inputForce, dt)
    {
        if (!targetEntity) return

        console.log("======= NEW FRAME =========")
        // 1. Calculer la vitesse cible basée sur l'input
        var targetSpeed = baseSpeed * baseSpeedMultiplier
        var targetVelocity = Qt.vector2d(0, 0)

        
        if (inputForce.length() > 0) {
            var inputDir = inputForce.normalized()
            targetVelocity = Qt.vector2d(inputDir.x * targetSpeed, inputDir.y * targetSpeed)
            console.log("targetVelocity", targetVelocity)
        }

        // 2. Appliquer l'accélération vers la vitesse cible
        var velocityDiff = Qt.vector2d(targetVelocity.x - velocity.x, targetVelocity.y - velocity.y)
        var accelForce = Qt.vector2d(
            Math.sign(velocityDiff.x) * Math.min(Math.abs(velocityDiff.x), acceleration * dt),
            Math.sign(velocityDiff.y) * Math.min(Math.abs(velocityDiff.y), acceleration * dt)
        )
        velocity = Qt.vector2d(velocity.x + accelForce.x, velocity.y + accelForce.y)

        // 3. Appliquer la friction quand pas d'input
        if (inputForce.length() == 0) {
            var frictionForce = friction * dt
            var velLen = velocity.length()
            if (velLen > 0) {
                var reduction = Math.min(frictionForce, velLen)
                console.log("reduction", reduction)
                var factor = (velLen - reduction) / velLen
                velocity = Qt.vector2d(velocity.x * factor, velocity.y * factor)
            }
        }

        // 4. Mettre à jour la physique 2D (position, collision, rebond)
        updatePhysics2D(dt)

        

        // 5. Faire tourner l'entité dans la direction du mouvement
        if (velocity.length() > 0.1) {
            var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
            var dx = velocity.x * gridSize * dt
            var dz = -velocity.y * gridSize * dt
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
            else
            {
                applyForce(inputVector, dt)
                // moveEntityRep(inputVector, dt)
            }


        }
    }
}

