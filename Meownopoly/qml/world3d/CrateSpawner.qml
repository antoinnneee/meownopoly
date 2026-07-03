/*
 * CrateSpawner — instancie, par PhysicalObjectTile (caisse) : un body
 * physique **Dynamic** ("crate:<uuid>", poussable par le joueur, sujet aux
 * impulsions du GrabController) et un cube 3D positionné depuis bodyState
 * (PhysicsActor, même pattern que joueur/ennemis).
 *
 * Cycle de vie du body : possédé par l'AUTORITÉ (monoposte ou hôte de
 * PhysicsSession) — côté client les bodies arrivent par snapshot réseau.
 * Rayon de collision : cercle inscrit de la tile (min(w,h)/2 en unités de
 * grille), comme l'ancienne intégration.
 *
 * Les coefficients physiques (mass/bounce/friction/damping) viennent du
 * PhysicalObjectParameter et sont ré-upsertés à chaud quand ils changent
 * (upsertBody C++ préserve position/velocity).
 */
import QtQuick
import QtQuick3D
import ItemSnapable

Item {
    id: root
    visible: false

    /// World3D hôte (scene + helpers de conversion + registry).
    required property var world3D
    required property var physicsWorld
    /// CombatController (autorité réseau). Seule l'autorité crée les bodies.
    required property var combat
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    readonly property var _crateTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || sp.tileType !== ItemSnapable.PhysicalObjectTile) continue
            out.push(t)
        }
        return out
    }

    function bodyIdFor(uuid) { return "crate:" + uuid }

    Instantiator {
        model: root._crateTiles

        delegate: Item {
            id: crateEntry

            readonly property var tile: modelData
            readonly property var crate: tile && tile.snapableParameters
                                         ? tile.snapableParameters.physicalObjectParameter : null
            readonly property string uuid: tile && tile.snapableParameters
                                           ? String(tile.snapableParameters.uniqueId) : ""
            readonly property string bodyId: root.bodyIdFor(uuid)

            // Taille de la tile en cellules de grille (suit un resize éditeur).
            readonly property real cellsW: {
                const gm = root.world3D ? root.world3D.gridManager : null
                const gs = gm ? gm.gridSize : 0
                return (gs > 0 && tile) ? tile.width / gs : 1
            }
            readonly property real cellsH: {
                const gm = root.world3D ? root.world3D.gridManager : null
                const gs = gm ? gm.gridSize : 0
                return (gs > 0 && tile) ? tile.height / gs : 1
            }
            readonly property real bodyRadius: Math.max(0.1, Math.min(cellsW, cellsH) / 2 * 0.9)

            property bool _bodySpawned: false

            function _spawnPos() {
                const gm = root.world3D ? root.world3D.gridManager : null
                const gs = gm ? gm.gridSize : 0
                if (!tile || gs <= 0) return Qt.vector2d(0, 0)
                return Qt.vector2d((tile.x + tile.width / 2) / gs,
                                   (tile.y + tile.height / 2) / gs)
            }

            function _bodyParams() {
                return {
                    bounceFactor: crate ? crate.bounceFactor : 0.3,
                    staticFriction: crate ? crate.frictionStrength : 0.4,
                    dynamicFriction: crate ? crate.frictionStrength * 0.6 : 0.2,
                    linearDamping: crate ? crate.linearDamping : 0.1
                }
            }

            function _syncBody() {
                if (!root.physicsWorld || uuid === "") return
                // Client réseau : bodies possédés par l'hôte (snapshots).
                if (!root.combat.isAuthority) return
                const wantBody = root.physicsWorld.running
                if (wantBody && !_bodySpawned) {
                    root.physicsWorld.createDynamicCircle(
                        bodyId, _spawnPos(), bodyRadius,
                        crate ? crate.mass : 1.0, _bodyParams())
                    _bodySpawned = true
                } else if (!wantBody && _bodySpawned) {
                    root.physicsWorld.removeBody(bodyId)
                    _bodySpawned = false
                    actor._seeded = false
                }
            }

            // Coefficients éditables à chaud depuis le panneau de config.
            function _reupsert() {
                if (!_bodySpawned) return
                // upsertBody C++ préserve position/velocity.
                root.physicsWorld.createDynamicCircle(
                    bodyId, _spawnPos(), bodyRadius,
                    crate ? crate.mass : 1.0, _bodyParams())
            }

            Component.onCompleted: _syncBody()
            Component.onDestruction: {
                if (_bodySpawned && root.physicsWorld)
                    root.physicsWorld.removeBody(bodyId)
            }

            Connections {
                target: root.physicsWorld
                function onRunningChanged() { crateEntry._syncBody() }
            }

            Connections {
                target: crateEntry.crate
                function onMassChanged() { crateEntry._reupsert() }
                function onBounceFactorChanged() { crateEntry._reupsert() }
                function onFrictionStrengthChanged() { crateEntry._reupsert() }
                function onLinearDampingChanged() { crateEntry._reupsert() }
            }

            Node {
                id: crateNode
                parent: root.world3D ? root.world3D.scene : null
                visible: root.combat.isAuthority
                         ? crateEntry._bodySpawned
                         : root.physicsWorld.running

                // Cube "caisse" dimensionné sur la tile : une cellule de
                // grille en unités monde = norme du vecteur de base b1 du
                // mapping affine (dépendance explicite à _gridBasis pour
                // suivre les recalibrages).
                Model {
                    source: "#Cube"   // primitive 100×100×100
                    readonly property real cellWorld: {
                        const b = root.world3D ? root.world3D._gridBasis : null
                        return b ? Math.hypot(b.b1x, b.b1z) : 1
                    }
                    scale: Qt.vector3d(
                        cellWorld * crateEntry.cellsW * 0.9 / 100,
                        cellWorld * Math.min(crateEntry.cellsW, crateEntry.cellsH) * 0.9 / 100,
                        cellWorld * crateEntry.cellsH * 0.9 / 100)
                    y: 50 * scale.y   // repose sur le sol (pivot cube au centre)
                    materials: PrincipledMaterial {
                        baseColor: "#a5773f"
                        roughness: 0.8
                    }
                }
            }

            PhysicsActor {
                id: actor
                bodyId: crateEntry.bodyId
                world3D: root.world3D
                node3D: crateNode
                autoOrient: false
            }
        }
    }
}
