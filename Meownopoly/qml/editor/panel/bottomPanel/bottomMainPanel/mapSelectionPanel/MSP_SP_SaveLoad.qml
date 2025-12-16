import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import EditorBottomPanel 1.0
import Game
import MapFileManager
import MapTypes

Item {
    id: saveLoadView
    width: parent.width
    height: mapsContainer.height

    function refreshMapList(){
       mapsList.model = MapFileManager.getAvailableMaps()
    }

    Rectangle {
        id: mapsContainer
        width: parent.width
        height: headerSection.height + contentHeight + 20
        color: "#333333"
        radius: 6
        border.color: "#4A90E2"
        border.width: 1
        
        property int contentHeight: mapsList.visible ? Math.max(200, mapsList.contentHeight + 20) : 140

        // Header avec titre
        Rectangle {
            id: headerSection
            width: parent.width
            height: 40
            color: "#383838"
            radius: 6
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 10
                
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: "#4A90E2"
                    opacity: 0.2
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🗺️"
                        font.pixelSize: 16
                    }
                }
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Load a map"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        // Liste des maps
        ListView {
            id: mapsList
            anchors.top: headerSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            height: Math.max(200, contentHeight)
            model: []
            spacing: 5
            clip: true
            focus: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            visible: model.length > 0

            Component.onCompleted: {
                refreshMapList()
            }

            ScrollBar.vertical: ScrollBar {
                id: scrollBar
                active: mapsList.contentHeight > mapsList.height
                policy: ScrollBar.AsNeeded
                visible: mapsList.contentHeight > mapsList.height
                interactive: true
                anchors.rightMargin: 8
                anchors.topMargin: 5
                anchors.bottomMargin: 5

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: width / 2
                    color: "#999999"
                    opacity: scrollBar.pressed ? 0.8 : 0.5
                }
            }

            delegate: Button {
                width: mapsList.width - 20
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
                    font.pixelSize: 16
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    console.log("Selected map: " + modelData)
                    if (typeof logic !== 'undefined') {
                        logic.removeCurrentMap()
                        var normalizedMapName = MapFileManager.findMapFileByName(modelData)
                        if (normalizedMapName !== "") {
                            Game.loadMap(normalizedMapName, MapTypes.CUSTOM)
                        } else {
                            console.error("Could not find map file for: " + modelData)
                        }
                    } else {
                        console.error("La fonction loadMap n'est pas accessible")
                    }
                }
            }
        }
        
        // Message "Aucune carte enregistrée" quand la liste est vide
        Rectangle {
            id: emptyStateMessage
            anchors.top: headerSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.topMargin: 20
            height: 100
            visible: mapsList.model.length === 0
            
            color: "#3a3a3a"
            radius: 8
            border.color: "#555555"
            border.width: 1
            
            Column {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📂"
                    font.pixelSize: 32
                    opacity: 0.5
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Aucune carte enregistrée"
                    color: "#999999"
                    font.pixelSize: 14
                    font.italic: true
                }
            }
        }
    }
}

