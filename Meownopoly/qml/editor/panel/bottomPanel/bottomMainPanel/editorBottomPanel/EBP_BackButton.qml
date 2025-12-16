import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects

import "../"

Button {
    visible: true
    text: "← Back"
    flat: true
    
    background: Rectangle {
        color: parent.pressed ? "#555555" : "transparent"
        border.color: "#666666"
        border.width: 1
        radius: 4
    }
    
    contentItem: Text {
        text: parent.text
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

}
