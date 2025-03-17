import QtQuick
import Game

Timer {
    id: endTurnTimer
    interval: 2000 // 2 seconds delay before ending turn
    repeat: false
    
    signal turnEnded()
    
    onTriggered: {
        Game.nextPlayer();
        turnEnded();
    }
} 