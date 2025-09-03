import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: control
    property string text: "Menu Assets"
    property int buttonIndex: 0

    signal buttonClicked(int index)
    

    color: "#b05758"
    border.color: "#862a2a"
    border.width: 1
    radius: 4
    width: 100
    height: 35
    Text {
        text: control.text
        anchors.centerIn: parent
        font.pixelSize: 12
        font.bold: true
        color: "white"
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: control.opacity = 0.9
        onExited: control.opacity = 1.0
        onClicked: {
            control.buttonClicked(control.buttonIndex)
        }
    }
}
