import QtQuick
import Game

// Shared component for player turn management
Item {
    id: root
    
    // Properties
    property bool hasDiceRolled: false
    
    // Signals
    signal turnEnded()
    
    // Function to handle ending the current player's turn
    function endTurn() {
        console.log("Ending turn for player: " + Game.players[Game.currentPlayerIndex].name);
        Game.nextPlayer();
        turnEnded();
        console.log("Turn ended, next player: " + Game.players[Game.currentPlayerIndex].name);
    }
    
    // Function to check if it's valid to end turn
    function canEndTurn() {
        return hasDiceRolled && Game.players.length > 0;
    }
    
    // Timer for delayed end turn (can be used by other components)
    Timer {
        id: delayedEndTurnTimer
        interval: 2000 // 2 seconds delay
        repeat: false
        
        onTriggered: {
            endTurn();
        }
    }
    
    // Start delayed end turn
    function endTurnWithDelay() {
        delayedEndTurnTimer.start();
    }
} 