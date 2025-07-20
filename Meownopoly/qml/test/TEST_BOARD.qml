import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Case
import "../case/"

Rectangle {
    id: root
    width: 800
    height: 800

    color: "#2c3e50"
    
    // Card dimensions
    property real cardWidth: Screen.pixelDensity * 25  // 2.5cm
    property real cardHeight: Screen.pixelDensity * 50   // Alternative height
    
    // Initialize game on component creation
    Component.onCompleted: {
        console.log("Initializing game...")
        Game.init()
        console.log("Game initialized. Total cases:", Game.listCases.length)
        
        // Debug: Print detailed info for first 10 cases
        for (var i = 0; i < Math.min(10, Game.listCases.length); i++) {
            var caseData = Game.listCases[i]
            console.log("QML Case", i, ":")
            console.log("  - Name:", caseData.name)
            console.log("  - Type:", caseData.type)
            console.log("  - Position:", caseData.position)
            console.log("  - Valid:", caseData ? "true" : "false")
            
            // Check if it's a property with additional details
            if (caseData.type === 1) {
                console.log("  - Property details:")
                console.log("    - Price:", caseData.price || "N/A")
                console.log("    - Mortgage:", caseData.morgagePrice || "N/A")
                console.log("    - Family:", caseData.family || "N/A")
            }
        }
    }
    
    // Title
    Text {
        id: titleText
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 10
        text: "MEOWNOPOLY - Test 10 Cards"
        color: "#ecf0f1"
        font.pixelSize: 16
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }
    
    // Colors mapping for family types
    property var familyColors: [
        "#ecf0f1",  // 0: FT_NONE
        "#795548",  // 1: FT_BROWN
        "#81D4FA",  // 2: FT_LIGHTBLUE
        "#F48FB1",  // 3: FT_PINK
        "#FF9800",  // 4: FT_ORANGE
        "#e74c3c",  // 5: FT_RED
        "#F9E155",  // 6: FT_YELLOW
        "#66BB6A",  // 7: FT_GREEN
        "#006064"   // 8: FT_DARKBLUE
    ]
    
    // Type icons for cases
    property var typeIcons: [
        "🏁",  // 0: CS_KibbleDispenser (Start)
        "🏠",  // 1: CS_RestArea (Property)
        "📦",  // 2: CS_CardBoardBox (Community Chest)
        "🎲",  // 3: CS_CatNip (Chance)
        "🔒",  // 4: CS_Jail
        "👮",  // 5: CS_ToJail (Go to Jail)
        "🚪",  // 6: CS_CatDoor (Railroad)
        "😴",  // 7: CS_FreeNap (Free Parking)
        "⚡",  // 8: CS_Device (Utility)
        "💰",  // 9: CS_Taxe (Tax)
        "❓"   // 10: CS_Unknow
    ]
    

    
    // Function to get family color
    function getFamilyColor(caseData) {
        if (caseData && caseData.type === Case.CS_RestArea && caseData.family !== undefined) {
            return familyColors[caseData.family] || "#ecf0f1"
        }
        return "#ecf0f1"
    }
    
    // Function to get type icon
    function getTypeIcon(caseType) {
        return typeIcons[caseType] || "❓"
    }
    
    // Card display area
    Grid {
        id: cardContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 50
        columns: 5
        spacing: 10
        
        // Create 10 cards
        Repeater {
            model: Game.listCases.length
            delegate : CaseTile {
                required property int index
                width: cardWidth
                height: cardHeight
                caseData: model[index]
                Component.onCompleted: {
                console.log("model[index] " + index)
                }
            }
            // delegate: Rectangle {
            //     id: caseCard

            //     property var caseData: index < Game.listCases.length ? Game.listCases[index] : null

            //     width: cardWidth
            //     height: cardHeight

            //     color: getFamilyColor(caseData)
            //     border.color: "#7f8c8d"
            //     border.width: 2
            //     radius: 8

            //     // Family color bar for properties
            //     Rectangle {
            //         anchors.top: parent.top
            //         anchors.left: parent.left
            //         anchors.right: parent.right
            //         height: 15
            //         color: getFamilyColor(caseData)
            //         visible: caseData && caseData.type === Case.CS_RestArea
            //         border.color: "#7f8c8d"
            //         border.width: 1
            //         radius: 6
            //     }

            //     Column {
            //         anchors.fill: parent
            //         anchors.margins: 8
            //         spacing: 4

            //         // Case name
            //         Text {
            //             width: parent.width
            //             text: caseData ? caseData.name : "Unknown"
            //             color: "#2c3e50"
            //             font.pixelSize: 10
            //             font.bold: true
            //             horizontalAlignment: Text.AlignHCenter
            //             wrapMode: Text.WordWrap
            //             maximumLineCount: 2
            //             elide: Text.ElideRight
            //         }

            //         // Type icon
            //         Text {
            //             anchors.horizontalCenter: parent.horizontalCenter
            //             text: caseData ? getTypeIcon(caseData.type) : "❓"
            //             font.pixelSize: 24
            //         }

            //         // Position number
            //         Text {
            //             anchors.horizontalCenter: parent.horizontalCenter
            //             text: caseData ? "Position: " + caseData.position : "Position: -"
            //             color: "#7f8c8d"
            //             font.pixelSize: 8
            //             font.bold: true
            //         }

            //         // Debug info
            //         Text {
            //             anchors.horizontalCenter: parent.horizontalCenter
            //             text: "Index: " + index
            //             color: "#95a5a6"
            //             font.pixelSize: 6
            //             visible: !caseData || caseData.type === 10 || caseData.position === -1
            //         }

            //         // Specific properties based on case type
            //         Column {
            //             width: parent.width
            //             spacing: 2

            //             // For RestArea (Properties)
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_RestArea
            //                 text: caseData && caseData.price ? "Price: " + caseData.price + "K" : ""
            //                 color: "#2c3e50"
            //                 font.pixelSize: 9
            //                 font.bold: true
            //                 horizontalAlignment: Text.AlignHCenter
            //             }

            //             // For CatPerks (Properties with mortgage)
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_RestArea && caseData.morgagePrice
            //                 text: caseData && caseData.morgagePrice ? "Mortgage: " + caseData.morgagePrice + "K" : ""
            //                 color: "#7f8c8d"
            //                 font.pixelSize: 8
            //                 horizontalAlignment: Text.AlignHCenter
            //             }

            //             // For CatDoor (Railroads)
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_CatDoor
            //                 text: caseData && caseData.price ? "Price: " + caseData.price + "K" : ""
            //                 color: "#2c3e50"
            //                 font.pixelSize: 9
            //                 font.bold: true
            //                 horizontalAlignment: Text.AlignHCenter
            //             }

            //             // For Device (Utilities)
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_Device
            //                 text: caseData && caseData.price ? "Price: " + caseData.price + "K" : ""
            //                 color: "#2c3e50"
            //                 font.pixelSize: 9
            //                 font.bold: true
            //                 horizontalAlignment: Text.AlignHCenter
            //             }

            //             // For Kibble Dispenser (Start/Tax)
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_KibbleDispenser
            //                 text: caseData && caseData.reward ? (caseData.reward > 0 ? "Reward: +" + caseData.reward + "K" : "Tax: " + caseData.reward + "K") : ""
            //                 color: caseData && caseData.reward > 0 ? "#27ae60" : "#e74c3c"
            //                 font.pixelSize: 9
            //                 font.bold: true
            //                 horizontalAlignment: Text.AlignHCenter
            //             }

            //             // For Free Nap
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_FreeNap
            //                 text: caseData && caseData.kibbleAmount ? "Pool: " + caseData.kibbleAmount + "K" : "FREE PARKING"
            //                 color: "#27ae60"
            //                 font.pixelSize: 9
            //                 font.bold: true
            //                 horizontalAlignment: Text.AlignHCenter
            //             }

            //             // Family name for properties
            //             Text {
            //                 width: parent.width
            //                 visible: caseData && caseData.type === Case.CS_RestArea && caseData.family !== undefined
            //                 text: {
            //                     if (caseData && caseData.family !== undefined) {
            //                         var families = ["None", "Brown", "Light Blue", "Pink", "Orange", "Red", "Yellow", "Green", "Dark Blue"]
            //                         return families[caseData.family] || "None"
            //                     }
            //                     return ""
            //                 }
            //                 color: "#7f8c8d"
            //                 font.pixelSize: 8
            //                 horizontalAlignment: Text.AlignHCenter
            //             }
            //         }
            //     }

            //     // Hover effect
            //     Rectangle {
            //         anchors.fill: parent
            //         color: "transparent"
            //         border.color: "#f39c12"
            //         border.width: 3
            //         visible: mouseArea.containsMouse
            //         radius: 8
            //     }

            //     MouseArea {
            //         id: mouseArea
            //         anchors.fill: parent
            //         hoverEnabled: true

            //                         onClicked: {
            //         if (caseData) {
            //             console.log("Clicked case:", caseData.name,
            //                        "Type:", caseData.type,
            //                        "Position:", caseData.position)

            //             // Show detailed info in console
            //             if (caseData.type === Case.CS_RestArea) {
            //                 console.log("  - Family:", caseData.family)
            //                 console.log("  - Price:", caseData.price)
            //                 console.log("  - Mortgage:", caseData.morgagePrice)
            //                 console.log("  - House Price:", caseData.housePrice)
            //                 console.log("  - Hotel Price:", caseData.hotelPrice)
            //                 console.log("  - Rent Prices:", caseData.rentPrice)
            //             }
            //         } else {
            //             console.log("Clicked card", index, "but caseData is null")
            //         }
            //     }
            //     }

            //     // Card index indicator with status
            //     Rectangle {
            //         anchors.top: parent.top
            //         anchors.right: parent.right
            //         anchors.margins: 5
            //         width: 20
            //         height: 20
            //         radius: 10
            //         color: {
            //             if (!caseData) return "#e74c3c"  // Red: No data
            //             if (caseData.type === 10) return "#f39c12"  // Orange: Unknown type
            //             if (caseData.position === -1) return "#e67e22"  // Dark orange: Invalid position
            //             return "#27ae60"  // Green: Valid
            //         }

            //         Text {
            //             anchors.centerIn: parent
            //             text: index + 1
            //             color: "white"
            //             font.pixelSize: 10
            //             font.bold: true
            //         }
            //     }

            //     // Error indicator for invalid cases
            //     Rectangle {
            //         anchors.top: parent.top
            //         anchors.left: parent.left
            //         anchors.margins: 5
            //         width: 15
            //         height: 15
            //         radius: 7
            //         color: "#e74c3c"
            //         visible: !caseData || caseData.type === 10 || caseData.position === -1

            //         Text {
            //             anchors.centerIn: parent
            //             text: "!"
            //             color: "white"
            //             font.pixelSize: 10
            //             font.bold: true
            //         }
            //     }
            // }
        }
    }
    
    // Legend
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10
        width: 220
        height: 140
        color: "#34495e"
        border.color: "#7f8c8d"
        border.width: 1
        radius: 8
        
        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            
            Text {
                text: "CARD LEGEND"
                color: "#ecf0f1"
                font.pixelSize: 12
                font.bold: true
            }
            
            Text {
                text: "🏁 Start (Kibble Dispenser)  🏠 Property"
                color: "#ecf0f1"
                font.pixelSize: 8
            }
            
            Text {
                text: "📦 Community Chest  🎲 Chance"
                color: "#ecf0f1"
                font.pixelSize: 8
            }
            
            Text {
                text: "🔒 Jail  👮 Go to Jail"
                color: "#ecf0f1"
                font.pixelSize: 8
            }
            
            Text {
                text: "🚪 Cat Door (Railroad)  😴 Free Nap"
                color: "#ecf0f1"
                font.pixelSize: 8
            }
            
            Text {
                text: "⚡ Cat Device (Utility)  💰 Tax"
                color: "#ecf0f1"
                font.pixelSize: 8
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: "#7f8c8d"
            }
            
            Text {
                text: "Static card display"
                color: "#f39c12"
                font.pixelSize: 8
                font.italic: true
            }
            
            Text {
                text: "Card dimensions: " + Math.round(cardWidth/Screen.pixelDensity) + "mm x " + Math.round(cardHeight/Screen.pixelDensity) + "mm"
                color: "#ecf0f1"
                font.pixelSize: 7
            }
        }
    }
    
    // Stats
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        width: 180
        height: 120
        color: "#34495e"
        border.color: "#7f8c8d"
        border.width: 1
        radius: 8
        
        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            
            Text {
                text: "CARD STATS"
                color: "#ecf0f1"
                font.pixelSize: 12
                font.bold: true
            }
            
            Text {
                text: "Displaying: " + Math.min(10, Game.listCases.length) + " cards"
                color: "#ecf0f1"
                font.pixelSize: 9
            }
            
            Text {
                text: "Total Cases: " + Game.listCases.length
                color: "#ecf0f1"
                font.pixelSize: 9
            }
            
            Text {
                text: "Card Size: " + Math.round(cardWidth) + "x" + Math.round(cardHeight)
                color: "#ecf0f1"
                font.pixelSize: 9
            }
            
            Text {
                text: "Game Status: " + (Game.listCases.length > 0 ? "Loaded" : "Not Loaded")
                color: Game.listCases.length > 0 ? "#27ae60" : "#e74c3c"
                font.pixelSize: 9
                font.bold: true
            }
            
            Text {
                text: "Click cards for details"
                color: "#f39c12"
                font.pixelSize: 8
                font.italic: true
            }
        }
    }
}
