import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    Slider{
        id: slider
        anchors.centerIn: parent
        width: 200
        height: 20
        value: 1
        from: 1
        to: 10
        stepSize: 1
        onValueChanged: {
            // change borderWidth of the rectangle to the value of the slider
            root.borderWidth = slider.value
        }
    }
    property int borderWidth: 0

    Component{
        id: redRectangleComponent
        Rectangle{
            id: redRectangle
            x: 0
            y: 0
            width: 100
            height: 100
            color: "red"
            border.color: "black"
            border.width: root.borderWidth
            radius: 10
            signal clicked()
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    redRectangle.clicked()
                }
            }
        }

    }
    
    Component{
        id: blueRectangleComponent
        Rectangle{
            id: blueRectangle
            x: 100
            y: 100
            width: 100
            height: 100
            color: "blue"
            border.color: "black"
            border.width: root.borderWidth
            radius: 10
            signal clicked()
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    blueRectangle.clicked()
                }
            }
        }
    }

    Loader{
        id: loader
        anchors.centerIn: parent
        sourceComponent: redRectangleComponent
        property int borderWidth

    }
    Connections{
        target: loader.item
        function onClicked() {
           console.log("loader clicked")
        }
    }

    Loader{
        id: loader2
        anchors.centerIn: parent
        sourceComponent: blueRectangleComponent
        property var borderWidth
    }

    Connections{
        target: loader2.item
        function onClicked() {
            console.log("loader2 clicked")
        }
    }
}
