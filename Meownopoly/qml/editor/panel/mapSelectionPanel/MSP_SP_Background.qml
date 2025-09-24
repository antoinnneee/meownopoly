import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"
import "."

import MapInfo

Item {
    id: backgroundView
    visible: contentArea.currentView === "background"
    width: parent.width
    height: backgroundLayout.height
    anchors.top: titleSection.bottom

    // property alias panelInfo : sidePanel

    Column {
        id: backgroundLayout
        width: parent.width
        spacing: 10 // réduit l'espacement
        padding: 5 // réduit le padding
        
        // Header avec titre, format standard
        Rectangle {
            width: parent.width - parent.padding * 2
            height: 40
            color: "#383838"
            radius: 6
            
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 10
                
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: "#E91E63"
                    opacity: 0.2
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🖼️"
                        font.pixelSize: 16
                    }
                }
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Background Settings"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
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
                
                // Background selector
                MSP_SP_BackgroundSelector {
                    width: parent.width
                    imagePath: backgroundPath
                    
                    onImageSelected: function(path) {
                        backgroundPath = path;
                        console.log("Background image selected:", path);
                    }
                    
                    onScalingModeSelected: function(mode) {
                        console.log("Scaling mode changed:", mode);
                        // Mettre à jour le mode de mise à l'échelle
                        if (mode === "stretch") {
                            // Code pour le mode Stretch
                        } else if (mode === "fit") {
                            // Code pour le mode Fit
                        } else if (mode === "repeat") {
                            // Code pour le mode Repeat
                        }
                    }
                    
                    onImageRemoved: {
                        contentArea.backgroundPath = "";
                        console.log("Background image removed");
                    }
                }
            }
        }
    }
}
