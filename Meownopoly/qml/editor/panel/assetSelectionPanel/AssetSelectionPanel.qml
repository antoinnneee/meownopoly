import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

Rectangle {
    id: root
    
    // Properties
    property bool isExpanded: false
    property string currentView: "categories" // "categories" or "assets"
    property string selectedCategory: ""
    property string selectedType: ""
    property string searchText: ""
    property string activeFilter: "All" // "All", "Decoration", "Characters"
    
    // Current selection state (from parent)
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    
    // Signals
    signal assetSelected(string category, string type, string id)
    
    // Dimensions
    readonly property int collapsedHeight: 40
    readonly property int expandedHeight: 250
    readonly property int animationDuration: 200
    
    // State management
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
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
            spacing: 15
            
            // Title with selection indicator
            Column {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                
                Text {
                    text: "Asset Library"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }
                
                Text {
                    text: root.currentSelectedId !== "" ? 
                          "Selected: " + root.currentSelectedType + " #" + root.currentSelectedId : 
                          "Click to select an asset"
                    color: root.currentSelectedId !== "" ? "#4CAF50" : "#999999"
                    font.pixelSize: 10
                    font.italic: true
                    visible: root.isExpanded
                }
            }
            
            // Quick filters (visible only when expanded)
            Row {
                visible: root.isExpanded
                spacing: 10
                Layout.alignment: Qt.AlignVCenter
                
                Repeater {
                    model: ["All", "Decoration", "Characters"]
                    
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
                placeholderText: "Search assets..."
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
            
            // Back button (visible when in assets view)
            Button {
                visible: root.isExpanded && root.currentView === "assets"
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
            
            // Clear selection button (visible when asset is selected)
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
                    root.assetSelected("", "", "")
                }
            }
            
            // Expand/collapse button
            Button {
                id: expandButton
                width: 30
                height: 30
                
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
        
        // Category grid
        AssetCategoryGrid {
            id: categoryGrid
            anchors.fill: parent
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
        AssetGrid {
            id: assetGrid
            anchors.fill: parent
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
