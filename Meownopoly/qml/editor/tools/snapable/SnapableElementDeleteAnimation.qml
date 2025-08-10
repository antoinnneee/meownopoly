import QtQuick 2.15
import QtQuick.Controls
import "."
import "../"

SequentialAnimation {
    id: deleteAnimation
    running: false
    NumberAnimation {
        target: snapableElement
        property: "scale"
        easing.bezierCurve: [0.612,0.0516,0.544,0.917,1,1]
        to: 0.1
        duration: 1000
        easing.type: Easing.InOutQuad
    }
}
