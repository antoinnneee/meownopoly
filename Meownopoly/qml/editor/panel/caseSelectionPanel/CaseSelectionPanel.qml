import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager
import Game
import Case
import CaseRestArea
import "../assetSelectionPanel"

Rectangle {
    id: root
    
    // Properties
    property bool isExpanded: true
    property string currentView: "categories" // "categories" ou "types"
    property string selectedCategory: ""
    property string selectedType: ""
    property string searchText: ""
    property string activeFilter: "All" // "All", "Propriétés", "Spéciales"
    
    required property var logic

    // Current selection state (from parent)
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    property bool isCaseSelected: currentSelectedCategory !== "" && currentSelectedType !== "" && currentSelectedId !== ""

    // Selected case element for details
    property var selectedCase: null
    property bool showDetailsPanel: true
    
    // Signals
    signal caseSelected(string category, string type, string id)
    width: 450
    signal selectionModeChanged(bool isActive)

    onCaseSelected: function(category, type, id) {
        if (root.isCaseSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
            clearCaseSelection();
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

    // Function to clear case selection
    function clearCaseSelection() {
        console.log("Clearing case selection")
        root.currentSelectedCategory = ""
        root.currentSelectedType = ""
        root.currentSelectedId = ""
        root.selectedCase = null
    }

    // Dimensions
    readonly property int collapsedHeight: Screen.pixelDensity * 12
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
    
    // Blur effect background
    Rectangle {
        anchors.fill: parent
        color: "#CC2C2C2C"
        radius: 8
        opacity: 0.9
    }
    
    // Yellow indicator background
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: "#33332211"  // Dark yellow with low opacity
        radius: 6
        opacity: 0.4
        z: -1
        
        // Yellow indicator strip (top)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 5
            color: "#b3ab48"  // More visible yellow
            radius: 3
        }
    }
    
    // Title bar
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: collapsedHeight
        color: "transparent"
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            anchors.rightMargin: 6
            spacing: 15
            
            // Title with selection indicator
            ColumnLayout {
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                
                Text {
                    text: "Case Library"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillHeight: true
                }
                
                Text {
                    text: root.currentSelectedId !== "" ?
                              "Selected: " + root.currentSelectedType + " #" + root.currentSelectedId.substring(0, 8) :
                              "Click to select a case"
                    color: root.currentSelectedId !== "" ? "#4CAF50" : "#999999"
                    font.pixelSize: 10
                    font.italic: true
                    visible: root.isExpanded
                    Layout.fillHeight: true
                }
            }
            
            // Quick filters (visible only when expanded)
            Row {
                visible: root.isExpanded
                spacing: 10
                Layout.alignment: Qt.AlignVCenter
                
                Repeater {
                    model: ["All", "Propriétés", "Spéciales"]
                    
                    Button {
                        text: modelData
                        flat: true
                        checkable: true
                        checked: root.activeFilter === modelData
                        
                        background: Rectangle {
                            color: parent.checked ? "#4A90E2" : "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 4
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.checked ? "white" : "#4A90E2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            root.activeFilter = text
                        }
                    }
                }
            }
            
            // Search bar (visible when expanded)
            TextField {
                visible: root.isExpanded
                Layout.preferredWidth: 200
                Layout.alignment: Qt.AlignVCenter
                placeholderText: "Search cases..."
                text: root.searchText
                
                background: Rectangle {
                    color: "#444444"
                    border.color: "#666666"
                    border.width: 1
                    radius: 4
                }
                
                color: "white"
                
                onTextChanged: root.searchText = text
            }
            
            // Spacer
            Item { Layout.fillWidth: true }

            // Back button (visible when in types view)
            Button {
                visible: root.isExpanded && root.currentView === "types"
                text: "← Back"
                flat: true

                background: Rectangle {
                    color: parent.pressed ? "#555555" : "transparent"
                    border.color: "#666666"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.currentView = "categories"
            }

            // Clear selection button (visible when case is selected)
            Button {
                visible: root.isExpanded && root.currentSelectedId !== ""
                text: "✕ Clear"
                flat: true

                background: Rectangle {
                    color: parent.pressed ? "#AA4444" : "transparent"
                    border.color: "#FF6666"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "#FF6666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                }

                onClicked: {
                    // Signal to parent to clear selection
                    root.caseSelected("", "", "")
                }
            }

            // Expand/collapse button
            Button {
                id: expandButton
                width: 30
                Layout.fillHeight: true
                Layout.topMargin: -6
                Layout.bottomMargin: 0

                background: Rectangle {
                    color: parent.pressed ? "#555555" : "#444444"
                    border.color: "#666666"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: root.isExpanded ? "▼" : "▲"
                    color: "white"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    anchors.fill: expandButton
                }

                onClicked: root.isExpanded = !root.isExpanded
            }
        }
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

        // Split view when details panel is shown
        Item {
            id: mainContainer
            anchors.fill: parent
            
            // Main content (categories/types)
            Item {
                id: mainContent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: root.showDetailsPanel ? detailsPanel.left : parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: root.showDetailsPanel ? 10 : 0
                
                // Category grid view
                CSP_CategoryGrid {
                    id: categoryGrid
                    anchors.fill: parent
                    anchors.topMargin: 6
                    visible: root.currentView === "categories"
                    searchText: root.searchText
                    activeFilter: root.activeFilter
                    
                    onCategorySelected: function(category, title) {
                        console.log("Category selected:", category, title);
                        root.selectedCategory = category;
                        root.selectedType = "all";
                        root.currentView = "types";
                    }
                }

                // Cases grid view
                Item {
                    id: typesContainer
                    anchors.fill: parent
                    anchors.topMargin: 6
                    visible: root.currentView === "types"
                    
                    // Title for the types view
                    Text {
                        id: typesTitle
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 30
                        text: {
                            if (root.selectedCategory === "achetable")
                                return "Propriétés achetables";
                            else
                                return "Cases temporaires";
                        }
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }
                    
                    // Grid of cases
                    CSP_Grid {
                        id: casesGrid
                        anchors.top: typesTitle.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 10
                        
                        categoryName: root.selectedCategory
                        typeName: root.selectedType
                        searchText: root.searchText
                        
                        // Get list of cases based on category
                        caseList: {
                            if (root.selectedCategory === "proprietes") {
                                return Game.getPurchasableCases();
                            } else {
                                return Game.getTemporaryCases();
                            }
                        }
                        
                        onCaseSelected: function(category, type, id) {
                            root.caseSelected(category, type, id);
                        }
                    }
                }
            }
            
            // Details Panel (right side)
            CSP_CaseConfigPanel {
                id: detailsPanel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: parent.width * 0.42
                visible: root.showDetailsPanel
                
                onConfigurationApplied: function(caseData) {
                    console.log("Case configuration applied for:", caseData.name);
                    // Here we would handle saving the configuration
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
                            return root.selectedCategory === "proprietes" ? "Propriétés" : "Spéciales"
                        }
                    }
            color: "#CCCCCC"
            font.pixelSize: 10
        }
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