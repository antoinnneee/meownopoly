import QtQuick
import QtQuick.Controls

/*
 * Button stylé cohérent avec le reste de l'éditeur. Variante `accent`
 * pour mettre en avant les actions principales (presets sélectionnés,
 * etc.).
 */
Button {
    id: control

    property bool accent: false

    padding: 8
    leftPadding: 12
    rightPadding: 12

    contentItem: Text {
        text: control.text
        color: control.enabled
                 ? (control.accent ? "#ffffff" : "#cccccc")
                 : "#666666"
        font.pixelSize: 12
        font.bold: control.accent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 4
        color: {
            if (!control.enabled) return "#1f1f1f"
            if (control.pressed)  return control.accent ? "#3d6f3f" : "#1a1a1a"
            if (control.hovered)  return control.accent ? "#5fa362" : "#3a3a3a"
            return control.accent ? "#569c58" : "#2a2a2a"
        }
        border.color: control.accent ? "#6fb872" : "#555555"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
