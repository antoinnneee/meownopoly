import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts
import AssetManager
import QtQuick.Window
import theme

ScrollView {
    id: root
    
    // Properties
    required property string activeFilter
    property string searchText: ""
    
    // Signals
    signal categorySelected(string category, string type)
    
    // Supprime les accents/diacritiques pour une recherche insensible aux accents
    function removeAccents(str) {
        return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    }

    // Public functions
    function refreshCategories() {
        generateCategories()
    }
    
    contentHeight: gridLayout.implicitHeight
    GridLayout {
        id: gridLayout
        anchors.fill: parent
        columnSpacing: Theme.spacingL
        rowSpacing: Theme.spacingL
        columns: Math.max(1, Math.floor(parent.width / (Screen.pixelDensity*25))-1)
        
        // Define category metadata with icons and descriptions
        property var categoryMetadata: {
            "grass": { name: "Grass", icon: "🌱", description: "Various grass textures" },
            "tree": { name: "Trees", icon: "🌳", description: "Tree decorations" },
            "toy": { name: "Toys", icon: "🎁", description: "Toys decorations" },
            "other": { name: "Other", icon: "🎨", description: "Miscellaneous decorations" },
            "water": { name: "Water", icon: "💧", description: "Water decorations" },
            "avatar": { name: "Player Icons", icon: "👤", description: "Character avatars" },
            "player_icons": { name: "Player Icons", icon: "👤", description: "Character avatars" }
        }
        
        // Dynamically generate categories from AssetManager
        property var categories: []
        
        Component.onCompleted: {
            generateCategories()
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
                let filtered = []
                for (let i = 0; i < gridLayout.categories.length; i++) {
                    const cat = gridLayout.categories[i]

                    // Apply filter
                    let passesFilter = true
                    if (root.activeFilter === "Decoration" && cat.category !== "decoration") {
                        passesFilter = false
                    } else if (root.activeFilter === "Tile" && cat.category !== "tile") {
                        passesFilter = false
                    }
                    
                    // Apply search (nom, description de catégorie, et tags/description des assets)
                    let passesSearch = true
                    if (root.searchText !== "") {
                        const searchNorm = root.removeAccents(root.searchText.toLowerCase())
                        passesSearch = root.removeAccents(cat.name.toLowerCase()).includes(searchNorm) ||
                                     root.removeAccents(cat.description.toLowerCase()).includes(searchNorm)

                        // Si pas trouvé dans le nom/description de catégorie, chercher dans les tags des assets
                        if (!passesSearch) {
                            passesSearch = AssetManager.hasMatchingAsset(cat.category, cat.type, root.searchText)
                        }
                    }
                    
                    if (passesFilter && passesSearch) {
                        filtered.push(cat)
                    }
                }
                return filtered
            }
            
            // Category card
            Rectangle {
                Layout.preferredWidth: Screen.pixelDensity*25
                Layout.preferredHeight:  Screen.pixelDensity*25
                color: categoryMouseArea.containsMouse ? Theme.borderLight : Theme.border
                border.color: Theme.textDisabled
                border.width: 1
                radius: Theme.radiusL

                Behavior on color {
                    ColorAnimation { duration: Theme.durationNormal }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    // Icon
                    Text {
                        text: modelData.icon
                        font.pixelSize: Theme.fontSizeHero
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    // Name
                    Text {
                        text: modelData.category + "\n" + modelData.name
                        elide: Text.ElideNone
                        color: Theme.textPrimary
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        minimumPointSize: 8
                        fontSizeMode: Text.Fit
                        width: parent.width
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
                    border.color: Theme.accent
                    border.width: categoryMouseArea.containsMouse ? 2 : 0
                    radius: Theme.radiusL

                    Behavior on border.width {
                        NumberAnimation { duration: Theme.durationNormal }
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
            spacing: Theme.spacingL

            Text {
                text: "🔍"
                font.pixelSize: Theme.fontSizeHero
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "No categories found"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeMedium
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Try adjusting your filters or search terms"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.Wrap
                width: 180
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
