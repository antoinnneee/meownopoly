import QtQuick 2.15
import QtQuick.Controls

Button{
    id: loadMapButton
    
    text: "Load Map"
    z:1000


    property color mainColor : "#6c5ce7"

    onClicked: {
        animation.running = true
    }

    SequentialAnimation {
        id: animation
        ColorAnimation {
            target: background
            property: "color"
            from: background.color
            to: Qt.lighter(mainColor, 1.2)
            duration: 150
            easing.type: Easing.InOutQuad
        }
        ColorAnimation {
            target: background
            property: "color"
            to: background.color
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    background: Rectangle {
        id: background
        radius: 8
        color: loadMapButton.hovered ? Qt.lighter(mainColor, 1.1) : mainColor
        border.color: "#5f3dc4"
        border.width: 1

       Behavior on color { ColorAnimation { duration: loadMapButton.hovered ? 150 : 250} }
    }
    contentItem: Text {
        text: loadMapButton.text
        color: "#ffffff"
        font.pixelSize: 12
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
