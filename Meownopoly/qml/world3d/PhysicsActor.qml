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
    property real visualY: 0

    // Lissage : 0 = pas de lissage (saut direct), 1 = jamais atteint.
    // 0.3 ≈ 70 % du chemin parcouru en 3 frames (~50 ms à 60 Hz).
    property bool interpolate: true
    property real smoothing: 0.3

    // Orientation auto depuis la velocity. Lerp doux pour éviter le jitter
    // d'orientation quand la velocity est presque nulle.
    property bool autoOrient: true
    property real orientLerp: 0.2

    property bool _seeded: false

    function pullAndApply(_unusedAlpha) {
        if (!world3D || !world3D.physicsWorld || !node3D) return
        const s = world3D.physicsWorld.bodyState(bodyId)
        if (!s.id) return                       // body pas (encore) créé

        // gridToWorldStable : mapping affine figé (origin + base capturés
        // au démarrage). Évite le jitter dû au coupling caméra↔mapping.
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

        if (autoOrient && s.velocity.length() > 0.1) {
            const target = Math.atan2(s.velocity.x, s.velocity.y) * 180 / Math.PI
            const cur = node3D.eulerRotation.y
            let d = target - cur
            while (d < -180) d += 360
            while (d >  180) d -= 360
            node3D.eulerRotation.y = cur + d * orientLerp
        }
    }

    Component.onCompleted: if (world3D) world3D.registryRef.add(root)
    Component.onDestruction: if (world3D) world3D.registryRef.remove(root)
}
