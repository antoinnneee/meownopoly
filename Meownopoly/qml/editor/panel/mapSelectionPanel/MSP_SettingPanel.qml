import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts
import "../editorBottomPanel"

Item {
    id: contentContainer
    width: secondContent.width - 20 // Account for scrollbar
    
    // General parameters view
    Item {
        id: generalParamsView
        visible: contentArea.currentView === "general"
        width: parent.width
        height: generalLayout.height
        
        Column {
            id: generalLayout
            width: parent.width * 0.7
            spacing: 15
            padding: 10
            
            Text {
                text: "Map Settings"
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
            
            // Map name input
            Column {
                width: parent.width - parent.padding * 2
                spacing: 5
                
                Text {
                    text: "Map Name"
                    color: "#DDDDDD"
                    font.pixelSize: 14
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#2A2A2A"
                    border.color: "#444444"
                    border.width: 1
                    
                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 5
                        color: "#FFFFFF"
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
                width: parent.width - parent.padding * 2
                spacing: 5
                
                Text {
                    text: "Version"
                    color: "#DDDDDD"
                    font.pixelSize: 14
                }
                
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#2A2A2A"
                    border.color: "#444444"
                    border.width: 1
                    
                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 5
                        color: "#FFFFFF"
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
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
            
            // Save button
            Rectangle {
                width: parent.width - parent.padding * 2
                height: 40
                color: "#2A2A2A"
                border.color: "#4CAF50"
                border.width: 1
                radius: 5
                
                Text {
                    anchors.centerIn: parent
                    text: "Save Current Map"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Saving map:", contentArea.mapName, "v" + contentArea.mapVersion)
                    }
                }
            }
            
            // Load button
            Rectangle {
                width: parent.width - parent.padding * 2
                height: 40
                color: "#2A2A2A"
                border.color: "#2196F3"
                border.width: 1
                radius: 5
                
                Text {
                    anchors.centerIn: parent
                    text: "Load Map"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Open load map dialog")
                    }
                }
            }
            
            // New map button
            Rectangle {
                width: parent.width - parent.padding * 2
                height: 40
                color: "#2A2A2A"
                border.color: "#FFC107"
                border.width: 1
                radius: 5
                
                Text {
                    anchors.centerIn: parent
                    text: "Create New Map"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Creating new map")
                        contentArea.mapName = "New Map"
                        contentArea.mapVersion = "1.0"
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
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
            
            // Select background button
            Rectangle {
                width: parent.width - parent.padding * 2
                height: 40
                color: "#2A2A2A"
                border.color: "#E91E63"
                border.width: 1
                radius: 5
                
                Text {
                    anchors.centerIn: parent
                    text: "Select Image/GIF"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }
            }
            
            // Current background path
            Column {
                width: parent.width - parent.padding * 2
                spacing: 5
                visible: contentArea.backgroundPath !== ""
                
                Text {
                    text: "Selected File:"
                    color: "#DDDDDD"
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
                width: parent.width - parent.padding * 2
                spacing: 5
                visible: contentArea.backgroundPath !== ""
                
                Text {
                    text: "Image Scaling"
                    color: "#DDDDDD"
                    font.pixelSize: 14
                }
                
                ComboBox {
                    width: parent.width
                    height: 40
                    model: ["Stretch", "Preserve Aspect Ratio", "Preserve Aspect Fit", "Tile"]
                    
                    contentItem: Text {
                        text: parent.displayText
                        color: "#FFFFFF"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        leftPadding: 5
                    }
                    
                    background: Rectangle {
                        color: "#2A2A2A"
                        border.color: "#444444"
                        border.width: 1
                    }
                    
                    popup.background: Rectangle {
                        color: "#2A2A2A"
                        border.color: "#444444"
                        border.width: 1
                    }
                    
                    delegate: ItemDelegate {
                        width: parent.width
                        contentItem: Text {
                            text: modelData
                            color: "#FFFFFF"
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
