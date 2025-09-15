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
    
    sidePanel: ScrollView {
        id: effectsScrollView
        anchors.top: parent.top
        anchors.right: parent.right
        contentHeight: effectsPanel.height
        anchors.bottom: parent.bottom
        width: parent.width

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

    // Visual Effects Panel in ScrollView
}

