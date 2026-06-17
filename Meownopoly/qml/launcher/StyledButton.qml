import QtQuick
import QtQuick.Controls
import theme

/*
 * StyledButton.qml — Bouton custom du launcher (thème sombre).
 *
 *  - défaut      : fond surface, bordure border, texte clair (actions neutres)
 *  - primary:true : rempli avec accentColor (actions principales)
 *  - danger:true  : texte/bordure rouge au survol (suppression)
 *
 * Reste un ComboBox-friendly Button : tous les comportements (checkable,
 * autoExclusive, ToolTip, font.pixelSize, implicit*) restent surchargeables.
 */
Button {
    id: control

    property color accentColor: Theme.accentAlt
    property bool  primary: false
    property bool  danger: false

    implicitHeight: 30
    leftPadding: Theme.spacingXL
    rightPadding: Theme.spacingXL
    font.pixelSize: Theme.fontSizeBody

    contentItem: Text {
        text: control.text
        font: control.font
        color: !control.enabled ? Theme.textHint
             : control.primary  ? Theme.textPrimary
             : (control.danger && control.hovered ? Theme.dangerSoft : Theme.textSoft)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.radiusS
        border.width: 1
        color: !control.enabled ? Theme.surface
             : control.primary
                 ? (control.pressed ? Theme.pressed(control.accentColor)
                    : (control.hovered ? Theme.hover(control.accentColor) : control.accentColor))
                 : (control.pressed ? Theme.background : (control.hovered ? Theme.surfaceAlt : Theme.surface))
        border.color: !control.enabled ? Theme.border
             : control.primary ? control.accentColor
             : (control.danger && control.hovered ? "#7f1d1d" : Theme.border)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }
}
