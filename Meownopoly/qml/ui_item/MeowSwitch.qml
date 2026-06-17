import QtQuick
import QtQuick.Controls
import theme

/*
 * MeowSwitch — interrupteur stylé canonique (track + pastille blanche animée).
 *
 * Factorise l'indicator custom recopié dans ZCP_GeneralSection et ailleurs.
 * Hérite du signal `toggled()` natif de Switch — le call-site y branche sa logique.
 */
Switch {
    id: control

    indicator: Rectangle {
        implicitWidth: Theme.px(36)
        implicitHeight: Theme.px(20)
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: height / 2
        color: control.checked ? Theme.accentAlt : Theme.surfaceAlt
        border.color: control.checked ? Theme.accentAlt : Theme.borderLight

        Rectangle {
            width: parent.height - 4
            height: parent.height - 4
            x: control.checked ? parent.width - width - 2 : 2
            y: 2
            radius: width / 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: Theme.durationNormal } }
        }
    }
}
