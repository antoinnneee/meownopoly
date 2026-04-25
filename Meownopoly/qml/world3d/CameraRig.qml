/*
 * CameraRig — Phase 4 (stratégies Follow + FreeCam)
 *
 * Port de l'ancien CameraController singleton vers un composant
 * instanciable, avec un mode énuméré. Phase 5 ajoutera FixedTopDown,
 * OrbitDebug et le switch à chaud propre.
 *
 * Dépendances :
 *  - `world3D`  : référence au World3D parent (pour view3D + grid sync)
 *  - `target`   : Node 3D que la caméra doit suivre (ex: entity du joueur)
 *  - `grid2D`   : Item 2D (la grille) à décaler en synchronisation
 *  - `mouseLogicRef` : optionnel, pour rafraîchir lastGridPos après déplacement
 *
 * Mode :
 *  - Follow : suit `target` avec lerp frame-rate independent ; sync grid 2D
 *  - FreeCam : moveManual depuis input externe ; pas de suivi
 */
import QtQuick
import QtQuick3D

Item {
    id: root

    enum Mode { Follow, FreeCam }

    required property var world3D
    property Node target: null
    property Item grid2D: null
    property var  mouseLogicRef: null

    property int  mode: CameraRig.Follow
    property real smoothSpeed: 2.0
    property vector3d offset: Qt.vector3d(0, 0, 0)

    // Recalcule un offset qui centre `target` à l'écran sous l'angle
    // actuel de la caméra. Appelé à `setTarget` et toujours réutilisable.
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

    // FreeCam : déplacement manuel par input (vecteur 2D), avec sync grid 2D.
    function moveManual(inputX, inputY, speed, dt) {
        const cam   = world3D ? world3D.camera : null
        const view3D = world3D ? world3D.view3D : null
        if (!cam || !view3D || !grid2D) return

        const dx = inputX * speed * dt
        const dz = inputY * speed * dt
        if (dx === 0 && dz === 0) return

        // Point de référence au sol pour mesurer le déplacement écran.
        const refPoint3D = Qt.vector3d(cam.x, 0, cam.z - 600)
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

    // Loop Follow : lerp + sync grid 2D.
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
}
