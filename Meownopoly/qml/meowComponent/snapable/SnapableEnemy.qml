import QtQuick 2.15
import QtQuick.Controls

import ItemSnapable
import EnemyParameter
import TileType
import theme

/*
 * SnapableEnemy — présentation 2D d'un ennemi dans l'éditeur.
 *
 * Vignette placeholder (carte nom + icône + stats) — le rendu réel est fait
 * par EnemySpawner dans la scène 3D (SkinnedModel + body physique).
 *
 * Sélectionnable / déplaçable comme les autres tiles (hérite SnapableElement).
 */
SnapableElement {
    id: root

    isResizable: true
    autoSnap: true

    readonly property var enemy: snapableParameters ? snapableParameters.enemyParameter : null

    Rectangle {
        anchors.fill: parent
        z: 1
        radius: Theme.radiusM
        color: Qt.rgba(0.28, 0.10, 0.12, 0.78)
        border.color: "#e05050"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXXS

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "👹"
                font.pixelSize: Math.max(Theme.fontSizeBody,
                                         Math.min(root.width, root.height) * 0.35)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.enemy && root.enemy.enemyName !== "" ? root.enemy.enemyName : "Ennemi"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.width - Theme.spacingS)
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.enemy && root.enemy.modelName !== ""
                text: root.enemy ? root.enemy.modelName : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeTiny
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.width - Theme.spacingS)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Badge PV / dégâts (aide visuelle éditeur uniquement).
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spacingXXS
        z: 2
        text: root.enemy ? ("❤" + root.enemy.maxHp + " ⚔" + root.enemy.attackDamage) : ""
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeTiny
    }
}
