import QtQuick 2.15
import QtQuick.Controls

import ItemSnapable
import PhysicalObjectParameter
import TileType
import theme

/*
 * SnapablePhysicalObject — présentation 2D d'une caisse (objet physique
 * dynamique poussable/attrapable) dans l'éditeur.
 *
 * Vignette placeholder (📦 + masse) — le rendu réel est fait par
 * CrateSpawner dans la scène 3D (cube + body Dynamic).
 *
 * Sélectionnable / déplaçable comme les autres tiles (hérite SnapableElement).
 */
SnapableElement {
    id: root

    isResizable: true
    autoSnap: true

    readonly property var crate: snapableParameters ? snapableParameters.physicalObjectParameter : null

    Rectangle {
        anchors.fill: parent
        z: 1
        radius: Theme.radiusM
        color: Qt.rgba(0.30, 0.22, 0.10, 0.80)
        border.color: "#c8963c"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXXS

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "📦"
                font.pixelSize: Math.max(Theme.fontSizeBody,
                                         Math.min(root.width, root.height) * 0.35)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Caisse"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }

    // Badge masse / grab (aide visuelle éditeur uniquement).
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spacingXXS
        z: 2
        text: root.crate
              ? ("⚖" + root.crate.mass.toFixed(1) + (root.crate.grabbable ? " ✋" : ""))
              : ""
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeTiny
    }
}
