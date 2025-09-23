import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EditorBottomPanel {
    id: root

    property alias activeFilter: titleBar.activeFilter
    property int selectedCaseType: -1
    property string selectedCaseTypeName: ""
    property string currentView: "categories"
    property string searchText: ""
//    isExpanded: true

    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()

    // Title bar
     titleBar: CSP_TitleBar {
         id: titleBar
         activeFilter: "All"
         anchors.left: parent.left
         anchors.right: parent.horizontalCenter
         anchors.top: parent.top
         isExpanded: true

         onCaseSelected: function(category, type, id) {
             console.log("titleBar select asset", category, type, id)
             root.assetSelected(category, type, id)
         }
         onSearchTextChanged: {
             // console.log("EditorBottomPanel - searchText filter changed", searchText)
             root.searchText = searchText
             root.searchText = Qt.binding(function(){ return root.searchText})
         }

         onCurrentViewChanged:  {
             root.currentView = titleBar.currentView
         }

         onBackButtonClicked: {
             root.currentView = "categories"
         }
         onButtonClicked: function(text, index)  {
             titleBar.activeFilter = text
             root.currentView = "categories"
         }

         searchText: root.searchText
         currentView: root.currentView

    }

    // Content area (visible only when expanded)
     contentArea: CSP_ContentArea {
            id: contentArea
            visible: true
            anchors.fill: parent
            currentView: root.currentView
            activeFilter: titleBar.activeFilter
            searchText: root.searchText
            isExpanded: true
            
            onCaseTypeSelected: function(type, typeName) {
                console.log("CaseSelectionPanel - case type selected:", type, typeName)
                root.selectedCaseType = type
                root.selectedCaseTypeName = typeName
                root.caseTypeSelected(type, typeName)
            }
            
            onCaseTypeCleared: function() {
                console.log("CaseSelectionPanel - case type cleared")
                root.selectedCaseType = -1
                root.selectedCaseTypeName = ""
                root.caseTypeCleared()
            }
    }

    // Fonction pour obtenir le type de case sélectionné
    function getSelectedCaseType() {
        return root.selectedCaseType
    }
    
    // Fonction pour obtenir le nom du type de case sélectionné
    function getSelectedCaseTypeName() {
        return root.selectedCaseTypeName
    }
    
    // Fonction pour effacer la sélection
    function clearSelection() {
        contentArea.clearCaseSelection()
    }
}
