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

EditorBottomPanel {
    id: root

    property alias activeFilter: titleBar.activeFilter
    onCurrentViewChanged: {
        titleBar.currentView = currentView
        contentArea.currentView = currentView
    }

    // Properties
    property string selectedCategory: ""
    property string selectedType: ""

    property alias caseManagerSettings: caseManagerSettings

    // Current selection state (from parent)
    QtObject{
        id: caseManagerSettings
        property string currentSelectedCategory: ""
        property string currentSelectedType: ""
        property string currentSelectedId: ""

        // Function to clear asset selection
        function clearCaseSelection() {
            console.log("Clearing asset selection")
            caseManagerSettings.currentSelectedCategory = ""
            caseManagerSettings.currentSelectedType = ""
            caseManagerSettings.currentSelectedId = ""
            root.selectedCase = null
        }

    }

    property alias currentSelectedCategory: caseManagerSettings.currentSelectedCategory
    property alias currentSelectedType: caseManagerSettings.currentSelectedType
    property alias currentSelectedId: caseManagerSettings.currentSelectedId

    property bool isAssetSelected: currentSelectedCategory !== "" && currentSelectedType !== "" && currentSelectedId !== ""

    // Selected case element for details
    property var selectedCase: null
    property bool showDetailsPanel: true
    
    // Signals
    signal caseSelected(string category, string type, string id)
    width: 450
    signal selectionModeChanged(bool isActive)

    onCaseSelected: function(category, type, id) {
        if (root.isCaseSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
            caseManagerSettings.clearCaseSelection();
            return
        }
        console.log("Case selected for placement:", category, type, id)
        root.currentSelectedCategory = category
        root.currentSelectedType = type
        root.currentSelectedId = id
        
        // Find the case data from Game singleton
        if (id) {
            // Retrieve case data using uniqueId
            var caseData = Game.getCaseById(id);
            if (caseData) {
                root.selectedCase = caseData;
                // Update the config panel
                if (detailsPanel) {
                    detailsPanel.updateForCase(caseData);
                }
            }
        }
    }


    // Title bar
     titleBar: CSP_TitleBar {
        id: titleBar
        activeFilter: "All"
        anchors.left: parent.left
        anchors.right: parent.horizontalCenter
        anchors.top: parent.top
        isExpanded: true
        onCaseSelected: function(category, type, id) {
            console.log("titleBar select case", category, type, id)
            root.caseSelected(category, type, id)
        }
        onSearchTextChanged: {
            console.log("EditorBottomPanel - searchText filter changed", searchText)
            root.searchText = searchText
            root.searchText = Qt.binding(function(){ return root.searchText})
        }
        onCurrentViewChanged: {
            console.log("TitleBar  - onCurrentViewChanged ", currentView)
            root.currentView = titleBar.currentView
        }
        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId
        searchText: root.searchText
        currentView: root.currentView
    }


    // Split view when details panel is shown
    contentArea: CSP_ContentArea {
        id: contentArea
        anchors.fill: parent
        currentView: root.currentView
        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId
        showDetailsPanel: root.showDetailsPanel
        onCurrentViewChanged: {
            root.currentView = contentArea.currentView
        }
        activeFilter: titleBar.activeFilter
        searchText: root.searchText
        onCaseSelected: function(category, type, id) {
            root.caseSelected(category, type, id)
        }
        isExpanded: true

    }



    // Status indicator
        CSP_StatusIndicator {
            anchors.bottom: parent.bottom
            anchors.margins: 5
            anchors.right: parent.right
            visible: root.isExpanded
        }
    
    // Placeholder function that would be implemented in Game.cpp
    // to categorize cases based on purchasability
    Component.onCompleted: {
        // Make sure Game has the necessary methods
        if (typeof Game.getPurchasableCases !== "function") {
            console.warn("Game.getPurchasableCases() is not implemented - would need to be added to C++ code");
        }
        
        if (typeof Game.getTemporaryCases !== "function") {
            console.warn("Game.getTemporaryCases() is not implemented - would need to be added to C++ code");
        }
        
        if (typeof Game.getCaseById !== "function") {
            console.warn("Game.getCaseById() is not implemented - would need to be added to C++ code");
        }
    }
}
