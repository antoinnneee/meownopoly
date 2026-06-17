import QtQuick
import QtQuick.Controls
import theme

/*
 * TextField stylé cohérent avec CCPS_GeneralSection (caseConfigPanel) :
 * fond Theme.surface, texte blanc, bordure Theme.borderLight avec accent Theme.accentAlt au focus.
 */
TextField {
    id: control

    color: Theme.textPrimary
    selectionColor: Theme.accentAlt
    selectedTextColor: Theme.textPrimary
    font.pixelSize: Theme.fontSizeBody
    padding: Theme.spacingS

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusXS
        border.color: control.activeFocus ? Theme.accentAlt : Theme.borderLight
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
    }
}
