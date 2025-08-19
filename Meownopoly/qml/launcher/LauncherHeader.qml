import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 80
    color: "#4a4a4a"
    radius: 12
    border.color: "#666666"
    border.width: 1
    
    signal backRequested()
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        
        Text {
            text: "🐱 Meownopoly Resource Launcher"
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
        }
        
        Item { Layout.fillWidth: true }
        
        Button {
            text: "Retour"
            onClicked: root.backRequested()
            
            background: Rectangle {
                color: parent.pressed ? "#d32f2f" : "#f44336"
                radius: 6
            }
            
            contentItem: Text {
                text: parent.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
