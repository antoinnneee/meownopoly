import QtQuick 2.15
import "../tools"

ScrollLogic {
    required property GridManager editorGrid
    required property var logic

    function scrollUp(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            console.log("CTRL POSE + scrollUp")
            logic.tileLogic.currentElementHeight +=1
        }
        if (wheel.modifiers & Qt.ShiftModifier) {
            console.log("SHIFT POSE + scrollUp")
            logic.tileLogic.currentElementWidth +=1
        }
    }
    function scrollDown(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            console.log("CTRL POSE+ scrollDown")
            if (logic.tileLogic.currentElementHeight > 1)
                logic.tileLogic.currentElementHeight -=1
        }
        if (wheel.modifiers & Qt.ShiftModifier) {
            console.log("SHIFT POSE + scrollDown")
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
