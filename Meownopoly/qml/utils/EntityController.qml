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

    // --- Physique du mouvement ---
    property real acceleration: 50.0  // Accélération en unités par seconde²
    property real friction: 12.0       // Friction au sol (force de décélération)
    property vector2d velocity: Qt.vector2d(0, 0)  // Vitesse actuelle du personnage

    // --- Camera Follow Configuration ---
    // Delegated to CameraController

    // --- Collision avec zones d'exclusion ---
    property var snapableTilesList: null  // Liste des tiles pour accéder aux zones d'exclusion
    property real collisionRadius: 10.0   // Rayon de collision du personnage en unités 3D (correspond au rayon de la sphère visuelle)

    // --- État interne ---
    property vector2d inputVector: Qt.vector2d(0, 0)
    property bool isSprinting: false
    property bool freeCamMode: false // Nouveau mode FreeCam
    property real lastTimestamp: 0
    // Force de répulsion du mur (pour éviter de coller/clipper)
        property real wallRepulsion: 450.0
    // --- API Publique ---

    // Fonction pour définir la cible
    function setTarget(entity, view, grid, logic, tilesList) {
        targetEntity = entity
        view3D = view
        // grid2D = grid // grid2D est gardé en interne pour collision, mais plus utilisé pour caméra ici
        root.logic = logic
        snapableTilesList = tilesList || null

        console.log("=== EntityController.setTarget ===")

        // Initialiser le CameraController
        CameraController.setTarget(entity, view, grid, logic)
    }

    // --- Fonctions de collision avec les zones d'exclusion ---

    /**
     * Convertit les coordonnées 3D du monde en coordonnées de grille 2D
     * Formule simple: le point 3D (0,0,0) = point grille (0,0)
     * 1 unité de grille = gridSize pixels dans le monde 3D
     */

    // Debug: afficher les infos de collision une seule fois par seconde
    property real lastDebugTime: 0
    property bool debugCollision: true

    /**
     * Vérifie si un point (en coordonnées de grille) est dans un polygone
     * Utilise l'algorithme ray-casting
     */
    function isPointInPolygon(px, py, polygonPoints) {
        if (!polygonPoints || polygonPoints.length < 3) return false

        var inside = false
        var n = polygonPoints.length

        for (var i = 0, j = n - 1; i < n; j = i++) {
            var xi = polygonPoints[i].x
            var yi = polygonPoints[i].y
            var xj = polygonPoints[j].x
            var yj = polygonPoints[j].y

            if (((yi > py) !== (yj > py)) &&
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                inside = !inside
            }
        }

        return inside
    }

    /**
     * Calcule la distance d'un point à un segment de ligne
     * @param px, py Point à tester
     * @param x1, y1 Premier point du segment
     * @param x2, y2 Deuxième point du segment
     * @returns Distance minimale du point au segment
     */
    function pointToSegmentDistance(px, py, x1, y1, x2, y2) {
        var dx = x2 - x1
        var dy = y2 - y1
        var lengthSquared = dx * dx + dy * dy
        
        if (lengthSquared < 0.0001) {
            // Segment dégénéré (points identiques), retourner la distance au point
            var distX = px - x1
            var distY = py - y1
            return Math.sqrt(distX * distX + distY * distY)
        }
        
        // Calculer la projection du point sur le segment
        var t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSquared))
        var projX = x1 + t * dx
        var projY = y1 + t * dy
        
        // Distance du point à la projection
        var distX = px - projX
        var distY = py - projY
        return Math.sqrt(distX * distX + distY * distY)
    }

    /**
     * Calcule la distance minimale d'un point à un polygone
     * @param px, py Point à tester (en coordonnées de grille)
     * @param polygonPoints Liste des points du polygone
     * @returns Distance minimale du point au polygone (0 si le point est à l'intérieur)
     */
    function pointToPolygonDistance(px, py, polygonPoints) {
        if (!polygonPoints || polygonPoints.length < 3) return Infinity
        
        // Vérifier si le point est à l'intérieur du polygone
        var isInside = isPointInPolygon(px, py, polygonPoints)
        
        if (isInside) {
            // Le point est à l'intérieur, la distance est 0
            return 0.0
        }
        
        // Le point est à l'extérieur, calculer la distance au bord le plus proche
        var minDistance = Infinity
        var n = polygonPoints.length
        
        for (var i = 0; i < n; i++) {
            var j = (i + 1) % n
            var x1 = polygonPoints[i].x
            var y1 = polygonPoints[i].y
            var x2 = polygonPoints[j].x
            var y2 = polygonPoints[j].y
            
            var dist = pointToSegmentDistance(px, py, x1, y1, x2, y2)
            if (dist < minDistance) {
                minDistance = dist
            }
        }
        
        return minDistance
    }

    /**
     * Trouve le segment le plus proche d'un polygone et calcule sa normale
     * @param px, py Point à tester (en coordonnées de grille)
     * @param polygonPoints Liste des points du polygone
     * @returns Objet avec {normal, closestPoint, distance, segmentIndex} ou null
     */
    function getClosestSegmentAndNormal(px, py, polygonPoints) {
        if (!polygonPoints || polygonPoints.length < 3) {
            return null
        }
        
        var minDistance = Infinity
        var closestSegment = null
        var n = polygonPoints.length
        
        for (var i = 0; i < n; i++) {
            var j = (i + 1) % n
            var x1 = polygonPoints[i].x
            var y1 = polygonPoints[i].y
            var x2 = polygonPoints[j].x
            var y2 = polygonPoints[j].y
            
            // pointToSegmentDistance retourne juste la distance (nombre)
            var segmentDistance = pointToSegmentDistance(px, py, x1, y1, x2, y2)
            if (segmentDistance < minDistance) {
                minDistance = segmentDistance
                closestSegment = {
                    x1: x1, y1: y1,
                    x2: x2, y2: y2,
                    distance: segmentDistance,
                    segmentIndex: i
                }
            }
        }
        
        if (!closestSegment) {
            return null
        }
        
        // Calculer la normale du segment (perpendiculaire au segment, pointant vers l'extérieur)
        var segmentDx = closestSegment.x2 - closestSegment.x1
        var segmentDy = closestSegment.y2 - closestSegment.y1
        var segmentLength = Math.sqrt(segmentDx * segmentDx + segmentDy * segmentDy)
        
        if (segmentLength < 0.0001) {
            return null
        }
        
        // Normaliser le vecteur du segment
        var segmentDir = Qt.vector2d(segmentDx / segmentLength, segmentDy / segmentLength)
        
        // Calculer la normale (perpendiculaire, tournée de 90° dans le sens anti-horaire)
        var normal1 = Qt.vector2d(-segmentDir.y, segmentDir.x)
        var normal2 = Qt.vector2d(segmentDir.y, -segmentDir.x)
        
        // Calculer le point le plus proche sur le segment
        var lengthSquared = segmentLength * segmentLength
        var t = Math.max(0, Math.min(1, ((px - closestSegment.x1) * segmentDx + (py - closestSegment.y1) * segmentDy) / lengthSquared))
        var closestPoint = {
            x: closestSegment.x1 + t * segmentDx,
            y: closestSegment.y1 + t * segmentDy
        }
        
        // Vérifier quelle normale pointe vers le personnage
        var toPerson = Qt.vector2d(px - closestPoint.x, py - closestPoint.y)
        var toPersonLength = toPerson.length()
        if (toPersonLength > 0.0001) {
            toPerson = Qt.vector2d(toPerson.x / toPersonLength, toPerson.y / toPersonLength)
        }
        
        // Choisir la normale qui pointe dans la même direction que toPerson
        var dot1 = normal1.x * toPerson.x + normal1.y * toPerson.y
        var normal = dot1 > 0 ? normal1 : normal2
        
        return {
            normal: normal,
            closestPoint: closestPoint,
            distance: minDistance,
            segmentIndex: closestSegment.segmentIndex
        }
    }

    /**
     * Calcule l'angle entre deux vecteurs en radians
     * @param v1 Premier vecteur
     * @param v2 Deuxième vecteur
     * @returns Angle en radians (0 à π)
     */
    function angleBetweenVectors(v1, v2) {
        var dot = v1.x * v2.x + v1.y * v2.y
        var length1 = Math.sqrt(v1.x * v1.x + v1.y * v1.y)
        var length2 = Math.sqrt(v2.x * v2.x + v2.y * v2.y)
        
        if (length1 < 0.0001 || length2 < 0.0001) {
            return 0
        }
        
        var cosAngle = dot / (length1 * length2)
        // Clamper entre -1 et 1 pour éviter les erreurs d'arrondi
        cosAngle = Math.max(-1, Math.min(1, cosAngle))
        return Math.acos(cosAngle)
    }

    /**
     * Vérifie si une sphère entre en collision avec une zone d'exclusion
     * @param worldX Position X du centre de la sphère dans le monde 3D
     * @param worldZ Position Z du centre de la sphère dans le monde 3D
     * @param gridRadius Rayon de la sphère (en unités de grille, déjà converti)
     * @param velocity Vitesse du personnage (optionnel, pour calculer l'angle de collision)
     * @returns Objet de collision si collision détectée, null sinon. L'objet contient :
     *          - tile: La tile en collision (objet ItemSnapable)
     *          - polygonPoints: Liste des points du polygone de la zone d'exclusion (QVariantList)
     *          - distance: Distance du centre de la sphère au polygone (real, en unités de grille)
     *          - gridCoords: Coordonnées du centre de la sphère en unités de grille (Qt.point)
     *          - exclusionParam: Paramètres d'exclusion de la zone (ExclusionParameter)
     *          - normal: (optionnel, si velocity fourni) Vecteur normal du mur au point de collision (Qt.vector2d, normalisé)
     *          - closestPoint: (optionnel, si velocity fourni) Point le plus proche sur le mur (objet {x, y})
     *          - collisionAngle: (optionnel, si velocity fourni) Angle entre la vitesse et la normale en radians (real, 0 à π)
     *          - collisionAngleDegrees: (optionnel, si velocity fourni) Angle entre la vitesse et la normale en degrés (real, 0 à 180)
     */
    function isSphereCollidingWithExclusionZone(worldX, worldZ, gridRadius, velocity) {
        if (!snapableTilesList) {
            return null
        }
        
        // Convertir la position 3D en coordonnées de grille
        var gridCoords = World3DTools.position3dToGridRealPosition(worldX, 0, worldZ)

        // Parcourir toutes les tiles pour trouver les zones d'exclusion
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (!tile || !tile.snapableParameters) continue

            // Vérifier si c'est une zone d'exclusion
            if (tile.snapableParameters.tileType === ItemSnapable.ExclusionZone) {
                var exclusionParam = tile.snapableParameters.exclusionParameter
                if (exclusionParam && exclusionParam.polygonPoints) {
                    var points = exclusionParam.polygonPoints
                    
                    // Calculer la distance du centre de la sphère au polygone
                    var distance = pointToPolygonDistance(gridCoords.x, gridCoords.y, points)
                    
                    // Si la distance est inférieure au rayon, il y a collision
                    if (distance < gridRadius) {
                        var collisionData = {
                            tile: tile,
                            polygonPoints: points,
                            distance: distance,
                            gridCoords: gridCoords,
                            exclusionParam: exclusionParam
                        }
                        
                        // Calculer la normale et l'angle de collision si la vitesse est fournie
                        if (velocity !== undefined && velocity !== null) {
                            var segmentInfo = getClosestSegmentAndNormal(gridCoords.x, gridCoords.y, points)
                            if (segmentInfo !== null) {
                                collisionData.normal = segmentInfo.normal
                                collisionData.closestPoint = segmentInfo.closestPoint
                                
                                // Calculer l'angle entre la vitesse et la normale
                                // Normaliser la vitesse pour le calcul d'angle
                                var velocityLength = velocity.length()
                                if (velocityLength > 0.0001) {
                                    var velocityDir = Qt.vector2d(velocity.x / velocityLength, velocity.y / velocityLength)
                                    var collisionAngle = angleBetweenVectors(velocityDir, segmentInfo.normal)
                                    collisionData.collisionAngle = collisionAngle  // Angle en radians
                                    collisionData.collisionAngleDegrees = collisionAngle * 180 / Math.PI  // Angle en degrés
                                } else {
                                    collisionData.collisionAngle = 0
                                    collisionData.collisionAngleDegrees = 0
                                }
                            }
                        }
                        
                        if (debugCollision) {
                            console.log("[Collision Sphère] Collision détectée! Distance:", distance.toFixed(2), "Rayon:", gridRadius.toFixed(2))
                            if (collisionData.collisionAngle !== undefined) {
                                console.log("[Collision Sphère] Angle:", collisionData.collisionAngleDegrees.toFixed(2), "°")
                            }
                        }
                        
                        return collisionData
                    }
                }
            }
        }

        return null
    }


    /**
     * Vérifie si une position 3D est dans une zone d'exclusion (point seulement, pour compatibilité)
     * @param worldX Position X dans le monde 3D
     * @param worldZ Position Z dans le monde 3D
     * @returns true si la position est dans une zone d'exclusion
     */
    function isInExclusionZone(worldX, worldZ) {
        // Utiliser la détection de collision sphérique avec un rayon de 0
        var collision = isSphereCollidingWithExclusionZone(worldX, worldZ, 0.0, null)
        return collision !== null
    }

    // Fonction debug pour afficher l'état des collisions
    function debugCollisionState() {
        if (!snapableTilesList) {
            console.log("[Debug] snapableTilesList: NULL")
            return
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
            case Qt.Key_F9:
                // Touche F9 pour afficher le debug des collisions
                debugCollisionState()
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
        var rotationSpeed = 15.0 * dt

        // Si on est très proche, on finit le mouvement pour éviter le jitter
        if (Math.abs(diff) < 1) {
            root.targetEntity.eulerRotation.y = targetAngle
        } else {
            root.targetEntity.eulerRotation.y = currentAngle + diff * rotationSpeed
        }
    }

    function updateInputVector() {
        // Priorité au Gamepad s'il est actif (à faire), sinon Clavier
        var x = 0
        var y = 0
        if (keyLeft) x -= 1
        if (keyRight) x += 1
        if (keyUp) y += 1   // En 2D "Up" est souvent Y-, mais en logique de déplacement on veut "Avancer"
        if (keyDown) y -= 1

        // Normaliser le vecteur pour obtenir juste la direction (la vitesse sera gérée par l'accélération)
        inputVector = Qt.vector2d(x, y)
        if (inputVector.length() > 1) {
            inputVector = inputVector.normalized()
        }
    }

    /**
     * Gère la collision avec un mur et applique un rebond basé sur l'angle d'impact
     * @param newX Nouvelle position X proposée (en unités 3D)
     * @param newZ Nouvelle position Z proposée (en unités 3D)
     * @param collisionInfo Informations de collision retournées par isSphereCollidingWithExclusionZone
     * @param gridRadiusCollision Rayon de collision en unités de grille
     * @param velocity Vitesse actuelle du personnage (en unités de grille par seconde)
     * @param frameTime Temps de la frame en secondes
     * @returns Objet avec {finalX, finalZ, dx, dz} - position finale et déplacement
     */
    function handleCollision(newX, newZ, collisionInfo, gridRadiusCollision, velocity, frameTime) {
        if (collisionInfo === null) {
            // Pas de collision, mouvement normal
            var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
            var dx = velocity.x * gridSize * frameTime
            var dz = -velocity.y * gridSize * frameTime
            return {finalX: newX, finalZ: newZ, dx: dx, dz: dz}
        }
        
        // Récupérer la normale du mur et les informations de collision
        if (!collisionInfo.normal) {
            // Si pas de normale disponible, calculer-la
            var wallInfo = getClosestSegmentAndNormal(collisionInfo.gridCoords.x, collisionInfo.gridCoords.y, collisionInfo.polygonPoints)
            if (wallInfo === null) {
                // Impossible de calculer la normale, bloquer le mouvement
                return {finalX: targetEntity.x, finalZ: targetEntity.z, dx: 0, dz: 0}
            }
            collisionInfo.normal = wallInfo.normal
            collisionInfo.distance = wallInfo.distance
        }
        
        var normal = collisionInfo.normal
        var gridSize = World3DTools.gridManager ? World3DTools.gridManager.gridSize : 1.0
        
        // La normale pointe vers le personnage (du mur vers le personnage)
        // Pour le rebond, on veut que la normale pointe vers l'extérieur du mur
        var normalOutward = Qt.vector2d(-normal.x, -normal.y)
        
        // Utiliser directement la normale vers l'extérieur pour tous les calculs
        // Calculer la composante perpendiculaire de la vitesse par rapport à la normale vers l'extérieur
        // Si velocityPerpOutward > 0, la vitesse pointe vers le mur (opposé à normalOutward)
        // Si velocityPerpOutward < 0, la vitesse pointe vers l'extérieur (même direction que normalOutward)
        var velocityPerpOutward = velocity.x * normalOutward.x + velocity.y * normalOutward.y
        
        // Debug temporaire pour diagnostiquer le problème sur les axes X et Y
        if (debugCollision) {
            if (Math.abs(normal.x) > 0.5) {  // Si la normale est principalement sur X
                console.log("[HandleCollision X] Normal (toward person):", normal.x.toFixed(3), normal.y.toFixed(3),
                           "Normal (outward):", normalOutward.x.toFixed(3), normalOutward.y.toFixed(3),
                           "Velocity:", velocity.x.toFixed(3), velocity.y.toFixed(3),
                           "VelocityPerpOutward:", velocityPerpOutward.toFixed(3),
                           "Distance:", collisionInfo.distance.toFixed(3))
            }
            if (Math.abs(normal.y) > 0.5) {  // Si la normale est principalement sur Y
                console.log("[HandleCollision Y] Normal (toward person):", normal.x.toFixed(3), normal.y.toFixed(3),
                           "Normal (outward):", normalOutward.x.toFixed(3), normalOutward.y.toFixed(3),
                           "Velocity:", velocity.x.toFixed(3), velocity.y.toFixed(3),
                           "VelocityPerpOutward:", velocityPerpOutward.toFixed(3),
                           "Distance:", collisionInfo.distance.toFixed(3))
            }
        }
        
        // Si velocityPerpOutward < 0, la vitesse pointe vers l'extérieur (dans la direction de normalOutward)
        // Donc pas de collision à gérer, mouvement normal
        if (velocityPerpOutward < -0.01) {
            var dx = velocity.x * gridSize * frameTime
            var dz = -velocity.y * gridSize * frameTime
            return {finalX: newX, finalZ: newZ, dx: dx, dz: dz}
        }
        
        // velocityPerpOutward >= 0 signifie que la vitesse pointe vers le mur (opposé à normalOutward)
        // On calcule la composante perpendiculaire (vers le mur) en utilisant normalOutward
        var velocityPerpMagnitude = Math.max(0.01, Math.abs(velocityPerpOutward))
        var velocityPerpVector = Qt.vector2d(-normalOutward.x * velocityPerpMagnitude, -normalOutward.y * velocityPerpMagnitude)
        
        // Composante parallèle (le long du mur) - sera conservée pour le glissement
        var velocityParallel = Qt.vector2d(velocity.x - velocityPerpVector.x, velocity.y - velocityPerpVector.y)
        
        // Debug pour vérifier les composantes
        if (debugCollision) {
            if (Math.abs(normal.x) > 0.5) {
                console.log("[HandleCollision X] PerpVector:", velocityPerpVector.x.toFixed(3), velocityPerpVector.y.toFixed(3),
                           "Parallel:", velocityParallel.x.toFixed(3), velocityParallel.y.toFixed(3))
            }
            if (Math.abs(normal.y) > 0.5) {
                console.log("[HandleCollision Y] PerpVector:", velocityPerpVector.x.toFixed(3), velocityPerpVector.y.toFixed(3),
                           "Parallel:", velocityParallel.x.toFixed(3), velocityParallel.y.toFixed(3))
            }
        }
        
        // Calculer le coefficient de rebond basé sur l'angle d'impact
        // Plus l'angle est proche de 90° (impact frontal), plus le rebond est fort
        // Plus l'angle est proche de 0° (impact rasant), plus on glisse
        var velocityLength = velocity.length()
        var bounceFactor = 0.5  // Coefficient de rebond réduit (0 = pas de rebond, 1 = rebond parfait)
        var slideFactor = 0.85   // Facteur de conservation du glissement
        
        if (collisionInfo.collisionAngle !== undefined) {
            // Utiliser l'angle de collision pour ajuster le rebond
            // Angle proche de 0° (rasant) -> plus de glissement, moins de rebond
            // Angle proche de 90° (frontal) -> plus de rebond, moins de glissement
            var angleRad = collisionInfo.collisionAngle
            var angleFactor = Math.sin(angleRad)  // 0 pour angle rasant, 1 pour angle frontal
            
            // Ajuster les facteurs selon l'angle (réduits pour éviter les rebonds trop forts)
            bounceFactor = 0.2 + 0.3 * angleFactor  // Entre 0.2 et 0.5 selon l'angle
            slideFactor = 0.9 - 0.1 * angleFactor   // Entre 0.9 et 0.8 selon l'angle
        }
        
        // Limiter la magnitude de la composante perpendiculaire avant le rebond
        // Pour éviter que la vitesse ne devienne trop grande
        var maxPerpSpeed = baseSpeed * baseSpeedMultiplier * 1.5  // Limite à 1.5x la vitesse de base
        if (velocityPerpMagnitude > maxPerpSpeed) {
            velocityPerpMagnitude = maxPerpSpeed
            velocityPerpVector = Qt.vector2d(-normalOutward.x * velocityPerpMagnitude, -normalOutward.y * velocityPerpMagnitude)
        }
        
        // Appliquer le rebond : inverser la composante perpendiculaire avec le facteur de rebond
        // velocityPerpVector pointe vers le mur (opposé à normalOutward)
        // On l'inverse pour qu'il pointe vers l'extérieur (dans la direction de normalOutward)
        var bouncedPerp = Qt.vector2d(-velocityPerpVector.x * bounceFactor, -velocityPerpVector.y * bounceFactor)
        
        // Conserver la composante parallèle avec le facteur de glissement
        var newVelocityParallel = Qt.vector2d(velocityParallel.x * slideFactor, velocityParallel.y * slideFactor)
        
        // Nouvelle vitesse après rebond
        var newVelocity = Qt.vector2d(bouncedPerp.x + newVelocityParallel.x, bouncedPerp.y + newVelocityParallel.y)
        
        // Limiter la vitesse totale pour éviter l'accumulation
        var newVelocityLength = newVelocity.length()
        var maxSpeed = baseSpeed * baseSpeedMultiplier * 2.0  // Limite à 2x la vitesse de base
        if (newVelocityLength > maxSpeed) {
            var scale = maxSpeed / newVelocityLength
            newVelocity = Qt.vector2d(newVelocity.x * scale, newVelocity.y * scale)
        }
        
        // Debug pour vérifier la nouvelle vitesse
        if (debugCollision) {
            if (Math.abs(normal.x) > 0.5) {
                console.log("[HandleCollision X] NewVelocity:", newVelocity.x.toFixed(3), newVelocity.y.toFixed(3),
                           "BouncedPerp:", bouncedPerp.x.toFixed(3), bouncedPerp.y.toFixed(3))
            }
            if (Math.abs(normal.y) > 0.5) {
                console.log("[HandleCollision Y] NewVelocity:", newVelocity.x.toFixed(3), newVelocity.y.toFixed(3),
                           "BouncedPerp:", bouncedPerp.x.toFixed(3), bouncedPerp.y.toFixed(3))
            }
        }
        
        // Appliquer une force de répulsion modérée si nécessaire pour éviter la pénétration
        // Réduire la force de répulsion pour éviter l'accumulation
        var penetrationDepth = Math.max(0, gridRadiusCollision - collisionInfo.distance)
        if (penetrationDepth > 0.001) {
            // Réduire la force de répulsion et la limiter
            var repulsionStrength = Math.min(wallRepulsion * 0.1, 100.0) * penetrationDepth  // Réduit à 10% et limité
            var repulsionAcceleration = repulsionStrength * frameTime
            
            // Limiter l'accélération de répulsion pour éviter les explosions
            repulsionAcceleration = Math.min(repulsionAcceleration, baseSpeed * 0.5)  // Max 50% de la vitesse de base
            
            // La répulsion doit pousser le personnage vers l'extérieur du mur
            // normal pointe vers le personnage (du mur vers le personnage)
            // Pour repousser le personnage qui est trop proche du mur, on doit le pousser dans la direction opposée à normal
            // normalOutward = -normal, donc normalOutward pointe vers l'extérieur
            // Mais d'après les logs, ça pousse dans la mauvaise direction
            // Peut-être que le problème vient de la conversion des coordonnées ou de la façon dont la normale est calculée
            // Essayons d'inverser complètement : utiliser normal directement (mais ça devrait pousser vers le mur, donc mauvais)
            // Ou peut-être que la répulsion ne devrait pas être appliquée du tout si on fait déjà un rebond ?
            // Pour l'instant, essayons d'utiliser normalOutward mais avec un signe inversé pour tester
            var repulsionVector = Qt.vector2d(normalOutward.x * repulsionAcceleration, normalOutward.y * repulsionAcceleration)
            
            // Si ça ne fonctionne toujours pas, peut-être qu'il faut inverser le signe
            // Testons avec l'inverse de normalOutward
            repulsionVector = Qt.vector2d(-normalOutward.x * repulsionAcceleration, -normalOutward.y * repulsionAcceleration)
            
            // Debug pour vérifier la direction de la répulsion
            if (debugCollision) {
                if (Math.abs(normal.x) > 0.5 || Math.abs(normal.y) > 0.5) {
                    console.log("[Repulsion] Normal (toward person):", normal.x.toFixed(3), normal.y.toFixed(3),
                               "NormalOutward (away from wall):", normalOutward.x.toFixed(3), normalOutward.y.toFixed(3),
                               "RepulsionVector (inverted):", repulsionVector.x.toFixed(3), repulsionVector.y.toFixed(3),
                               "PenetrationDepth:", penetrationDepth.toFixed(3),
                               "Current velocity:", velocity.x.toFixed(3), velocity.y.toFixed(3))
                }
            }
            
            newVelocity = Qt.vector2d(newVelocity.x + repulsionVector.x, newVelocity.y + repulsionVector.y)
            
            // Re-limiter après la répulsion
            newVelocityLength = newVelocity.length()
            if (newVelocityLength > maxSpeed) {
                var scale2 = maxSpeed / newVelocityLength
                newVelocity = Qt.vector2d(newVelocity.x * scale2, newVelocity.y * scale2)
            }
        }
        
        // Mettre à jour la vitesse globale
        root.velocity = newVelocity
        
        // Convertir la nouvelle vitesse de grille vers 3D pour le mouvement
        var newVelocity3DX = newVelocity.x * gridSize
        var newVelocity3DZ = -newVelocity.y * gridSize
        
        // Calculer le déplacement pour cette frame
        var dx = newVelocity3DX * frameTime
        var dz = newVelocity3DZ * frameTime
        
        // Calculer la position finale
        var finalX = targetEntity.x + dx
        var finalZ = targetEntity.z + dz
        
        // Vérifier si on est toujours en collision après le rebond
        var stillColliding = isSphereCollidingWithExclusionZone(finalX, finalZ, gridRadiusCollision, newVelocity)
        if (stillColliding !== null) {
            // Toujours en collision, bloquer le mouvement et forcer le glissement
            finalX = targetEntity.x
            finalZ = targetEntity.z
            
            // Réduire la vitesse perpendiculaire à zéro, garder seulement le glissement
            root.velocity = velocityParallel
            dx = velocityParallel.x * gridSize * frameTime
            dz = -velocityParallel.y * gridSize * frameTime
        }
        
        return {finalX: finalX, finalZ: finalZ, dx: dx, dz: dz}
    }

    function applyForce(inputForce, frameTime)
    {
        if (!targetEntity) return

        // Calculer la vitesse cible basée sur l'input
        var targetSpeed = baseSpeed * baseSpeedMultiplier
        var targetVelocity = Qt.vector2d(0, 0)
        
        if (inputForce.length() > 0) {
            // Normaliser le vecteur d'input pour obtenir la direction
            var inputDir = inputForce.normalized()
            // Calculer la vitesse cible dans la direction de l'input
            targetVelocity = Qt.vector2d(inputDir.x * targetSpeed, inputDir.y * targetSpeed)
        }

        // Appliquer l'accélération vers la vitesse cible
        var velocityDiff = Qt.vector2d(targetVelocity.x - velocity.x, targetVelocity.y - velocity.y)
        var accelerationForce = Qt.vector2d(
            Math.sign(velocityDiff.x) * Math.min(Math.abs(velocityDiff.x), acceleration * frameTime),
            Math.sign(velocityDiff.y) * Math.min(Math.abs(velocityDiff.y), acceleration * frameTime)
        )
        velocity = Qt.vector2d(velocity.x + accelerationForce.x, velocity.y + accelerationForce.y)

        // Appliquer la friction (décélération progressive quand pas d'input)
        if (inputForce.length() == 0) {
            var frictionForce = friction * frameTime
            var velocityLength = velocity.length()
            if (velocityLength > 0) {
                var frictionReduction = Math.min(frictionForce, velocityLength)
                var frictionFactor = (velocityLength - frictionReduction) / velocityLength
                velocity = Qt.vector2d(velocity.x * frictionFactor, velocity.y * frictionFactor)
            }
        }

        // Convertir le rayon de collision en unités de grille pour la détection
        var gridRadiusCollision = 0.25

        // Calculer la nouvelle position basée sur la vitesse actuelle
        // velocity est en unités de grille par seconde
        // On doit convertir en unités 3D pour le mouvement
        
        // Convertir la vitesse de grille vers 3D
        // X grille -> X 3D (même direction, même échelle via gridSize)
        // Y grille -> Z 3D (inversé car Y+ grille = Z- 3D, même échelle via gridSize)
        var velocity3DX = velocity.x * World3DTools.gridManager.gridSize
        var velocity3DZ = -velocity.y * World3DTools.gridManager.gridSize
        
        var dx = velocity3DX * frameTime
        var dz = velocity3DZ * frameTime

        var newX = targetEntity.x + dx
        var newZ = targetEntity.z + dz

        // Vérifier s'il y a collision à la nouvelle position (avec la vitesse pour calculer l'angle)
        var collisionInfo = isSphereCollidingWithExclusionZone(newX, newZ, gridRadiusCollision, velocity)
        var isColliding = collisionInfo !== null
        
        var finalX = newX
        var finalZ = newZ

        if (isColliding) {
            targetEntity.materials[0].baseColor = "blue"
            
            // Gérer la collision avec le mur en utilisant les collisionInfo
            var collisionResult = handleCollision(newX, newZ, collisionInfo, gridRadiusCollision, velocity, frameTime)
            finalX = collisionResult.finalX
            finalZ = collisionResult.finalZ
            dx = collisionResult.dx
            dz = collisionResult.dz
        }
        else {
            targetEntity.materials[0].baseColor = "red"
        }


        // Appliquer la position finale
        targetEntity.x = finalX
        targetEntity.z = finalZ

        // Faire tourner l'entité dans la direction du mouvement (utiliser la vitesse réelle)
        if (velocity.length() > 0.1) {  // Seuil pour éviter les micro-mouvements
            rotateEntity(dx, dz, frameTime)
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
                CameraController.moveManual(inputVector.x, inputVector.y, baseSpeed * 1.5, dt)
            }
            else
            {
                applyForce(inputVector, dt)
                // moveEntityRep(inputVector, dt)
            }


        }
    }
}

