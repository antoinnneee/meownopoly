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
    property real moveSpeed: 200.0
    property real sprintMultiplier: 2.0

    // --- Camera Follow Configuration ---
    // Delegated to CameraController

    // --- Collision avec zones d'exclusion ---
    property var snapableTilesList: null  // Liste des tiles pour accéder aux zones d'exclusion
    property real collisionRadius: 0.0   // Rayon de collision du personnage en unités 3D

    // --- État interne ---
    property vector2d inputVector: Qt.vector2d(0, 0)
    property bool isSprinting: false
    property bool freeCamMode: false // Nouveau mode FreeCam
    property real lastTimestamp: 0

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
    function worldToGridCoords(worldX, worldZ) {
        // On récupère grid2D depuis CameraController s'il n'est plus stocké localement,
        // ou on le stocke localement via setTarget.
        // Pour l'instant, on va utiliser la prop CameraController.grid2D si possible ou restaurer la prop locale.
        var grid = CameraController.grid2D
        if (!grid) return Qt.point(0, 0)

        // Conversion simple:
        // X 3D → X grille
        // Z 3D négatif → Y grille positif (avancer en Z- = descendre en Y grille)
        var gridX = worldX / grid.gridSize
        var gridY = -worldZ / grid.gridSize

        return Qt.point(gridX, gridY)
    }

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
     * Vérifie si une position 3D est dans une zone d'exclusion
     * @param worldX Position X dans le monde 3D
     * @param worldZ Position Z dans le monde 3D
     * @returns true si la position est dans une zone d'exclusion
     */
    function isInExclusionZone(worldX, worldZ) {
        if (!snapableTilesList) {
            if (debugCollision) console.log("[Collision] snapableTilesList est NULL")
            return false
        }
        //position3dToGridRealPosition
        var gridCoords = view3D.parent.position3dToGridRealPosition(worldX, 0, worldZ)
        var exclusionZoneCount = 0

        // Parcourir toutes les tiles pour trouver les zones d'exclusion
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (!tile || !tile.snapableParameters) continue

            // Vérifier si c'est une zone d'exclusion
            if (tile.snapableParameters.tileType === ItemSnapable.ExclusionZone) {
                exclusionZoneCount++
                var exclusionParam = tile.snapableParameters.exclusionParameter
                if (exclusionParam && exclusionParam.polygonPoints) {
                    var points = exclusionParam.polygonPoints
                    if (isPointInPolygon(gridCoords.x, gridCoords.y, points)) {
                        if (debugCollision) {
                            console.log("[Collision] DANS ZONE! gridCoords:", gridCoords.x.toFixed(2), gridCoords.y.toFixed(2))
                        }
                        return true
                    }
                }
            }
        }

        return false
    }

    // Fonction debug pour afficher l'état des collisions
    function debugCollisionState() {
        if (!snapableTilesList) {
            console.log("[Debug] snapableTilesList: NULL")
            return
        }

        var grid = CameraController.grid2D

        console.log("[Debug] ╔════════════════════════════════════════════╗")
        console.log("[Debug] ║        ÉTAT DES COLLISIONS (F9)           ║")
        console.log("[Debug] ╚════════════════════════════════════════════╝")
        console.log("[Debug] Nombre total de tiles:", snapableTilesList.length)
        console.log("[Debug] grid2D.gridSize:", grid ? grid.gridSize : "NULL")

        if (targetEntity) {
            console.log("[Debug] ")
            console.log("[Debug] === PERSONNAGE ===")
            console.log("[Debug] Position 3D: X=" + targetEntity.x.toFixed(1) + ", Z=" + targetEntity.z.toFixed(1))

            var gridCoords = worldToGridCoords(targetEntity.x, targetEntity.z)
            console.log("[Debug] Position GRILLE calculée: X=" + gridCoords.x.toFixed(2) + ", Y=" + gridCoords.y.toFixed(2))
            console.log("[Debug] ")
            console.log("[Debug] Formule: gridX = worldX / gridSize = " + targetEntity.x.toFixed(1) + " / " + (grid ? grid.gridSize : "?") + " = " + gridCoords.x.toFixed(2))
            console.log("[Debug] Formule: gridY = -worldZ / gridSize = " + (-targetEntity.z).toFixed(1) + " / " + (grid ? grid.gridSize : "?") + " = " + gridCoords.y.toFixed(2))
        }

        console.log("[Debug] ")
        console.log("[Debug] === ZONES D'EXCLUSION ===")
        var zoneCount = 0
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile && tile.snapableParameters &&
                tile.snapableParameters.tileType === ItemSnapable.ExclusionZone) {
                zoneCount++
                var ep = tile.snapableParameters.exclusionParameter
                if (ep && ep.polygonPoints) {
                    var pts = ep.polygonPoints
                    // Calculer le centre de la zone
                    var sumX = 0, sumY = 0
                    for (var j = 0; j < pts.length; j++) {
                        sumX += pts[j].x
                        sumY += pts[j].y
                    }
                    var centerX = sumX / pts.length
                    var centerY = sumY / pts.length

                    console.log("[Debug] Zone #" + zoneCount + " (" + pts.length + " points) - Centre: (" + centerX.toFixed(2) + ", " + centerY.toFixed(2) + ")")
                    for (var k = 0; k < pts.length; k++) {
                        console.log("[Debug]   Point " + k + ": (" + pts[k].x.toFixed(2) + ", " + pts[k].y.toFixed(2) + ")")
                    }

                    // Vérifier si le personnage est dans cette zone
                    if (targetEntity) {
                        var targetEntityPos = view3D.parent.getEntityGridRealPosition(targetEntity);

                        var isIn = isPointInPolygon(targetEntityPos.x, targetEntityPos.y, pts)
                        console.log("[Debug]   → Personnage dans cette zone ? " + (isIn ? "OUI !" : "non") )
                        console.log("[Debug]   → Position de l'entité en grille: (" + targetEntityPos.x.toFixed(2) + ", " + targetEntityPos.y.toFixed(2) + ")")
                    }
                }
            }
        }
        console.log("[Debug] Total zones d'exclusion:", zoneCount)

        if (zoneCount > 0 && targetEntity) {
            console.log("[Debug] ")
            console.log("[Debug] === AIDE CALIBRATION ===")
            console.log("[Debug] Si le personnage est VISUELLEMENT sur la zone mais 'non' ci-dessus,")
            console.log("[Debug] la conversion 3D→grille n'est pas correcte.")
            console.log("[Debug] Déplacez le personnage AU CENTRE de la zone et notez les coordonnées.")
        }
    }

    /**
     * Vérifie si un mouvement est valide (ne traverse pas de zone d'exclusion)
     * Vérifie plusieurs points le long du rayon de collision
     */
    function canMoveTo(newX, newZ) {
        // Vérifier le centre
        if (isInExclusionZone(newX, newZ)) return false

        // Vérifier les 4 points cardinaux autour du personnage (rayon de collision)
        var checkPoints = [
            { x: newX + collisionRadius, z: newZ },
            { x: newX - collisionRadius, z: newZ },
            { x: newX, z: newZ + collisionRadius },
            { x: newX, z: newZ - collisionRadius }
        ]

        for (var i = 0; i < checkPoints.length; i++) {
            if (isInExclusionZone(checkPoints[i].x, checkPoints[i].z)) {
                return false
            }
        }

        return true
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

    function rotateEntity(dx, dz) {
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

    function moveEntity(inputVector, dt)
    {

        // --- 1. Déplacement ---
        if (inputVector.length() > 0) {
            // Vitesse actuelle

        var dx = inputVector.x * speed * dt
        var dz = -inputVector.y * speed * dt // Avancer (Y+) = aller vers Z négatif

        // // Appliquer le déplacement
        // root.targetEntity.x += dx
        // root.targetEntity.z += dz

        // Calculer la nouvelle position
        var newX = root.targetEntity.x + dx
        var newZ = root.targetEntity.z + dz

        // Vérifier les collisions avec les zones d'exclusion
        var canMoveX = canMoveTo(newX, root.targetEntity.z)
        var canMoveZ = canMoveTo(root.targetEntity.x, newZ)
        var canMoveBoth = canMoveTo(newX, newZ)

        // Appliquer le déplacement selon ce qui est possible
        if (canMoveBoth) {
            // Mouvement complet autorisé
            root.targetEntity.x = newX
            root.targetEntity.z = newZ
        } else if (canMoveX && !canMoveZ) {
            // Glisser le long de l'obstacle (axe X seulement)
            root.targetEntity.x = newX
            if (debugCollision) console.log("[Collision] Bloqué en Z, glisse en X")
        } else if (!canMoveX && canMoveZ) {
            // Glisser le long de l'obstacle (axe Z seulement)
            root.targetEntity.z = newZ
            if (debugCollision) console.log("[Collision] Bloqué en X, glisse en Z")
        } else if (!canMoveX && !canMoveZ) {
            if (debugCollision) console.log("[Collision] Bloqué complètement!")
        }
        var speed = root.moveSpeed * (root.isSprinting ? root.sprintMultiplier : 1.0)

        // Rotation du personnage vers la direction du mouvement (optionnel mais cool)
        if (dx !== 0 || dz !== 0){
            rotateEntity(dx, dz)
        }

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
                if ( inputVector.length() > 0)
                    CameraController.moveManual(inputVector.x, inputVector.y, speed * 1.5, dt)
            }
            else
            {
                moveEntity(inputVector, dt)
            }


        }
    }
}

