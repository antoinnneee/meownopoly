import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Rectangle {
    id: root
    color: "#34495e"

    property int diceValue1: 1
    property int diceValue2: 1
    property bool rolling: false

    RowLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 15

        // Current player indicator
        Rectangle {
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: "#27ae60"
            visible: Game.players.length > 0
        }

        Text {
            text: {
                if (Game.players.length > 0 && Game.currentPlayerIndex >= 0 && Game.currentPlayerIndex < Game.players.length) {
                    return Game.players[Game.currentPlayerIndex].name + "'s turn"
                }
                return "No players"
            }
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }

        Item { Layout.fillWidth: true }

        // Dice display
        Row {
            spacing: 10
            
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
            enabled: !rolling && Game.players.length > 0
            
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
                rollDice()
            }
        }

        Button {
            text: "End Turn"
            Layout.preferredWidth: 120
            Layout.preferredHeight: 40
            enabled: !rolling && Game.players.length > 0
            
            background: Rectangle {
                color: parent.pressed ? "#3498db" : (parent.enabled ? "#2980b9" : "#95a5a6")
                radius: 6
            }
            
            contentItem: Text {
                text: parent.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                Game.nextPlayer()
            }
        }
    }
    
    // Function to simulate rolling dice
    function rollDice() {
        rolling = true
        
        // Animation for rolling
        let rollCount = 0
        let maxRolls = 10
        
        let rollTimer = rollTimerComponent.createObject(root)
        rollTimer.start()
    }
    
    // Timer component for dice rolling animation
    Component {
        id: rollTimerComponent
        
        Timer {
            interval: 100
            repeat: true
            property int rollCount: 0
            property int maxRolls: 10
            
            onTriggered: {
                // Generate random dice values
                root.diceValue1 = Math.floor(Math.random() * 6) + 1
                root.diceValue2 = Math.floor(Math.random() * 6) + 1
                
                rollCount++
                
                if (rollCount >= maxRolls) {
                    stop()
                    finishRoll()
                    destroy()
                }
            }
            
            function finishRoll() {
                let steps = root.diceValue1 + root.diceValue2
                Game.movePlayer(Game.currentPlayerIndex, steps)
                
                // Check if the dice values are the same (doubles)
                if (root.diceValue1 === root.diceValue2) {
                    console.log("Rolled doubles! Player gets another turn.")
                    // Player gets another turn
                } else {
                    // End turn if not doubles
                    /*
                      that not work qrc:/qml/ControlPanel.qml:178: ReferenceError: setTimeout is not defined
                    setTimeout(function() {
                        Game.nextPlayer()
                    }, 2000)
                    */
                }
                
                root.rolling = false
            }
        }
    }
} 
