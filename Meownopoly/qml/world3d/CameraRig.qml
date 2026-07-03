/*
 * CameraRig — Phase 5 (Follow / FreeCam / FixedTopDown / OrbitDebug)
 *
 * Composant instanciable, hérite de l'ancien CameraController singleton.
 *
 * Modes :
 *  - Follow        : suit `target` avec lerp frame-rate independent ; sync
 *                    grid 2D côté éditeur (gameGrid suit la caméra).
 *  - FreeCam       : pas de suivi ; déplacement manuel via `moveManual`
 *                    (boucle externe qui lit l'input).
 *  - FixedTopDown  : caméra figée (snap top-down 90°), pas de suivi, pas de
 *                    mouvement automatique. Utile pour inspection statique.
 *  - OrbitDebug    : orbite autour de `target` (orbitYaw / orbitPitch /
 *                    orbitDistance). Pas de sync grid 2D. Pour debug 3D.
 *
 * Switch à chaud : `setMode(newMode)` gère les transitions (snap des
 * valeurs caméra utiles, recompute offset au passage en Follow).
 *
 * Dépendances :
 *  - `world3D`        : référence au World3D parent (view3D + caméra)
 *  - `target`         : Node à suivre / orbiter
 *  - `grid2D`         : Item 2D (la grille) à décaler en Follow
 *  - `mouseLogicRef`  : optionnel, pour rafraîchir lastGridPos
 */
import QtQuick
import QtQuick3D

