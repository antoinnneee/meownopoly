import QtQuick
import Game

// Instead of reinventing this timer, use the TurnManager
TurnManager {
    id: endTurnTimer
    
    Component.onCompleted: {
        // For backward compatibility, start the delayed end turn timer
        endTurnWithDelay();
    }
} 