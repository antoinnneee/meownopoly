/*
 * PhysicsActor — Phase 4
 *
 * Présentateur 3D : ne crée PAS de body côté C++. Il lit `bodyState(bodyId)`
 * à chaque frame de rendu et applique la position au `node3D` avec un
 * lissage exponentiel impératif.
 *
 * Approche après plusieurs essais :
 *  - Lissage exponentiel direct sur `node3D.x/z` (amortit les sauts 60 Hz +
 *    le tremblement basse-fréquence injecté par le mapping caméra↔grille).
 *  - Pas de Binding dynamique (cassait l'écriture sur `eulerRotation.y` qui
 *    n'est pas une property simple) ni de SmoothedAnimation (Binding sur un
 *    node externe ne s'attachait pas correctement, joueur restait à zéro).
 *
 * La création du body est de la responsabilité de l'orchestrateur :
 *  - LocalPlayerSpawner pour le joueur local (Kinematic)
 *  - EditorPhysicsBridge pour les objets dynamiques posés en éditeur (Dynamic)
 *
 * Auto-enregistrement dans le registry de World3D pour participer au tick.
 */
import QtQuick
import QtQuick3D

Item {
    id: root

    required property string bodyId
    required property var world3D
    property Node node3D: null

    // Hauteur visuelle (2.5D présentation, hors physique).
    // Animée par les helpers jump()/wave() ci-dessous via SequentialAnimation
    // sur cette property. `pullAndApply` ré-écrit node3D.y = visualY à chaque
    // frame de rendu donc la valeur courante de l'anim suit naturellement.
    property real visualY: 0

    // Hauteur de repos (revenir à) — utile si plus tard un actor "vit" sur
    // une plateforme à Y constant non nul.
    property real restY: 0

    // Lissage : 0 = pas de lissage (saut direct), 1 = jamais atteint.
    // 0.3 ≈ 70 % du chemin parcouru en 3 frames (~50 ms à 60 Hz).
    property bool interpolate: true
    property real smoothing: 0.3

    // Orientation auto depuis la velocity. Lerp doux pour éviter le jitter
    // d'orientation quand la velocity est presque nulle.
    property bool autoOrient: true
    property real orientLerp: 0.2

    property bool _seeded: false

    // ---- Debug jitter ---------------------------------------------------
    // `startJitterTrace(N)` active un log CSV pendant N frames. Tous les
    // observateurs sont capturés dans la même frame de rendu pour pouvoir
    // corréler. Format conçu pour être grep-é puis chargé dans un tableur.
    //
    // Colonnes :
    //   frame, lastTick, dTick, frameMs,
    //   physGx, physGy, physVx, physVy,
    //   stableX, stableZ, unstableX, unstableZ, mapDx, mapDz,
    //   nodePreX, nodePreZ, nodePostX, nodePostZ, nodeDx, nodeDz,
    //   camX, camZ
    //
    // dTick : nombre de ticks physiques écoulés depuis la frame précédente
    //   (devrait être 0 ou 1 à 60Hz tick = 60Hz rendu ; 2+ = saut).
    // mapDx/Dz : delta entre stable et unstable mapping → quantifie le
    //   tremblement basse-fréquence dû au coupling caméra.
    // nodeDx/Dz : déplacement effectif du node entre 2 frames (utile pour
    //   spotter les sauts visibles).
    property int  _traceFramesLeft: 0
    property int  _traceFrameIdx: 0
    property real _traceLastMs: 0
    property int  _traceLastTick: -1
    property real _traceLastNodeX: 0
    property real _traceLastNodeZ: 0

    function startJitterTrace(frames) {
        _traceFramesLeft = frames > 0 ? frames : 180
        _traceFrameIdx   = 0
        _traceLastMs     = Date.now()
        _traceLastTick   = -1
        _traceLastNodeX  = node3D ? node3D.x : 0
        _traceLastNodeZ  = node3D ? node3D.z : 0
        console.log("[JITTER] trace start frames=" + _traceFramesLeft
                    + " bodyId=" + bodyId)
        console.log("[JITTER] CSV header: "
                    + "frame,tick,dTick,frameMs,"
                    + "physGx,physGy,physVx,physVy,"
                    + "stableX,stableZ,unstableX,unstableZ,mapDx,mapDz,"
                    + "nodePreX,nodePreZ,nodePostX,nodePostZ,nodeDx,nodeDz,"
                    + "camX,camZ")
    }

    function _logTrace(s, posStable, posUnstable, prePosX, prePosZ) {
        const nowMs   = Date.now()
        const dtMs    = _traceLastMs > 0 ? (nowMs - _traceLastMs) : 0
        _traceLastMs  = nowMs
        const tick    = world3D.physicsWorld.currentGuiTick
                        ? world3D.physicsWorld.currentGuiTick() : 0
        const dTick   = _traceLastTick < 0 ? 0 : (tick - _traceLastTick)
        _traceLastTick = tick
        const cam = world3D.camera
        const camX = cam ? cam.x : 0
        const camZ = cam ? cam.z : 0
        const nodeDx = node3D.x - _traceLastNodeX
        const nodeDz = node3D.z - _traceLastNodeZ
        _traceLastNodeX = node3D.x
        _traceLastNodeZ = node3D.z
        console.log("[JITTER] " + _traceFrameIdx
            + "," + tick + "," + dTick + "," + dtMs.toFixed(2)
            + "," + s.position.x.toFixed(5) + "," + s.position.y.toFixed(5)
            + "," + s.velocity.x.toFixed(3) + "," + s.velocity.y.toFixed(3)
            + "," + posStable.x.toFixed(3) + "," + posStable.z.toFixed(3)
            + "," + posUnstable.x.toFixed(3) + "," + posUnstable.z.toFixed(3)
            + "," + (posStable.x - posUnstable.x).toFixed(4)
            + "," + (posStable.z - posUnstable.z).toFixed(4)
            + "," + prePosX.toFixed(3) + "," + prePosZ.toFixed(3)
            + "," + node3D.x.toFixed(3) + "," + node3D.z.toFixed(3)
            + "," + nodeDx.toFixed(4) + "," + nodeDz.toFixed(4)
            + "," + camX.toFixed(3) + "," + camZ.toFixed(3))
        _traceFrameIdx++
    }

    function pullAndApply(_unusedAlpha) {
        if (!world3D || !world3D.physicsWorld || !node3D) return
        const s = world3D.physicsWorld.bodyState(bodyId)
        if (!s.id) return                       // body pas (encore) créé

        // gridToWorldStable : mapping affine figé (origin + base capturés
        // au démarrage). Évite le jitter dû au coupling caméra↔mapping.
        const pos3D = world3D.gridToWorldStable(s.position.x, s.position.y)

        // Pour le trace : capturer aussi le mapping non-stable pour mesurer
        // l'écart caméra-induit, et la position node3D AVANT lissage pour
        // mesurer ce que le lissage absorbe.
        let posUnstable = null
        let prePosX = 0, prePosZ = 0
        if (_traceFramesLeft > 0) {
            posUnstable = world3D.gridPositionTo3D(s.position.x, s.position.y)
            prePosX = node3D.x
            prePosZ = node3D.z
        }

        if (!_seeded || !interpolate) {
            node3D.x = pos3D.x
            node3D.z = pos3D.z
            _seeded = true
        } else {
            node3D.x += (pos3D.x - node3D.x) * smoothing
            node3D.z += (pos3D.z - node3D.z) * smoothing
        }
        node3D.y = visualY

        if (autoOrient && s.velocity.length() > 0.1) {
            const target = Math.atan2(s.velocity.x, s.velocity.y) * 180 / Math.PI
            const cur = node3D.eulerRotation.y
            let d = target - cur
            while (d < -180) d += 360
            while (d >  180) d -= 360
            node3D.eulerRotation.y = cur + d * orientLerp
        }

        if (_traceFramesLeft > 0) {
            _logTrace(s, pos3D, posUnstable, prePosX, prePosZ)
            _traceFramesLeft--
            if (_traceFramesLeft === 0)
                console.log("[JITTER] trace end")
        }
    }

    // ---- Phase 8 — Y visuel animé (saut + vague) -----------------------
    // Ces helpers ne touchent JAMAIS au moteur physique : ils ne font que
    // varier `visualY`, lue à chaque frame par `pullAndApply` et appliquée
    // sur `node3D.y`. La collision (rayon, position grille) reste inchangée.
    //
    // Implémentation : on instancie une SequentialAnimation à la volée et
    // on la stocke dans `_yAnim` pour pouvoir la stopper proprement (un
    // nouveau jump pendant qu'un wave tourne, etc.).

    property var _yAnim: null

    property Component _jumpAnim: SequentialAnimation {
        id: jumpSeq
        property real height: 1.0
        property real duration: 600
        property real baseY: 0
        NumberAnimation {
            target: root; property: "visualY"
            from: jumpSeq.baseY
            to: jumpSeq.baseY + jumpSeq.height
            duration: jumpSeq.duration / 2
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root; property: "visualY"
            from: jumpSeq.baseY + jumpSeq.height
            to: jumpSeq.baseY
            duration: jumpSeq.duration / 2
            easing.type: Easing.InQuad
        }
    }

    property Component _waveAnim: SequentialAnimation {
        id: waveSeq
        property real amplitude: 0.5
        property real period: 800
        property real baseY: 0
        loops: Animation.Infinite
        NumberAnimation {
            target: root; property: "visualY"
            from: waveSeq.baseY
            to: waveSeq.baseY + waveSeq.amplitude
            duration: waveSeq.period / 2
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root; property: "visualY"
            from: waveSeq.baseY + waveSeq.amplitude
            to: waveSeq.baseY
            duration: waveSeq.period / 2
            easing.type: Easing.InOutSine
        }
    }

    // Saut purement cosmétique. height en unités world3D (la même unité que
    // node3D.y, i.e. pixels-grille × gridSize). duration en ms.
    function jump(height, duration) {
        const h = (height === undefined) ? 1.0 : height
        const d = (duration === undefined) ? 600 : duration
        stopVisualY()
        _yAnim = _jumpAnim.createObject(root, {
            "height": h, "duration": d, "baseY": restY
        })
        if (_yAnim) _yAnim.start()
    }

    // Sinusoïde infinie autour de restY. amplitude/period mêmes unités.
    function wave(amplitude, period) {
        const a = (amplitude === undefined) ? 0.5 : amplitude
        const p = (period === undefined) ? 800 : period
        stopVisualY()
        _yAnim = _waveAnim.createObject(root, {
            "amplitude": a, "period": p, "baseY": restY
        })
        if (_yAnim) _yAnim.start()
    }

    // Stoppe l'anim en cours (s'il y en a une) et ramène visualY à restY.
    function stopVisualY() {
        if (_yAnim) {
            _yAnim.stop()
            _yAnim.destroy()
            _yAnim = null
        }
        visualY = restY
    }

    Component.onCompleted: if (world3D) world3D.registryRef.add(root)
    Component.onDestruction: {
        stopVisualY()
        if (world3D) world3D.registryRef.remove(root)
    }
}
