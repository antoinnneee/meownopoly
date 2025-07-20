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
    property real cardWidth: Screen.pixelDensity * 20  // 2.5cm
    property real cardHeight: Screen.pixelDensity * 35   // Alternative height

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

    // Card display area
    RowLayout {
        id: cardContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 50
        spacing: 10

        Repeater {
            id : repeater
            model: 10
            delegate : CaseTile {
                required property int index
                // required property Case modelData : Game.listCases[index]

                width: cardWidth
                height: cardHeight
                caseData: Game.listCases[index]
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
