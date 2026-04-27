/*
 * PhysicsObject — Phase 9
 *
 * Présentateur 3D pour un body Dynamic du moteur Pattounx (typiquement une
 * caisse posée par l'éditeur). Identique à PhysicsActor côté lecture du
 * snapshot ; la différence est purement sémantique (le body côté worker
 * a `BodyType::Dynamic` → poussé par les chats, ralenti par friction,
 * répond aux impulsions) — la création du body est déléguée à
 * `EditorPhysicsBridge` (cf. décision §19 du plan).
 *
 * Comme PhysicsActor, on s'auto-enregistre dans le registry de World3D
 * pour que le tick d'interpolation appelle `pullAndApply()`.
 */
import QtQuick
import QtQuick3D

Item {
    id: root

    required property string bodyId
    required property var world3D
    property Node node3D: null

    // Lissage exponentiel comme PhysicsActor — même justification (jitter
    // de mapping caméra↔grille). 0.3 ≈ 70 % du chemin parcouru en 3 frames.
    property bool interpolate: true
    property real smoothing: 0.3

    // Hauteur de pose (les caisses reposent sur le sol par défaut).
    property real visualY: 0

    property bool _seeded: false

    function pullAndApply(_unusedAlpha) {
        if (!world3D || !world3D.physicsWorld || !node3D) return
        const s = world3D.physicsWorld.bodyState(bodyId)
        if (!s.id) return                       // body pas (encore) créé

        const pos3D = world3D.gridToWorldStable(s.position.x, s.position.y)

        if (!_seeded || !interpolate) {
            node3D.x = pos3D.x
            node3D.z = pos3D.z
            _seeded = true
        } else {
            node3D.x += (pos3D.x - node3D.x) * smoothing
            node3D.z += (pos3D.z - node3D.z) * smoothing
        }
        node3D.y = visualY
    }

    Component.onCompleted: if (world3D) world3D.registryRef.add(root)
    Component.onDestruction: if (world3D) world3D.registryRef.remove(root)
}
