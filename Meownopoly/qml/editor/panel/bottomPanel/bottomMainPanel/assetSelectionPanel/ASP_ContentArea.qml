import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import editorBottomPanel
import visualEffectPanel


EBP_Content {
    id: contentArea
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""

    property string selectedCategory: ""
    property string selectedType: ""

    property string selected
    signal assetSelected(string category, string type, string id)
    signal categorieSelected()

    property int titleHeight
    
    // Propriété pour gérer l'onglet actif (0=Visual Effects, 1=Transform)
    property int currentTabIndex: 0

    sidePanelRatio: /*0.5*/ 0


    mainContent: Item {
        id: mainContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.rightMargin: 5
        width: parent.width


        // Category grid
        ASP_CategoryGrid {
            id: categoryGrid
            anchors.fill: parent
            anchors.topMargin: 6
            visible: contentArea.currentView === "categories"
            activeFilter: contentArea.activeFilter
            searchText: contentArea.searchText
            
            onCategorySelected: function(category, type) {
                contentArea.selectedCategory = category
                contentArea.selectedType = type
                categorieSelected()
            }
        }
        
        // Asset grid
        ASP_Grid {
            id: assetGrid
            anchors.fill: parent
            anchors.topMargin: 6
            visible: contentArea.currentView === "assets"
            category: contentArea.selectedCategory
            type: contentArea.selectedType
            searchText: contentArea.searchText
            
            // Pass selection state
            currentSelectedCategory: contentArea.currentSelectedCategory
            currentSelectedType: contentArea.currentSelectedType
            currentSelectedId: contentArea.currentSelectedId
            
            onAssetSelected: function(id) {
                contentArea.assetSelected(contentArea.selectedCategory, contentArea.selectedType, id)
            }
        }
    }

}

