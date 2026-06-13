import QtQuick
import theme

/*
 * TrashIcon.qml — Petite icône « poubelle » composée de Rectangles.
 * (Pas de Canvas → rendu garanti même en très petit ; pas d'emoji → pas de
 * glyphe manquant.) Sert de contenu aux boutons de suppression.
 */
Item {
    id: icon
    property color color: Theme.textSoft
    implicitWidth: 14
    implicitHeight: 16

    // Anse
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.height * 0.02
        width: icon.width * 0.44
        height: Math.max(1.5, icon.height * 0.10)
        radius: height / 2
        color: icon.color
    }
    // Couvercle
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.height * 0.17
        width: icon.width * 0.92
        height: Math.max(1.6, icon.height * 0.11)
        radius: 1
        color: icon.color
    }
    // Corps (seau)
    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: icon.height * 0.33
        width: icon.width * 0.70
        height: icon.height * 0.55
        radius: icon.width * 0.14
        color: "transparent"
        border.color: icon.color
        border.width: Math.max(1, icon.width * 0.09)

        // Stries verticales
        Row {
            anchors.centerIn: parent
            spacing: body.width * 0.18
            Repeater {
                model: 3
                delegate: Rectangle {
                    width: Math.max(1, icon.width * 0.06)
                    height: body.height * 0.46
                    radius: 1
                    color: icon.color
                }
            }
        }
    }
}
