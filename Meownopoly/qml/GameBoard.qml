import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game


Rectangle {
    id: root
    color: "#2c3e50"  // Dark blue-gray background

    property int boardSideSize: Math.floor(Math.sqrt(Game.boardSize))  // Calculate side size from total board size

    // Game board container
    Rectangle {
        id: boardContainer
        width: Math.min(parent.width * 0.8, parent.height - controlPanel.height - 10 )
        height: width
        color: "#34495e"  // Slightly lighter blue-gray
        radius: 15
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -playerPanel.width/2
        anchors.verticalCenterOffset: -controlPanel.height/2
        border.color: "#95a5a6"
        border.width: 2

        BoardGrid {
            id: boardGrid

            anchors {
                fill: parent
                margins: 10
            }
        }
    }

    // Player info panel
    PlayerPanel {
        id: playerPanel
        width: parent.width * 0.2  // Made wider for better display
        height: parent.height
        anchors {
            right: parent.right
            top: parent.top
        }
    }

    // Game controls
    ControlPanel {
        id: controlPanel
        height: 60
        anchors {
            left: parent.left
            right: playerPanel.left
            bottom: parent.bottom
        }
    }

} 
