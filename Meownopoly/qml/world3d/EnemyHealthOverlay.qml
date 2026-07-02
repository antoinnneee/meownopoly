/*
 * EnemyHealthOverlay — barres de vie des ennemis, en coords workArea
 * (pixels : suit pan/zoom sans projection 3D, comme NPCDialogueOverlay).
 *
 * La position suit le body physique (l'ennemi se déplace) : un Timer 10 Hz
 * incrémente _posTick, les délégués relisent bodyState à chaque tick.
 * Visible uniquement quand le moteur tourne (mode jeu).
 */
import QtQuick
import ItemSnapable
import theme

Item {
    id: root

    /// CombatController (hp/maxHp + états + tick).
    required property var combat
    required property var physicsWorld
    property var gridManager: null
    property var tilesList: []
    property int tilesRevision: 0

    visible: physicsWorld ? physicsWorld.running : false

    property int _posTick: 0
    Timer {
        interval: 100
        repeat: true
        running: root.visible
        onTriggered: root._posTick++
    }

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

    Repeater {
        model: root._enemyTiles

        delegate: Item {
            id: bar

            readonly property var tile: modelData
            readonly property string uuid: tile && tile.snapableParameters
                                           ? String(tile.snapableParameters.uniqueId) : ""

            readonly property bool dead: {
                root.combat.stateRevision
                root.combat.isDead(uuid)
            }
            readonly property real ratio: {
                root.combat.stateRevision
                const max = root.combat.maxHpOf(uuid)
                return max > 0 ? root.combat.hpOf(uuid) / max : 0
            }

            // Position pixels workArea depuis le body (coords grille × gridSize).
            readonly property var _pos: {
                root._posTick
                const gs = root.gridManager ? root.gridManager.gridSize : 0
                if (gs <= 0 || !root.physicsWorld) return null
                const s = root.physicsWorld.bodyState(root.combat.bodyIdFor(uuid))
                if (!s.id) return null
                return Qt.point(s.position.x * gs, s.position.y * gs)
            }

            visible: !dead && _pos !== null
            x: _pos ? _pos.x - width / 2 : 0
            y: _pos ? _pos.y - (root.gridManager ? root.gridManager.gridSize : 0) - height : 0
            width: root.gridManager ? root.gridManager.gridSize * 1.4 : 40
            height: Theme.px(6)
            z: 99998   // sous les bulles de dialogue, au-dessus des tiles

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 1
            }
            Rectangle {
                x: 1; y: 1
                width: Math.max(0, (parent.width - 2) * Math.min(1, bar.ratio))
                height: parent.height - 2
                radius: height / 2
                // Vert → orange → rouge selon les PV restants.
                color: bar.ratio > 0.5 ? "#4CAF50" : bar.ratio > 0.25 ? "#FF9800" : "#F44336"
            }
        }
    }
}
