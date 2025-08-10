import QtQuick 2.15
import QtQuick.Controls
import "."
import "../"

SequentialAnimation {
    id: createAnimation
    running: false
    NumberAnimation {
        target: snapableElement
        property: "scale"
        easing.bezierCurve: [0.612,0.0516,0.544,0.917,1,1]
        from: 0.0
        to: 1.0
        duration: 450
        easing.type: Easing.InOutQuad
    }
}
