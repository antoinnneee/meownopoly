/*
 * PhysicsStatusPanel — badge éditeur indiquant l'état du moteur Pattounx.
 *
 * Cliquer le badge → toggle start/stop. Le `pattounxWorld` consommé est
 * l'instance globale exposée par C++ (qmlapp.cpp setContextProperty),
 * partagée par toutes les scènes (éditeur, CatwayTest, futur World3D).
 */
import QtQuick 2.15
import QtQuick.Controls

Item {
    id: root

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 12
    anchors.rightMargin: 12

    z: 10000

    width: badge.width
    height: badge.height

    Rectangle {
        id: badge
        width: badgeRow.implicitWidth + 20
        height: badgeRow.implicitHeight + 10
        radius: 6
        color: pattounxWorld.running ? "#1e4d3a" : "#3a1e1e"
        border.color: pattounxWorld.running ? "#22c55e" : "#ef4444"
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: pattounxWorld.running ? "#22c55e" : "#ef4444"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pattounxWorld.running
                      ? ("Physique · ON · " + pattounxWorld.tickRate + " Hz")
                      : "Physique · OFF"
                color: "#f4f4f5"
                font.pixelSize: 12
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (pattounxWorld.running) pattounxWorld.stop()
                else                       pattounxWorld.start()
            }
        }

        ToolTip.visible: hover.hovered
        ToolTip.delay: 400
        ToolTip.text: pattounxWorld.running
                      ? ("tick=" + pattounxWorld.currentTick
                         + "  ·  click pour arrêter le moteur")
                      : "click pour démarrer le moteur physique"
        HoverHandler { id: hover }
    }
}
