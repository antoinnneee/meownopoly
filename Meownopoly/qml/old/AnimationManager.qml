import QtQuick
import QtQuick.Controls
import Game 1.0

Item {
    id: animationManager
    
    // Reference to the game board grid
    property var boardGrid: null
    
    // Board mapping
    property var tilePositions: []
    property var activeAnimations: []
    
    // Store info about currently animating players
    property var movingPlayers: ({})
    
    property var playerTokens: ({}) // Store player tokens permanently
    
    Component.onCompleted: {
        // Initialize to empty array
        var positions = new Array(Game.boardSize);
        tilePositions = positions;
    }
    
    // Record a tile's position for animation paths
    function registerTilePosition(tileIndex, centerX, centerY) {
        tilePositions[tileIndex] = { x: centerX, y: centerY };
    }
    
    // Get the central position of a tile
    function getTilePosition(tileIndex) {
        if (tileIndex >= 0 && tileIndex < tilePositions.length && tilePositions[tileIndex]) {
            return tilePositions[tileIndex];
        }
        return null;
    }
    
    // Function to animate player movement
    function animatePlayerMovement(playerName, playerColor, oldPosition, newPosition, steps) {
        console.log("Animating player movement for: " + playerName);
        console.log("Old position: " + oldPosition + ", New position: " + newPosition + ", Steps: " + steps);
        
        // If animation is already running for this player, cancel it
        if (movementAnimation.running && movementAnimation.playerName === playerName) {
            movementAnimation.stop();
        }
        
        // Don't create a new token if one already exists for this player
        let playerToken = playerTokens[playerName];
        
        if (!playerToken) {
            // Create a new player token if it doesn't exist
            var tokenComponent = Qt.createComponent("BoardTile.qml");
            if (tokenComponent.status === Component.Ready) {
                playerToken = tokenComponent.createObject(animationManager, {
                    width: 30,
                    height: 30,
                    color: playerColor,
                    tileName: playerName,
                    isAnimationToken: true
                });
                
                // Store token in our map for future use
                playerTokens[playerName] = playerToken;
            } else {
                console.error("Error creating player token component:", tokenComponent.errorString());
                return;
            }
        }
        
        // Position the token at the old position tile
        const oldTile = boardGrid.getTileAt(oldPosition);
        if (oldTile) {
            playerToken.x = oldTile.x + (oldTile.width - playerToken.width) / 2;
            playerToken.y = oldTile.y + (oldTile.height - playerToken.height) / 2;
            playerToken.visible = true;
            
            // Get array of path positions
            let path = [];
            if (steps > 0) {
                // Normal movement - generate path through each tile
                for (let i = 1; i <= steps; i++) {
                    const pathPosition = (oldPosition + i) % 40; // Assuming 40 tiles on board
                    path.push(pathPosition);
                }
            } else {
                // Special movement (like going to jail) - direct movement
                path.push(newPosition);
            }
            
            // Start animation
            movementAnimation.playerName = playerName;
            movementAnimation.playerToken = playerToken;
            movementAnimation.path = path;
            movementAnimation.pathIndex = 0;
            movementAnimation.restart();
        } else {
            console.error("Could not find tile at position:", oldPosition);
        }
    }
    
    // Timer to animate movement step by step
    Timer {
        id: movementAnimation
        interval: 300 // Time between steps
        repeat: true
        running: false
        
        property var playerToken: null
        property string playerName: ""
        property var path: []
        property int pathIndex: 0
        
        onTriggered: {
            if (pathIndex < path.length) {
                const targetPosition = path[pathIndex];
                const targetTile = boardGrid.getTileAt(targetPosition);
                
                if (targetTile) {
                    // Animate the token to the target tile
                    tokenAnimation.stop();
                    tokenAnimation.target = playerToken;
                    tokenAnimation.to = Qt.point(
                        targetTile.x + (targetTile.width - playerToken.width) / 2,
                        targetTile.y + (targetTile.height - playerToken.height) / 2
                    );
                    tokenAnimation.restart();
                    
                    pathIndex++;
                } else {
                    console.error("Could not find tile at position:", targetPosition);
                    stop();
                }
            } else {
                // Animation complete
                stop();
                // We no longer destroy the token - it stays visible
            }
        }
    }
    
    // Animation for smooth movement
    NumberAnimation {
        id: tokenAnimation
        properties: "x,y"
        duration: 250
        easing.type: Easing.InOutQuad
    }
    
    // Function to clear all animation tokens - call this when starting a new game
    function clearAllTokens() {
        for (let playerName in playerTokens) {
            if (playerTokens[playerName]) {
                playerTokens[playerName].destroy();
            }
        }
        playerTokens = {};
    }
    
    // Function to hide a specific player's token
    function hidePlayerToken(playerName) {
        if (playerTokens[playerName]) {
            playerTokens[playerName].visible = false;
        }
    }
    
    // Function to show a specific player's token
    function showPlayerToken(playerName) {
        if (playerTokens[playerName]) {
            playerTokens[playerName].visible = true;
        }
    }
    
    // Function to position a token at a specific board position
    function positionTokenAtTile(playerName, position) {
        if (playerTokens[playerName]) {
            const tile = boardGrid.getTileAt(position);
            if (tile) {
                const token = playerTokens[playerName];
                token.x = tile.x + (tile.width - token.width) / 2;
                token.y = tile.y + (tile.height - token.height) / 2;
            }
        }
    }
} 
