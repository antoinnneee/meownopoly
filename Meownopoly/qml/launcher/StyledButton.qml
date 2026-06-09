import QtQuick
import QtQuick.Controls

/*
 * StyledButton.qml — Bouton custom du launcher (thème sombre).
 *
 *  - défaut      : fond #2a2a2e, bordure #3a3a3a, texte clair (actions neutres)
 *  - primary:true : rempli avec accentColor (actions principales)
 *  - danger:true  : texte/bordure rouge au survol (suppression)
 *
 * Reste un ComboBox-friendly Button : tous les comportements (checkable,
 * autoExclusive, ToolTip, font.pixelSize, implicit*) restent surchargeables.
 */
Button {
    id: control

    property color accentColor: "#569c58"
    property bool  primary: false
    property bool  danger: false

    implicitHeight: 30
    leftPadding: 14
    rightPadding: 14
    font.pixelSize: 12

    contentItem: Text {
        text: control.text
        font: control.font
        color: !control.enabled ? "#6b7280"
             : control.primary  ? "#ffffff"
             : (control.danger && control.hovered ? "#fca5a5" : "#e5e7eb")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 5
        border.width: 1
        color: !control.enabled ? "#26262b"
             : control.primary
                 ? (control.pressed ? Qt.darker(control.accentColor, 1.25)
                    : (control.hovered ? Qt.lighter(control.accentColor, 1.12) : control.accentColor))
                 : (control.pressed ? "#1b1b1f" : (control.hovered ? "#34343a" : "#2a2a2e"))
        border.color: !control.enabled ? "#3a3a3a"
             : control.primary ? control.accentColor
             : (control.danger && control.hovered ? "#7f1d1d" : "#3a3a3a")
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
