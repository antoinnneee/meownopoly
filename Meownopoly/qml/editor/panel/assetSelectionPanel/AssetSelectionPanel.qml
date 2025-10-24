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

    property string selectedCategory: ""
    property string selectedType: ""
    property bool comingFromOtherMenu: false // Track if we're coming from another menu
    property string currentView: "categories" // "categories" or "assets"
    
    onComingFromOtherMenuChanged: {
        console.log("AssetSelectionPanel: comingFromOtherMenu changed to", comingFromOtherMenu)
    }
    
    property alias assetManagerSettings: assetManagerSettings
    property alias visualEffectsPanel: contentArea.visualEffectsPanel
    property alias currentTabIndex: contentArea.currentTabIndex
    // Current selection state (from parent)
    QtObject{
        id: assetManagerSettings
        property string currentSelectedCategory: ""
        property string currentSelectedType: ""
        property string currentSelectedId: ""

        // Function to clear asset selection
        function clearAssetSelection() {
            assetManagerSettings.currentSelectedCategory = ""
            assetManagerSettings.currentSelectedType = ""
            assetManagerSettings.currentSelectedId = ""
        }
    }

    property alias currentSelectedCategory: assetManagerSettings.currentSelectedCategory
    property alias currentSelectedType: assetManagerSettings.currentSelectedType
    property alias currentSelectedId: assetManagerSettings.currentSelectedId

    property bool isAssetSelected: currentSelectedCategory !== "" && currentSelectedType !== "" && currentSelectedId !== ""

    // Selected decoration element for effects
    property bool showEffectsPanel: true

    // Signals
    signal assetSelected(string category, string type, string id)
    signal assetCleared()

    signal effectChanged()

    function updateSelectedAsset(category, type, id)
    {
         if (root.isAssetSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
             root.assetCleared()
             return
         }
         root.currentSelectedCategory = category
         root.currentSelectedType = type
         root.currentSelectedId = id
         
         // Ajuster les dimensions au ratio natif de l'asset
         var asset = AssetManager.getAssetById(category, type, id)
         if (asset && asset.id && logic && logic.tileLogic) {
             var ratioWidth = asset.ratioWidth || 1
             var ratioHeight = asset.ratioHeight || 1
             console.log("AssetSelectionPanel: Asset sélectionné avec ratio", ratioWidth + ":" + ratioHeight)
             logic.tileLogic.adjustToNativeRatio(ratioWidth, ratioHeight)
         }
         
         root.assetSelected(category, type, id)

    }

    // Function to handle coming from another menu
    function setComingFromOtherMenu(value) {
        root.comingFromOtherMenu = value
        
        // Si on vient d'un autre menu, on ne change pas l'état, on laisse l'état actuel
        if (value) {
            console.log("AssetSelectionPanel: Coming from other menu, keeping current state:", root.currentView)
            // Ne pas forcer de changement d'état, laisser l'état actuel
        }
    }




    // Title bar
     titleBar: ASP_TitleBar {
        id: titleBar
        activeFilter: "All"
        anchors.left: parent.left
        anchors.right: parent.horizontalCenter
        anchors.top: parent.top
        isExpanded: true

        onAssetSelected: function(category, type, id) {
            root.assetSelected(category, type, id)
        }
        onSearchTextChanged: {
            root.searchText = searchText
            root.searchText = Qt.binding(function(){ return root.searchText})
        }


        onCurrentViewChanged:  {
            root.currentView = titleBar.currentView
        }

        onBackButtonClicked: {
            // Si on vient d'un autre menu, on reste dans la catégorie sélectionnée
            // Sinon, on retourne à la sélection des catégories
            if (root.comingFromOtherMenu) {
                // Rester dans la catégorie actuelle
                root.comingFromOtherMenu = false
            } else {
                // Retourner à la sélection des catégories
                root.currentView = "categories"
                root.assetCleared()
            }
        }
        onButtonClicked: function(text, index)  {
            titleBar.activeFilter = text
            root.currentView = "categories"
        }


        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId

        searchText: root.searchText
        currentView: root.currentView

    }

     contentArea: ASP_ContentArea {
            id: contentArea
            anchors.fill: parent
            currentSelectedCategory: root.currentSelectedCategory
            currentSelectedType: root.currentSelectedType
            currentSelectedId: root.currentSelectedId
            showEffectsPanel: root.showEffectsPanel
            currentView: root.currentView
            activeFilter: titleBar.activeFilter
            searchText: root.searchText
            onCategorieSelected: {
                root.currentView = "assets"
                // Mettre à jour les propriétés de catégorie sélectionnée
                root.selectedCategory = contentArea.selectedCategory
                root.selectedType = contentArea.selectedType
            }
            onAssetSelected: function(category, type, id) {
                root.updateSelectedAsset(category, type, id)
            }
            isExpanded: true
            onEffectChanged: {
                root.effectChanged()
            }
            titleHeight: titleBar.height
    }

    // Status indicator
    ASP_StatusIndicator {
        anchors.bottom: parent.bottom
        anchors.margins: 5
        anchors.right: parent.right
        visible: root.isExpanded
        currentSelectedCategory: root.currentSelectedCategory
        currentView: root.currentView
    }
}
