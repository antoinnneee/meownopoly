import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../editorBottomPanel"


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
    property alias visualEffectsPanel : effectsPanel
    property alias effectLocked: effectsPanel.effectsLocked

    property bool blockEffectChangedSignal: false
    signal effectChanged()
    
    // Propriété pour gérer l'onglet actif (0=Visual Effects, 1=Transform)
    property int currentTabIndex: 0

    sidePanelRatio: 0.5
    function updateFromDisplayParameter(dispParam) {
        if (effectLocked){
            effectChanged()
        }
        else
        {
            blockEffectChangedSignal = true
            effectsPanel.updateFromDisplayParameter(dispParam)
            transformSection.updateFromDisplayParameter(dispParam)
            advancedEffectsSection.updateFromDisplayParameter(dispParam)
            blockEffectChangedSignal = false
        }
    }

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


    sidePanel: Item {
        anchors.fill: parent
        
        // StackLayout pour les contenus des onglets (contrôlé depuis MenuSelector)
        StackLayout {
            id: stackLayout
            anchors.fill: parent
            anchors.topMargin: -contentArea.titleHeight
            currentIndex: contentArea.currentTabIndex
            
            // Onglet Visual Effects Panel
            ScrollView {
                id: effectsScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                contentHeight: effectsPanelContainer.height
                clip: true
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                Item {
                    id: effectsPanelContainer
                    width: effectsScrollView.availableWidth
                    height: effectsPanel.height
                    
                    VisualEffectsPanel {
                        id: effectsPanel
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 16
                        
                        onEffectChanged: {
                            if (contentArea.blockEffectChangedSignal) {
                                return
                            }
                            contentArea.effectChanged()
                        }
                    }
                }
            }
            
            // Onglet Transform & Advanced
            ScrollView {
                id: transformScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                contentHeight: transformContainer.height
                clip: true
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                Item {
                    id: transformContainer
                    width: transformScrollView.availableWidth
                    height: secondarySection.height + 20
                    
                    Column {
                        id: secondarySection
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 16
                        spacing: 10
                        
                        // Transform Section
                        VEP_TransformSection {
                            id: transformSection
                            width: parent.width
                            
                            onEffectChanged: {
                                if (contentArea.blockEffectChangedSignal) {
                                    return
                                }
                                contentArea.effectChanged()
                            }
                        }
                        
                        // Advanced Effects Section
                        VEP_AdvancedEffectsSection {
                            id: advancedEffectsSection
                            width: parent.width
                            
                            onEffectChanged: {
                                if (contentArea.blockEffectChangedSignal) {
                                    return
                                }
                                contentArea.effectChanged()
                            }
                        }
                        
                        // Reset buttons panel
                        VEP_ResetButtonsPanel {
                            id: resetButtonsPanel
                            width: parent.width
                            
                            onEffectChanged: {
                                if (contentArea.blockEffectChangedSignal) {
                                    return
                                }
                                contentArea.effectChanged()
                            }
                        }
                    }
                }
            }
        }
    }
}

