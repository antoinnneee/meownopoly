import QtQuick
import QtQuick.Controls
import theme

/*
 * SpinBox stylé cohérent avec le reste de l'éditeur.
 * Boutons + / − à gauche/droite, fond central Theme.surface, accent Theme.accentAlt au focus.
 */
SpinBox {
    id: control

    implicitHeight: 32
    implicitWidth: 110
    editable: true
    font.pixelSize: Theme.fontSizeBody

    contentItem: TextInput {
        text: control.displayText
        color: Theme.textPrimary
        font: control.font
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        selectByMouse: true
        selectionColor: Theme.accentAlt
        selectedTextColor: Theme.textPrimary
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusXS
        border.color: control.activeFocus ? Theme.accentAlt : Theme.borderLight
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    up.indicator: Rectangle {
        x: control.width - width
        height: control.height
        implicitWidth: 24
        radius: Theme.radiusXS
        color: control.up.pressed
                 ? Theme.pressed(Theme.surface)
                 : (control.up.hovered ? Theme.surfaceHover : Theme.surface)
        Text {
            anchors.centerIn: parent
            text: "+"
            color: control.enabled ? Theme.textSecondary : Theme.borderLight
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
    }

    down.indicator: Rectangle {
        x: 0
        height: control.height
        implicitWidth: 24
        radius: Theme.radiusXS
        color: control.down.pressed
                 ? Theme.pressed(Theme.surface)
                 : (control.down.hovered ? Theme.surfaceHover : Theme.surface)
        Text {
            anchors.centerIn: parent
            text: "−"
            color: control.enabled ? Theme.textSecondary : Theme.borderLight
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
    }
}
