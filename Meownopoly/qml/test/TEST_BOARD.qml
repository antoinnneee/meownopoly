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

    Button {
        property alias rp : repeater

        width : 50
        height: width
            CaseTile {
                visible:false
                id: tile
                caseData: Game.getNewCaseType(Case.CS_CatDoor)
                width: 100
                height: 50
            }
            onClicked:{
            rp.push(tile)
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

        Repeater {
            id : repeater
            model: Game.listCases
            delegate : CaseTile {
                required property Case modelData

                width: cardWidth
                height: cardHeight
                caseData: modelData
            }
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
