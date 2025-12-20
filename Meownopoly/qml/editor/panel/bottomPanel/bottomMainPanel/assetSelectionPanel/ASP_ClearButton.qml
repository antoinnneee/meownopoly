import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AssetManager

import editorBottomPanel

Button {
    text: "✕ Clear"
    flat: true
    
    background: Rectangle {
        color: parent.pressed ? "#AA4444" : "transparent"
        border.color: "#FF6666"
        border.width: 1
        radius: 4
    }
    
    contentItem: Text {
        text: parent.text
        color: "#FF6666"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 11
    }
    
    onClicked: {
        // Signal to parent to clear selection
        titleBar.assetSelected("", "", "")
    }
}
