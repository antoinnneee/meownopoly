/*
 * PlayerHealthHud — barre de vie du joueur local (HUD fixe à l'écran).
 * Lit les PV dans le HealthModule via le CombatController (stateRevision
 * re-déclenche l'évaluation à chaque healthChanged).
 */
import QtQuick
import GameplayModuleManager 1.0
import theme

Item {
    id: root

    required property var combat

    readonly property var _health: GameplayModuleManager.healthModule

    readonly property int hp: {
        combat.stateRevision
        _health ? _health.hp(combat.playerActorId) : 0
    }
    readonly property int maxHp: {
        combat.stateRevision
        _health ? _health.maxHp(combat.playerActorId) : 1
    }
    readonly property real ratio: maxHp > 0 ? hp / maxHp : 0
    readonly property bool dead: hp <= 0

    visible: combat.active
    implicitWidth: Theme.px(220)
    implicitHeight: Theme.px(30)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusM
        color: Theme.panelSurface
        border.color: Theme.border
        border.width: 1
        opacity: 0.92
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        spacing: Theme.spacingXS

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dead ? "💀" : "❤️"
            font.pixelSize: Theme.fontSizeBody
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.px(80)
            height: Theme.px(12)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.45)
            }
            Rectangle {
                x: 1; y: 1
                width: Math.max(0, (parent.width - 2) * Math.min(1, root.ratio))
                height: parent.height - 2
                radius: height / 2
                color: root.ratio > 0.5 ? "#4CAF50" : root.ratio > 0.25 ? "#FF9800" : "#F44336"
                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hp + "/" + root.maxHp
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
    }
}
