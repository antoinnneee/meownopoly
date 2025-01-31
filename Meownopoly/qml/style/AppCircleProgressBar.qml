import QtQuick
import QtQuick.Shapes

Item {
    id:baseRec
    height: 400
    width: height
    property double value: 25
    property double from: 0
    property double to: 100
    property double calcValue : value
    property color backgroundColor: AppStyle.globalText
    property color color: AppStyle.globalPrimaryAccent
    property color textColor: color
    property color errorColor: "red"
    property color defaultColor : color
    property double progressWidth: height * 0.03
    property double emptyWitdh: height * 0.03
    property int centralHeight: (height < width) ? height : width
    property alias centralText: centralText
    onValueChanged: {
        if(value > to) {
            calcValue = to
            defaultColor = errorColor
        } else if(value < from) {
            calcValue = from
            defaultColor = errorColor
        } else {
            calcValue = value
            defaultColor = color
        }
    }
    //onValueChanged: cadran.requestPaint()

    AppLabel {
        id:centralText
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: (text.length > 3) ? centralHeight * 0.4 - contentWidth : centralHeight * 0.4
        color: baseRec.textColor
        text: baseRec.value
        z: 1
    }

    Shape {
        id:shape
        function degreesToRadians(degrees) {
            return degrees * (Math.PI / 180);
        }

        function scale(value, in_min, in_max, out_min, out_max) {
            return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
        }

        property int centerXY: centralHeight / 2
        property double degree: scale(baseRec.calcValue, baseRec.from, baseRec.to, 0, 360)
        property double startAngle: degreesToRadians(90)
        property double fullAngle: degreesToRadians(450)
        property double progressAngle: startAngle + degreesToRadians(degree)
        property int rayon: centralHeight / 2

        ShapePath {
            fillColor: defaultColor
            strokeColor: "transparent"
            strokeWidth: 5
            startX: Math.cos(shape.startAngle) * shape.rayon + shape.centerXY
            startY: Math.sin(shape.startAngle) * shape.rayon + shape.centerXY
            /*Component.onCompleted: {
                console.log("startAngle : " + shape.startAngle)
                console.log("fullAngle : " + shape.fullAngle)
                console.log("progressAngle : " + shape.progressAngle)
                console.log("degree : " + shape.degree)
                console.log("cosStart : " + startX)
                console.log("sinStart : " + startY)
                console.log("rayon : " + shape.rayon)
            }*/

            PathArc {
                id:arc
                x: Math.cos(shape.progressAngle) * shape.rayon + shape.centerXY
                y: Math.sin(shape.progressAngle) * shape.rayon + shape.centerXY
                radiusX:  shape.rayon; radiusY: shape.rayon
                useLargeArc: !!(shape.degree > 180)
            }

            PathLine {
                x: Math.cos(shape.progressAngle) * (shape.rayon * 0.9) + shape.centerXY
                y: Math.sin(shape.progressAngle) * (shape.rayon * 0.9) + shape.centerXY
                //radiusX:  3; radiusY: 3
                //direction: (value == maxValue) ? PathArc.Counterclockwise : PathArc.Clockwise
            }

            PathArc {
                x: Math.cos(shape.startAngle) * (shape.rayon * 0.9) + shape.centerXY
                y: Math.sin(shape.startAngle) * (shape.rayon * 0.9) + shape.centerXY
                radiusX:  shape.rayon * 0.9; radiusY: shape.rayon * 0.9
                direction: PathArc.Counterclockwise
                useLargeArc: !!(shape.degree > 180)
            }

            PathLine {
                x: Math.cos(shape.startAngle) * shape.rayon + shape.centerXY
                y: Math.sin(shape.startAngle) * shape.rayon + shape.centerXY
                //radiusX:  3; radiusY: 3
                //useLargeArc: false
            }
        }

        Timer {
            interval: 1000
            running: false
            repeat: true
            onTriggered: {
                console.log("Timer X :" + emptyCircle.width)
                console.log("Timer Y :" + emptyCircle.height)
            }
        }
    }

    Rectangle {
        id:emptyCircle
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        height: baseRec.centralHeight * 0.95
        width: height
        radius: height
        z: -1
        color: "transparent"
        border.color: baseRec.backgroundColor
        border.width: 5 //shape.rayon - (shape.rayon * 0.9)
    }

}
