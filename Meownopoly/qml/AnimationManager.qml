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
    
    // Animate a player token
    function animatePlayerMovement(player, oldPosition, newPosition, steps) {
        console.log("Animating player:", player.name);
        console.log("  - Moving from", oldPosition, "to", newPosition, "in", steps, "steps");
        
        // Check if player is already moving
        if (movingPlayers[player.name]) {
            console.log("  - Player is already moving, ignoring new movement");
            return;
        }
        
        // Calculate global coordinates for animation parent
        var startTile = getTilePosition(oldPosition);
        var endTile = getTilePosition(newPosition);
        
        if (!startTile || !endTile) {
            console.error("Cannot animate - missing tile position information");
            console.log("  - Start tile position:", startTile ? "Available" : "Missing");
            console.log("  - End tile position:", endTile ? "Available" : "Missing");
            return;
        }
        
        // Get the player's index to properly show the correct token
        var playerIndex = -1;
        for (var i = 0; i < Game.players.length; i++) {
            if (Game.players[i].name === player.name) {
                playerIndex = i;
                break;
            }
        }
        
        if (playerIndex === -1) {
            console.error("Cannot find player index for animation:", player.name);
            return;
        }
        
        // Create the animated token
        var tokenComponent = Qt.createComponent("boardTile/AnimatedPlayerToken.qml");
        if (tokenComponent.status === Component.Ready) {
            var token = tokenComponent.createObject(root, {
                playerName: player.name,
                playerColor: player.color,
                playerIndex: playerIndex,
                isCurrentPlayer: Game.currentPlayerIndex === playerIndex,
                currentPosition: oldPosition,
                targetPosition: newPosition,
                tilePositions: tilePositions,
                x: startTile.x - 10, // center token (token width = 20)
                y: startTile.y - 10  // center token (token height = 20)
            });
            
            console.log("  - Created animation token for player:", player.name);
            
            // Start animation
            token.moveToken(newPosition, steps);
            
            // Track this animation
            movingPlayers[player.name] = token;
            
            // Clean up when animation is done
            token.movementComplete.connect(function() {
                console.log("  - Animation complete for player:", player.name);
                
                // Remove from tracking
                delete movingPlayers[player.name];
                
                // Create timer to ensure token is displayed on final position before destruction
                var destroyTimer = Qt.createQmlObject(
                    'import QtQuick; Timer {interval: 100; repeat: false;}',
                    token
                );
                
                function destroyToken() {
                    console.log("  - Cleaning up animation token for player:", player.name);
                    token.destroy();
                }
                
                destroyTimer.triggered.connect(destroyToken);
                destroyTimer.start();
            });
        } else {
            console.error("Error creating animated token:", tokenComponent.errorString());
        }
    }
} 
