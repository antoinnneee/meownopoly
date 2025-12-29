import QtQuick 2.15

WheelHandler {
    onWheel: (wheel) => {
        if (wheel.angleDelta.y > 0) {
            logic.scrollLogic.scrollUp(wheel)
        }
        else if (wheel.angleDelta.y < 0) {
            logic.scrollLogic.scrollDown(wheel)
        }
        if (wheel.angleDelta.x > 0) {
            logic.scrollLogic.scrollRight(wheel)
        }
        else if (wheel.angleDelta.x < 0) {
            logic.scrollLogic.scrollLeft(wheel)
        }
    }
}
