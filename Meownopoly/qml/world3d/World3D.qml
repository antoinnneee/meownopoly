/*
 * World3D — Phase 4 (remplace GameScene.qml + World3DTools singleton)
 *
 * Une scène 3D autonome :
 *  - View3D + OrthographicCamera + DirectionalLight + entityNode (id alias)
 *  - Helpers de conversion grid 2D ↔ monde 3D (ex-World3DTools)
 *  - Registry des PhysicsActor pour le tick d'interpolation
 *  - Consomme l'instance globale `pattounxWorld` (cf. qmlapp.cpp)
 *
 * Préserve l'API publique de GameScene pour minimiser les ripples dans
 * Editor.qml : view3D, scene, camera, entity, environment, gridManager,
 * cameraMagnification, modelName + functions generateSphere /
 * moveEntityToGridPixelPosition / moveEntityToGridPosition /
 * getEntityGridPixelPosition / getEntityGridRealPosition.
 */
import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import AssetManager
import meowComponent

Item {
    id: root

    // --- Public API (héritée de GameScene) ---
    property alias view3D: view3D
    property alias scene: sceneNode
    property alias camera: cameraOrthographic
    property alias entity: entityNode
    property alias environment: sceneEnvironment
    required property GridManager gridManager

    property real cameraMagnification: 1.0
    property string modelName: "Princess"
    // Re-skin Color ID Map du joueur principal (JSON du PlayerProfile).
    property string colorVariant: ""
    // Couleur d'équipe imposée par la partie (sur les zones team:true).
    property color teamColorOverride: "transparent"

    // Référence au moteur physique global. Utilisé par PhysicsActor /
    // CameraRig / InputController. Décision §3 du plan : un PhysicsWorld
    // par scène à terme — pour l'instant on consomme le global pour ne pas
    // recréer le worker thread à chaque navigation Editor↔CatwayTest.
    readonly property var physicsWorld: pattounxWorld

    // --- Conversions grille ↔ monde 3D (ex-World3DTools) ---

    // Conversion symétrique grid 2D → world 3D (X3D = gx*gridSize, Z3D = -gy*gridSize).
    // Pas de projection caméra : utilisable même sans avoir un view3D rendu.
    function gridToWorld(gx, gy) {
        const s = gridManager ? gridManager.gridSize : 1.0
        return Qt.vector3d(gx * s, 0, -gy * s)
    }

    function worldToGrid(x3D, z3D) {
        const s = gridManager ? gridManager.gridSize : 1.0
        return Qt.vector2d(x3D / s, -z3D / s)
    }

    // Mapping affine stable calibré une fois sur gridPositionTo3D, puis figé.
    //
    // gridPositionTo3D dépend de la caméra (mapTo3DScene) ; or la caméra
    // lerp à part du tick physique, donc même position grille produit des
    // positions 3D légèrement différentes selon la frame de rendu →
    // tremblement visible (jitter basse fréquence).
    //
    // La projection ortho étant affine, les vecteurs de base (b1, b2) sont
    // **constants** dans le temps : seule l'origine peut dériver. On capture
    // origin/b1/b2 au premier appel (quand view3D est prêt) et on réutilise
    // toujours ces coefficients. La caméra peut bouger, gameGrid peut
    // recalibrer son offset 2D, le mapping monde 3D reste fixe — c'est
    // exactement ce qu'on veut pour la stabilité visuelle.
    property var _gridBasis: null

    function _ensureGridBasis() {
        if (_gridBasis) return _gridBasis
        if (!view3D || !gridManager) return null
        // Sentinelle : si view3D n'a pas encore de taille, mapTo3DScene
        // peut renvoyer du bruit. On reporte au prochain appel.
        if (view3D.width <= 0 || view3D.height <= 0) return null
        const o  = gridPositionTo3D(0, 0)
        const ux = gridPositionTo3D(1, 0)
        const uy = gridPositionTo3D(0, 1)
        _gridBasis = {
            ox: o.x, oz: o.z,
            b1x: ux.x - o.x, b1z: ux.z - o.z,
            b2x: uy.x - o.x, b2z: uy.z - o.z
        }
        return _gridBasis
    }

    // Recalibrage manuel si jamais l'API publique en a besoin (ex: changement
    // de gridSize à chaud, ou repositionnement de la caméra hors d'un suivi
    // continu). Aussi appelé automatiquement par les Connections plus bas
    // dès qu'un input du mapping affine bouge (resize, zoom, gridSize).
    function invalidateGridBasis() { _gridBasis = null }

    // Invalidation réactive du basis. La translation de caméra (pan/follow)
    // est absorbée par construction : b1/b2 sont des deltas, donc invariants
    // sous translation. En revanche, ces inputs **changent** la projection
    // ortho (ratio pixels écran ↔ unités monde) ou la grille elle-même :
    //  - resize de view3D (largeur/hauteur du viewport ortho)
    //  - changement de magnification (zoom multiplicatif ×1.1 par cran)
    //  - changement de gridSize (mmSize × pixelDensity)
    // Sans recapture, l'actor 3D dérive lentement par rapport à la collision
    // physique (qui reste en coords grille), d'où l'écart visuel/physique
    // observé au redimensionnement de la fenêtre depuis le refactor v2.
    Connections {
        target: view3D
        function onWidthChanged()  { root.invalidateGridBasis() }
        function onHeightChanged() { root.invalidateGridBasis() }
    }
    Connections {
        target: cameraOrthographic
        function onHorizontalMagnificationChanged() { root.invalidateGridBasis() }
        function onVerticalMagnificationChanged()   { root.invalidateGridBasis() }
        // La ROTATION caméra change aussi la projection (contrairement à la
        // translation, absorbée par construction) : FixedTopDown/OrbitDebug
        // du CameraRig pilotent eulerRotation — sans recapture, le mapping
        // affine resterait calé sur l'ancien angle au retour en Follow.
        function onEulerRotationChanged()           { root.invalidateGridBasis() }
    }
    Connections {
        target: gridManager
        enabled: gridManager !== null
        ignoreUnknownSignals: true
        function onGridSizeChanged() { root.invalidateGridBasis() }
    }

    function gridToWorldStable(gx, gy) {
        const b = _ensureGridBasis()
        if (!b) {
            // Fallback tant que la base n'est pas calibrable.
            return gridPositionTo3D(gx, gy)
        }
        return Qt.vector3d(b.ox + b.b1x * gx + b.b2x * gy,
                           0,
                           b.oz + b.b1z * gx + b.b2z * gy)
    }

    // Projette une position 3D sur la grille en passant par la View3D
    // (utile quand on a déjà un node 3D et qu'on veut sa case logique).
    function position3dToGridRealPosition(xPos, yPos, zPos) {
        if (!view3D || !gridManager) return Qt.point(0, 0)
        const viewPos = view3D.mapFrom3DScene(Qt.vector3d(xPos, yPos, zPos))
        const gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y)
        return Qt.point(gridPos.x / gridManager.gridSize,
                        gridPos.y / gridManager.gridSize)
    }

    // Inverse, via View3D + intersection plan Y=0.
    function gridPositionTo3D(gridX, gridY) {
        if (!gridManager || !view3D) return Qt.vector3d(0, 0, 0)
        const gridPixelX = gridX * gridManager.gridSize
        const gridPixelY = gridY * gridManager.gridSize
        const viewPos = gridManager.mapToItem(view3D, gridPixelX, gridPixelY)
        return getGroundIntersection(viewPos.x, viewPos.y)
    }

    // Projette un point écran sur le plan Y=0 (utilisé par les outils éditeur
    // pour poser une entité à l'endroit cliqué).
    function getGroundIntersection(viewX, viewY) {
        if (!view3D || !cameraOrthographic) return Qt.vector3d(0, 0, 0)
        const scenePos = view3D.mapTo3DScene(Qt.point(viewX, viewY))
        const angleDeg = cameraOrthographic.eulerRotation.x
        const rad = angleDeg * Math.PI / 180
        const rayDirY = Math.sin(rad)
        const rayDirZ = -Math.cos(rad)
        let targetX = scenePos.x
        let targetZ = scenePos.z
        if (Math.abs(rayDirY) > 0.0001) {
            const t = -scenePos.y / rayDirY
            targetZ = scenePos.z + t * rayDirZ
        }
        return Qt.vector3d(targetX, 0, targetZ)
    }

    // --- Helpers de manipulation d'entités (ex-GameScene) ---

    function moveEntityToGridPixelPosition(node, gridPixelX, gridPixelY) {
        if (!view3D || !node) return
        const pos3D = getGroundIntersection(gridPixelX, gridPixelY)
        node.x = pos3D.x; node.y = pos3D.y; node.z = pos3D.z
    }

    function moveEntityToGridPosition(node, gridX, gridY) {
        if (!view3D || !node) return
        const gridPos = gridManager.getGridPixelPosition(gridX, gridY)
        const pos3D = getGroundIntersection(gridPos.x, gridPos.y)
        node.x = pos3D.x; node.y = pos3D.y; node.z = pos3D.z
    }

    function getEntityGridPixelPosition(node) {
        if (!view3D || !node || !gridManager) return Qt.point(0, 0)
        const viewPos = view3D.mapFrom3DScene(Qt.vector3d(node.x, node.y, node.z))
        const gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y)
        return Qt.point(gridPos.x, gridPos.y)
    }

    function getEntityGridRealPosition(node) {
        if (!view3D || !node || !gridManager) return Qt.point(0, 0)
        const viewPos = view3D.mapFrom3DScene(Qt.vector3d(node.x, node.y, node.z))
        const gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y)
        return Qt.point(gridPos.x / gridManager.gridSize,
                        gridPos.y / gridManager.gridSize)
    }

    Component {
        id: sphereComponent
        Model {
            source: "#Sphere"
            materials: PrincipledMaterial { baseColor: "white" }
        }
    }

    function generateSphere(x, y, z, radius, color) {
        const sphere = sphereComponent.createObject(sceneNode, {
            "x": x, "y": y, "z": z,
            "scale": Qt.vector3d(radius / 50, radius / 50, radius / 50)
        })
        if (sphere === null) return null
        sphere.materials[0].baseColor = color
        return sphere
    }

    // --- Registry des PhysicsActor ---
    //
    // Chaque PhysicsActor s'auto-enregistre dans Component.onCompleted.
    // À chaque frame de rendu, on calcule un alpha d'interpolation et on
    // demande à chaque actor de tirer son bodyState et de l'appliquer à
    // son node 3D. Avant de lire les snapshots, on appelle beginFrame()
    // pour que le triple buffer ne consomme qu'une frame physique par
    // frame de rendu (cf. PhysicsWorld::beginFrame).
    QtObject {
        id: registry
        property var actors: []
        function add(a)    { actors = actors.concat([a]) }
        function remove(a) {
            const i = actors.indexOf(a)
            if (i >= 0) { const next = actors.slice(); next.splice(i, 1); actors = next }
        }
    }
    property alias registryRef: registry

    FrameAnimation {
        id: renderTick
        running: physicsWorld && physicsWorld.running
        onTriggered: {
            if (!physicsWorld) return
            physicsWorld.beginFrame()
            // dt de la frame de rendu (secondes, property du FrameAnimation)
            // — consommé par le lissage framerate-indépendant des actors.
            // (L'ancien calcul d'alpha était triplement cassé et ignoré :
            // stepDurationNs référencé sans parenthèses, horloge Date.now()
            // vs horloge worker — supprimé, cf. review Q8 ; une vraie
            // interpolation prev/next viendra avec le chantier N13.)
            const dt = renderTick.frameTime
            for (let i = 0; i < registry.actors.length; i++)
                registry.actors[i].pullAndApply(dt)
        }
    }

    // --- Scène 3D (identique à GameScene) ---
    Node {
        id: sceneNode

        DirectionalLight {
            x: 0
            y: 264.806
            z: 1111.39001
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1.0)
            brightness: 1.2
            eulerRotation.x: -25
        }

        Node {
            id: entityNode
            x: 0
            y: 0
            z: 0

            // Modèle joueur re-skinné (format kura : .glb + Color ID Map).
            // Gère aussi les primitives Cube/Sphere. Remplace l'ancien couple
            // Model(primitive) + Loader3D(.qml).
            SkinnedModel {
                modelName: root.modelName
                colorVariant: root.colorVariant
                teamColorOverride: root.teamColorOverride
            }
        }

        OrthographicCamera {
            id: cameraOrthographic
            x: 0
            y: 1000
            clipNear: -10000
            clipFar: 1000055
            eulerRotation.z: 0
            eulerRotation.y: 0
            pivot.x: 0
            z: 600
            eulerRotation.x: -55
            horizontalMagnification: root.cameraMagnification
            verticalMagnification: root.cameraMagnification
        }
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: cameraOrthographic
        importScene: sceneNode

        environment: SceneEnvironment {
            id: sceneEnvironment
            antialiasingMode: SceneEnvironment.ProgressiveAA
            backgroundMode: SceneEnvironment.Transparent
        }
    }
}
