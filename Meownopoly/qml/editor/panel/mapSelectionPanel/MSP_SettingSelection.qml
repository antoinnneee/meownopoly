import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts
import "../editorBottomPanel"

Item {
    id: mainContent
    
    
    // Column layout for buttons
    Column {
        width: parent.width * 0.7
        height: parent.height
        anchors.margins: 10
        spacing: 15
        
        // General parameters button
        Rectangle {
            id: generalButton
            width: parent.width
            height: 50
            color: contentArea.currentView === "general" ? "#3F51B5" : "#1E1E1E"
            border.color: "#333333"
            border.width: 1
            radius: 5
            
            Text {
                anchors.centerIn: parent
                text: "General Parameters"
                color: "#FFFFFF"
                font.pixelSize: 16
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contentArea.currentView = "general"
                }
            }
        }
        
        // Save/Load button
        Rectangle {
            id: saveLoadButton
            width: parent.width
            height: 50
            color: contentArea.currentView === "saveLoad" ? "#3F51B5" : "#1E1E1E"
            border.color: "#333333"
            border.width: 1
            radius: 5
            
            Text {
                anchors.centerIn: parent
                text: "Save/Load Map"
                color: "#FFFFFF"
                font.pixelSize: 16
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contentArea.currentView = "saveLoad"
                }
            }
        }
        
        // Background modification button
        Rectangle {
            id: backgroundButton
            width: parent.width
            height: 50
            color: contentArea.currentView === "background" ? "#3F51B5" : "#1E1E1E"
            border.color: "#333333"
            border.width: 1
            radius: 5
            
            Text {
                anchors.centerIn: parent
                text: "Modify Background"
                color: "#FFFFFF"
                font.pixelSize: 16
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contentArea.currentView = "background"
                }
            }
        }
    }
}
