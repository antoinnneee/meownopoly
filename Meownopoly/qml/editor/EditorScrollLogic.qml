import QtQuick 2.15
import "tools"

QtObject {
    required property GridManager editorGrid
    required property var logic

    function scrollUp(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            console.log("CTRL + scrollUp")
            editorGrid.updateSize(editorGrid.mmSize + 1)
        }
    }
    function scrollDown(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            console.log("CTRL + scrollDown")
            editorGrid.updateSize(editorGrid.mmSize - 1)
        }
    }
    function scrollLeft(wheel) {
        console.log("scrollLeft")
    }
    function scrollRight(wheel) {
        console.log("scrollRight")
    }

}
