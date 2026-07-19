import QtQuick
import QtQuick.Controls
import theme

/*
 * MeowTextArea — zone de texte multiligne canonique de l'application.
 *
 * Elle conserve l'API native de TextArea (readOnly, wrapMode, selection,
 * ScrollView…) et ne mutualise que le style visuel.
 */
TextArea {
    id: control

    property color fieldColor: Theme.background
    property color borderColor: Theme.border
    property color focusBorderColor: Theme.accentAlt

    color: control.readOnly ? Theme.textSecondary : Theme.textPrimary
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accentAlt
    selectedTextColor: Theme.textPrimary
    font.pixelSize: Theme.fontSizeSmall
    padding: Theme.spacingM

    background: Rectangle {
        color: control.fieldColor
        radius: Theme.radiusXS
        border.width: 1
        border.color: control.activeFocus
                      ? control.focusBorderColor : control.borderColor
        Behavior on border.color {
            ColorAnimation { duration: Theme.durationNormal }
        }
    }
}
