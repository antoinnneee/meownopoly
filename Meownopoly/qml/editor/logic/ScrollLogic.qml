import QtQuick 2.15
import "../tools"

QtObject {
    property GridManager editorGrid
    property var logic

    function scrollUp(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            logic.updateSize(logic.mmSize + 1)
        }
    }
    function scrollDown(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            logic.updateSize(logic.mmSize - 1)
        }
    }
    function scrollLeft(wheel) {
        console.log("scrollLeft")
    }
    function scrollRight(wheel) {
        console.log("scrollRight")
    }

}
