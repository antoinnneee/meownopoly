import QtQuick
import QtQuick.Controls

/*
 * RadioButton stylé cohérent avec le reste de l'éditeur :
 * - indicator personnalisé (cercle plein vert au check)
 * - texte blanc
 */
RadioButton {
    id: control

    spacing: 6
    padding: 4

    indicator: Rectangle {
        implicitWidth: 16
        implicitHeight: 16
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 8
        color: "transparent"
        border.color: control.checked ? "#569c58"
                                       : (control.hovered ? "#888888" : "#555555")
        border.width: 2

        Behavior on border.color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: 8
            height: 8
            radius: 4
            anchors.centerIn: parent
            color: "#569c58"
            visible: control.checked
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: control.enabled ? "#cccccc" : "#666666"
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }
}
