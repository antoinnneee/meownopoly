import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EditorBottomPanel {
    id: root

    default property alias contentArea: contentArea.children


    property alias activeFilter: titleBar.activeFilter

    property string selectedCategory: ""
    property string selectedType: ""
    
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



    // Title bar
    ASP_TitleBar {
        id: titleBar
        anchors.left: parent.left
        anchors.right: parent.horizontalCenter
        anchors.top: parent.top
        isExpanded: root.isExpanded

        onAssetSelected: function(category, type, id) {
            console.log("titleBar select asset", category, type, id)
            root.assetSelected(category, type, id)
        }

        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId
        searchText: root.searchText
        currentView: root.currentView

        Timer{
            interval: 600
            running: true
            repeat: true
            onTriggered: {
                console.log("EditorBottomPanel activeFilter", titleBar.activeFilter)
            }
        }

    }

    // Content area (visible only when expanded)

    Item {
        id: contentPlaceHolder
        anchors.bottom: root.bottom
        anchors.left: root.left
        anchors.margins: 10
        anchors.right: root.right
        anchors.top: titleBar.bottom
        ASP_ContentArea {
            id: contentArea
            anchors.fill: parent
            currentSelectedCategory: root.currentSelectedCategory
            currentSelectedType: root.currentSelectedType
            currentSelectedId: root.currentSelectedId
            showEffectsPanel: root.showEffectsPanel
            currentView: root.currentView
            activeFilter: titleBar.activeFilter
            searchText: root.searchText
            onAssetSelected: function(category, type, id) {
                root.assetSelected(category, type, id)
            }
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
