import QtQuick
import QtQuick.Controls
import theme

/*
 * RadioButton stylé cohérent avec le reste de l'éditeur.
 * Indicator : cercle creux Theme.borderLight (hover Theme.textMuted), point plein Theme.accentAlt au check.
 * Texte : Theme.textSecondary (Theme.textPrimary au check).
 */
RadioButton {
    id: control

    spacing: Theme.spacingM
    padding: Theme.spacingXS
    font.pixelSize: Theme.fontSizeBody

    indicator: Rectangle {
        implicitWidth: 16
        implicitHeight: 16
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: 8
        color: "transparent"
        border.color: control.checked
                        ? Theme.accentAlt
                        : (control.hovered ? Theme.textMuted : Theme.borderLight)
        border.width: 2

        Behavior on border.color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.centerIn: parent
            width: control.checked ? 8 : 0
            height: width
            radius: width / 2
            color: Theme.accentAlt

            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.spacing
        text: control.text
        color: !control.enabled ? Theme.textDisabled
              : control.checked ? Theme.textPrimary : Theme.textSecondary
        font: control.font
        verticalAlignment: Text.AlignVCenter
    }
}
