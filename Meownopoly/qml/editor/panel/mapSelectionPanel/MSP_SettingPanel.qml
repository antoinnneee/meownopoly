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
        property alias panelInfo : sidePanel
        onRefreshContentHeight: getContentHeight()
        Component.onCompleted: getContentHeight()
    }

    // Background modification view
    MSP_SP_Background {
        id: backgroundView
        property alias panelInfo : sidePanel
        Component.onCompleted: getContentHeight()
    }
}
