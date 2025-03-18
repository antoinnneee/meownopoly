import QtQuick

Timer {
    id: resetDiceStateTimer
    interval: 500 // Half second delay
    repeat: false
    
    property var controlPanel: null
    
    onTriggered: {
        if (controlPanel) {
            console.log("ResetDiceStateTimer: Resetting isDiceRolling to false");
            controlPanel.isDiceRolling = false;
        } else {
            console.error("ResetDiceStateTimer: No control panel reference provided");
        }
    }
} 
