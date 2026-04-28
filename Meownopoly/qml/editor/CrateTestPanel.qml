/*
 * CrateTestPanel — Phase 9 (PhysicsObject — caisse à pousser).
 *
 * Petit badge top-right (sous JumpTestPanel) avec deux actions :
 *  - "Spawn crate" : pose une PhysicalObjectTile près du joueur P1 et
 *    laisse le moteur s'en occuper (le bridge créera le body Dynamic ;
 *    le PhysicsObjectSpawner instanciera le node 3D associé).
 *  - "Clear crates" : supprime toutes les PhysicalObjectTile présentes
 *    sur la map courante (debug rapide pour repartir d'une scène propre).
 *
 * Utilise ItemSnapableFactory.createPhysicalObject + Game.updateMap
 * pour passer par le pipeline standard (et donc déclencher
 * `tileAddedToMap` → ItemSnapableEvents → bridge + spawner).
 */
import QtQuick 2.15
import QtQuick.Controls

import ItemSnapable
import ItemSnapableFactory
import Game
import EditDelta 1.0
import MapFileManager

Item {
    id: root

    // Logic du editor (pour appeler tileLogic.createItemSnapableTile et
    // tileLogic.deleteElement). Doit être assigné par Editor.qml.
    required property var logic

    // PhysicsActor du joueur (utilisé pour positionner les caisses
    // proches du chat — la caisse spawn ~1 case devant la position grille
    // de l'actor pour qu'il puisse la pousser tout de suite).
    required property var actor

    // Référence au PhysicsWorld pour lire la position courante du body
    // joueur (en grille). Optionnel — sans, on spawn à (0,0).
    required property var physicsWorld

    // Stack vertical : sous JumpTestPanel (topMargin 156 + ~24 + 12 = 192).
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 192
    anchors.rightMargin: 12

    z: 10000

    width: badge.width
    height: badge.height

    // Masse de la prochaine caisse spawnée. Lue par _spawnCrate. Slider
    // 0.5 → 5.0 (le mapping couleur de SnapablePhysicalObject couvre cette
    // plage : orange clair → brun-rouge foncé).
    property real spawnMass: 1.0

    Rectangle {
        id: badge
        width: badgeRow.implicitWidth + 16
        height: badgeRow.implicitHeight + 10
        radius: 6
        color: "#2a2a2e"
        border.color: "#71717a"
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 10; height: 10; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: "#fb923c"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Crates"
                color: "#f4f4f5"
                font.pixelSize: 12
                font.bold: true
            }

            Rectangle {
                width: 1; height: 14
                color: "#52525b"
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                id: spawnBtn
                width: spawnText.implicitWidth + 12
                height: 18
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: spawnMa.containsMouse
                       ? (spawnMa.pressed ? "#3f3f46" : "#33333a")
                       : "transparent"
                border.color: "#52525b"
                border.width: 1
                Text {
                    id: spawnText
                    anchors.centerIn: parent
                    text: "Spawn"
                    color: "#f4f4f5"
                    font.pixelSize: 10
                    font.bold: true
                }
                MouseArea {
                    id: spawnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._spawnCrate()
                }
                ToolTip.visible: spawnMa.containsMouse
                ToolTip.delay: 400
                ToolTip.text: "Pose une caisse Dynamic ~1 case devant le joueur."
            }

            Rectangle {
                id: clearBtn
                width: clearText.implicitWidth + 12
                height: 18
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: clearMa.containsMouse
                       ? (clearMa.pressed ? "#3f3f46" : "#33333a")
                       : "transparent"
                border.color: "#52525b"
                border.width: 1
                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear"
                    color: "#f4f4f5"
                    font.pixelSize: 10
                    font.bold: true
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._clearCrates()
                }
                ToolTip.visible: clearMa.containsMouse
                ToolTip.delay: 400
                ToolTip.text: "Supprime toutes les caisses de la map."
            }

            Rectangle {
                width: 1; height: 14
                color: "#52525b"
                anchors.verticalCenter: parent.verticalCenter
            }

            // Slider de masse pour la prochaine caisse. Discret : 5 crans
            // 0.5 / 1.0 / 2.0 / 3.5 / 5.0 (cliquable, pas un Slider Qt
            // pour éviter la dépendance et garder le badge compact).
            Row {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "m=" + root.spawnMass.toFixed(1)
                    color: "#f4f4f5"
                    font.pixelSize: 10
                    font.bold: true
                    rightPadding: 4
                }

                Repeater {
                    model: [0.5, 1.0, 2.0, 3.5, 5.0]
                    delegate: Rectangle {
                        readonly property real value: modelData
                        readonly property bool active: Math.abs(root.spawnMass - value) < 0.01
                        width: 18; height: 18
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: active
                            ? "#fb923c"
                            : (massMa.containsMouse
                                ? (massMa.pressed ? "#3f3f46" : "#33333a")
                                : "transparent")
                        border.color: active ? "#fdba74" : "#52525b"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: value.toFixed(value < 1 ? 1 : 0)
                            color: "#f4f4f5"
                            font.pixelSize: 9
                            font.bold: true
                        }
                        MouseArea {
                            id: massMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.spawnMass = value
                        }
                    }
                }
            }
        }
    }

    function _spawnCrate() {
        if (!logic || !logic.tileLogic) {
            console.warn("[CrateTestPanel] tileLogic indisponible")
            return
        }

        const params = ItemSnapableFactory.createPhysicalObject()
        // Position de spawn : 1.5 case "devant" le joueur (ici simplifié à
        // X+1, Y+0). Si pas d'actor, on tombe sur (0, 0).
        let gx = 0, gy = 0
        if (root.physicsWorld && root.actor) {
            const s = root.physicsWorld.bodyState(root.actor.bodyId)
            if (s && s.id) {
                gx = Math.round(s.position.x + 1.5)
                gy = Math.round(s.position.y)
            }
        }
        params.displayParameter.gridRelativePositionX = gx
        params.displayParameter.gridRelativePositionY = gy
        params.displayParameter.unitSizeWidth  = 1
        params.displayParameter.unitSizeHeight = 1
        params.displayParameter.zLayer = 2

        // Masse choisie via le slider — pour les autres coefs on garde
        // les defaults de PhysicalObjectParameter (bounce 0.3, friction 0.4,
        // damping 0.1).
        if (params.physicalObjectParameter)
            params.physicalObjectParameter.mass = root.spawnMass

        const tile = logic.tileLogic.createItemSnapableTile(params)
        if (tile && tile.snapableParameters)
            Game.updateMap(EditDelta.TileAdded, tile.snapableParameters)
    }

    function _clearCrates() {
        if (!logic || !logic.tileLogic) return
        const list = (logic.snapableTilesList || []).slice()
        for (let i = list.length - 1; i >= 0; --i) {
            const t = list[i]
            if (t && t.snapableParameters &&
                t.snapableParameters.tileType === ItemSnapable.PhysicalObjectTile) {
                logic.tileLogic.deleteElement(t)
            }
        }
    }
}
