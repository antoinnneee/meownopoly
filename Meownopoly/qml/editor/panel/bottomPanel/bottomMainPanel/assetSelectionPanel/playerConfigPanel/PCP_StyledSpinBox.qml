import QtQuick
import QtQuick.Controls

/*
 * SpinBox stylé cohérent avec le reste de l'éditeur.
 * Boutons + / − à gauche/droite, fond central #2a2a2a, accent #569c58 au focus.
 */
SpinBox {
    id: control

    implicitHeight: 32
    implicitWidth: 110
    editable: true
    font.pixelSize: 12

    contentItem: TextInput {
        text: control.displayText
        color: "#ffffff"
        font: control.font
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        selectByMouse: true
        selectionColor: "#569c58"
        selectedTextColor: "#ffffff"
    }

    background: Rectangle {
        color: "#2a2a2a"
        radius: 3
        border.color: control.activeFocus ? "#569c58" : "#555555"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    up.indicator: Rectangle {
        x: control.width - width
        height: control.height
        implicitWidth: 24
        radius: 3
        color: control.up.pressed
                 ? "#1f1f1f"
                 : (control.up.hovered ? "#3a3a3a" : "#2a2a2a")
        Text {
            anchors.centerIn: parent
            text: "+"
            color: control.enabled ? "#cccccc" : "#555555"
            font.pixelSize: 14
            font.bold: true
        }
    }

    down.indicator: Rectangle {
        x: 0
        height: control.height
        implicitWidth: 24
        radius: 3
        color: control.down.pressed
                 ? "#1f1f1f"
                 : (control.down.hovered ? "#3a3a3a" : "#2a2a2a")
        Text {
            anchors.centerIn: parent
            text: "−"
            color: control.enabled ? "#cccccc" : "#555555"
            font.pixelSize: 14
            font.bold: true
        }
    }
}
