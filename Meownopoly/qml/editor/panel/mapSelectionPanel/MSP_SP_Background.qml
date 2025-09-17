import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

import MapInfo

Item {
    id: backgroundView
    visible: contentArea.currentView === "background"
    width: parent.width
    height: backgroundLayout.height
    anchors.top: titleSection.bottom
    
    Column {
        id: backgroundLayout
        width: parent.width
        spacing: 10 // réduit l'espacement
        padding: 5 // réduit le padding
        
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
