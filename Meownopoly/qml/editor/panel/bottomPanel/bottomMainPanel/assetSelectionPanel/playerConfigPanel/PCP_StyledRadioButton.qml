import QtQuick
import QtQuick.Controls

/*
 * RadioButton stylé cohérent avec le reste de l'éditeur.
 * Indicator : cercle creux #555555 (focus #888888), point plein #569c58 au check.
 * Texte : #cccccc (#ffffff au check).
 */
RadioButton {
    id: control

    spacing: 8
    padding: 4
    font.pixelSize: 12

    indicator: Rectangle {
        implicitWidth: 16
        implicitHeight: 16
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: 8
        color: "transparent"
        border.color: control.checked
                        ? "#569c58"
                        : (control.hovered ? "#888888" : "#555555")
        border.width: 2

        Behavior on border.color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.centerIn: parent
            width: control.checked ? 8 : 0
            height: width
            radius: width / 2
            color: "#569c58"

            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: !control.enabled ? "#666666"
              : control.checked ? "#ffffff" : "#cccccc"
        font: control.font
        verticalAlignment: Text.AlignVCenter
    }
}