Item {
    id: root

    enum Mode { Follow, FreeCam, FixedTopDown, OrbitDebug }

    required property var world3D
    property Node target: null
    property Item grid2D: null
    property var  mouseLogicRef: null

    property int  mode: CameraRig.Follow
    property real smoothSpeed: 2.0
    property vector3d offset: Qt.vector3d(0, 0, 0)

    // Distance (unités monde) devant la caméra du point de référence au sol
    // utilisé par moveManual pour mesurer le déplacement écran de la grille.
    property real groundRefDistance: 600

    // --- Paramètres du mode OrbitDebug ---
    // Yaw en degrés autour de l'axe Y du target ; pitch en degrés (clamp
    // -89..89 pour éviter le gimbal). Distance horizontale projetée au sol.
    property real orbitYaw: 0
    property real orbitPitch: -55
    property real orbitDistance: 600

    // Angles caméra capturés à l'entrée d'un mode "destructeur"
    // (FixedTopDown écrase pitch à -90, OrbitDebug pilote pitch/yaw chaque
    // frame). Sans restauration, le retour en Follow ferait recomputeOffset()
    // avec tan(-90°) → caméra top-down définitive, et un yaw résiduel
    // d'OrbitDebug casserait le mapping affine caméra↔grille.
    property var _savedAngles: null

    // Recalcule un offset qui centre `target` à l'écran sous l'angle
    // actuel de la caméra. Appelé à `setTarget` et toujours réutilisable.
    // (Anciennement `setOffsetFromCameraAngle` dans le plan §5.10.)
    function recomputeOffset() {
        const cam = world3D ? world3D.camera : null
        if (!cam) return
        const cameraHeight = cam.y
        const angleRad = cam.eulerRotation.x * Math.PI / 180
        // tan(rad) ≈ 0 si l'angle est ~0 → garde-fou
        const t = Math.tan(angleRad)
        const zOffset = Math.abs(t) > 0.0001 ? -cameraHeight / t : 0
        offset = Qt.vector3d(0, cameraHeight, zOffset)
    }

    function setTarget(newTarget, newGrid2D, newMouseLogicRef) {
        target = newTarget
        if (newGrid2D !== undefined)        grid2D = newGrid2D
        if (newMouseLogicRef !== undefined) mouseLogicRef = newMouseLogicRef
        recomputeOffset()
    }

    function snapToTarget() {
        const cam = world3D ? world3D.camera : null
        if (!cam || !target) return
        cam.x = target.x + offset.x
        cam.y = target.y + offset.y
        cam.z = target.z + offset.z
    }

    // Switch à chaud propre : initialise les paramètres internes du mode
    // entrant à partir de l'état actuel de la caméra (pas de saut visuel),
    // et arrête naturellement la boucle Follow / Orbit du mode sortant
    // via le `running` binding des FrameAnimation.
    function setMode(newMode) {
        if (newMode === mode) return
        const cam = world3D ? world3D.camera : null
        if (!cam) { mode = newMode; return }

        // Capture des angles d'origine à l'entrée du PREMIER mode
        // destructeur (pas d'écrasement en passant FixedTopDown↔OrbitDebug),
        // restauration à la sortie AVANT le recomputeOffset du mode entrant.
        const destructive = (newMode === CameraRig.FixedTopDown
                             || newMode === CameraRig.OrbitDebug)
        if (destructive && _savedAngles === null) {
            _savedAngles = { x: cam.eulerRotation.x,
                             y: cam.eulerRotation.y,
                             z: cam.eulerRotation.z }
        } else if (!destructive && _savedAngles !== null) {
            cam.eulerRotation.x = _savedAngles.x
            cam.eulerRotation.y = _savedAngles.y
            cam.eulerRotation.z = _savedAngles.z
            _savedAngles = null
        }

        if (newMode === CameraRig.Follow) {
            recomputeOffset()
        } else if (newMode === CameraRig.FixedTopDown) {
            // Snap top-down strict : caméra droit dessus, regard vertical.
            // On capture la position XZ actuelle pour ne pas téléporter.
            cam.eulerRotation.x = -90
            cam.eulerRotation.y = 0
            cam.eulerRotation.z = 0
        } else if (newMode === CameraRig.OrbitDebug && target) {
            // Initialise yaw/pitch/distance à partir du delta target↔cam
            // pour ne pas téléporter au switch.
            const dx = cam.x - target.x
            const dy = cam.y - target.y
            const dz = cam.z - target.z
            const horizDist = Math.sqrt(dx * dx + dz * dz)
            orbitDistance = Math.max(horizDist, 50)
            orbitYaw   = Math.atan2(dx, dz) * 180 / Math.PI
            orbitPitch = -Math.atan2(dy, horizDist) * 180 / Math.PI
            // L'orbit applique sa propre rotation chaque frame.
        }
        mode = newMode
    }

    // FreeCam : déplacement manuel par input (vecteur 2D), avec sync grid 2D.
    function moveManual(inputX, inputY, speed, dt) {
        const cam   = world3D ? world3D.camera : null
        const view3D = world3D ? world3D.view3D : null
        if (!cam || !view3D || !grid2D) return

        const dx = inputX * speed * dt
        const dz = inputY * speed * dt
        if (dx === 0 && dz === 0) return

        // Point de référence au sol pour mesurer le déplacement écran.
        const refPoint3D = Qt.vector3d(cam.x, 0, cam.z - groundRefDistance)
        const screenPosPre = view3D.mapFrom3DScene(refPoint3D)

        cam.x += dx
        cam.z += dz

        const screenPosPost = view3D.mapFrom3DScene(refPoint3D)
        const dxScreen = screenPosPost.x - screenPosPre.x
        const dyScreen = screenPosPost.y - screenPosPre.y

        grid2D.x += dxScreen
        grid2D.y += dyScreen

        if (mouseLogicRef)
            mouseLogicRef.lastGridPos = Qt.point(grid2D.x, grid2D.y)
    }

    // OrbitDebug : applique un delta yaw/pitch/distance (boucle externe ou
    // input direct). Le `clampPitch` évite la singularité du pôle.
    function orbitDelta(deltaYaw, deltaPitch, deltaDist) {
        orbitYaw   += deltaYaw
        orbitPitch = Math.max(-89, Math.min(89, orbitPitch + deltaPitch))
        orbitDistance = Math.max(20, orbitDistance + deltaDist)
    }

    // --- Boucle Follow : lerp + sync grid 2D ---
    FrameAnimation {
        running: root.mode === CameraRig.Follow
                 && root.target !== null
                 && root.world3D !== null
                 && root.world3D.camera !== null

        onTriggered: {
            const cam   = root.world3D.camera
            const view3D = root.world3D.view3D
            const dt    = frameTime

            // Pré-mesure (avant déplacement caméra) de la position écran
            // de la cible — sert à recalibrer le grid 2D.
            let screenPosPre = Qt.point(0, 0)
            if (root.grid2D && view3D)
                screenPosPre = view3D.mapFrom3DScene(root.target.position)

            const targetCamX = root.target.x + root.offset.x
            const targetCamY = root.target.y + root.offset.y
            const targetCamZ = root.target.z + root.offset.z

            // Lerp frame-rate independent : 1 - exp(-k * dt)
            const t = 1.0 - Math.exp(-root.smoothSpeed * dt)
            cam.x += (targetCamX - cam.x) * t
            cam.y += (targetCamY - cam.y) * t
            cam.z += (targetCamZ - cam.z) * t

            if (root.grid2D && view3D) {
                const screenPosPost = view3D.mapFrom3DScene(root.target.position)
                const dxScreen = screenPosPost.x - screenPosPre.x
                const dyScreen = screenPosPost.y - screenPosPre.y
                root.grid2D.x += dxScreen
                root.grid2D.y += dyScreen
                if (root.mouseLogicRef)
                    root.mouseLogicRef.lastGridPos = Qt.point(root.grid2D.x,
                                                              root.grid2D.y)
            }
        }
    }

    // --- Boucle OrbitDebug : pose la caméra depuis yaw/pitch/distance ---
    // Pas de sync grid 2D : c'est un mode debug, la grille n'a pas à suivre.
    FrameAnimation {
        running: root.mode === CameraRig.OrbitDebug
                 && root.target !== null
                 && root.world3D !== null
                 && root.world3D.camera !== null

        onTriggered: {
            const cam = root.world3D.camera
            const yawRad   = root.orbitYaw   * Math.PI / 180
            const pitchRad = root.orbitPitch * Math.PI / 180
            const horiz = root.orbitDistance * Math.cos(pitchRad)
            const vert  = -root.orbitDistance * Math.sin(pitchRad)
            cam.x = root.target.x + horiz * Math.sin(yawRad)
            cam.z = root.target.z + horiz * Math.cos(yawRad)
            cam.y = root.target.y + vert
            cam.eulerRotation.x = root.orbitPitch
            cam.eulerRotation.y = root.orbitYaw
            cam.eulerRotation.z = 0
        }
    }
}
