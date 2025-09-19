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
    height: saveLoadLayout.height
    anchors.top: titleSection.bottom

    // Propriété pour gérer les vues
    property string currentView: "buttons"
    
    // Signal pour notifier que la hauteur du contenu a changé
    signal refreshContentHeight()
    
    // Signal émis quand la liste des maps est chargée
    signal mapsLoaded()
    
    // Fonction pour calculer la hauteur totale
    function updateHeight() {
        // Force layout update
        saveLoadLayout.height = saveLoadLayout.implicitHeight
        // Notify parent to update its height
        refreshContentHeight()
    }

    // Mettre à jour quand la vue change
    onCurrentViewChanged: {
        Qt.callLater(updateHeight)
    }

    Column {
        id: saveLoadLayout
        width: parent.width
        spacing: 10
        padding: 5
        
        Text {
            text: "Save/Load Options"
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }
        
        // Controls container - Boutons principaux
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
                        mapsList.maps = MapLoader.getAvailableMaps()
                        saveLoadView.currentView = "availableMaps"
                        // Notify that maps are loaded
                        saveLoadView.mapsLoaded()
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
        
        // Container pour la liste des maps disponibles
        Rectangle {
            id: mapsContainer
            width: parent.width - parent.padding * 2
            color: "#333333"
            radius: 6
            border.color: "#4A90E2"
            border.width: 1
            visible: saveLoadView.currentView === "availableMaps"
            height: mapsList.visible ? mapsList.height + headerSection.height + 20 : 0
            
            // Header avec bouton retour
            Rectangle {
                id: headerSection
                width: parent.width
                height: 40
                color: "#383838"
                radius: 4
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                
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
            
            // Liste des maps avec support de défilement amélioré
            ListView {
                id: mapsList
                anchors.top: headerSection.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 20
                height: Math.min(300, contentHeight) // Limite la hauteur max à 300px
                model: []
                spacing: 5
                clip: true
                focus: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                
                // Défilement par molette de souris géré via un WheelHandler
                WheelHandler {
                    id: wheelHandler
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property: "contentY"
                    orientation: Qt.Vertical
                    target: mapsList
                    
                    onWheel: {
                        // Empêcher la propagation au parent
                        event.accepted = true
                    }
                }
                
                property var maps: []
                onMapsChanged: {
                    model = maps
                    // Déclencher la mise à jour de hauteur après le chargement du modèle
                    Qt.callLater(saveLoadView.updateHeight)
                    // Réinitialiser la position de défilement
                    contentY = 0
                    // Donner le focus à la liste
                    forceActiveFocus()
                }
                
                // S'assurer que la liste prend le focus quand elle devient visible
                onVisibleChanged: {
                    if (visible) {
                        forceActiveFocus()
                    }
                }
                
                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    active: mapsList.contentHeight > mapsList.height
                    policy: ScrollBar.AlwaysOn
                    visible: mapsList.contentHeight > mapsList.height
                    interactive: true
                    
                    contentItem: Rectangle {
                        implicitWidth: 8
                        radius: width / 2
                        color: "#999999"
                        opacity: scrollBar.pressed ? 0.8 : 0.5
                    }
                }
                
                delegate: Button {
                    width: mapsList.width
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
