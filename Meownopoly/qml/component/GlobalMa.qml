import QtQuick 2.15
import QtQuick.Controls
import QtQml

MouseArea{
    id: mainMa

    required property var mouseLogic


    drag.target: null
    drag.axis: Drag.XAndYAxis

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    pressAndHoldInterval: 300
    hoverEnabled: true

    drag.onActiveChanged: {
        mouseLogic.dragChanged(mouseX, mouseY, drag)
    }
    
    function elementClicked(tile)
    {
        mouseLogic.elementClicked(tile, drag)
    }
    
    onPressed: function (mouse) {
        if (mouse.button === Qt.LeftButton) {
            mouseLogic.pressedLeft(mouse, drag)
        }
        else if (mouse.button === Qt.MiddleButton) {
            mouseLogic.pressedMiddle(mouse, drag)
        }
        else if (mouse.button === Qt.RightButton) {
            mouseLogic.pressedRight(mouse, drag)
        }
    }
    
    onReleased: function(mouse) {
        mouseLogic.release(mouse, drag)
    }
    
    onPositionChanged: function(mouse) {
        mouseLogic.positionChanged(mouse, drag)
    }
    
    onPressAndHold: function (mouse) {
        mouseLogic.pressedAndHold(mouse)
    }

    onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            mouseLogic.clickedLeft(mouse, drag)
        }
        else if (mouse.button === Qt.RightButton) {
            mouseLogic.clickedRight(mouse, drag)
        }
        else if (mouse.button === Qt.MiddleButton) {
            mouseLogic.clickedMiddle(mouse, drag)
        }
    }
}
