import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import EditorBottomPanel 1.0

import MapInfo

Rectangle {
    id: sidePanel
    width: sidePanelScroll.width - 20 // Account for scrollbar

    property string mapName
    property int mapVersion
    property string dateOfCreation
    property string dateOfLastModification
    property string description

    // Propriété pour stocker les hauteurs calculées
    property var viewHeights: ({
        "general": -1,
        "saveLoad": -1, 
        "background": -1
    })
    
    // Flag pour indiquer si la mesure initiale est complète
    property bool heightsMeasured: false

    color: "#2a2a2a"
    radius: 12
    border.color: "#444444"
    border.width: 1

    anchors.margins: 5

    // Hauteur calculée dynamiquement
    height: getContentHeight()
    
    // Fonction pour calculer la hauteur du panneau
    function getContentHeight() {
        var contentHeight = 0;
        
        // Utiliser les hauteurs mesurées si disponibles
        if (viewHeights[contentArea.currentView] > 0) {
            contentHeight = viewHeights[contentArea.currentView];
        } 
        // Sinon utiliser les hauteurs actuelles
        else {
            switch (contentArea.currentView) {
                case "general": contentHeight = generalParamsView.height; break;
                case "saveLoad": contentHeight = saveLoadView.height; break;
                case "background": contentHeight = backgroundView.height; break;
            }
        }
        
        return titleSection.height + contentHeight;
    }
    
    // Fonction pour mettre à jour la hauteur du panneau
    function updatePanelHeight() {
        height = getContentHeight();
    }
    
    // Mettre à jour la hauteur quand la vue change
    Connections {
        target: contentArea
        function onCurrentViewChanged() {
            // Déclencher une mise à jour des hauteurs
            measureCurrentView();
            Qt.callLater(updatePanelHeight);
        }
    }
    
    // Mesurer la vue actuelle et mettre à jour sa hauteur
    function measureCurrentView() {
        switch (contentArea.currentView) {
            case "general": 
                if (generalParamsView.visible && generalParamsView.height > 0) {
                    viewHeights.general = generalParamsView.height;
                }
                break;
            case "saveLoad": 
                if (saveLoadView.visible && saveLoadView.height > 0) {
                    viewHeights.saveLoad = saveLoadView.height;
                }
                break;
            case "background": 
                if (backgroundView.visible && backgroundView.height > 0) {
                    viewHeights.background = backgroundView.height;
                }
                break;
        }
    }

    onVisibleChanged: {
        if (visible) {
            measureCurrentView();
            Qt.callLater(updatePanelHeight);
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
        property alias panelInfo: sidePanel
        
        // Écouter les changements de hauteur
        onHeightChanged: {
            if (visible && height > 0) {
                viewHeights.general = height;
                if (contentArea.currentView === "general") {
                    updatePanelHeight();
                }
            }
        }
        
        onNewMap: saveLoadView.refreshMapList()
    }

    // Save/Load map view
    MSP_SP_SaveLoad {
        id: saveLoadView
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "red"
        }
        property alias panelInfo: sidePanel
        
        // Écouter les changements de hauteur
        onHeightChanged: {
            if (visible && height > 0) {
                viewHeights.saveLoad = height;
                if (contentArea.currentView === "saveLoad") {
                    updatePanelHeight();
                }
            }
        }
    }

    // Background modification view
    MSP_SP_Background {
        id: backgroundView
        property alias panelInfo: sidePanel
        
        // Écouter les changements de hauteur
        onHeightChanged: {
            if (visible && height > 0) {
                viewHeights.background = height;
                if (contentArea.currentView === "background") {
                    updatePanelHeight();
                }
            }
        }
    }
}
