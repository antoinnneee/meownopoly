import QtQuick
import QtQuick.Controls
import Game

Item {
    id: root
    width: 20
    height: 20
    
    property string playerName: ""
    property string playerColor: "#7f8c8d"
    property bool isCurrentPlayer: false
    property int playerIndex: 0
    property int currentPosition: 0
    property int targetPosition: 0
    property var tilePositions: []  // Array of {x, y} positions for each tile
    
    // State variables for animation
    property bool isMoving: false
    property int stepsLeft: 0
    property int nextPosition: 0
    property int totalSteps: 0
    property real moveDuration: 300 // milliseconds per step
    
    // Track animation path points
    property var pathPoints: []
    property int currentPathIndex: 0
    
    // Signal when movement is complete
    signal movementComplete()
    
    // The actual token
    Rectangle {
        id: playerToken
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: playerColor
        border.width: isCurrentPlayer ? 2 : 0
        border.color: "white"
        
        // Player initial
        Text {
            anchors.centerIn: parent
            text: playerName.charAt(0).toUpperCase()
            color: "white"
            font.pixelSize: parent.width * 0.7
            font.bold: true
        }
        
        // Scale animation during movement
        scale: root.isMoving ? 1.2 : 1.0
        
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }
    
    // Debug visual for pathPoints
    Repeater {
        model: pathPoints.length
        Rectangle {
            x: pathPoints[index].x - 2 - root.x
            y: pathPoints[index].y - 2 - root.y
            width: 4
            height: 4
            radius: 2
            color: "red"
            visible: false // Set to true for debugging
        }
    }
    
    // Animation for movement
    SequentialAnimation {
        id: moveAnimation
        running: false
        
        // Prepare animation
        ScriptAction {
            script: {
                if (pathPoints.length > 0 && currentPathIndex < pathPoints.length) {
                    // Get next position
                    var nextPoint = pathPoints[currentPathIndex];
                    console.log("Moving to point:", currentPathIndex, "x:", nextPoint.x, "y:", nextPoint.y);
                }
            }
        }
        
        // Move to next position
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "x"
                to: currentPathIndex < pathPoints.length ? pathPoints[currentPathIndex].x - width/2 : x
                duration: moveDuration
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "y"
                to: currentPathIndex < pathPoints.length ? pathPoints[currentPathIndex].y - height/2 : y
                duration: moveDuration
                easing.type: Easing.OutQuad
            }
        }
        
        // Process next step
        ScriptAction {
            script: {
                // Update position
                currentPathIndex++;
                
                if (currentPathIndex < pathPoints.length) {
                    // Continue movement
                    moveAnimation.restart();
                } else {
                    // End of movement
                    isMoving = false;
                    root.movementComplete();
                }
            }
        }
    }
    
    // Function to start movement animation
    function moveToken(newPosition, steps) {
        if (isMoving) return;
        
        // Calculate steps and path
        isMoving = true;
        totalSteps = steps;
        stepsLeft = steps;
        targetPosition = newPosition;
        
        // Generate path for animation
        generatePath();
        
        // Log path for debugging
        console.log("Path generated with " + pathPoints.length + " points for player " + playerName);
        for (var i = 0; i < pathPoints.length; i++) {
            console.log("  Point " + i + ": x=" + pathPoints[i].x + ", y=" + pathPoints[i].y);
        }
        
        // Start animation if path was generated
        if (pathPoints.length > 0) {
            currentPathIndex = 0;
            moveAnimation.restart();
        } else {
            console.error("No path points generated for animation!");
            isMoving = false;
            movementComplete();
        }
    }
    
    // Generate path for token movement
    function generatePath() {
        console.log("Generating path for player " + playerName);
        console.log("  From position " + currentPosition + " to " + targetPosition);
        console.log("  Total steps: " + totalSteps);
        
        pathPoints = [];
        
        // If tile positions array is empty or invalid index, can't animate
        if (!tilePositions || tilePositions.length === 0) {
            console.error("No tile positions available for animation");
            return;
        }
        
        // Calculate path for the token
        var boardSize = Game.boardSize;
        var current = currentPosition;
        
        // Add starting position as first point
        var startPos = tilePositions[current];
        if (startPos) {
            pathPoints.push({ x: startPos.x, y: startPos.y });
        }
        
        // Add each step to the path
        for (var i = 1; i <= totalSteps; i++) {
            var nextPos = (current + 1) % boardSize;
            current = nextPos;
            
            // Check if we have position data for this tile
            if (nextPos < tilePositions.length && tilePositions[nextPos]) {
                pathPoints.push({
                    x: tilePositions[nextPos].x,
                    y: tilePositions[nextPos].y
                });
            }
        }
        
        // If not even the end position is available, we can't animate
        if (pathPoints.length <= 1) {
            console.error("Cannot generate path - missing tile positions");
            for (var j = 0; j < totalSteps; j++) {
                var checkPos = (currentPosition + j + 1) % boardSize;
                console.log("  Position " + checkPos + " data: " + (tilePositions[checkPos] ? "Available" : "Missing"));
            }
            pathPoints = [];
        }
    }
} 
