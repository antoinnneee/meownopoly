import QtQuick
import QtQuick.Controls

/*
 * StyledCheckBox.qml — Case à cocher custom du launcher (thème sombre).
 * Indicateur visible : case #2a2a2e bordure claire au repos, remplie en
 * accentColor + ✓ blanc quand cochée. Texte clair.
 */
CheckBox {
    id: control

    property color accentColor: "#569c58"

    spacing: 6
    font.pixelSize: 12

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: 4
        color: control.checked ? control.accentColor : "#2a2a2e"
        border.width: 1
        border.color: control.checked ? control.accentColor
                    : (control.hovered ? "#8b919b" : "#555a63")
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "#ffffff"
            font.pixelSize: 13
            font.bold: true
            visible: control.checked
        }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "#d1d5db" : "#6b7280"
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
