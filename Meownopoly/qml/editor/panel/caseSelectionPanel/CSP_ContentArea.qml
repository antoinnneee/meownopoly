import QtQuick 2.15
import QtQuick.Controls 2.15
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
    
    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()
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
                console.log("Case type selected:", type, typeName)
                contentArea.caseTypeSelected(type, typeName)
            }
            
            onTypeCleared: function() {
                console.log("Case type cleared")
                contentArea.caseTypeCleared()
            }
        }
    }

    sidePanel: CaseConfigurationPanelSection{
        id: caseConfigurationPanelSection
        anchors.fill: parent
        anchors.topMargin: -contentArea.titleHeight
        
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
    function clearCaseSelection()
    {
        caseTypeSelector.clearCaseSelection()
    }
}
