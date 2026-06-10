import QtQuick
import QtQuick.Controls
import theme

/*
 * StyledCheckBox.qml — Case à cocher custom du launcher (thème sombre).
 * Indicateur visible : case surface bordure claire au repos, remplie en
 * accentColor + ✓ blanc quand cochée. Texte clair.
 */
CheckBox {
    id: control

    property color accentColor: Theme.accentAlt

    spacing: Theme.spacingS
    font.pixelSize: Theme.fontSizeBody

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        radius: Theme.radiusS
        color: control.checked ? control.accentColor : Theme.surface
        border.width: 1
        border.color: control.checked ? control.accentColor
                    : (control.hovered ? Theme.textHint : Theme.borderLight)
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            visible: control.checked
        }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? Theme.textSecondary : Theme.textHint
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
