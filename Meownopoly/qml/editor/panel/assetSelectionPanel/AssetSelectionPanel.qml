import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"

Rectangle {
    id: root
    
    // Properties
    property bool isExpanded: true
    property string currentView: "categories" // "categories" or "assets"
    property string selectedCategory: ""
    property string selectedType: ""
    property string searchText: ""
    property string activeFilter: "All" // "All", "Decoration", "Characters"
    
    required property var logic
    
    // Current selection state (from parent)
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    property bool isAssetSelected: currentSelectedCategory !== "" && currentSelectedType !== "" && currentSelectedId !== ""

    // Selected decoration element for effects
    property var selectedDecoration: null
    property bool showEffectsPanel: true//selectedDecoration !== null && selectedDecoration.type === 2 // DecorationTile
    
    // Signals
    signal assetSelected(string category, string type, string id)
    width: 450
    signal selectionModeChanged(bool isActive)


    onAssetSelected: function(category, type, id) {
        if (root.isAssetSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
            clearAssetSelection();
            return
        }
        console.log("Asset selected for placement:", category, type, id)
        root.currentSelectedCategory = category
        root.currentSelectedType = type
        root.currentSelectedId = id
    }

    // Function to clear asset selection
    function clearAssetSelection() {
        console.log("Clearing asset selection")
        root.currentSelectedCategory = ""
        root.currentSelectedType = ""
        root.currentSelectedId = ""
    }

    // Dimensions
    readonly property int collapsedHeight: 0
    readonly property int expandedHeight: 400
    readonly property int animationDuration: 200
    
    // State management
    height: isExpanded ? expandedHeight : collapsedHeight
    
    color: "#E6000000" // Semi-transparent black
    border.color: "#333333"
    border.width: 1
    
    // Smooth height animation
    Behavior on height {
        NumberAnimation {
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
    }
    

    // Title bar
    ASP_TitleBar {
        id: titleBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        isExpanded: root.isExpanded

        onAssetSelected: function(category, type, id) {
            root.assetSelected(category, type, id)
        }

        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId
        activeFilter: root.activeFilter
        searchText: root.searchText

    }

    // Content area (visible only when expanded)
    Item {
        id: contentArea
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        visible: root.isExpanded
        opacity: root.isExpanded ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
        }

        // Split view when effects panel is shown
        Item {
            id: item1
            anchors.fill: parent
            
            // Main content (categories/assets)
            Item {
                id: mainContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: root.showEffectsPanel ? effectsScrollView.left : parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: root.showEffectsPanel ? 5 : 0
                
                // Category grid
                ASP_CategoryGrid {
                    id: categoryGrid
                    anchors.fill: parent
                    anchors.topMargin: 6
                    visible: root.currentView === "categories"
                    activeFilter: root.activeFilter
                    searchText: root.searchText

                    onCategorySelected: function(category, type) {
                        root.selectedCategory = category
                        root.selectedType = type
                        root.currentView = "assets"
                    }
                }

                // Asset grid
                ASP_Grid {
                    id: assetGrid
                    anchors.fill: parent
                    anchors.topMargin: 6
                    visible: root.currentView === "assets"
                    category: root.selectedCategory
                    type: root.selectedType
                    searchText: root.searchText

                    // Pass selection state
                    currentSelectedCategory: root.currentSelectedCategory
                    currentSelectedType: root.currentSelectedType
                    currentSelectedId: root.currentSelectedId

                    onAssetSelected: function(id) {
                        root.assetSelected(root.selectedCategory, root.selectedType, id)
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

                
                Behavior on visible {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                VisualEffectsPanel {
                    id: effectsPanel
                    width: effectsScrollView.width - 20 // Account for scrollbar
                    targetDecoration: root.selectedDecoration
                    
                    onEffectChanged: {
                        // Optional: emit signal when effects change
                        console.log("Visual effect changed")
                    }
                }
            }
        }
    }

    // Status indicator
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 5
        width: statusText.width + 10
        height: 20
        color: "#444444"
        radius: 10
        visible: root.isExpanded

        Text {
            id: statusText
            anchors.centerIn: parent
            text: {
                if (root.currentView === "categories") {
                    return "Select a category"
                } else {
                    return root.selectedCategory + " > " + root.selectedType
                }
            }
            color: "#CCCCCC"
            font.pixelSize: 10
        }
    }
}
