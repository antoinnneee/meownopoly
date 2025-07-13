import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Rectangle {
    id: root
    width: 200
    height: 150
    color: "#34495e"
    radius: 8
    
    // Use the DiceBase component for core dice functionality
    DiceBase {
        id: diceCore
        
        // Forward signals with error handling
        onDiceRolled: function(dice1, dice2) {
            try {
                root.diceRolled(dice1, dice2);
            } catch (e) {
                console.error("Error in dice rolled handler:", e);
            }
        }
    }
    
    // Use TurnManager for core turn functionality
    TurnManager {
        id: turnManager
        hasDiceRolled: diceCore.hasDiceRolled
    }
    
    // Properties forwarded from DiceBase
    property alias diceValue1: diceCore.diceValue1
    property alias diceValue2: diceCore.diceValue2
    property alias isDiceRolling: diceCore.isDiceRolling
    property alias hasDiceRolled: diceCore.hasDiceRolled
    
    // Signals
    signal diceRolled(int dice1, int dice2)
    
    // Guard against multiple simultaneous dice rolls
    property bool isProcessingRoll: false
    
    // Current player indicator at the top
    Item {
        id: playerIndicator
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        height: 20
        
        Row {
            spacing: 5
            anchors.centerIn: parent
            
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: "#27ae60"
                anchors.verticalCenter: parent.verticalCenter
                visible: Game.players.length > 0
            }
            
            Text {
                text: {
                    if (Game.players.length > 0 && Game.currentPlayerIndex >= 0) {
                        return Game.players[Game.currentPlayerIndex].name + "'s turn"
                    }
                    return "No players"
                }
                color: "white"
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
    
    // Actual dice display and UI
    ColumnLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 5
        
        Text {
            text: "Dice"
            font.pixelSize: 16
            font.bold: true
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Dice display (compact)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 15
            
            // First Die
            Rectangle {
                width: 35
                height: 35
                radius: 5
                color: "white"
                border.color: "#bdc3c7"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: diceValue1
                    color: "black"
                    font.pixelSize: 18
                    font.bold: true
                }
            }
            
            // Second Die
            Rectangle {
                width: 35
                height: 35
                radius: 5
                color: "white"
                border.color: "#bdc3c7"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: diceValue2
                    color: "black"
                    font.pixelSize: 18
                    font.bold: true
                }
            }
            
            // Total
            Rectangle {
                width: 35
                height: 35
                radius: 5
                color: "#2c3e50"
                border.color: "#2980b9"
                border.width: 1
                visible: diceValue1 > 0 && diceValue2 > 0
                
                Text {
                    anchors.centerIn: parent
                    text: diceValue1 + diceValue2
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }
            }
        }
        
        // Dice actions
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            
            // Roll Button
            Button {
                width: 75
                height: 32
                text: "Roll"
                enabled: !hasDiceRolled && Game.players.length > 0
                
                background: Rectangle {
                    color: parent.pressed ? "#27ae60" : (parent.enabled ? "#2ecc71" : "#95a5a6")
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    font.bold: true
                }
                
                onClicked: {
                    rollDice();
                }
            }
            
            // End Turn Button
            Button {
                width: 75
                height: 32
                text: "End Turn"
                enabled: hasDiceRolled && Game.players.length > 0
                
                background: Rectangle {
                    color: parent.pressed ? "#3498db" : (parent.enabled ? "#2980b9" : "#95a5a6")
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    font.bold: true
                }
                
                onClicked: {
                    console.log("End turn clicked");
                    Game.nextPlayer();
                    resetDiceState();
                    console.log("Turn ended - Reset dice states");
                }
            }
        }
    }
    
    // Function to roll dice - delegates to diceCore with safety checks
    function rollDice() {
        if (isDiceRolling || isProcessingRoll) {
            console.log("Ignoring roll request - dice already rolling");
            return;
        }
        
        // Set processing flag to prevent multiple rolls
        isProcessingRoll = true;
        
        // Safety timer to reset processing state if something goes wrong
        processingResetTimer.restart();
        
        try {
            console.log("Rolling dice...");
            diceCore.rollDice();
        } catch (e) {
            console.error("Error rolling dice:", e);
            isProcessingRoll = false;
        }
    }
    
    // Reset dice state - delegates to diceCore with safety checks
    function resetDiceState() {
        try {
            diceCore.resetDiceState();
            isProcessingRoll = false;
        } catch (e) {
            console.error("Error resetting dice state:", e);
        }
    }
    
    // Safety timer to reset processing state if stuck
    Timer {
        id: processingResetTimer
        interval: 5000 // 5 seconds
        repeat: false
        onTriggered: {
            if (isProcessingRoll) {
                console.warn("Dice processing state stuck, forcing reset");
                isProcessingRoll = false;
                diceCore.isDiceRolling = false;
            }
        }
    }
    
    // When dice rolling completes, clear the processing flag
    Connections {
        target: diceCore
        function onDiceRolled() {
            // Clear processing flag after a short delay to ensure all handlers have executed
            resetProcessingTimer.restart();
        }
    }
    
    Timer {
        id: resetProcessingTimer
        interval: 500 // Half-second delay
        repeat: false
        onTriggered: {
            isProcessingRoll = false;
        }
    }
} 
