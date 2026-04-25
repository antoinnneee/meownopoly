/*
 * LocalPlayerSpawner — Phase 4
 *
 * Crée un body Kinematic "joueur" dans le PhysicsWorld dès que le moteur
 * tourne, le retire à la destruction. Le PhysicsActor associé (même bodyId)
 * positionne le node 3D du joueur.
 *
 * Réactif sur `physicsWorld.running` : les commandes émises pendant que le
 * worker thread n'existe pas encore sont silencieusement perdues
 * (QueuedConnection sans receiver), donc on diffère la création jusqu'au
 * démarrage. Idempotent côté worker (cmdUpsertBody remplace si déjà présent).
 */
import QtQuick

Item {
    id: root

    required property var physicsWorld
    required property string actorId

    property vector2d initialPosition: Qt.vector2d(0, 0)
    property real radius: 0.2
    property var params: ({})       // BodySpec overrides (acceleration, maxSpeed, …)

    function _spawnIfReady() {
        if (!physicsWorld || !physicsWorld.running) return
        physicsWorld.createKinematicActor(actorId, initialPosition, radius, params)
        console.log("[LocalPlayerSpawner] body créé:", actorId, "@",
                    initialPosition.x, initialPosition.y)
    }

    Component.onCompleted: _spawnIfReady()
    Component.onDestruction: {
        if (physicsWorld && physicsWorld.running) physicsWorld.removeBody(actorId)
    }

    Connections {
        target: physicsWorld
        function onRunningChanged() {
            if (physicsWorld.running) root._spawnIfReady()
        }
    }
}
