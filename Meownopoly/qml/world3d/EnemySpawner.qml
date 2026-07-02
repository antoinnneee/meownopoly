/*
 * EnemySpawner — instancie, par EnemyTile : un body physique Kinematic
 * ("enemy:<uuid>", piloté par le tick IA du CombatController via pushInput)
 * et un node 3D SkinnedModel positionné depuis bodyState (même pattern que
 * le joueur : PhysicsActor lit la position lissée chaque frame).
 *
 * Cycle de vie du body : créé quand le moteur tourne (les commandes émises
 * avant `running` sont perdues — cf. LocalPlayerSpawner), retiré à la mort
 * (combat.isDead observe stateRevision) et recréé au respawn, au point de
 * spawn de la tile.
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
    /// CombatController (états vivant/mort + spawn pos).
    required property var combat
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    readonly property var _enemyTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || sp.tileType !== ItemSnapable.EnemyTile) continue
            out.push(t)
        }
        return out
    }

    Instantiator {
        model: root._enemyTiles

        delegate: Item {
            id: enemyEntry

            readonly property var tile: modelData
            readonly property var enemy: tile && tile.snapableParameters
                                         ? tile.snapableParameters.enemyParameter : null
            readonly property string uuid: tile && tile.snapableParameters
                                           ? String(tile.snapableParameters.uniqueId) : ""
            readonly property string bodyId: root.combat.bodyIdFor(uuid)

            readonly property bool dead: {
                root.combat.stateRevision
                root.combat.isDead(uuid)
            }

            property bool _bodySpawned: false

            function _syncBody() {
                if (!root.physicsWorld || uuid === "") return
                const wantBody = root.physicsWorld.running && !dead
                if (wantBody && !_bodySpawned) {
                    root.physicsWorld.createKinematicActor(
                        bodyId,
                        root.combat.spawnPosFor(tile),
                        0.25,
                        {
                            acceleration: 30.0,
                            maxSpeed: enemy ? enemy.moveSpeed : 2.0,
                            linearDamping: 0.1
                        })
                    _bodySpawned = true
                } else if (!wantBody && _bodySpawned) {
                    root.physicsWorld.removeBody(bodyId)
                    _bodySpawned = false
                    actor._seeded = false   // re-seed position au respawn
                }
            }

            onDeadChanged: _syncBody()
            Component.onCompleted: _syncBody()
            Component.onDestruction: {
                if (_bodySpawned && root.physicsWorld)
                    root.physicsWorld.removeBody(bodyId)
            }

            Connections {
                target: root.physicsWorld
                function onRunningChanged() { enemyEntry._syncBody() }
            }

            // Vitesse éditable à chaud depuis le panneau de config.
            Connections {
                target: enemyEntry.enemy
                function onMoveSpeedChanged() {
                    if (enemyEntry._bodySpawned) {
                        // upsertBody C++ préserve position/velocity.
                        root.physicsWorld.createKinematicActor(
                            enemyEntry.bodyId,
                            root.combat.spawnPosFor(enemyEntry.tile),
                            0.25,
                            {
                                acceleration: 30.0,
                                maxSpeed: enemyEntry.enemy.moveSpeed,
                                linearDamping: 0.1
                            })
                    }
                }
            }

            Node {
                id: enemyNode
                parent: root.world3D ? root.world3D.scene : null
                visible: !enemyEntry.dead && enemyEntry._bodySpawned

                SkinnedModel {
                    modelName: enemyEntry.enemy ? enemyEntry.enemy.modelName : ""
                }
            }

            PhysicsActor {
                id: actor
                bodyId: enemyEntry.bodyId
                world3D: root.world3D
                node3D: enemyNode
            }
        }
    }
}
