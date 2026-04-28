import QtQuick
import QtQuick.Controls

/*
 * TextField stylé cohérent avec CCPS_GeneralSection (caseConfigPanel) :
 * fond #2a2a2a, texte blanc, bordure #555555 avec accent #569c58 au focus.
 */
TextField {
    id: control

    color: "#ffffff"
    selectionColor: "#569c58"
    selectedTextColor: "#ffffff"
    font.pixelSize: 12
    padding: 6

    background: Rectangle {
        color: "#2a2a2a"
        radius: 3
        border.color: control.activeFocus ? "#569c58" : "#555555"
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 150 } }
    }
}
