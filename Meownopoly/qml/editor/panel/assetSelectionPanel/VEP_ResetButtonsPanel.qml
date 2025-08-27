import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    
    // Properties for the target decoration element
    property var targetDecoration: null
    
    // Visual properties
    color: "transparent"
    
    // Dimensions
    height: resetButtonsLayout.implicitHeight
    width: resetButtonsLayout.implicitWidth
    
    // Signals
    signal effectChanged()
    
    // Reset buttons layout
    RowLayout {
        id: resetButtonsLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 5
        
        Button {
            text: "Reset Color Effects"
            Layout.fillWidth: true
            
            onClicked: {
                if (root.targetDecoration) {
                    root.targetDecoration.resetColorEffects()
                    root.effectChanged()
                }
            }
            
            background: Rectangle {
                color: parent.pressed ? "#666666" : "#555555"
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: "#cccccc"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        Button {
            text: "Reset All Effects"
            Layout.fillWidth: true
            
            onClicked: {
                if (root.targetDecoration) {
                    root.targetDecoration.resetAllEffects()
                    root.effectChanged()
                }
            }
            
            background: Rectangle {
                color: parent.pressed ? "#ff6666" : "#ff4444"
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: "#ffffff"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

}
