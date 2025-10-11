import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../editorBottomPanel"
import "../assetSelectionPanel"

EBP_Content {
    id: contentArea
    
    // Propriétés requises par EBP_Content
    currentView: "categories"
    activeFilter: "All"
    
    // Propriétés supplémentaires
    searchText: ""
    isExpanded: true
    property alias caseConfigurationPanelSection: caseConfigurationPanelSection  // Exposer pour l'accès externe
    property alias connectionsConfigSection: connectionsConfigSection  // Exposer pour l'accès externe
    
    // Propriétés pour les onglets
    property int currentTabIndex: 0  // 0=Case, 1=Connexions
    
    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()
    signal connectionRequested(string kind)  // Propager les demandes de connexion
    sidePanelRatio: 0.5

    property int titleHeight
    // Main content (categories/assets)
    mainContent: Item {
        id: mainContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        // Sélecteur de types de cases
        CSP_CaseTypeSelector {
            id: caseTypeSelector
            anchors.fill: parent
            currentView: contentArea.currentView
            activeFilter: contentArea.activeFilter
            
            onTypeSelected: function(type, typeName) {
                contentArea.caseTypeSelected(type, typeName)
            }
            
            onTypeCleared: function() {
                contentArea.caseTypeCleared()
            }
        }
    }

    sidePanel: Item {
        anchors.fill: parent
        
        // TabBar pour basculer entre les onglets
        TabBar {
            id: tabBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.leftMargin: 10
            anchors.topMargin: -contentArea.titleHeight
            height: Screen.pixelDensity * 12
            currentIndex: contentArea.currentTabIndex


            background: Rectangle {
                color: "#2a2a2a"
                border.color: "#444444"
                border.width: 1
                radius: 10
                visible: false
            }
            
            onCurrentIndexChanged: {
                contentArea.currentTabIndex = currentIndex
            }
            
            TabButton {
                text: "⚙️ Case"
                display: AbstractButton.TextOnly
                
                contentItem: Text {
                    text: parent.text
                    color: parent.checked ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter

                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: parent.checked ? "#4a90e2" : "#333333"
                    border.color: parent.checked ? "#5a9fe8" : "#444444"
                    border.width: 1
                    radius: 10
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }
            
            TabButton {
                text: "🔗 Connexions"
                
                contentItem: Text {
                    text: parent.text
                    color: parent.checked ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                background: Rectangle {
                    color: parent.checked ? "#4a90e2" : "#333333"
                    border.color: parent.checked ? "#5a9fe8" : "#444444"
                    border.width: 1
                    radius: 10
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }
        }
        
        // StackLayout pour les contenus des onglets
        StackLayout {
            id: stackLayout
            anchors.top: tabBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 5
            currentIndex: contentArea.currentTabIndex
            
            // Onglet Configuration Case
            CaseConfigurationPanelSection {
                id: caseConfigurationPanelSection
                anchors.fill: parent
                
                // Gérer le changement de type de case
                onRequestChangeType: function(newType) {
                    if (targetCase) {
                        console.log("Changing case type to:", newType)
                        targetCase.type = newType
                        // Mettre à jour les contrôles pour refléter le nouveau type
                        updateControls()
                    }
                }
            }
            
            // Onglet Configuration Connexions
            ConnectionsConfigurationSection {
                id: connectionsConfigSection
                anchors.fill: parent
                
                onRequestAddConnection: function(kind) {
                    contentArea.connectionRequested(kind)
                }
            }
        }
    }
    function clearCaseSelection()
    {
        caseTypeSelector.clearCaseSelection()
    }
}
