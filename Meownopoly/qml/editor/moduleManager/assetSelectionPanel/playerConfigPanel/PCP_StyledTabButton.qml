import QtQuick
import QtQuick.Controls
import theme

/*
 * TabButton stylé : surligne au survol et marque l'onglet actif avec
 * un fond Theme.accentAlt + barre inférieure.
 */
TabButton {
    id: control

    padding: Theme.spacingM

    contentItem: Text {
        text: control.text
        color: control.checked ? Theme.textPrimary
                                : (control.hovered ? Theme.textSecondary : Theme.textMuted)
        font.pixelSize: Theme.fontSizeBody
        font.bold: control.checked
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: control.checked ? Theme.accentAlt
                                : (control.hovered ? Theme.hover(Theme.surface) : "transparent")
        radius: Theme.radiusXS
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.hover(Theme.accentAlt)
            visible: control.checked
        }
    }
}
