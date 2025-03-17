import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game


Rectangle {
    id: root
    color: "#2c3e50"  // Dark blue-gray background

    property int boardSideSize: Math.floor(Math.sqrt(Game.boardSize))  // Calculate side size from total board size
    property int tileSize: Math.min(width, height) / (boardSideSize + 1)  // Add 1 to account for corner tiles

    // Game board container
    Rectangle {
        id: boardContainer
        width: Math.min(parent.width * 0.8, parent.height * 0.8)
        height: width
        color: "#34495e"  // Slightly lighter blue-gray
        radius: 15
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -playerPanel.width/2
        anchors.verticalCenterOffset: -controlPanel.height/2
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

    // Game controls
    ControlPanel {
        id: controlPanel
        height: 60
        anchors {
            left: parent.left
            right: playerPanel.left
            bottom: parent.bottom
        }
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
            // Player data may have changed (including positions)
            // Disconnect old signal connections and create new ones
            connectPlayerSignals();
        }
    }

    // Register tile positions for animation paths when tiles are created
    Component.onCompleted: {
        // Wait for layout to be complete
        registerTilesTimer.start();
    }

    Timer {
        id: registerTilesTimer
        interval: 100
        repeat: false
        onTriggered: {
            registerTilePositions();
            connectPlayerSignals();
        }
    }

    // Register all tile positions for animation paths
    function registerTilePositions() {
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

    // Connect to player signals for movement
    function connectPlayerSignals() {
        // First, clear any previous connections
        for (var player in playerConnections) {
            if (playerConnections[player]) {
                playerConnections[player].disconnect();
                playerConnections[player] = null;
            }
        }
        
        playerConnections = {}; // Reset connections
        
        // Then create new connections with proper indexing
        for (var i = 0; i < Game.players.length; i++) {
            var player = Game.players[i];
            var playerName = player.name;
            
            // Use an immediately invoked function expression to capture the current player
            (function(currentPlayer, playerIndex) {
                console.log("Connecting player signals for: " + currentPlayer.name + " (index: " + playerIndex + ")");
                
                // Store the connection handler for later disconnection
                playerConnections[currentPlayer.name] = currentPlayer.playerMoved.connect(
                    function(oldPos, newPos, steps) {
                        console.log("Player moved signal received for: " + currentPlayer.name);
                        console.log("Old position: " + oldPos + ", New position: " + newPos + ", Steps: " + steps);
                        animationManager.animatePlayerMovement(currentPlayer, oldPos, newPos, steps);
                    }
                );
            })(player, i);
        }
    }
    
    // Keep track of player connections to properly disconnect them
    property var playerConnections: ({})

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
