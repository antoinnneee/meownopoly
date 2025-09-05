import QtQuick 2.15

QtObject {
    property var editorGrid

    function scrollUp(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            console.log("CTRL + scrollUp")
            editorGridd.updateSize(parent.mmSize + 1)
        }
    }
    function scrollDown(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            console.log("CTRL + scrollDown")
            editorGridd.updateSize(parent.mmSize - 1)
        }
    }
    function scrollLeft(wheel) {
        console.log("scrollLeft")
    }
    function scrollRight(wheel) {
        console.log("scrollRight")
    }

}
