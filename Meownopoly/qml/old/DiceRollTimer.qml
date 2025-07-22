import QtQuick

Timer {
    id: root
    interval: 50
    repeat: true
    running: false
    
    property var controlPanel
    property int rollCount: 0
    property int maxRolls: 20
    property int dice1: 1
    property int dice2: 1
    
    signal rollComplete(int dice1, int dice2)
    
    onTriggered: {
        // Generate random dice values during animation
        dice1 = Math.floor(Math.random() * 6) + 1;
        dice2 = Math.floor(Math.random() * 6) + 1;
        
        // Update the control panel's dice values
        if (controlPanel) {
            controlPanel.diceValue1 = dice1;
            controlPanel.diceValue2 = dice2;
        }
        
        rollCount++;
        
        // Stop after a certain number of rolls
        if (rollCount >= maxRolls) {
            stop();
            
            // Emit the rollComplete signal with final values
            rollComplete(dice1, dice2);
        }
    }
    
    function startRoll() {
        rollCount = 0;
        
        // Start the animation
        start();
    }
} 