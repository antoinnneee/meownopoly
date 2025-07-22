import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Game

import "boardTile/"

Item {
    id: root

    property int tileSpace: 2
    property int tileSize: (parent.width / 10) - tileSpace*3

    // Reference to all tile components for updating
    property var allTiles: []

    // Flag to track if an update is in progress
    property bool isUpdating: false

    // Bottom row (0-9)
    RowLayout {
        id: bottomRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: root.tileSize
        spacing: 2
        Component.onCompleted:{
            console.log("board", width, height)
        }

        Repeater {
            model: 10
            BoardTile {
                tileIndex: 9-index
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
            }
        }
    }

    // Top row (18-27)
    RowLayout {
        id: topRow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: root.tileSize
        spacing: 2

        Repeater {
            model: 10
            BoardTile {
                tileIndex: 18 + index
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
            }
        }
    }

    // 10 - 17
    ColumnLayout {
        id: leftColumn
        anchors {
            top: topRow.bottom
            topMargin: 2

            bottom: bottomRow.top
            bottomMargin: 2
            left: parent.left
        }
        width: root.tileSize
        spacing: 2

        Repeater {
            model: 8
            BoardTile {
                tileIndex: 17 - index
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
            }
        }
    }

    // Right column (28-35)
    ColumnLayout {
        id: rightColumn
        anchors {
            top: topRow.bottom
            topMargin: 2

            bottom: bottomRow.top
            bottomMargin: 2
            right: parent.right
        }
        width: root.tileSize
        spacing: 2

        Repeater {
            model: 8
            BoardTile {
                tileIndex: 28 + index
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
            }
        }
    }

    // Center area (logo)
    Rectangle {
        anchors {
            left: leftColumn.right
            right: rightColumn.left
            top: topRow.bottom
            bottom: bottomRow.top
            margins: 2
        }
        color: "#34495e"
        radius: 8
        visible: true
        z: -1
        BoardTile {
            tileIndex: 35
            width: 200
            height: 200
            anchors.centerIn: parent
            tileName: root.getBoardTileName(tileIndex)
            tileType: root.getBoardTileType(tileIndex)
            tileData: root.getBoardTileData(tileIndex)
        }

        Text {
            anchors.centerIn: parent
            text: "MEOWNOPOLY"
            color: "#ecf0f1"
            visible: false
            font {
                pixelSize: 40
                bold: true
                family: "Arial"
            }
            rotation: -45
        }
    }

    // Function to force update all tiles with error handling
    function updateAllTiles() {
        // Prevent concurrent updates
        if (isUpdating) {
            console.log("Tile update already in progress, deferring");
            tileUpdateQueueTimer.restart();
            return;
        }
        
        console.log("Forcing update of all board tiles");
        isUpdating = true;
        
        try {
            // Update each tile's data
            for (let i = 0; i < allTiles.length; i++) {
                let tile = allTiles[i];
                if (tile && tile.tileIndex !== undefined) {
                    try {
                        // Refresh the tile data
                        let newData = getBoardTileData(tile.tileIndex);
                        tile.tileData = newData;
                    } catch (e) {
                        console.error("Error updating tile:", tile.tileIndex, e);
                    }
                }
            }
        } catch (e) {
            console.error("Error in updateAllTiles:", e);
        } finally {
            // Set a timer to clear the updating flag
            updateFlagClearTimer.restart();
        }
    }
    
    // Timer to queue updates if an update is already in progress
    Timer {
        id: tileUpdateQueueTimer
        interval: 200 // 200ms
        repeat: false
        onTriggered: {
            if (!isUpdating) {
                updateAllTiles();
            } else {
                // Try again later
                restart();
            }
        }
    }
    
    // Timer to clear the updating flag
    Timer {
        id: updateFlagClearTimer
        interval: 500 // 500ms
        repeat: false
        onTriggered: {
            isUpdating = false;
        }
    }
    
    // Collect references to all tiles after creation with error handling
    function collectTileReferences() {
        try {
            allTiles = [];
            
            // Helper function to safely collect tiles from a container
            function collectFromContainer(container) {
                if (!container || !container.children) return;
                
                for (let i = 0; i < container.children.length; i++) {
                    let child = container.children[i];
                    // Check if it's a BoardTile by testing its properties
                    if (child && typeof child.tileIndex !== 'undefined') {
                        allTiles.push(child);
                    }
                }
            }
            
            // Collect from each container
            collectFromContainer(bottomRow);
            collectFromContainer(topRow);
            collectFromContainer(leftColumn);
            collectFromContainer(rightColumn);
            
            console.log("Collected " + allTiles.length + " board tiles for updating");
        } catch (e) {
            console.error("Error collecting tile references:", e);
        }
    }
    
    // Helper functions with error handling
    function getBoardTileType(index) {
        try {
            if (index < 0 || index >= Game.boardSize) return -1;
            var boardCase = Game.getCaseAt(index);
            return boardCase ? boardCase.type : -1;
        } catch (e) {
            console.error("Error in getBoardTileType:", e);
            return -1;
        }
    }

    function getBoardTileName(index) {
        try {
            if (index < 0 || index >= Game.boardSize) return "Empty";
            var boardCase = Game.getCaseAt(index);
            return boardCase ? boardCase.name : "Unknown";
        } catch (e) {
            console.error("Error in getBoardTileName:", e);
            return "Error";
        }
    }

    function getBoardTileData(index) {
        try {
            if (index < 0 || index >= Game.boardSize) {
                console.log("index issue", index);
                return null;
            }
            
            var boardCase = Game.getCaseAt(index);
            if (!boardCase) {
                console.log("case unknown", index);
                return null;
            }

            var data = {};
            data.position = index;

            if (boardCase.type === 1) {
                // Safe property access with default values
                data.family = boardCase.family || 0;
                data.restQuality = boardCase.restQuality || 0;
                data.owner = boardCase.owner ? boardCase.owner.name : null;
                data.price = boardCase.price || 0;
                data.prices = boardCase.prices || [];
                return data;
            } else if (boardCase.type === 0) {
                data.reward = boardCase.reward || 0;
                return data;
            } else if (boardCase.type === 4) {
                data.fine = boardCase.fine || 0;
                return data;
            } else {
                console.log("unknown type", index, boardCase.type);
                return null;
            }
        } catch (e) {
            console.error("Error in getBoardTileData for index " + index + ":", e);
            return null;
        }
    }
    
    // Call this after the component is fully loaded
    Component.onCompleted: {
        try {
            // Short delay to ensure all repeaters have finished creating their items
            delayedInitTimer.start();
        } catch (e) {
            console.error("Error in BoardGrid onCompleted:", e);
        }
    }
    
    // Timer for delayed initialization
    Timer {
        id: delayedInitTimer
        interval: 500 // Half second delay
        repeat: false
        onTriggered: {
            collectTileReferences();
        }
    }
    
    // Listen for property purchases to update the board
    Connections {
        target: Game
        
        function onPropertyPurchased(position, newOwner) {
            try {
                console.log("Property purchased at position " + position);
                // Use the tile update queue system
                tileUpdateQueueTimer.restart();
            } catch (e) {
                console.error("Error handling property purchase:", e);
            }
        }
    }
} 
