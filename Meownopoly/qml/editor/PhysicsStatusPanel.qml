/*
 * PhysicsStatusPanel — badge éditeur indiquant l'état du moteur Pattounx.
 *
 * Cliquer le badge → toggle start/stop. Le `pattounxWorld` consommé est
 * l'instance globale exposée par C++ (qmlapp.cpp setContextProperty),
 * partagée par toutes les scènes (éditeur, CatwayTest, futur World3D).
 */
import QtQuick 2.15
import QtQuick.Controls
import theme

Item {
    id: root

    // Placement dans la Column `leftBadgeStack` d'Editor.qml.
    width: badge.width
    height: badge.height

    Rectangle {
        id: badge
        width: badgeRow.implicitWidth + 20
        height: badgeRow.implicitHeight + 10
        radius: Theme.radiusM
        color: pattounxWorld.running ? "#1e4d3a" : "#3a1e1e"
        border.color: pattounxWorld.running ? Theme.success : Theme.danger
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: Theme.spacingM
            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: pattounxWorld.running ? Theme.success : Theme.danger
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pattounxWorld.running
                      ? ("Physique · ON · " + pattounxWorld.tickRate + " Hz")
                      : "Physique · OFF"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeBody
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
        HoverHandler { id: hover }
    }
}
