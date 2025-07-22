import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game


Rectangle {
    id: root
    objectName: "gameBoard"
    color: "#2c3e50"  // Dark blue-gray background

    // Track the state of ongoing operations to prevent race conditions
    property bool isHandlingPlayerMovement: false
    property bool isCheckingProperties: false

    property int boardSideSize: Math.floor(Math.sqrt(Game.boardSize))  // Calculate side size from total board size
    property int tileSize: Math.min(width, height) / (boardSideSize + 1)  // Add 1 to account for corner tiles

    // Game board container
    Rectangle {
        id: boardContainer
        width: Math.min(parent.width * 0.8, parent.height * 0.95)
        height: width
        color: "#34495e"  // Slightly lighter blue-gray
        radius: 15
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -playerPanel.width/2
        border.color: "#95a5a6"
        border.width: 2

        BoardGrid {
            id: boardGrid
            anchors {
                fill: parent
                margins: 20
            }
        }
    }

    // Player info panel
    PlayerPanel {
        id: playerPanel
        width: parent.width * 0.2  // Made wider for better display
        height: parent.height
        anchors {
            right: parent.right
            top: parent.top
        }
    }


    // New Compact Dice Control
    CompactDiceControl {
        id: diceControl
        anchors {
            right: playerPanel.left
            bottom: boardContainer.bottom
            leftMargin: parent.width*0.2
            bottomMargin: parent.height*0.02
        }
        
        onDiceRolled: function(dice1, dice2) {
            try {
                // Only check for buyable property if we're not already handling a check
                if (!isCheckingProperties) {
                    // Delay property check to allow animations to complete
                    propertyCheckTimer.restart();
                }
            } catch (e) {
                console.error("Error handling dice rolled event:", e);
            }
        }
    }

    // Game action dialog
    GameActionDialog {
        id: gameActionDialog
        visible: true
        
        // Provide a reference to the board grid for updates
        property var boardGridReference: boardGrid
    }

    // Animation manager for player tokens
    AnimationManager {
        id: animationManager
        anchors.fill: boardContainer
        boardGrid: boardGrid
    }

    // Connect to player movement signals
    Connections {
        target: Game
        
        function onPlayersChanged() {
            // Update player positions on the board when players change
            updatePlayerPositions();
        }
        
        function onCurrentPlayerIndexChanged() {
            // Reset dice control when player changes
            diceControl.resetDiceState();
        }
    }

    // Check if the player landed on a buyable property and show the purchase dialog
    function checkLandedOnBuyableProperty() {
        // Set flag to indicate we're checking properties
        isCheckingProperties = true;
        
        // Safety timer to reset flag if something goes wrong
        propertyCheckResetTimer.restart();
        
        try {
            console.log("Checking if player landed on buyable property");
            
            if (Game.players.length === 0) {
                isCheckingProperties = false;
                return;
            }
            
            if (Game.currentPlayerIndex < 0 || Game.currentPlayerIndex >= Game.players.length) {
                console.error("Invalid current player index:", Game.currentPlayerIndex);
                isCheckingProperties = false;
                return;
            }
            
            var currentPlayer = Game.players[Game.currentPlayerIndex];
            if (!currentPlayer) {
                console.error("Current player is null");
                isCheckingProperties = false;
                return;
            }
            
            var position = currentPlayer.position;
            var boardCase = Game.getCaseAt(position);
            
            if (!boardCase) {
                console.error("No board case at position:", position);
                isCheckingProperties = false;
                return;
            }
            
            console.log("Current tile type: " + boardCase.type + ", name: " + boardCase.name);
            
            // Check if the property is buyable - allow different property types
            // Type 1: RestArea (properties)
            // Type 2: CardBoardBox (utilities)
            var isBuyablePropertyType = (boardCase.type === 1 || boardCase.type === 2);
            
            if (isBuyablePropertyType) {
                // Check if it's unowned and has a price
                if (!boardCase.owner && boardCase.price > 0) {
                    console.log("Property is buyable, showing dialog");
                    
                    // Pass the board grid reference to the dialog
                    gameActionDialog.boardGridReference = boardGrid;
                    
                    // Show purchase dialog with error handling
                    try {
                        gameActionDialog.showBuyProperty();
                    } catch (e) {
                        console.error("Error showing buy property dialog:", e);
                    }
                }
            }
            
            // Clear the property checking flag
            isCheckingProperties = false;
        } catch (e) {
            console.error("Error checking for buyable property:", e);
            isCheckingProperties = false;
        }
    }
    
    // Timer to delay property check after movement
    Timer {
        id: propertyCheckTimer
        interval: 500 // Increased delay to ensure animations complete
        repeat: false
        onTriggered: {
            if (!isCheckingProperties) {
                checkLandedOnBuyableProperty();
            } else {
                console.log("Property check already in progress, skipping");
            }
        }
    }
    
    // Safety timer to reset property checking flag if stuck
    Timer {
        id: propertyCheckResetTimer
        interval: 3000 // 3 seconds
        repeat: false
        onTriggered: {
            if (isCheckingProperties) {
                console.warn("Property checking flag stuck, forcing reset");
                isCheckingProperties = false;
            }
        }
    }
    
    // Listen for player movement and check for buyable property
    Connections {
        target: Game
        
        function onPlayerMoved(oldPosition, newPosition, steps) {
            try {
                console.log("Player moved from " + oldPosition + " to " + newPosition);
                
                // Set handling flag
                isHandlingPlayerMovement = true;
                
                // Force update the board to refresh all tiles
                if (boardGrid) {
                    try {
                        boardGrid.updateAllTiles();
                    } catch (e) {
                        console.error("Error updating board tiles:", e);
                    }
                }
                
                // Schedule check for buyable property after a short delay
                // This ensures the game state is fully updated
                propertyCheckTimer.restart();
                
                // Clear the handling flag after a delay
                movementHandlingTimer.restart();
            } catch (e) {
                console.error("Error handling player movement:", e);
                isHandlingPlayerMovement = false;
            }
        }
    }
    
    // Timer to reset movement handling flag
    Timer {
        id: movementHandlingTimer
        interval: 1000 // 1 second
        repeat: false
        onTriggered: {
            isHandlingPlayerMovement = false;
        }
    }

    // Function to update positions of all player tokens with error handling
    function updatePlayerPositions() {
        try {
            if (!animationManager) {
                console.error("Animation manager is null");
                return;
            }
            
            const players = Game.players;
            for (let i = 0; i < players.length; i++) {
                const player = players[i];
                if (player && player.name) {
                    // Check if animation token exists and update its position
                    try {
                        animationManager.positionTokenAtTile(player.name, player.position);
                    } catch (e) {
                        console.error("Error positioning token for player:", player.name, e);
                    }
                }
            }
        } catch (e) {
            console.error("Error updating player positions:", e);
        }
    }

    // Connect to individual player movement signals
    function connectPlayerSignals() {
        const players = Game.players;
        for (let i = 0; i < players.length; i++) {
            const player = players[i];
            player.playerMoved.connect(function(oldPosition, newPosition, steps) {
                console.log("Player moved signal received for: " + player.name);
                console.log("Old position: " + oldPosition + ", New position: " + newPosition + ", Steps: " + steps);
                
                // Animate the player movement
                animationManager.animatePlayerMovement(player.name, player.color, oldPosition, newPosition, steps);
            });
        }
    }

    // Object to track last movement of each player to prevent duplicate animations
    property var playerMovementTracker: ({})

    Component.onCompleted: {
        registerTilesTimer.start()
        // Connect to game started signal to initialize player tokens
    }

    Timer {
        id: registerTilesTimer
        interval: 100
        repeat: false
        onTriggered: {
            console.log("game started")
            // Clear existing tokens when starting a new game
            animationManager.clearAllTokens();
            playerMovementTracker = {};

            // Connect all player signals
            connectPlayerSignals();

            // Initialize player positions
            updatePlayerPositions();
            registerTilePositions();
        }
    }

    // Register all tile positions for animation paths
    function registerTilePositions() {
        console.log("register tiles")
        var allTiles = findAllTiles(boardGrid);
        
        for (var i = 0; i < allTiles.length; i++) {
            var tile = allTiles[i];
            var tilePos = tile.mapToItem(animationManager, tile.width/2, tile.height/2);
            animationManager.registerTilePosition(tile.tileIndex, tilePos.x, tilePos.y);
        }
    }

    // Find all BoardTile objects in the board
    function findAllTiles(parent) {
        var tiles = [];
        
        for (var i = 0; i < parent.children.length; i++) {
            var child = parent.children[i];
            
            // If the child is a Repeater, scan its delegates
            if (child.hasOwnProperty("model") && child.hasOwnProperty("count")) {
                for (var j = 0; j < child.count; j++) {
                    var item = child.itemAt(j);
                    if (item && item.hasOwnProperty("tileIndex")) {
                        tiles.push(item);
                    }
                }
            }
            // If it's a container, scan its children
            else if (child.hasOwnProperty("children")) {
                var childTiles = findAllTiles(child);
                for (var k = 0; k < childTiles.length; k++) {
                    tiles.push(childTiles[k]);
                }
            }
            // If it's a BoardTile, add it
            else if (child.hasOwnProperty("tileIndex")) {
                tiles.push(child);
            }
        }
        
        return tiles;
    }

    // Helper functions to get board tile information from the Game
    function getBoardTileType(index) {
        if (index < 0 || index >= Game.boardSize) return -1;
        var boardCase = Game.getCaseAt(index);
        return boardCase ? boardCase.type : -1;
    }

    function getBoardTileName(index) {
        if (index < 0 || index >= Game.boardSize) return "Empty";
        var boardCase = Game.getCaseAt(index);
        return boardCase ? boardCase.name : "Unknown";
    }

    function getBoardTileData(index) {
        if (index < 0 || index >= Game.boardSize) return null;
        var boardCase = Game.getCaseAt(index);
        if (!boardCase) return null;

        var data = {};
        data.position = index;

        // Add specific properties based on tile type
        if (boardCase.type === 1) { // Rest Area
            data.family = boardCase.family;
            data.restQuality = boardCase.restQuality;
            data.owner = boardCase.owner ? boardCase.owner.name : null;
            data.price = boardCase.price;
            data.prices = boardCase.prices;
        } else if (boardCase.type === 0) { // Kibble Dispenser
            data.reward = boardCase.reward;
        } else if (boardCase.type === 4) { // Jail
            data.fine = boardCase.fine;
        }

        return data;
    }

    // Calculate positions for tiles
    function getTileX(index) {
        if (index === 0) return 0;  // Start position
        if (index <= boardSideSize) return index * tileSize;  // Top row
        if (index <= 2 * boardSideSize) return boardSideSize * tileSize;  // Right column
        if (index <= 3 * boardSideSize) return (3 * boardSideSize - index) * tileSize;  // Bottom row
        return 0;  // Left column
    }

    function getTileY(index) {
        if (index === 0) return 0;  // Start position
        if (index <= boardSideSize) return 0;  // Top row
        if (index <= 2 * boardSideSize) return (index - boardSideSize) * tileSize;  // Right column
        if (index <= 3 * boardSideSize) return boardSideSize * tileSize;  // Bottom row
        return (4 * boardSideSize - index) * tileSize;  // Left column
    }

    function getTileRotation(index) {
        if (index <= boardSideSize) return 0;  // Top row
        if (index <= 2 * boardSideSize) return 90;  // Right column
        if (index <= 3 * boardSideSize) return 180;  // Bottom row
        return 270;  // Left column
    }
} 
