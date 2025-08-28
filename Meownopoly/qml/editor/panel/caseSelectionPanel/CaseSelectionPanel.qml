import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager
import "../assetSelectionPanel"

Rectangle {
    id: root
    
    // Properties
    property bool isExpanded: true
    property string currentView: "categories" // "categories" ou "types"
    property string selectedCategory: ""
    property string selectedType: ""
    property string searchText: ""
    property string activeFilter: "All" // "All", "Properties", "Events"
    
    required property var logic

    // Current selection state (from parent)
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    property bool isAssetSelected: currentSelectedCategory !== "" && currentSelectedType !== "" && currentSelectedId !== ""

    // Selected case element for details
    property var selectedCase: null
    property bool showDetailsPanel: true
    
    // Signals
    signal caseSelected(string category, string type, string id)
    width: 450
    signal selectionModeChanged(bool isActive)

    onCaseSelected: function(category, type, id) {
        if (root.isAssetSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
            clearCaseSelection();
            return
        }
        console.log("Case selected for placement:", category, type, id)
        root.currentSelectedCategory = category
        root.currentSelectedType = type
        root.currentSelectedId = id
    }

    // Function to clear case selection
    function clearCaseSelection() {
        console.log("Clearing case selection")
        root.currentSelectedCategory = ""
        root.currentSelectedType = ""
        root.currentSelectedId = ""
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
                              "Selected: " + root.currentSelectedType + " #" + root.currentSelectedId :
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
                    model: ["All", "Properties", "Events"]
                    
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
                            root.currentView = "categories"
                        }
                    }
                }
            }
            
            // Search bar (optional, visible when expanded)
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
                anchors.right: root.showDetailsPanel ? detailsScrollView.left : parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: root.showDetailsPanel ? 5 : 0
                
                // Placeholder for the Category grid (future implementation)
                Rectangle {
                    id: categoryGrid
                    anchors.fill: parent
                    anchors.topMargin: 6
                    visible: root.currentView === "categories"
                    color: "#333333"
                    opacity: 0.7
                    radius: 4
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        
                        Text {
                            text: "Case Categories"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: "This is a placeholder for future case categories"
                            color: "#CCCCCC"
                            font.pixelSize: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Button {
                            text: "Go to Types View"
                            anchors.horizontalCenter: parent.horizontalCenter
                            onClicked: {
                                root.selectedCategory = "property"
                                root.selectedType = "all"
                                root.currentView = "types"
                            }
                        }
                    }
                }

                // Placeholder for the Type grid (future implementation)
                Rectangle {
                    id: typeGrid
                    anchors.fill: parent
                    anchors.topMargin: 6
                    visible: root.currentView === "types"
                    color: "#333333"
                    opacity: 0.7
                    radius: 4
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        
                        Text {
                            text: "Case Types for " + root.selectedCategory
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: "This is a placeholder for future case types"
                            color: "#CCCCCC"
                            font.pixelSize: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
            
            // Details Panel in ScrollView
            ScrollView {
                id: detailsScrollView
                anchors.top: parent.top
                anchors.right: parent.right
                contentHeight: detailsPanel.height
                width: parent.width * 0.42
                anchors.bottom: parent.bottom
                
                visible: root.showDetailsPanel
                
                Behavior on visible {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                
                // Placeholder for the Details Panel
                Rectangle {
                    id: detailsPanel
                    width: detailsScrollView.width - 20
                    height: 500
                    color: "#333333"
                    radius: 4
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15
                        
                        Text {
                            text: "Case Details"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            width: parent.width
                        }
                        
                        Text {
                            text: "This panel will show details for the selected case"
                            color: "#CCCCCC"
                            font.pixelSize: 12
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#444444"
                        }
                        
                        Text {
                            text: "Properties"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            width: parent.width
                        }
                        
                        // Placeholder properties
                        Column {
                            width: parent.width
                            spacing: 10
                            
                            Repeater {
                                model: ["Name", "Type", "Value", "Position", "Size"]
                                
                                Row {
                                    width: parent.width
                                    spacing: 10
                                    
                                    Text {
                                        width: 80
                                        text: modelData + ":"
                                        color: "#AAAAAA"
                                        font.pixelSize: 12
                                    }
                                    
                                    Text {
                                        text: "Sample " + modelData.toLowerCase()
                                        color: "white"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
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
