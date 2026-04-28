/*
 * PhysicsObjectSpawner — Phase 9
 *
 * Écoute `ItemSnapableEvents` et instancie/détruit côté 3D un
 * `Model` + `PhysicsObject` (présentateur) pour chaque
 * `PhysicalObjectTile` posée dans l'éditeur.
 *
 * Le bridge (`EditorPhysicsBridge`) s'occupe en parallèle de pousser le
 * body Dynamic correspondant côté worker physique. Les deux écoutent
 * la même source d'événements donc convergent. La séparation est
 * volontaire :
 *  - le bridge travaille en unités grille pures (ne connaît pas la 3D),
 *  - le spawner travaille en unités world3D (ne connaît pas le moteur).
 *
 * Le `bodyId` qui lie les deux côtés est la string du QUuid de la tile,
 * exactement comme le fait le bridge (`tile.uniqueId.toString()`).
 *
 * À noter : le `World3D` racine fournit `gridManager.gridSize` pour
 * choisir la taille du Model 3D (cube de coté = unitSizeWidth*gridSize).
 */
import QtQuick
import QtQuick3D
import Pattounx 1.0
import ItemSnapable

Item {
    id: root

    required property var world3D

    // Map<bodyId(string), {model: Model, presenter: PhysicsObject}> pour
    // démontage à la suppression d'une tile.
    property var _spawned: ({})

    // Component templates inline. Évite un fichier additionnel pour la box +
    // permet de faire varier matériau/scale facilement plus tard.
    Component {
        id: cubeModelComponent
        Model {
            source: "#Cube"
            // Cube unitaire #Cube fait 100×100×100 dans QtQuick3D ;
            // on le scale pour qu'il colle au unitSizeWidth × gridSize.
            // `userSize` est attendu en pixels world3D ; on fixe scale ici
            // une fois pour toutes (on suppose que la taille de la tile
            // ne change pas en cours de session — Phase 9 ne supporte pas
            // le resize, cf. SnapablePhysicalObject.isResizable=false).
            property real userSize: 100
            scale: Qt.vector3d(userSize / 100.0, userSize / 100.0, userSize / 100.0)
            materials: PrincipledMaterial {
                baseColor: "#fb923c"     // orange — cohérent avec le snapable 2D
                roughness: 0.6
            }
        }
    }

    Component {
        id: physicsObjectComponent
        PhysicsObject {
            // node3D + bodyId + world3D définis lors du createObject.
        }
    }

    Connections {
        target: ItemSnapableEvents
        function onTileCreated(tile)         { root._maybeSpawn(tile) }
        function onTileDeleted(tileId, type) {
            if (type === ItemSnapable.PhysicalObjectTile)
                root._despawn(tileId.toString())
        }
        // tileMoved n'a pas besoin d'action côté 3D : c'est le snapshot
        // physique qui rapatriera la position via PhysicsObject.pullAndApply.
    }

    function _maybeSpawn(tile) {
        if (!tile || tile.tileType !== ItemSnapable.PhysicalObjectTile) return
        const id = tile.uniqueId.toString()
        if (_spawned[id]) return                    // déjà spawné
        if (!world3D || !world3D.scene || !world3D.gridManager) return

        const dp  = tile.displayParameter
        const w   = dp ? dp.unitSizeWidth  : 1
        const gs  = world3D.gridManager.gridSize
        const sideWorld = Math.max(0.05, w * gs)

        // Hauteur visuelle = demi-côté pour que la base du cube touche le sol Y=0.
        // On pose explicitement visualY sur le presenter ; pullAndApply
        // l'assignera à node3D.y chaque frame.
        const halfSide = sideWorld / 2.0

        const model = cubeModelComponent.createObject(world3D.scene, {
            "userSize": sideWorld
        })
        if (!model) return

        const presenter = physicsObjectComponent.createObject(root, {
            "bodyId":   id,
            "world3D":  world3D,
            "node3D":   model,
            "visualY":  halfSide
        })
        if (!presenter) {
            model.destroy()
            return
        }
        _spawned[id] = { model: model, presenter: presenter }
    }

    function _despawn(id) {
        const entry = _spawned[id]
        if (!entry) return
        if (entry.presenter) entry.presenter.destroy()
        if (entry.model)     entry.model.destroy()
        delete _spawned[id]
    }

    Component.onDestruction: {
        const ids = Object.keys(_spawned)
        for (let i = 0; i < ids.length; i++) _despawn(ids[i])
    }
}
