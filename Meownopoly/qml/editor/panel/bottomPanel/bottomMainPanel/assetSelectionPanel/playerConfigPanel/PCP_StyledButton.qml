import QtQuick
import QtQuick.Controls
import theme

/*
 * Button stylé cohérent avec le reste de l'éditeur. Variante `accent`
 * pour mettre en avant les actions principales (presets sélectionnés,
 * etc.).
 */
Button {
    id: control

    property bool accent: false

    padding: Theme.spacingM
    leftPadding: Theme.spacingXL
    rightPadding: Theme.spacingXL

    contentItem: Text {
        text: control.text
        color: control.enabled
                 ? (control.accent ? Theme.textPrimary : Theme.textSecondary)
                 : Theme.textDisabled
        font.pixelSize: Theme.fontSizeBody
        font.bold: control.accent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusS
        color: {
            if (!control.enabled) return Theme.pressed(Theme.surface)
            if (control.pressed)  return control.accent ? Theme.pressed(Theme.accentAlt) : Theme.background
            if (control.hovered)  return control.accent ? Theme.hover(Theme.accentAlt) : Theme.surfaceHover
            return control.accent ? Theme.accentAlt : Theme.surface
        }
        border.color: control.accent ? Theme.hover(Theme.accentAlt) : Theme.borderLight
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
