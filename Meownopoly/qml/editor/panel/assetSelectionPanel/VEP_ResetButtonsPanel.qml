import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    // Visual properties
    color: "transparent"
    
    // Dimensions
    height: resetButtonsLayout.implicitHeight
    width: resetButtonsLayout.implicitWidth
    
    // Signals
    signal effectChanged()
    signal resetColorEffects()
    signal resetAllEffects()
    signal resetAllTransforms()
    
    // Reset buttons layout
    Column {
        id: resetButtonsLayout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 5
        
        // First row - Effects
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 5
            
            Button {
                text: "Reset Color Effects"
                Layout.fillWidth: true
                
                onClicked: {
                        root.resetColorEffects()
                        root.effectChanged()
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
                        root.resetAllEffects()
                        root.effectChanged()
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
        
        // Second row - Transforms
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 5
            
            Button {
                text: "Reset Transforms"
                Layout.fillWidth: true
                
                onClicked: {
                        root.resetAllTransforms()
                        root.effectChanged()
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
                text: "Reset Everything"
                Layout.fillWidth: true
                
                onClicked: {
                        root.resetAllEffects()
                        root.resetAllTransforms()
                        root.effectChanged()
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

}
