import QtQuick 2.15
import "../tools"
import "../tools/grid"

ScrollLogic {
    required property GridManager editorGrid
    required property var logic

    function scrollUp(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            logic.tileLogic.currentElementHeight +=1
        }
        if (wheel.modifiers & Qt.ShiftModifier) {
            logic.tileLogic.currentElementWidth +=1
        }
    }
    function scrollDown(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            if (logic.tileLogic.currentElementHeight > 1)
                logic.tileLogic.currentElementHeight -=1
        }
        if (wheel.modifiers & Qt.ShiftModifier) {
            if (logic.tileLogic.currentElementWidth > 1)
            logic.tileLogic.currentElementWidth -=1
        }

    }
    function scrollLeft(wheel) {
        console.log("scrollLeft")
    }
    function scrollRight(wheel) {
        console.log("scrollRight")
    }

}
