import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EditorBottomPanel {
    id: root


    // property string activeFilter
    property alias activeFilter: titleBar.activeFilter
//    property alias currentView: root.currentView
    // property string currentView: "categories" // "categories" or "assets"
    onCurrentViewChanged: {
        titleBar.currentView = currentView
        contentArea.currentView = currentView
    }

    property string selectedCategory: ""
    property string selectedType: ""
    
    property alias assetManagerSettings: assetManagerSettings
    // Current selection state (from parent)
    QtObject{
        id: assetManagerSettings
        property string currentSelectedCategory: ""
        property string currentSelectedType: ""
        property string currentSelectedId: ""

        // Function to clear asset selection
        function clearAssetSelection() {
            console.log("Clearing asset selection")
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
    property var selectedDecoration: null
    property bool showEffectsPanel: true//selectedDecoration !== null && selectedDecoration.type === 2 // DecorationTile
    
    // Signals
    signal assetSelected(string category, string type, string id)
    width: 450
    signal selectionModeChanged(bool isActive)



    onAssetSelected: function(category, type, id) {
        if (root.isAssetSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
            assetManagerSettings.clearAssetSelection();
            return
        }
        console.log("Asset selected for placement:", category, type, id)
        root.currentSelectedCategory = category
        root.currentSelectedType = type
        root.currentSelectedId = id
    }



    // Title bar
     titleBar: ASP_TitleBar {
        id: titleBar
        activeFilter: "All"
        anchors.left: parent.left
        anchors.right: parent.horizontalCenter
        anchors.top: parent.top
        isExpanded: root.isExpanded

        onAssetSelected: function(category, type, id) {
            console.log("titleBar select asset", category, type, id)
            root.assetSelected(category, type, id)
        }
        onSearchTextChanged: {
            console.log("EditorBottomPanel - searchText filter changed", searchText)
            root.searchText = searchText
            root.searchText = Qt.binding(function(){ return root.searchText})
        }


        onCurrentViewChanged:  {
            root.currentView = titleBar.currentView
        }


        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId

        searchText: root.searchText
        currentView: root.currentView


    }

    // Content area (visible only when expanded)
     contentArea: ASP_ContentArea {
            id: contentArea
            anchors.fill: parent
            currentSelectedCategory: root.currentSelectedCategory
            currentSelectedType: root.currentSelectedType
            currentSelectedId: root.currentSelectedId
            showEffectsPanel: root.showEffectsPanel
            currentView: root.currentView
            onCurrentViewChanged: {
                console.log("currentView changed in contentArea")
                // Propager le changement vers le parent
                root.currentView = contentArea.currentView
            }
            activeFilter: titleBar.activeFilter
            searchText: root.searchText
            onAssetSelected: function(category, type, id) {
                root.assetSelected(category, type, id)
            }

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
