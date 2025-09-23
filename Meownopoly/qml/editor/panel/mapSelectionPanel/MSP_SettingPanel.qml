import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

import MapInfo

Rectangle {
    id: sidePanel
    width: sidePanelScroll.width - 20 // Account for scrollbar

    property string mapName
    property int mapVersion
    property string backgroundPath: ""
    property string backgroundScaling: "Stretch"
    property string dateOfCreation
    property string dateOfLastModification
    property string description

    color: "#2a2a2a"
    radius: 12
    border.color: "#444444"
    border.width: 1

    anchors.margins: 5

    height : getContentHeight()
    function getContentHeight() {
        // Calculer précisément la hauteur en fonction de la vue active
        var contentHeight = 0;
        switch (contentArea.currentView) {
        case "general": contentHeight = generalParamsView.height; break;
        case "saveLoad": contentHeight = saveLoadView.height; break;
        case "background": contentHeight = backgroundView.height; break;
        }

        // Utiliser la hauteur exacte sans padding supplémentaire
        return titleSection.height + contentHeight;
    }


    // Mettre à jour la hauteur quand la vue change
    Connections {
        target: contentArea
        function onCurrentViewChanged() {
            Qt.callLater(function() {
                sidePanel.height = getContentHeight();
            });
        }
    }
    
    // Connections pour écouter les changements de hauteur de saveLoadView
    Connections {
        target: saveLoadView
        function onRefreshContentHeight() {
            Qt.callLater(function() {
                sidePanel.height = getContentHeight();
            });
        }
        
        function onMapsLoaded() {
            Qt.callLater(function() {
                sidePanel.height = getContentHeight();
            });
        }
    }

    // Mettre à jour également quand le panneau devient visible
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                sidePanel.height = getContentHeight();
            });
        }
    }

    Item {
        id: titleSection
        width: parent.width
        height: 70
        z: 10

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#2a2a2a"
            radius: 8
            border.color: "#555555"
            border.width: 1

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#333333" }
                GradientStop { position: 1.0; color: "#2a2a2a" }
            }

            Row {
                anchors.centerIn: parent
                spacing: 15

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: "#4A90E2"
                    opacity: 0.3

                    Text {
                        anchors.centerIn: parent
                        text: "✏️"
                        font.pixelSize: 18
                    }
                }

                Text {
                    text: "Map Settings"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // General parameters view
    MSP_SP_General {
        id: generalParamsView
        property alias panelInfo : sidePanel
        Component.onCompleted: getContentHeight()
    }

    // Save/Load map view
    MSP_SP_SaveLoad {
        id: saveLoadView
        visible: contentArea.currentView === "saveLoad"
        width: parent.width
        height: saveLoadLayout.height
        anchors.top: titleSection.bottom

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
                                mapInfo.mapName = contentArea.mapName
                                mapInfo.version = contentArea.mapVersion

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
    MSP_SP_Background {
        id: backgroundView
        property alias panelInfo : sidePanel
        Component.onCompleted: getContentHeight()
    }
}
