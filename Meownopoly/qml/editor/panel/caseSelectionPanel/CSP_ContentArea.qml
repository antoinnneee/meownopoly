import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager
import Game
import Case
import CaseRestArea
import "../assetSelectionPanel"
import "../"
import "../editorBottomPanel"

EBP_Content {
    id: root
    // Main content (categories/types)
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""

    property string selectedCategory: ""
    property string selectedType: ""

//    property string selected
    property bool showDetailsPanel: true
    signal caseSelected(string category, string type, string id)
    Item {
        id: mainContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: root.showDetailsPanel ? detailsPanel.left : parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.showDetailsPanel ? 10 : 0
        
        // Category grid view
        CSP_CategoryGrid {
            id: categoryGrid
            anchors.fill: parent
            anchors.topMargin: 6
            visible: root.currentView === "categories"
            searchText: root.searchText
            activeFilter: root.activeFilter
            
            onCategorySelected: function(category, title) {
                console.log("Category selected:", category, title);
                root.selectedCategory = category;
                root.selectedType = "all";
                root.currentView = "types";
            }
        }
        
        // Cases grid view
        Item {
            id: typesContainer
            anchors.fill: parent
            anchors.topMargin: 6
            visible: root.currentView === "types"
            
            // Title for the types view
            Text {
                id: typesTitle
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 30
                text: {
                    if (root.selectedCategory === "achetable")
                        return "Propriétés achetables";
                    else
                        return "Cases temporaires";
                }
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
            
            // Grid of cases
            CSP_Grid {
                id: casesGrid
                anchors.top: typesTitle.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 10
                
                categoryName: root.selectedCategory
                typeName: root.selectedType
                searchText: root.searchText
                
                // Get list of cases based on category
                caseList: {
                    if (root.selectedCategory === "proprietes") {
                        return Game.getPurchasableCases();
                    } else {
                        return Game.getTemporaryCases();
                    }
                }
                
                onCaseSelected: function(category, type, id) {
                    root.caseSelected(category, type, id);
                }
            }
        }
    }
    
    // Details Panel (right side)
    CSP_CaseConfigPanel {
        id: detailsPanel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width * 0.42
        visible: root.showDetailsPanel
        
        onConfigurationApplied: function(caseData) {
            console.log("Case configuration applied for:", caseData.name);
            // Here we would handle saving the configuration
        }
    }
}
