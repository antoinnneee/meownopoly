import QtQuick
import Game

Timer {
    id: diceRollTimer
    interval: 100
    repeat: true
    
    property int rollCount: 0
    property int maxRolls: 10
    property Item controlPanel: null
    
    signal rollComplete(int dice1, int dice2)
    
    onTriggered: {
        if (!controlPanel) {
            console.error("ControlPanel reference is missing");
            stop();
            return;
        }
        
        // Generate random dice values
        controlPanel.diceValue1 = Math.floor(Math.random() * 6) + 1;
        controlPanel.diceValue2 = Math.floor(Math.random() * 6) + 1;
        
        rollCount++;
        
        if (rollCount >= maxRolls) {
            stop();
            
            // Signal roll is complete
            rollComplete(controlPanel.diceValue1, controlPanel.diceValue2);
            
            // Reset for next use
            rollCount = 0;
        }
    }
    
    function startRoll() {
        if (!controlPanel) {
            console.error("Cannot start roll - ControlPanel reference is missing");
            return;
        }
        
        rollCount = 0;
        start();
    }
} 