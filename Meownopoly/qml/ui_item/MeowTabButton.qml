import QtQuick
import QtQuick.Controls
import theme

/* Bouton d'onglet canonique, compatible TabBar et ButtonGroup. */
TabButton {
    id: control

    property color accentColor: Theme.accentAlt
    property int fontSize: Theme.fontSizeBody

    implicitHeight: Theme.px(36)
    leftPadding: Theme.spacingL
    rightPadding: Theme.spacingL
    font.pixelSize: control.fontSize
    font.bold: control.checked

    contentItem: Text {
        text: control.text
        color: !control.enabled ? Theme.textDisabled
             : control.checked ? Theme.textPrimary : Theme.textSecondary
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusS
        color: control.checked ? Theme.surfaceAlt
             : control.hovered ? Theme.hover(Theme.surface) : Theme.surface
        border.width: control.visualFocus || control.checked ? 2 : 1
        border.color: control.checked || control.visualFocus
                      ? control.accentColor : Theme.borderLight
        Behavior on color {
            ColorAnimation { duration: Theme.durationFast }
        }
    }
}
