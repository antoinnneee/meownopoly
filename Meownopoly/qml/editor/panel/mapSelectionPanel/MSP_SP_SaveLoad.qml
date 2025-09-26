import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

import MapLoader

Item {
    id: saveLoadView
    visible: contentArea.currentView === "saveLoad"
    width: parent.width
    height: 250
    anchors.top: titleSection.bottom

    function refreshMapList(){
       mapsList.model = MapLoader.getAvailableMaps()
    }

    Rectangle {
        id: mapsContainer
        anchors.fill: parent
        color: "#333333"
        radius: 6
        border.color: "#4A90E2"
        border.width: 1

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
            anchors.bottom: parent.bottom
            anchors.margins: 10
            model: []
            spacing: 5
            clip: true
            focus: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            Component.onCompleted: {
                refreshMapList()
            }

            ScrollBar.vertical: ScrollBar {
                id: scrollBar
                active: mapsList.contentHeight > mapsList.height
                policy: ScrollBar.AsNeeded
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
                        logic.removeCurrentMap()
                        MapLoader.loadMap(modelData)
                    } else {
                        console.error("La fonction loadMap n'est pas accessible")
                    }
                }
            }
        }
    }
}
