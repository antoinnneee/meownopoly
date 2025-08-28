import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Game
import Case
import CaseRestArea

ScrollView {
    id: root
    
    // Properties
    property string searchText: ""
    property string activeFilter: "All" // "All", "Propriétés", "Spéciales"
    
    // Signal for category selection
    signal categorySelected(string category, string title)
    
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
            "proprietes": { name: "Propriétés", icon: "🏠", description: "Cases achetables avec prix" },
            "speciales": { name: "Spéciales", icon: "🎲", description: "Cases avec effets spéciaux" }
        }
        
        // Define our categories
        property var categories: [
            {
                name: "Propriétés",
                category: "proprietes",
                type: "all",
                icon: "🏠",
                description: "Cases achetables avec prix",
                filter: "Propriétés"
            },
            {
                name: "Spéciales",
                category: "speciales",
                type: "all",
                icon: "🎲",
                description: "Cases avec effets spéciaux",
                filter: "Spéciales"
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
                    if (root.activeFilter !== "All" && cat.filter !== root.activeFilter) {
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
                            // Get case count for this category
                            var count = 0;
                            if (modelData.category === "proprietes") {
                                try {
                                    count = Game.getPurchasableCases().length;
                                } catch (e) {
                                    count = "?";
                                }
                            } else {
                                try {
                                    count = Game.getTemporaryCases().length;
                                } catch (e) {
                                    count = "?";
                                }
                            }
                            text = count + " cases";
                        }
                    }
                }
                
                MouseArea {
                    id: categoryMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        root.categorySelected(modelData.category, modelData.name)
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
                text: "Aucune catégorie trouvée"
                color: "#CCCCCC"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Ajustez vos filtres ou termes de recherche"
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