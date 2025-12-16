import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts
import EditorBottomPanel 1.0

Item {
    id: mainContent
    
    
    // Row layout for buttons
    Row {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.8
        anchors.margins: 10
        spacing: 20
        layoutDirection: Qt.LeftToRight
        
        // General parameters button
        Rectangle {
            id: generalButton
            width: 160
            height: 160
            color: contentArea.currentView === "general" ? "#3F51B5" : "#1E1E1E"
            border.color: "#333333"
            border.width: 1
            radius: 8
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🗺️"
                    font.pixelSize: 60
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "General Parameters"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contentArea.currentView = "general"
                }
                hoverEnabled: true
                onEntered: parent.opacity = 0.8
                onExited: parent.opacity = 1.0
            }
        }
        
        // Save/Load button
        Rectangle {
            id: saveLoadButton
            width: 160
            height: 160
            color: contentArea.currentView === "saveLoad" ? "#3F51B5" : "#1E1E1E"
            border.color: "#333333"
            border.width: 1
            radius: 8
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "💾"
                    font.pixelSize: 60
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Save/Load Map"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contentArea.currentView = "saveLoad"
                }
                hoverEnabled: true
                onEntered: parent.opacity = 0.8
                onExited: parent.opacity = 1.0
            }
        }
        
        // Background modification button
        Rectangle {
            id: backgroundButton
            width: 160
            height: 160
            color: contentArea.currentView === "background" ? "#3F51B5" : "#1E1E1E"
            border.color: "#333333"
            border.width: 1
            radius: 8
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🖼️"
                    font.pixelSize: 60
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Modify Background"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    contentArea.currentView = "background"
                }
                hoverEnabled: true
                onEntered: parent.opacity = 0.8
                onExited: parent.opacity = 1.0
            }
        }
    }
}
