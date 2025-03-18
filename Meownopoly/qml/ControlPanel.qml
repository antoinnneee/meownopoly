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
    property bool isDiceRolling: false
    property bool hasDiceRolled: false  // Track if dice were rolled this turn
    property bool isPropertyBuyable: false  // Track if current tile is a buyable property
    property int propertyPrice: 0  // Track the price of the property
    property string propertyName: ""  // Track the name of the property

    // Fixed timers
    DiceRollTimer {
        id: diceTimer
        controlPanel: root
        
        onRollComplete: function(dice1, dice2) {
            let steps = dice1 + dice2;
            
            // Signal that dice are rolled
            root.diceRolled(dice1, dice2);
            
            // Move the player
            Game.movePlayer(Game.currentPlayerIndex, steps);
            
            // Update property status after moving
            updatePropertyStatus();
            
            // Important: Set dice states
            hasDiceRolled = true;
            isDiceRolling = false;
            
            console.log("Dice roll complete. hasDiceRolled: " + hasDiceRolled + ", isDiceRolling: " + isDiceRolling);
            
            // Check if doubles
            if (dice1 === dice2) {
                console.log("Rolled doubles! Player gets another turn.");
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
    
    // Signal when dice are rolled
    signal diceRolled(int dice1, int dice2)

    // Initialize property status when the control panel is created
    Component.onCompleted: {
        updatePropertyStatus();
        console.log("ControlPanel initialized");
    }
    
    // Track changes in player position to update property buyable status
    Connections {
        target: Game
        
        function onCurrentPlayerIndexChanged() {
            // Reset dice roll status for the new player's turn
            hasDiceRolled = false;
            isDiceRolling = false;
            updatePropertyStatus();
            console.log("Player changed - Reset dice states. hasDiceRolled: " + hasDiceRolled);
        }
        
        function onPlayersChanged() {
            // Player data changed, check if property status needs updating
            updatePropertyStatus();
        }
    }
    
    // Update the property buyable status based on current player position
    function updatePropertyStatus() {
        console.log("Updating property status...");
        if (Game.players.length === 0) {
            isPropertyBuyable = false;
            return;
        }
        
        var currentPlayer = Game.players[Game.currentPlayerIndex];
        if (!currentPlayer) {
            isPropertyBuyable = false;
            return;
        }
        
        var position = currentPlayer.position;
        var boardCase = Game.getCaseAt(position);
        
        if (!boardCase) {
            isPropertyBuyable = false;
            return;
        }
        
        console.log("Current tile type: " + boardCase.type + ", name: " + boardCase.name);
        
        // Check if the property is buyable - allow different property types
        // Type 1: RestArea
        // Type 2: CardBoardBox
        var isBuyablePropertyType = (boardCase.type === 1 || boardCase.type === 2);
        
        if (isBuyablePropertyType) {
            // Check if it's unowned and has a price
            if (!boardCase.owner && boardCase.price > 0) {
                isPropertyBuyable = true;
                propertyPrice = boardCase.price;
                propertyName = boardCase.name;
                console.log("Property is buyable: " + propertyName + " for " + propertyPrice + "K");
            } else {
                isPropertyBuyable = false;
                console.log("Property is not buyable (already owned or no price)");
            }
        } else {
            isPropertyBuyable = false;
            console.log("Current tile is not a buyable property (type " + boardCase.type + ")");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5
        
        // Debug info text (hidden in release)
        Text {
            text: "hasDiceRolled: " + hasDiceRolled + " | isDiceRolling: " + isDiceRolling
            color: "#e74c3c"
            font.pixelSize: 10
            Layout.margins: 2
            visible: false // Set to true for debugging
        }
        
        // Main control panel row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.6
            spacing: 15
            Layout.margins: 10

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
                
                // Modified button state logic
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
                    rollDice()
                }
            }

            Button {
                id: endTurnButton
                text: "End Turn"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                
                // Modified button state logic
                enabled: hasDiceRolled && Game.players.length > 0
                
                background: Rectangle {
                    color: endTurnButton.pressed ? "#3498db" : (endTurnButton.enabled ? "#2980b9" : "#95a5a6")
                    radius: 6
                }
                
                contentItem: Text {
                    text: endTurnButton.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    console.log("End turn clicked");
                    Game.nextPlayer();
                    hasDiceRolled = false;
                    isDiceRolling = false;
                    updatePropertyStatus();
                    console.log("Turn ended - Reset dice states. hasDiceRolled: " + hasDiceRolled);
                }
            }
        }
        
        // Property purchase section - separate row
        Rectangle {
            visible: isPropertyBuyable && hasDiceRolled
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.3
            color: "#27ae60"  // Green color for buy button
            radius: 5
            Layout.margins: 10
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                
                Column {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Text {
                        text: "Buy " + propertyName + "?"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        width: parent.width
                        elide: Text.ElideRight
                    }
                    
                    Text {
                        text: "Price: " + propertyPrice + "K"
                        color: "white"
                        font.pixelSize: 14
                    }
                }
                
                Button {
                    text: "Buy Now"
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: parent.pressed ? "#2c3e50" : "#34495e"
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        // Call the game's buy property function
                        var success = Game.buyProperty(Game.currentPlayerIndex, Game.players[Game.currentPlayerIndex].position);
                        if (success) {
                            // Successfully purchased
                            console.log("Property purchased successfully!");
                            updatePropertyStatus(); // Update the button status
                        } else {
                            // Failed to purchase (not enough money, etc.)
                            console.log("Could not purchase property");
                        }
                    }
                }
            }
        }
    }
    
    // Function to simulate rolling dice
    function rollDice() {
        if (isDiceRolling) return;
        
        console.log("Rolling dice...");
        isDiceRolling = true;
        diceTimer.startRoll();
    }
} 
