import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Rectangle {
    id: root
    color: "#34495e"
    
    // Use TurnManager for core turn functionality
    TurnManager {
        id: turnManager
        hasDiceRolled: root.hasDiceRolled
        
        onTurnEnded: {
            root.turnEnded();
        }
    }
    
    // Properties
    property bool hasDiceRolled: false  // This is set by the parent
    
    // Signals
    signal turnEnded()
    
    RowLayout {
        anchors.fill: parent
        spacing: 15
        
        // Current player indicator
        Rectangle {
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: "#27ae60"
            visible: Game.players.length > 0
        }
        
        Text {
            text: {
                if (Game.players.length > 0 && Game.currentPlayerIndex >= 0 && Game.currentPlayerIndex < Game.players.length) {
                    return Game.players[Game.currentPlayerIndex].name + "'s turn"
                }
                return "No players"
            }
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }
        
        Item { Layout.fillWidth: true }
        
        Button {
            id: endTurnButton
            text: "End Turn"
            Layout.preferredWidth: 120
            Layout.preferredHeight: 40
            
            // Button state logic
            enabled: turnManager.canEndTurn()
            
            background: Rectangle {
                color: endTurnButton.pressed ? "#3498db" : (endTurnButton.enabled ? "#2980b9" : "#95a5a6")
                radius: 6
            }
            
            contentItem: Text {
                text: endTurnButton.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                turnManager.endTurn();
            }
        }
    }
} 