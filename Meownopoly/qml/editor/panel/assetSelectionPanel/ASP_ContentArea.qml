import QtQuick 2.15
import QtQuick.Controls 2.15
import "../editorBottomPanel"


EBP_Content {
    id: contentArea
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""

    property string selectedCategory: ""
    property string selectedType: ""

    property string selected
    property bool showEffectsPanel: true
    signal assetSelected(string category, string type, string id)
    signal categorieSelected()

    property alias visualEffectsPanel : effectsPanel
    signal effectChanged()

    // Main content (categories/assets)
    Item {
        id: mainContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: contentArea.showEffectsPanel ? effectsScrollView.left : parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: contentArea.showEffectsPanel ? 5 : 0


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
    
    // Visual Effects Panel in ScrollView
    ScrollView {
        id: effectsScrollView
        anchors.top: parent.top
        anchors.right: parent.right
        contentHeight: effectsPanel.height
        width: parent.width *0.42
        anchors.bottom: parent.bottom
        
        visible: root.showEffectsPanel
        
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
        
        VisualEffectsPanel {
            id: effectsPanel
            width: effectsScrollView.width - 20 // Account for scrollbar
            
            onEffectChanged: {
                // Optional: emit signal when effects change
                contentArea.effectChanged()
            }
        }
    }
    
}
