import QtQuick

Timer {
    id: resetDiceStateTimer
    interval: 500
    repeat: false
    
    property Item controlPanel: null
    
    onTriggered: {
        if (controlPanel) {
            controlPanel.rolling = false;
        }
    }
} 