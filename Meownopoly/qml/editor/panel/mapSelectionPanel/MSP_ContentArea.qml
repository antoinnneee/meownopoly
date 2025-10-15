import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts
import "../editorBottomPanel"

EBP_Content {
    id: contentArea

    property bool showEffectsPanel: true
    
    property string mapName: "New Map"
    property string mapVersion: "1.0"
    property string backgroundPath: ""
    
    property int titleHeight
    property int currentTabIndex: 0  // 0=General, 1=Load, 2=Background
    sidePanelRatio: 0.5

    signal effectChanged()

    // Synchroniser currentView avec currentTabIndex pour compatibilité
    onCurrentTabIndexChanged: {
        switch(currentTabIndex) {
            case 0: currentView = "general"; break;
            case 1: currentView = "saveLoad"; break;
            case 2: currentView = "background"; break;
        }
    }

    mainContent: Item {
        id: mainContentWrapper
        anchors.fill: parent
        
        // StackLayout pour afficher les différents panneaux en pleine largeur
        StackLayout {
            id: stackLayout
            anchors.fill: parent
            anchors.margins: 10
            currentIndex: contentArea.currentTabIndex
            
            // Onglet 0: General Parameters
            ScrollView {
                id: generalScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: generalParamsView.height
                contentWidth: availableWidth
                clip: true
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                MSP_SP_General {
                    id: generalParamsView
                    width: generalScrollView.availableWidth
                    
                    onNewMap: saveLoadView.refreshMapList()
                }
            }
            
            // Onglet 1: Save/Load Map
            ScrollView {
                id: saveLoadScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: saveLoadView.height
                contentWidth: availableWidth
                clip: true
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                MSP_SP_SaveLoad {
                    id: saveLoadView
                    width: saveLoadScrollView.availableWidth
                }
            }
            
            // Onglet 2: Background Settings
            ScrollView {
                id: backgroundScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: backgroundView.height
                contentWidth: availableWidth
                clip: true
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                MSP_SP_Background {
                    id: backgroundView
                    width: backgroundScrollView.availableWidth
                }
            }
        }
    }

    // Side panel - vide mais conserve la largeur pour cohérence avec les autres menus
    sidePanel: Item {
        anchors.fill: parent
        anchors.topMargin: -contentArea.titleHeight
        
        // Panel vide, juste pour maintenir la structure
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "transparent"
        }
    }
}
