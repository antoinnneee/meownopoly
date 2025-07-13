import QtQuick
import QtQuick.Controls
import Game

// Base component for dice rolling functionality
Item {
    id: root
    
    // Properties
    property int diceValue1: 1
    property int diceValue2: 1
    property bool isDiceRolling: false
    property bool hasDiceRolled: false  // Track if dice were rolled this turn
    
    // Signals
    signal diceRolled(int dice1, int dice2)
    
    // Dice roll timer
    DiceRollTimer {
        id: diceTimer
        controlPanel: root
        
        onRollComplete: function(dice1, dice2) {
            try {
                let steps = dice1 + dice2;
                
                // Signal that dice are rolled
                root.diceRolled(dice1, dice2);
                
                // Only move player if valid dice values
                if (dice1 >= 1 && dice2 >= 1) {
                    // Safety check for valid player index and game state
                    if (Game.players.length > 0 && Game.currentPlayerIndex >= 0 && 
                        Game.currentPlayerIndex < Game.players.length) {
                        // Move the player
                        Game.movePlayer(Game.currentPlayerIndex, steps);
                        
                        // Important: Set dice states
                        hasDiceRolled = true;
                        isDiceRolling = false;
                        
                        console.log("Dice roll complete. hasDiceRolled: " + hasDiceRolled + 
                                    ", isDiceRolling: " + isDiceRolling);
                        
                        // Check if doubles
                        if (dice1 === dice2) {
                            console.log("Rolled doubles! Player gets another turn.");
                        }
                    } else {
                        console.error("Invalid player index or no players");
                        resetDiceState();
                    }
                } else {
                    console.error("Invalid dice values:", dice1, dice2);
                    resetDiceState();
                }
            } catch (e) {
                console.error("Error handling dice roll:", e);
                // Reset dice state to recover
                resetEmergencyState();
            }
        }
    }
    
    // Timer to manually reset dice rolling state if it gets stuck
    Timer {
        id: diceStateResetTimer
        interval: 3000  // 3 seconds safety timeout
        repeat: false
        running: isDiceRolling
        onTriggered: {
            console.log("Safety timer triggered - resetting dice state");
            isDiceRolling = false;
        }
    }
    
    // Emergency recovery timer
    Timer {
        id: emergencyResetTimer
        interval: 5000  // 5 seconds safety timeout
        repeat: false
        onTriggered: {
            console.log("Emergency reset timer triggered");
            resetEmergencyState();
        }
    }
    
    // Function to simulate rolling dice with error handling
    function rollDice() {
        try {
            if (isDiceRolling) {
                console.log("Already rolling, ignoring roll request");
                return;
            }
            
            // Safety check for valid game state
            if (Game.players.length === 0 || Game.currentPlayerIndex < 0 || 
                Game.currentPlayerIndex >= Game.players.length) {
                console.error("Cannot roll dice: invalid game state");
                return;
            }
            
            console.log("Rolling dice...");
            isDiceRolling = true;
            
            // Start emergency timer as a safety net
            emergencyResetTimer.restart();
            
            diceTimer.startRoll();
        } catch (e) {
            console.error("Error initiating dice roll:", e);
            resetEmergencyState();
        }
    }
    
    // Reset dice state with error handling
    function resetDiceState() {
        try {
            hasDiceRolled = false;
            isDiceRolling = false;
            emergencyResetTimer.stop();
            console.log("Dice states reset. hasDiceRolled: " + hasDiceRolled);
        } catch (e) {
            console.error("Error resetting dice state:", e);
        }
    }
    
    // Emergency reset function to recover from any state
    function resetEmergencyState() {
        console.warn("Performing emergency dice state reset");
        hasDiceRolled = false;
        isDiceRolling = false;
        diceTimer.stop();
        diceStateResetTimer.stop();
        emergencyResetTimer.stop();
    }
} 