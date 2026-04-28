import QtQuick
import QtQuick.Controls

/*
 * TabButton stylé : surligne au survol et marque l'onglet actif avec
 * un fond #569c58 + barre inférieure.
 */
TabButton {
    id: control

    padding: 8

    contentItem: Text {
        text: control.text
        color: control.checked ? "#ffffff"
                                : (control.hovered ? "#cccccc" : "#888888")
        font.pixelSize: 12
        font.bold: control.checked
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: control.checked ? "#569c58"
                                : (control.hovered ? "#2f2f2f" : "transparent")
        radius: 3
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: "#6fb872"
            visible: control.checked
        }
    }
}
