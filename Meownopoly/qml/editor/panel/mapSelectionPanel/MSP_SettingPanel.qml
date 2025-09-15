import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

Rectangle {
    id: contentContainer
    width: secondContent.width - 20 // Account for scrollbar
    height: Math.max(generalParamsView.height, saveLoadView.height, backgroundView.height) + 20 // Add padding
    
    // Visual properties
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1
    
    // Add internal margins
    anchors.margins: 10
    
    // General parameters view
    Item {
        id: generalParamsView
        visible: contentArea.currentView === "general"
        width: parent.width
        height: generalLayout.height
        
        Column {
            id: generalLayout
            width: parent.width
            spacing: 15
            padding: 10
            
            Text {
                text: "Map Settings"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
            
            // Controls container
            Rectangle {
                width: parent.width - parent.padding * 2
                color: "#333333"
                radius: 6
                border.color: "#444444"
                border.width: 1
                height: controlsColumn.height + 20
                
                Column {
                    id: controlsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15
                
                    // Map name input
                    Column {
                        width: parent.width
                        spacing: 5
                
                Text {
                    text: "Map Name"
                    color: "#999999"
                    font.pixelSize: 14
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "transparent"
                    border.color: "#4A90E2"
                    border.width: 1
                    radius: 4
                    
                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 5
                        color: "white"
                        font.pixelSize: 14
                        text: contentArea.mapName
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        
                        onTextChanged: {
                            contentArea.mapName = text
                        }
                    }
                }
            }
            
            // Map version input
            Column {
                width: parent.width
                spacing: 5
                
                Text {
                    text: "Version"
                    color: "#999999"
                    font.pixelSize: 14
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "transparent"
                    border.color: "#4A90E2"
                    border.width: 1
                    radius: 4
                    
                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 5
                        color: "white"
                        font.pixelSize: 14
                        text: contentArea.mapVersion
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        
                        onTextChanged: {
                            contentArea.mapVersion = text
                        }
                    }
                    }
                    }
                }
            }
        }
    }
    
    // Save/Load map view
    Item {
        id: saveLoadView
        visible: contentArea.currentView === "saveLoad"
        width: parent.width
        height: saveLoadLayout.height
        
        Column {
            id: saveLoadLayout
            width: parent.width
            spacing: 15
            padding: 10
            
            Text {
                text: "Save/Load Options"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
            
            // Controls container
            Rectangle {
                width: parent.width - parent.padding * 2
                color: "#333333"
                radius: 6
                border.color: "#444444"
                border.width: 1
                height: buttonsColumn.height + 20
                
                Column {
                    id: buttonsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15
                
                    // Save button
                    Button {
                        width: parent.width
                        height: 40
                        flat: true
                
                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#4CAF50"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Text {
                    text: "Save Current Map"
                    color: "#4CAF50"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
                
                onClicked: {
                    console.log("Saving map:", contentArea.mapName, "v" + contentArea.mapVersion)
                }
            }
            
            // Load button
            Button {
                width: parent.width
                height: 40
                flat: true
                
                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#4A90E2"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Text {
                    text: "Load Map"
                    color: "#4A90E2"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
                
                onClicked: {
                    console.log("Open load map dialog")
                }
            }
            
            // New map button
            Button {
                width: parent.width
                height: 40
                flat: true
                
                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#FFC107"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Text {
                    text: "Create New Map"
                    color: "#FFC107"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
                
                onClicked: {
                    console.log("Creating new map")
                    contentArea.mapName = "New Map"
                    contentArea.mapVersion = "1.0"
                    }
                    }
                }
            }
        }
    }
    
    // Background modification view
    Item {
        id: backgroundView
        visible: contentArea.currentView === "background"
        width: parent.width
        height: backgroundLayout.height
        
        Column {
            id: backgroundLayout
            width: parent.width
            spacing: 15
            padding: 10
            
            Text {
                text: "Background Settings"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
            
            // Controls container
            Rectangle {
                width: parent.width - parent.padding * 2
                color: "#333333"
                radius: 6
                border.color: "#444444"
                border.width: 1
                height: bgControlsColumn.height + 20
                
                Column {
                    id: bgControlsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15
                
                    // Select background button
                    Button {
                        width: parent.width
                        height: 40
                        flat: true
                
                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#E91E63"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: Text {
                    text: "Select Image/GIF"
                    color: "#E91E63"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
                
                onClicked: {
                }
            }
            
            // Current background path
            Column {
                width: parent.width
                spacing: 5
                visible: contentArea.backgroundPath !== ""
                
                Text {
                    text: "Selected File:"
                    color: "#999999"
                    font.pixelSize: 14
                }
                
                Text {
                    text: contentArea.backgroundPath
                    color: "#4CAF50"
                    font.pixelSize: 12
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideMiddle
                }
            }
            
            // Image scaling options
            Column {
                width: parent.width
                spacing: 5
                visible: contentArea.backgroundPath !== ""
                
                Text {
                    text: "Image Scaling"
                    color: "#999999"
                    font.pixelSize: 14
                }
                
                ComboBox {
                    width: parent.width
                    height: 40
                    model: ["Stretch", "Preserve Aspect Ratio", "Preserve Aspect Fit", "Tile"]
                    
                    contentItem: Text {
                        text: parent.displayText
                        color: "white"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        leftPadding: 5
                    }
                    
                    background: Rectangle {
                        color: "transparent"
                        border.color: "#4A90E2"
                        border.width: 1
                        radius: 4
                    }
                    
                    popup.background: Rectangle {
                        color: "#222222"
                        border.color: "#4A90E2"
                        border.width: 1
                        radius: 4
                    }
                    
                    delegate: ItemDelegate {
                        width: parent.width
                        contentItem: Text {
                            text: modelData
                            color: "white"
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        highlighted: parent.highlightedIndex === index
                    }
                    
                    onActivated: {
                        console.log("Selected scaling mode:", model[index])
                    }
                    }
                    }
                }
            }
        }
    }
}
