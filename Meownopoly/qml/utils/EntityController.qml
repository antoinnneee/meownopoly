pragma Singleton
import QtQuick

Item {
    id: root

    // --- Configuration ---
    property var targetEntity: null
    property var view3D: null

    // Vitesse de déplacement en unités par seconde
    property real moveSpeed: 500.0
    property real sprintMultiplier: 2.0

    // --- État interne ---
    property vector2d inputVector: Qt.vector2d(0, 0)
    property bool isSprinting: false
    property real lastTimestamp: 0

    // --- API Publique ---

    // Fonction pour définir la cible
    function setTarget(entity, view) {
        targetEntity = entity
        view3D = view
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

            // Vitesse actuelle
            var speed = root.moveSpeed * (root.isSprinting ? root.sprintMultiplier : 1.0)

            // Si pas d'input, on arrête
            if (inputVector.length() === 0) return

            // Calcul du déplacement local (X = droite, Y = avant)
            // Mais attention, dans le monde 3D QtQuick3D:
            // X = Droite
            // Y = Haut (Ciel)
            // Z = Profondeur (Sort de l'écran) -> -Z est "Avant"

            // Il faut projeter l'input "Avancer" (Y input) vers la direction "Avant" de la caméra projetée au sol
            // Et "Droite" (X input) vers la droite de la caméra.

            // Pour une caméra orthographique à -55 deg sur X:
            // Droite caméra = X Monde
            // Avant caméra = Z Monde (négatif) projeté

            // Simplification pour vue Top-Down :
            // Input X -> World X
            // Input Y -> World -Z (Avancer vers le fond)

            var dx = inputVector.x * speed * dt
            var dz = -inputVector.y * speed * dt // Avancer (Y+) = aller vers Z négatif

            // TODO: Ajouter ici la logique de rotation relative à la caméra si besoin

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
    }
}

