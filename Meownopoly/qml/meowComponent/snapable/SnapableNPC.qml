import QtQuick 2.15
import QtQuick.Controls

import AssetManager
import ItemSnapable
import NPCParameter
import TileType
import theme

/*
 * SnapableNPC — présentation 2D d'un PNJ dans l'éditeur.
 *
 * Deux rendus selon npcParameter.visualKind :
 *  - Sprite2D : réutilise le pipeline DecorationParameter (image de l'asset),
 *    comme SnapableDecoration (sans les MultiEffect — un PNJ n'a pas
 *    vocation à porter d'effets visuels).
 *  - Model3D : vignette placeholder (carte nom + icône) — le rendu réel est
 *    fait par NPCSpawner dans la scène 3D.
 *
 * Sélectionnable / déplaçable comme les autres tiles (hérite SnapableElement).
 */
SnapableElement {
    id: root

    isResizable: true
    autoSnap: true

    readonly property var npc: snapableParameters ? snapableParameters.npcParameter : null
    readonly property bool isSprite: npc && npc.visualKind === NPCParameter.Sprite2D

    readonly property bool assetAvailable: isSprite
        && snapableParameters.decorationParameter.decorationCategory !== ""
        && snapableParameters.decorationParameter.decorationType !== ""
        && snapableParameters.decorationParameter.decorationId !== ""
    readonly property var asset: assetAvailable
        ? AssetManager.getAssetById(snapableParameters.decorationParameter.decorationCategory,
                                    snapableParameters.decorationParameter.decorationType,
                                    snapableParameters.decorationParameter.decorationId)
        : null

    // --- Rendu sprite ---
    AnimatedImage {
        anchors.fill: parent
        visible: root.isSprite
        source: (root.asset && root.asset.id) ? root.asset.path : ""
        z: 1
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    // --- Placeholder modèle 3D / sprite sans asset ---
    Rectangle {
        anchors.fill: parent
        visible: !root.isSprite || !root.assetAvailable
        z: 1
        radius: Theme.radiusM
        color: Qt.rgba(0.16, 0.12, 0.25, 0.75)
        border.color: Theme.accent
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXXS

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "🎭"
                font.pixelSize: Math.max(Theme.fontSizeBody,
                                         Math.min(root.width, root.height) * 0.35)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.npc && root.npc.npcName !== "" ? root.npc.npcName : "PNJ"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.width - Theme.spacingS)
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.isSprite && root.npc && root.npc.modelName !== ""
                text: root.npc ? root.npc.modelName : ""
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeTiny
                elide: Text.ElideRight
                width: Math.min(implicitWidth, root.width - Theme.spacingS)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Badge du mode de déclenchement (aide visuelle éditeur uniquement).
    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spacingXXS
        z: 2
        text: {
            if (!root.npc) return ""
            switch (root.npc.triggerMode) {
            case NPCParameter.Proximity: return "📡"
            case NPCParameter.Click:     return "👆"
            case NPCParameter.Always:    return "📢"
            }
            return ""
        }
        font.pixelSize: Theme.fontSizeSmall
    }
}
