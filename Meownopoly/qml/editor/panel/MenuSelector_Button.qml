import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Button {
    id: control

    width: 100
    height: 35

    text: "Menu Assets"
    property color mainColor : "#b05758"
    property color borderColor : "#862a2a"
    property int buttonIndex: 0

    signal buttonClicked(int index)

    onClicked: {
        animation.running = true
        control.buttonClicked(control.buttonIndex)
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

    contentItem: Text {
        text: control.text
        color: "#ffffff"
        font.pixelSize: 12
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        id: background
        anchors.fill: parent
        color: control.hovered ? Qt.lighter(mainColor, 1.1) : mainColor
        border.color:control.hovered ? Qt.lighter(borderColor, 1.1) : borderColor
        border.width: 1
        topLeftRadius: 0
        topRightRadius: 10

       Behavior on color { ColorAnimation { duration: control.hovered ? 150 : 250} }
    }
}
