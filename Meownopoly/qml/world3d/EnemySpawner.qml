/*
 * EnemySpawner — instancie, par EnemyTile : un body physique Kinematic
 * ("enemy:<uuid>", piloté par le tick IA du CombatController via pushInput)
 * et un node 3D SkinnedModel positionné depuis bodyState (même pattern que
 * le joueur : PhysicsActor lit la position lissée chaque frame).
 *
 * Cycle de vie du body : possédé par l'AUTORITÉ de combat uniquement
 * (monoposte ou hôte de PhysicsSession) — côté client, les bodies ennemis
 * arrivent par les snapshots réseau et ne doivent jamais être créés/retirés
 * localement. Créé quand le moteur tourne (les commandes émises avant
 * `running` sont perdues — cf. LocalPlayerSpawner), retiré à la mort
 * (combat.isDead observe stateRevision) et recréé au respawn, au point de
 * spawn de la tile.
 *
 * Animations procédurales (présentation pure, jamais le moteur) :
 *  - mort : écrasement (scale → 0) + enfoncement, puis node caché ;
 *  - respawn : pop-in (scale 0 → 1) ;
 *  - attaque (combat.playerHit) : petit hop via PhysicsActor.jump().
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
    /// CombatController (états vivant/mort + spawn pos + autorité).
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
                // L'autorité fait partie du wantBody (pas un early-return) :
                // une session démarrée APRÈS la création des bodies doit
                // retirer les bodies locaux d'un client (ils arrivent par
                // snapshot), et une promotion en hôte doit les créer.
                const wantBody = root.physicsWorld.running
                                 && root.combat.isAuthority && !dead
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

            onDeadChanged: {
                if (dead) deathAnim.restart()
                else {
                    deathAnim.stop()
                    respawnAnim.restart()
                }
                _syncBody()
            }
            Component.onCompleted: _syncBody()
            Component.onDestruction: {
                if (_bodySpawned && root.physicsWorld)
                    root.physicsWorld.removeBody(bodyId)
            }

            Connections {
                target: root.physicsWorld
                function onRunningChanged() { enemyEntry._syncBody() }
            }

            // Changement d'autorité à chaud (session démarrée/arrêtée,
            // promotion en hôte) : re-statuer sur la possession du body.
            Connections {
                target: root.combat
                function onIsAuthorityChanged() { enemyEntry._syncBody() }
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

            // Hop d'attaque : l'ennemi bondit légèrement quand il frappe.
            Connections {
                target: root.combat
                function onPlayerHit(uuid, damage) {
                    if (uuid === enemyEntry.uuid && !enemyEntry.dead)
                        actor.jump(0.5, 250)
                }
            }

            Node {
                id: enemyNode
                parent: root.world3D ? root.world3D.scene : null
                // Visible tant que vivant ou pendant l'anim de mort. Côté
                // client (non-autorité), pas de _bodySpawned local : la
                // position vient des snapshots réseau.
                visible: (root.combat.isAuthority
                          ? (enemyEntry._bodySpawned || deathAnim.running)
                          : root.physicsWorld.running)
                         && (!enemyEntry.dead || deathAnim.running)

                SkinnedModel {
                    modelName: enemyEntry.enemy ? enemyEntry.enemy.modelName : ""
                }
            }

            // Mort : écrasement (scale Y → 0), ~450 ms. Le body est déjà
            // retiré (pullAndApply ne touche plus le node), on peut animer
            // le scale directement.
            SequentialAnimation {
                id: deathAnim
                Vector3dAnimation {
                    target: enemyNode; property: "scale"
                    to: Qt.vector3d(1.2, 0.05, 1.2)
                    duration: 450; easing.type: Easing.InQuad
                }
            }

            // Respawn : pop-in élastique.
            SequentialAnimation {
                id: respawnAnim
                PropertyAction { target: enemyNode; property: "scale"; value: Qt.vector3d(0.01, 0.01, 0.01) }
                Vector3dAnimation {
                    target: enemyNode; property: "scale"
                    to: Qt.vector3d(1, 1, 1)
                    duration: 350; easing.type: Easing.OutBack
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
