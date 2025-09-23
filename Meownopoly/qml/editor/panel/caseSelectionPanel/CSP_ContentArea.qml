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
    
    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()

    // Main content (categories/assets)
    Item {
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
    function clearCaseSelection()
    {
        caseTypeSelector.clearCaseSelection()
    }
}
