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

    // Lissage : fraction du chemin parcourue par frame DE RÉFÉRENCE 60 Hz
    // (0 = figé sur place, 1 = snap immédiat). 0.3 ≈ 66 % du chemin en
    // 3 frames (~50 ms à 60 Hz). La conversion framerate-indépendante
    // (1 - pow(1-s, dt·60), équivalent 1-exp(-k·dt)) est faite dans
    // pullAndApply — un facteur appliqué "par frame" serait ~2.4× plus
    // raide à 144 Hz qu'à 60 Hz (même famille que la régression jitter
    // du triple buffer déjà corrigée ; CameraRig fait pareil).
    property bool interpolate: true
    property real smoothing: 0.3

    // Orientation auto depuis la velocity. Lerp doux pour éviter le jitter
    // d'orientation quand la velocity est presque nulle. Même sémantique
    // 60 Hz de référence + conversion framerate-indépendante que smoothing.
    property bool autoOrient: true
    property real orientLerp: 0.2

    // True dès que le node a reçu au moins une position physique valide.
    // Les spawners conditionnent la visibilité dessus côté client réseau :
    // sans ça, un node est affiché à l'origine (0,0,0) tant que le
    // BodiesAnnounce n'est pas arrivé, et reste figé si le body disparaît
    // côté hôte (dé-seed après _missTolerance échecs consécutifs).
    property bool seeded: false
    // Nombre de frames consécutives sans bodyState avant de dé-seeder
    // (~1,5 s à 60 Hz : tolère les trous transitoires de table idIndex).
    property int missTolerance: 90
    property int _missCount: 0

    /// Force un re-seed : le prochain état valide est appliqué sans lissage
    /// (respawn, re-création du body).
    function reseed() {
        seeded = false
        _missCount = 0
    }

    // `dt` : durée de la frame de rendu en secondes (frameTime du tick de
    // World3D). Sert au lissage framerate-indépendant ; fallback 1/60 si
    // absent (premier tick, appelant legacy).
    function pullAndApply(dt) {
        if (!world3D || !world3D.physicsWorld) return
        applyState(world3D.physicsWorld.bodyState(bodyId), dt)
    }

    // Variante batch : World3D tire les états de TOUS les actors en un seul
    // appel C++ (bodyStates) et distribue ici — cf. review T13/Q13.
    function applyState(s, dt) {
        if (!node3D) return
        if (!s || !s.id) {
            // Body pas (encore) créé — ou disparu côté hôte : dé-seed après
            // tolérance pour que la visibilité (spawners) retombe.
            if (seeded && ++_missCount >= missTolerance) reseed()
            return
        }
        _missCount = 0

        const frameDt = (dt !== undefined && dt > 0) ? dt : 1 / 60

        // gridToWorldStable : mapping affine figé (origin + base capturés
        // au démarrage). Évite le jitter dû au coupling caméra↔mapping.
        const pos3D = world3D.gridToWorldStable(s.position.x, s.position.y)

        if (!seeded || !interpolate) {
            node3D.x = pos3D.x
            node3D.z = pos3D.z
            seeded = true
        } else {
            const t = smoothing >= 1 ? 1
                    : 1 - Math.pow(1 - smoothing, frameDt * 60)
            node3D.x += (pos3D.x - node3D.x) * t
            node3D.z += (pos3D.z - node3D.z) * t
        }
        node3D.y = visualY

        // Orientation : atan2(vx, vy) sur la velocity GRILLE alors que le
        // mapping monde est Z3D = -gy — le yaw est donc en miroir sur Z par
        // rapport à un mapping naïf. C'est compensé par l'orientation de
        // base des modèles (validé visuellement : les actors regardent dans
        // leur direction de déplacement). Ne pas "corriger" sans re-tester
        // tous les modèles — cf. review Q9.
        if (autoOrient && s.velocity.length() > 0.1) {
            const target = Math.atan2(s.velocity.x, s.velocity.y) * 180 / Math.PI
            const cur = node3D.eulerRotation.y
            let d = target - cur
            while (d < -180) d += 360
            while (d >  180) d -= 360
            const ot = orientLerp >= 1 ? 1
                     : 1 - Math.pow(1 - orientLerp, frameDt * 60)
            node3D.eulerRotation.y = cur + d * ot
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
