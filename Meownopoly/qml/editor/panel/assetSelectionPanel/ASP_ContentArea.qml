import QtQuick
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

    property int titleHeight
    property alias visualEffectsPanel : effectsPanel
    signal effectChanged()

    sidePanelRatio: 0.5

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
        anchors.topMargin: -contentArea.titleHeight
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: effectsPanel.height

        visible: root.showEffectsPanel

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        VisualEffectsPanel {
            id: effectsPanel
            anchors.left: parent.left
            anchors.right: secondarySection.left
            anchors.leftMargin: 0
            anchors.rightMargin: 6 // Account for scrollbar

            onEffectChanged: {
                // Optional: emit signal when effects change
                contentArea.effectChanged()
            }
        }

        // Main layout
        Column {
            id: secondarySection
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 20
            anchors.topMargin: 0
            width: parent.width/2
            // // Transform Section
            VEP_TransformSection {
                id: transformSection
                anchors.right: parent.right
                anchors.left: parent.left

                onEffectChanged: {
//                    root.effectChanged()
                    contentArea.effectChanged()
                }
            }
            // Advanced Effects Section
            VEP_AdvancedEffectsSection {
                id: advancedEffectsSection
                anchors.left: parent.left
                anchors.right: parent.right

                onEffectChanged: {
                    contentArea.effectChanged()
                }
            }
            // Reset buttons panel
            VEP_ResetButtonsPanel {
                id: resetButtonsPanel

                anchors.left: parent.left
                anchors.right: parent.right

                onEffectChanged: {
                    contentArea.effectChanged()
                }
            }
        }
    }

    // Visual Effects Panel in ScrollView
}

