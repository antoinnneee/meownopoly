import QtQuick
import QtQuick.Controls
import Game

Item {
    id: root
    width: parent.width
    height: parent.height
    
    property int tilePosition: 0
    property var players: []
    property int currentPlayerIndex: 0 // Index of the current player
    
    // Calculate which players are on this tile
    function updatePlayers() {
        let playersOnTile = [];
        
        for (let i = 0; i < Game.players.length; i++) {
            let player = Game.players[i];
            if (player.position === root.tilePosition) {
                playersOnTile.push({
                    name: player.name,
                    color: player.color,
                    isCurrent: i === root.currentPlayerIndex
                });
            }
        }
        
        // Update our players model
        root.players = playersOnTile;
    }
    
    // Arrange tokens in a circular pattern
    Item {
        id: tokenContainer
        anchors.fill: parent
        
        Repeater {
            model: root.players
            
            PlayerToken {
                property int tokenCount: root.players.length
                property real angle: (index / tokenCount) * 2 * Math.PI
                property real radius: Math.min(parent.width, parent.height) * 0.3
                
                // Position in a circle if multiple tokens
                x: parent.width/2 + (tokenCount > 1 ? radius * Math.cos(angle) - width/2 : -width/2)
                y: parent.height/2 + (tokenCount > 1 ? radius * Math.sin(angle) - height/2 : -height/2)
                
                width: tokenCount > 2 ? 18 : 22
                height: width
                playerName: modelData.name
                playerColor: modelData.color
                isCurrentPlayer: modelData.isCurrent
                
                totalTokens: tokenCount
                tokenIndex: index
            }
        }
    }
    
    // Update players when the tile position changes or when players change
    Component.onCompleted: updatePlayers()
    onTilePositionChanged: updatePlayers()
    
    // Listen for player position changes
    Connections {
        target: Game
        function onPlayersChanged() {
            updatePlayers()
        }
    }
} 