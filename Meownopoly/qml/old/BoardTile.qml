import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game

Rectangle {
    id: root
    color: "#ecf0f1"
    border.color: "#bdc3c7"
    border.width: 1
    radius: 4

    // Properties
    property int tileIndex: 0
    property int tileType: -1  // 0: Kibble, 1: RestArea, 2: CardBoard, etc.
    property string tileName: ""
    property string tileColor: "#ecf0f1"
    property string tileIcon: ""
    property var tileData: null  // Additional data for the tile
    Component.onCompleted: {
        /*
        console.log("Tile " + tileIndex + ":")
        console.log("\t name: " + tileName)
        console.log("\t type: " + tileType)
        console.log("\t data: " + tileData)
        */
    }

    // Colors for different family types
    property var familyColors: [
        "#ecf0f1",  // None
        "#795548",  // Brown
        "#81D4FA",  // Light Blue
        "#F48FB1",  // Pink
        "#FF9800",  // Orange
        "#e74c3c",  // Red
        "#F9E155",  // Yellow
        "#66BB6A",  // Green
        "#006064"   // Dark Blue
    ]

    // Text icons as fallback (until real icons are available)
    property var fallbackIcons: [
        "🐱💰",       // 0: Kibble Dispenser
        "🛌",          // 1: Rest Area
        "📦❓",       // 2: Card Board Box
        "🌿",          // 3: Cat Nip
        "🔒",          // 4: Jail
        "➡️🔒",       // 5: To Jail
        "🚪",          // 6: Cat Door
        "😴",          // 7: Free Nap
        "💧",          // 8: Water Fountain
        "🔴",          // 9: Laser Pointer
        "👑",          // 10: Golden Collar
        "💸",          // 11: Fur Tax
    ]

    // Icons for different tile types - using resource paths
    property var tileIcons: [
        "qrc:/asset/kibble.png",       // 0: Kibble Dispenser
        "qrc:/asset/bed.png",          // 1: Rest Area
        "qrc:/asset/cardboard.png",    // 2: Card Board Box
        "qrc:/asset/catnip.png",       // 3: Cat Nip
        "qrc:/asset/jail.png",         // 4: Jail
        "qrc:/asset/tojail.png",       // 5: To Jail
        "qrc:/asset/catdoor.png",      // 6: Cat Door
        "qrc:/asset/nap.png",          // 7: Free Nap
        "qrc:/asset/fountain.png",     // 8: Water Fountain
        "qrc:/asset/laser.png",        // 9: Laser Pointer
        "qrc:/asset/tax.png",          // 10: Golden Collar
        "qrc:/asset/tax.png"           // 11: Fur Tax
    ]

    Rectangle {
        id: colorBar
        visible: tileType === 1  // Only visible for Rest Area tiles
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: parent.height * 0.2
        color: tileData && tileData.family ? familyColors[tileData.family] : "#ecf0f1"
        radius: 4
        Rectangle {
            width: parent.width
            height: parent.radius
            color: parent.color
            anchors.bottom: parent.bottom
        }
    }

    Item {
        anchors {
            left: parent.left
            right: parent.right
            top: tileType === 1 ? colorBar.bottom : parent.top
            bottom: parent.bottom
            margins: 4
        }

        // Tile name
        Text {
            id: nameText
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            text: tileName
            color: "#2c3e50"
            font.pixelSize: Math.min(parent.width * 0.1, 10)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            width: parent.width
            z:1
        }

        // Star rating for Rest Areas
        Row {
            id: starRating
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: nameText.bottom
                topMargin: 2
            }
            spacing: 2
            visible: tileType === 1

            Repeater {
                model: 4
                Text {
                    text: index < (tileData && tileData.restQuality ? tileData.restQuality : 0) ? "★" : "☆"
                    color: "#f1c40f"  // Yellow color for stars
                    font.pixelSize: Math.min(parent.parent.width * 0.15, 12)
                }
            }
        }

        // Tile icon (using Image)
        Image {
            id: icon
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: tileType === 1 ? parent.height * 0.1 : 0
            }
            width: parent.width * (tileType === 1 ? 0.6 : 0.8)  // Smaller icon for rest areas
            height: width
            source: tileType >= 0 && tileType < tileIcons.length ? tileIcons[tileType] : ""
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
            asynchronous: true
            
            onStatusChanged: {
                if (status === Image.Error) {
                    fallbackText.visible = true;
                }
            }
        }
        
        // Fallback text icon when image isn't available
        Text {
            id: fallbackText
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: nameText.bottom
                topMargin: 2
            }
            width: parent.width * 0.4
            height: width
            text: tileType >= 0 && tileType < fallbackIcons.length ? fallbackIcons[tileType] : "?"
            font.pixelSize: parent.width * 0.25
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: !icon.visible
        }

        // Tile price (for Rest Area only)
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: (icon.visible ? icon.bottom : fallbackText.bottom)
                topMargin: 2
            }
            visible: tileType === 1 && tileData && tileData.price
            text: visible ? tileData.price + "K" : ""
            color: "#2c3e50"
            font.pixelSize: parent.width * 0.12
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            tileDetailsPopup.open();
        }
    }

    // Popup for showing tile details
    Popup {
        id: tileDetailsPopup
        width: 300
        height: 400
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: Overlay.overlay

        contentItem: Rectangle {
            color: "#ecf0f1"
            border.color: "#bdc3c7"
            border.width: 1
            radius: 8

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 10
                }
                spacing: 10

                // Title bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: tileType === 1 && tileData && tileData.family ? familyColors[tileData.family] : "#34495e"
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: tileName
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                // Tile icon
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    
                    Image {
                        anchors.fill: parent
                        source: tileType >= 0 && tileType < tileIcons.length ? tileIcons[tileType] : ""
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                        asynchronous: true
                    }
                    
                    Text {
                        anchors.fill: parent
                        text: tileType >= 0 && tileType < fallbackIcons.length ? fallbackIcons[tileType] : "?"
                        font.pixelSize: parent.width * 0.7
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: parent.children[0].status !== Image.Ready
                    }
                }

                // Tile details
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        // Tile type
                        Text {
                            text: "Type: " + getTileTypeName()
                            font.pixelSize: 14
                            color: "#2c3e50"
                        }

                        // Rest Area specific information
                        ColumnLayout {
                            visible: tileType === 1
                            spacing: 5

                            Text {
                                text: "Family: " + getFamilyName()
                                font.pixelSize: 14
                                color: "#2c3e50"
                                visible: tileType === 1
                            }

                            Text {
                                text: "Owner: " + (tileData && tileData.owner ? tileData.owner : "None")
                                font.pixelSize: 14
                                color: "#2c3e50"
                                visible: tileType === 1
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                visible: tileType === 1

                                Text {
                                    text: "Rest Quality:"
                                    font.pixelSize: 14
                                    color: "#2c3e50"
                                }

                                Row {
                                    spacing: 2
                                    Repeater {
                                        model: 4
                                        Text {
                                            text: index < (tileData && tileData.restQuality ? tileData.restQuality : 0) ? "★" : "☆"
                                            color: "#f1c40f"
                                            font.pixelSize: 16
                                        }
                                    }
                                }
                            }

                            // Price information
                            Text {
                                text: "Prices:"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#2c3e50"
                                visible: root.tileType === 1
                            }

                            GridLayout {
                                visible: root.tileType === 1 && root.tileData && root.tileData.prices
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 5

                                Text { text: "Purchase:"; font.pixelSize: 12; color: "#2c3e50" }
                                Text { 
                                    text: root.tileData && root.tileData.prices && tileData.prices[0] ? tileData.prices[0] + "K" : "N/A"
                                    font.pixelSize: 12; 
                                    color: "#2c3e50" 
                                }

                                Text { text: "1 Star:"; font.pixelSize: 12; color: "#2c3e50" }
                                Text { 
                                    text: tileData && tileData.prices && tileData.prices[1] ? tileData.prices[1] + "K" : "N/A"
                                    font.pixelSize: 12; 
                                    color: "#2c3e50" 
                                }

                                Text { text: "2 Stars:"; font.pixelSize: 12; color: "#2c3e50" }
                                Text { 
                                    text: tileData && tileData.prices && tileData.prices[2] ? tileData.prices[2] + "K" : "N/A"
                                    font.pixelSize: 12; 
                                    color: "#2c3e50" 
                                }

                                Text { text: "3 Stars:"; font.pixelSize: 12; color: "#2c3e50" }
                                Text { 
                                    text: tileData && tileData.prices && tileData.prices[3] ? tileData.prices[3] + "K" : "N/A"
                                    font.pixelSize: 12; 
                                    color: "#2c3e50" 
                                }

                                Text { text: "4 Stars:"; font.pixelSize: 12; color: "#2c3e50" }
                                Text { 
                                    text: tileData && tileData.prices && tileData.prices[4] ? tileData.prices[4] + "K" : "N/A"
                                    font.pixelSize: 12; 
                                    color: "#2c3e50" 
                                }

                                Text { text: "Hotel:"; font.pixelSize: 12; color: "#2c3e50" }
                                Text { 
                                    text: tileData && tileData.prices && tileData.prices[5] ? tileData.prices[5] + "K" : "N/A"
                                    font.pixelSize: 12; 
                                    color: "#2c3e50" 
                                }
                            }
                        }

                        // Other tile types can have specific information here
                        ColumnLayout {
                            visible: tileType === 0  // Kibble Dispenser
                            spacing: 5

                            Text {
                                text: "Collect 200K when passing"
                                font.pixelSize: 14
                                color: "#2c3e50"
                            }
                        }

                        ColumnLayout {
                            visible: tileType === 4  // Jail
                            spacing: 5

                            Text {
                                text: "Jail Time: 3 turns (unless you roll doubles or pay fine)"
                                font.pixelSize: 14
                                color: "#2c3e50"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Close button
                Button {
                    text: "Close"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: tileDetailsPopup.close()
                    
                    background: Rectangle {
                        color: parent.pressed ? "#95a5a6" : "#7f8c8d"
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Helper functions
    function getTileTypeName() {
        const tileTypes = [
            "Kibble Dispenser", "Rest Area", "Card Board Box", "Cat Nip",
            "Jail", "Go To Jail", "Cat Door", "Free Nap", 
            "Water Fountain", "Laser Pointer", "Golden Collar", "Fur Tax"
        ];
        return tileType >= 0 && tileType < tileTypes.length ? tileTypes[tileType] : "Unknown";
    }

    function getFamilyName() {
        const families = [
            "None", "Brown", "Light Blue", "Pink", "Orange", 
            "Red", "Yellow", "Green", "Dark Blue"
        ];
        return tileData && tileData.family >= 0 && tileData.family < families.length ? 
            families[tileData.family] : "None";
    }

    function getRestQualityName() {
        const qualities = [
            "None", "1 Star", "2 Stars", "3 Stars", "4 Stars", "Hotel"
        ];
        return tileData && tileData.restQuality >= 0 && tileData.restQuality < qualities.length ? 
            qualities[tileData.restQuality] : "None";
    }
} 
