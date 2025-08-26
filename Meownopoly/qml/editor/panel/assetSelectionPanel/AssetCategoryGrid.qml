import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AssetManager

ScrollView {
    id: root
    
    // Properties
    property string activeFilter: "All"
    property string searchText: ""
    
    // Signals
    signal categorySelected(string category, string type)
    
    // Public functions
    function refreshCategories() {
        generateCategories()
    }
    
    // Content
    contentWidth: gridLayout.implicitWidth
    contentHeight: gridLayout.implicitHeight
    
    GridLayout {
        id: gridLayout
        anchors.fill: parent
        columns: Math.max(1, Math.floor(root.width / 120)) // Responsive columns
        columnSpacing: 10
        rowSpacing: 10
        
        // Define category metadata with icons and descriptions
        property var categoryMetadata: {
            "grass": { name: "Grass", icon: "🌱", description: "Various grass textures" },
            "tree": { name: "Trees", icon: "🌳", description: "Tree decorations" },
            "toy": { name: "Toys", icon: "🎁", description: "Toys decorations" },
            "other": { name: "Other Decorations", icon: "🎨", description: "Miscellaneous decorations" },
            "water": { name: "Water", icon: "💧", description: "Water decorations" },
            "avatar": { name: "Player Icons", icon: "👤", description: "Character avatars" },
            "player_icons": { name: "Player Icons", icon: "👤", description: "Character avatars" }
        }
        
        // Dynamically generate categories from AssetManager
        property var categories: []
        
        Component.onCompleted: {
            generateCategories()
        }
        
        // Refresh categories when assets are reloaded
        Connections {
            target: AssetManager
            function onDecorationModelChanged() {
                generateCategories()
            }
            function onPlayerIconModelChanged() {
                generateCategories()
            }
        }
        
        function generateCategories() {
            var newCategories = []
            var availableCategories = AssetManager.getAvailableCategories()
            
            for (var i = 0; i < availableCategories.length; i++) {
                var categoryName = availableCategories[i]
                var types = AssetManager.getAvailableTypes(categoryName)
                
                for (var j = 0; j < types.length; j++) {
                    var typeName = types[j]
                    var metadata = categoryMetadata[typeName] || categoryMetadata[categoryName]
                    
                    if (metadata) {
                        newCategories.push({
                            name: metadata.name,
                            category: categoryName,
                            type: typeName,
                            icon: metadata.icon,
                            description: metadata.description
                        })
                    } else {
                        // Fallback for unknown types
                        newCategories.push({
                            name: typeName.charAt(0).toUpperCase() + typeName.slice(1),
                            category: categoryName,
                            type: typeName,
                            icon: "📁",
                            description: typeName + " assets"
                        })
                    }
                }
            }
            
            categories = newCategories
        }
        
        Repeater {
            model: {
                // Filter categories based on activeFilter and searchText
                var filtered = []
                for (var i = 0; i < gridLayout.categories.length; i++) {
                    var cat = gridLayout.categories[i]
                    
                    // Apply filter
                    var passesFilter = true
                    if (root.activeFilter === "Decoration" && cat.category !== "decoration") {
                        passesFilter = false
                    } else if (root.activeFilter === "Characters" && cat.category !== "avatar") {
                        passesFilter = false
                    }
                    
                    // Apply search
                    var passesSearch = true
                    if (root.searchText !== "") {
                        var searchLower = root.searchText.toLowerCase()
                        passesSearch = cat.name.toLowerCase().includes(searchLower) ||
                                     cat.description.toLowerCase().includes(searchLower)
                    }
                    
                    if (passesFilter && passesSearch) {
                        filtered.push(cat)
                    }
                }
                return filtered
            }
            
            // Category card
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                color: categoryMouseArea.containsMouse ? "#555555" : "#444444"
                border.color: "#666666"
                border.width: 1
                radius: 8
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    // Icon
                    Text {
                        text: modelData.icon
                        font.pixelSize: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    // Name
                    Text {
                        text: modelData.name
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        width: 90
                    }
                    
                    // Asset count
                    Text {
                        id: countText
                        color: "#CCCCCC"
                        font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Component.onCompleted: {
                            // Get asset count for this category/type
                            var model = AssetManager.getTypeModel(modelData.category, modelData.type)
                            if (model) {
                                text = model.rowCount() + " items"
                            } else {
                                text = "0 items"
                            }
                        }
                    }
                }
                
                MouseArea {
                    id: categoryMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        root.categorySelected(modelData.category, modelData.type)
                    }
                }
                
                // Hover effect
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#4A90E2"
                    border.width: categoryMouseArea.containsMouse ? 2 : 0
                    radius: 8
                    
                    Behavior on border.width {
                        NumberAnimation { duration: 150 }
                    }
                }
            }
        }
        
        // Add spacing item if needed
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: gridLayout.children.length === 1 // Only spacer visible
        }
    }
    
    // Empty state when no categories match filters
    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 100
        color: "transparent"
        visible: gridLayout.children.length === 1 // Only the spacer item
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                text: "🔍"
                font.pixelSize: 32
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "No categories found"
                color: "#CCCCCC"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Try adjusting your filters or search terms"
                color: "#999999"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.Wrap
                width: 180
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
