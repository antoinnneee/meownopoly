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
    // Phase 6 : 2e entité pour le multi-actors local. Visuel volontairement
    // distinct (Cube blanc) pour différencier P2 du joueur principal.
    // `visible` géré côté Editor via la property `multiActorEnabled`.
    property alias entity2: entity2Node
    property alias environment: sceneEnvironment
    required property GridManager gridManager

    property real cameraMagnification: 1.0
    property string modelName: "Princess"

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
    // continu). Pour le moment, personne n'appelle.
    function invalidateGridBasis() { _gridBasis = null }

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
        running: physicsWorld && physicsWorld.running
        onTriggered: {
            if (!physicsWorld) return
            physicsWorld.beginFrame()
            const stepNs = physicsWorld.stepDurationNs
            const nowNs  = Date.now() * 1e6
            const snapNs = physicsWorld.currentTimestampNs
            const alpha  = stepNs > 0 ? Math.min(1, (nowNs - snapNs) / stepNs) : 1
            for (let i = 0; i < registry.actors.length; i++)
                registry.actors[i].pullAndApply(alpha)
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

            Model {
                id: primitiveModel
                visible: root.modelName === "Cube" || root.modelName === "Sphere"
                source: root.modelName === "Cube" ? "#Cube" : "#Sphere"
                materials: PrincipledMaterial { baseColor: "white" }
            }

            Loader3D {
                id: modelLoader
                visible: root.modelName !== "Cube" && root.modelName !== "Sphere"
                source: visible ? ("file:///" + AssetManager.getAppDataPath()
                                  + "/models/" + root.modelName + "/"
                                  + root.modelName + ".qml")
                                : ""
                onStatusChanged: {
                    if (status === Loader3D.Error)
                        console.error("Erreur chargement modèle 3D:",
                                      sourceComponent ? sourceComponent.errorString() : "")
                }
            }
        }

        // Phase 6 — 2e entité (test multi-actors local). Cube orange pour
        // bien voir P2 vs Princess (P1). `visible: false` par défaut, le
        // Editor.qml l'allume quand multiActor est activé via le panneau.
        Node {
            id: entity2Node
            x: 0
            y: 0
            z: 0
            visible: false
            Model {
                source: "#Cube"
                scale: Qt.vector3d(0.5, 0.5, 0.5)
                materials: PrincipledMaterial { baseColor: "#f97316" }
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
