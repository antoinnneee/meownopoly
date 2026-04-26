/*
 * MultiActorTestPanel — toggle pour spawner P2 (Phase 6).
 *
 * Petit badge top-right (sous CameraTestPanel) : clic → toggle
 * `editor.multiActorEnabled` ; Editor.qml a un Loader gated par cette
 * property qui crée/détruit (LocalPlayerSpawner + PhysicsActor +
 * InputController) pour le 2e joueur.
 *
 * Quand actif : affiche aussi la position courante de "player2"
 * (lue via pattounxWorld.bodyState à 5 Hz).
 *
 * Mapping touches : P1 = ZQSD (toujours actif), P2 = flèches (toggleable).
 */
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // Référence à Editor.qml (pour lire/écrire `multiActorEnabled`).
    required property var editor

    anchors.top: parent.top
    anchors.right: parent.right
    // Stack vertical : 12 (PhysicsStatusPanel) + ~24 (panel height) +
    // 12 (CameraTestPanel) + ~24 + marge = 84
    anchors.topMargin: 84
    anchors.rightMargin: 12

    z: 10000

    width: badge.width
    height: badge.height

    readonly property bool _on: editor && editor.multiActorEnabled

    // Compteur 5 Hz pour rafraîchir la lecture de position P2 quand le
    // panel est ouvert (bodyState n'émet pas de signal de changement).
    property int _posTick: 0
    Timer {
        running: root._on
        interval: 200
        repeat: true
        onTriggered: root._posTick++
    }

    Rectangle {
        id: badge
        width: badgeContent.implicitWidth + 20
        height: badgeContent.implicitHeight + 10
        radius: 6
        color: root._on ? "#7c2d12" : "#2a2a2e"   // orange foncé si ON (cohérent visuel P2)
        border.color: root._on ? "#f97316" : "#71717a"
        border.width: 1

        Column {
            id: badgeContent
            anchors.centerIn: parent
            spacing: 2
            Row {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._on ? "#f97316" : "#71717a"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._on ? "P2 · ON · ←↑↓→" : "P2 · OFF"
                    color: "#f4f4f5"
                    font.pixelSize: 12
                    font.bold: true
                }
            }
            // Position P2 si actif. ↗ Lecture via pattounxWorld.bodyState
            // (bodyState retourne {} si le body n'existe pas encore — le
            // Loader peut être actif avant que le worker ait traité la cmd).
            Text {
                visible: root._on
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    root._posTick   // dépendance pour rebind
                    if (!pattounxWorld) return ""
                    const s = pattounxWorld.bodyState("player2")
                    if (!s.id) return "(spawn…)"
                    return "(" + s.position.x.toFixed(1) + ", "
                               + s.position.y.toFixed(1) + ")"
                }
                color: "#fed7aa"
                font.pixelSize: 10
                font.family: "monospace"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (editor) editor.multiActorEnabled = !editor.multiActorEnabled
        }

        ToolTip.visible: hover.hovered
        ToolTip.delay: 400
        ToolTip.text: root._on
                ? "Désactiver P2 (cube orange piloté par les flèches)"
                : "Activer P2 — spawn cube orange piloté par les flèches"
        HoverHandler { id: hover }
    }
}
