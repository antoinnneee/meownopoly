import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import editorBottomPanel
import assetSelectionPanel
import caseConfigPanel
import caseSelectionPanelMain

EBP_Content {
    id: contentArea
    
    // Propriétés requises par EBP_Content
    currentView: "categories"
    activeFilter: "All"
    
    // Propriétés supplémentaires
    searchText: ""
    height: isExpanded ? expandedHeight : collapsedHeight // Hauteur explicite

    property var logic: null  // Référence au logic pour sauvegarder
    
    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()
    sidePanelRatio: /*0.5*/ 0

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

    function clearCaseSelection()
    {
        caseTypeSelector.clearCaseSelection()
    }
}
