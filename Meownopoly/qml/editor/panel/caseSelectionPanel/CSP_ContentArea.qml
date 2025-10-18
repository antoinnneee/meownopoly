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
        
        // StackLayout pour les contenus des onglets (contrôlé depuis MenuSelector)
        StackLayout {
            id: stackLayout
            anchors.fill: parent
            anchors.topMargin: -contentArea.titleHeight
            currentIndex: contentArea.currentTabIndex
            
            // Onglet Configuration Case
            CaseConfigurationPanelSection {
                id: caseConfigurationPanelSection
                
                // Gérer le changement de type de case
                onRequestChangeType: function(newType) {
                    if (targetCase) {
                        console.log("Changing case type to:", newType)
                        //targetCase.type = newType
                        targetSnapableCase.snapableParameters.changeCaseDataType(newType)
                        // Mettre à jour les contrôles pour refléter le nouveau type
                        setTargetCase(targetSnapableCase)
                    }
                }
            }
            
            // Onglet Configuration Connexions
            ConnectionsConfigurationSection {
                id: connectionsConfigSection
                
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
