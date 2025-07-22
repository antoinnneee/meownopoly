import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Rectangle {
    id: root
    color: "#34495e"

    // Shared state properties
    property bool hasDiceRolled: dicePanel.hasDiceRolled
    
    // Main container layout
        RowLayout {
            anchors.fill: parent
            Layout.preferredHeight: parent.height * 0.6
            Layout.margins: 10
            spacing: 10

            
            // Dice rolling panel
            DicePanel {
                id: dicePanel
                Layout.fillHeight: true
                Layout.fillWidth: true
                
                onDiceRolled: function(dice1, dice2) {
                    // Update property status after moving
                    propertyPanel.updatePropertyStatus();
                }
            }
        
        // Property purchase panel
        PropertyPurchasePanel {
            id: propertyPanel
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.3
            Layout.margins: 10
            hasDiceRolled: root.hasDiceRolled
        }
        // Player turn management panel
        PlayerTurnPanel {
            id: playerTurnPanel
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.3
            hasDiceRolled: root.hasDiceRolled

            onTurnEnded: {
                // Reset dice state when turn ends
                dicePanel.resetDiceState();
                // Update property status
                propertyPanel.updatePropertyStatus();
            }
        }
    }
    
    // Connections to game events
    Connections {
        target: Game
        
        function onCurrentPlayerIndexChanged() {
            // Reset dice roll status for the new player's turn
            dicePanel.resetDiceState();
            propertyPanel.updatePropertyStatus();
        }
    }
    
    Component.onCompleted: {
        console.log("ControlPanel initialized");
        propertyPanel.updatePropertyStatus();
    }
} 
