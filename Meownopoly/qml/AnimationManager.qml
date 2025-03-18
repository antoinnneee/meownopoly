import QtQuick
import QtQuick.Controls
import Game

Item {
    id: root
    
    // Reference to the game board grid
    property var boardGrid: null
    
    // Board mapping
    property var tilePositions: []
    property var activeAnimations: []
    
    // Store info about currently animating players
    property var movingPlayers: ({})
    
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
    
    // Animate player movement
    function animatePlayerMovement(player, fromPosition, toPosition, steps) {
        console.log("Animating player: " + player.name);
        console.log("  - Moving from " + fromPosition + " to " + toPosition + " in " + steps + " steps");
        
        // Check if we already have an active animation for this player
        if (movingPlayers[player.name]) {
            console.log("  - Player is already moving, ignoring new movement");
            return;
        }
        
        // Verify we have position data for both tiles
        if (!tilePositions[fromPosition] || !tilePositions[toPosition]) {
            console.error("  - Missing tile position data for animation");
            return;
        }
        
        try {
            // Create animated token
            var tokenComponent = Qt.createComponent("boardTile/AnimatedPlayerToken.qml");
            var token = tokenComponent.createObject(root, {
                playerName: player.name,
                playerColor: player.color,
                isCurrentPlayer: (player === Game.players[Game.currentPlayerIndex]),
                currentPosition: fromPosition,
                targetPosition: toPosition,
                tilePositions: tilePositions,
                playerIndex: Game.players.indexOf(player)
            });
            
            if (token) {
                console.log("  - Created animation token for player: " + player.name);
                
                // Track this player as moving
                movingPlayers[player.name] = token;
                activeAnimations.push(token);
                
                // Connect to the completion signal
                token.movementComplete.connect(function() {
                    console.log("  - Animation complete for player: " + player.name);
                    
                    // Remove from tracking arrays
                    var index = activeAnimations.indexOf(token);
                    if (index >= 0) {
                        activeAnimations.splice(index, 1);
                    }
                    
                    // Clear from moving players map
                    delete movingPlayers[player.name];
                    
                    console.log("  - Cleaning up animation token for player: " + player.name);
                    token.destroy();
                });
                
                // Start the animation
                token.moveToken(toPosition, steps);
            } else {
                console.error("  - Failed to create animation token");
            }
        } catch (e) {
            console.error("Error creating animated token: " + e);
        }
    }
} 
