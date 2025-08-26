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
    
    // Content
    contentWidth: gridLayout.implicitWidth
    contentHeight: gridLayout.implicitHeight
    
    GridLayout {
        id: gridLayout
        anchors.fill: parent
        columns: Math.max(1, Math.floor(root.width / 120)) // Responsive columns
        columnSpacing: 10
        rowSpacing: 10
        
        // Define available categories based on AssetManager structure
        property var categories: [
            {
                name: "Grass",
                category: "decoration",
                type: "grass",
                icon: "🌱",
                description: "Various grass textures"
            },
            {
                name: "Trees",
                category: "decoration", 
                type: "tree",
                icon: "🌳",
                description: "Tree decorations"
            },
            {
                name: "Toys",
                category: "decoration",
                type: "toy",
                icon: "🎁",
                description: "Toys decorations"
            },
            {
                name: "Other Decorations",
                category: "decoration",
                type: "other", 
                icon: "🎨",
                description: "Miscellaneous decorations"
            },
            {
                name: "Player Icons",
                category: "avatar",
                type: "avatar",
                icon: "👤",
                description: "Character avatars"
            }
        ]
        
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
