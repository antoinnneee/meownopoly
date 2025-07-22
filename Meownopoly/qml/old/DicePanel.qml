import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Rectangle {
    id: root
    color: "#34495e"
    
    // Use the DiceBase component for core dice functionality
    DiceBase {
        id: diceCore
        
        // Forward signals
        onDiceRolled: function(dice1, dice2) {
            root.diceRolled(dice1, dice2);
        }
    }
    
    // Properties forwarded from DiceBase
    property alias diceValue1: diceCore.diceValue1
    property alias diceValue2: diceCore.diceValue2
    property alias isDiceRolling: diceCore.isDiceRolling
    property alias hasDiceRolled: diceCore.hasDiceRolled
    
    // Signals
    signal diceRolled(int dice1, int dice2)
    
    RowLayout {
        anchors.fill: parent
        spacing: 15
        
        // Debug info text (hidden in release)
        Text {
            text: "hasDiceRolled: " + hasDiceRolled + " | isDiceRolling: " + isDiceRolling
            color: "#e74c3c"
            font.pixelSize: 10
            visible: true // Set to true for debugging
            Layout.alignment: Qt.AlignLeft
        }
        
        Item { Layout.fillWidth: true }
        
        // Dice display
        Row {
            spacing: 10
            Layout.alignment: Qt.AlignCenter
            
            Rectangle {
                width: 40
                height: 40
                radius: 6
                color: "white"
                border.color: "#bdc3c7"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: root.diceValue1
                    color: "black"
                    font.pixelSize: 20
                    font.bold: true
                }
            }
            
            Rectangle {
                width: 40
                height: 40
                radius: 6
                color: "white"
                border.color: "#bdc3c7"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: root.diceValue2
                    color: "black"
                    font.pixelSize: 20
                    font.bold: true
                }
            }
        }
        
        Button {
            text: "Roll Dice"
            id: buttonRoll
            Layout.preferredWidth: 120
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignRight
            
            // Button state logic
            enabled: !hasDiceRolled && Game.players.length > 0
            
            background: Rectangle {
                color: buttonRoll.pressed ? "#2ecc71" : (buttonRoll.enabled ? "#27ae60" : "#95a5a6")
                radius: 6
            }
            
            contentItem: Text {
                text: buttonRoll.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                diceCore.rollDice();
            }
        }
    }
    
    // Function to roll dice - delegates to diceCore
    function rollDice() {
        diceCore.rollDice();
    }
    
    // Reset dice state - delegates to diceCore
    function resetDiceState() {
        diceCore.resetDiceState();
    }
} 