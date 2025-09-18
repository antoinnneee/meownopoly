import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

import MapInfo
import MapLoader

Item {
    id: saveLoadView
    visible: contentArea.currentView === "saveLoad"
    width: parent.width
    height: currentView === "buttons" ? saveLoadLayout.height : availableMapsView.height
    anchors.top: titleSection.bottom

    // property alias panelInfo : sidePanel

    // Propriété pour gérer les vues
    property string currentView: "buttons"
    
    Column {
        id: saveLoadLayout
        width: parent.width
        spacing: 10 // réduit l'espacement
        padding: 5 // réduit le padding
        
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
            visible: saveLoadView.currentView === "buttons"
            
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
                        if (typeof logic !== 'undefined' && typeof logic.saveMap === 'function') {
                            var mapInfo = logic.mapInfo
                            mapInfo.mapName = mapName
                            mapInfo.version = mapVersion
                            mapInfo.mapDescription = description
                            mapInfo.mapCreationDate = dateOfCreation
                            mapInfo.mapLastModified = dateOfLastModification

                            logic.saveMap()
                        } else {
                            console.error("La fonction saveMap n'est pas accessible. Vérifiez que la variable 'logic' est définie.")
                        }
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
                        console.log("Loading available maps")
                        availableMapsView.maps = MapLoader.getAvailableMaps()
                        saveLoadView.currentView = "availableMaps"
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
    
    // Vue des cartes disponibles
    Item {
        id: availableMapsView
        visible: saveLoadView.currentView === "availableMaps"
        width: parent.width
        height: mapsContainer.height + 20
        
        property var maps: []
        
        Column {
            id: availableMapsColumn
            width: parent.width
            spacing: 10
            padding: 5
            
            
            // Container pour les cartes
            Rectangle {
                id: mapsContainer
                width: parent.width - parent.padding * 2
                height: mapsContentColumn.height + 20
                color: "#333333"
                radius: 6
                border.color: "#4A90E2"
                border.width: 1
                
                Column {
                    id: mapsContentColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15
                    
                    // Header avec bouton retour
                    Rectangle {
                        width: parent.width
                        height: 40
                        color: "#383838"
                        radius: 4
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 10
                            
                            Button {
                                width: 30
                                height: 30
                                flat: true
                                
                                contentItem: Text {
                                    text: "←"
                                    color: "#4A90E2"
                                    font.pixelSize: 16
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    saveLoadView.currentView = "buttons"
                                }
                            }
                            
                            Text {
                                text: "Select a Map"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    
                    // Liste des cartes
                    ListView {
                        width: parent.width
                        height: Math.min(300, contentHeight)
                        model: availableMapsView.maps
                        spacing: 5
                        clip: true
                        
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AlwaysOn
                        }
                        
                        delegate: Button {
                            width: parent.width
                            height: 40
                            
                            background: Rectangle {
                                anchors.fill: parent
                                color: "#444444"
                                radius: 4
                                border.color: "#4A90E2"
                                border.width: 1
                            }
                            
                            contentItem: Text {
                                text: modelData
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                console.log("Selected map: " + modelData)
                                if (typeof logic !== 'undefined') {
                                    MapLoader.loadMap(modelData)
                                    saveLoadView.currentView = "buttons"
                                } else {
                                    console.error("La fonction loadMap n'est pas accessible")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
