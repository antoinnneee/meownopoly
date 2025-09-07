import QtQuick 2.15
import QtQuick.Controls

Button{
    id: loadMapButton
    
    text: "Load Map"
    z:1000

    // Style moderne pour le bouton
    background: Rectangle {
        radius: 8
        color: loadMapButton.hovered ? "#74b9ff" : "#6c5ce7"
        border.color: "#5f3dc4"
        border.width: 1
        
        Behavior on color { ColorAnimation { duration: 150 } }
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
