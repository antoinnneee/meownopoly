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
    
    // Animation style constants
    readonly property int animStyleStraight: 0    // Direct straight line movement
    readonly property int animStyleCurved: 1      // Curved path movement
    readonly property int animStylePause: 2       // Movement with pauses
    readonly property int animStyleZigzag: 3      // Zigzag erratic movement
    
    // Current animation properties
    property int animationStyle: animStyleStraight  // Will be chosen randomly
    property bool useRandomPath: true                // If true, will have random intermediate points
    
    // State variables for animation
    property bool isMoving: false
    property int stepsLeft: 0
    property int nextPosition: 0
    property int totalSteps: 0
    
    // Dynamically calculated durations
    property real baseMoveDuration: 800 // Base milliseconds per step
    property real currentMoveDuration: baseMoveDuration // Will be adjusted based on distance
    property real pauseDuration: 80 // milliseconds for pauses
    
    // Track animation path points
    property var pathPoints: []
    property int currentPathIndex: 0
    property var currentSegmentPauses: []
    
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
        scale: root.isMoving ? 1.1 : 1.0
        
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
        
        // Add slight rotation for more natural movement
        rotation: root.isMoving ? Math.sin(Date.now() / 300) * 5 : 0
        
        Behavior on rotation {
            NumberAnimation {
                duration: 150
            }
        }
    }
    
    // Path for the animation
    Path {
        id: motionPath
        startX: 0
        startY: 0
    }
    
    // Animation for smooth curved movement
    PathAnimation {
        id: pathAnimation
        target: root
        path: motionPath
        orientationEntryDuration: 0
        orientationExitDuration: 0
        duration: calculateTotalDuration()
        easing.type: getAnimationEasing()
        running: false
        
        onRunningChanged: {
            if (!running && isMoving) {
                // Animation finished, clean up
                isMoving = false;
                root.movementComplete();
            }
        }
    }
    
    // Timer for pauses along the path (only used in ANIM_STYLE_PAUSE)
    Timer {
        id: pauseTimer
        interval: 100
        repeat: false
        
        property int currentPauseSegment: 0
        property real progress: 0
        
        onTriggered: {
            // Resume the animation
            pathAnimation.resume();
        }
    }
    
    // Calculate the total duration of the animation based on style and distance
    function calculateTotalDuration() {
        var baseDuration;
        
        switch (animationStyle) {
            case animStylePause:
                // Pause style is slightly slower
                baseDuration = currentMoveDuration * pathPoints.length * 1.2;
                break;
            case animStyleZigzag:
                // Zigzag is slightly faster despite more points
                baseDuration = currentMoveDuration * pathPoints.length * 0.8;
                break;
            case animStyleCurved:
                // Curved is normal speed
                baseDuration = currentMoveDuration * pathPoints.length;
                break;
            case animStyleStraight:
            default:
                // Straight is faster
                baseDuration = currentMoveDuration * pathPoints.length * 0.7;
                break;
        }
        
        return baseDuration;
    }
    
    // Get the appropriate easing based on animation style
    function getAnimationEasing() {
        switch (animationStyle) {
            case animStylePause:
                return Easing.OutBack; // Slight overshoot for pausing animations
            case animStyleZigzag:
                return Easing.Linear; // Linear for zigzag for more erratic feel
            case animStyleCurved:
                return Easing.OutCubic; // Smooth acceleration for curves
            case animStyleStraight:
            default:
                return Easing.OutQuad; // Simple easing for straight lines
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
        
        // Calculate speed based on distance
        calculateMoveDuration();
        
        // Randomly choose animation style
        chooseAnimationStyle();
        
        // Generate path for animation
        generatePath();
        
        // Create the path for animation
        createAnimationPath();
        
        // Start animation if path was generated
        if (pathPoints.length > 0) {
            pathAnimation.duration = calculateTotalDuration();
            pathAnimation.start();
            
            // Set up pause points if animation style has pauses
            if (animationStyle === animStylePause) {
                setupPathPauses();
            }
        } else {
            console.error("No path points generated for animation!");
            isMoving = false;
            movementComplete();
        }
    }
    
    // Choose a random animation style
    function chooseAnimationStyle() {
        // Select a random animation style with different weights:
        // - STRAIGHT: 40% chance (0-39)
        // - CURVED: 35% chance (40-74)
        // - PAUSE: 15% chance (75-89)
        // - ZIGZAG: 10% chance (90-99)
        var randomValue = Math.floor(Math.random() * 100);
        
        if (randomValue < 40) {
            animationStyle = animStyleStraight;
        } else if (randomValue < 75) {
            animationStyle = animStyleCurved;
        } else if (randomValue < 90) {
            animationStyle = animStylePause;
        } else {
            animationStyle = animStyleZigzag;
        }
        
        // Special cases
        if (totalSteps <= 2) {
            // For short movements, prefer straight or curve
            animationStyle = Math.random() < 0.6 ? animStyleStraight : animStyleCurved;
        } else if (totalSteps >= 10) {
            // For very long movements, avoid the pause style
            if (animationStyle === animStylePause) {
                animationStyle = Math.random() < 0.5 ? animStyleStraight : animStyleCurved;
            }
        }
        
        // Decide if we should use random intermediate points
        useRandomPath = Math.random() < 0.7; // 70% chance
        
        console.log("Animation style chosen: " + getAnimationStyleName());
    }
    
    // Get a descriptive name for the animation style (for debugging)
    function getAnimationStyleName() {
        switch (animationStyle) {
            case animStylePause: return "PAUSE";
            case animStyleZigzag: return "ZIGZAG";
            case animStyleCurved: return "CURVED";
            case animStyleStraight: return "STRAIGHT";
            default: return "UNKNOWN";
        }
    }
    
    // Setup pauses along the path (for ANIM_STYLE_PAUSE)
    function setupPathPauses() {
        // Create a NumberAnimation to track progress
        var progressAnimation = Qt.createQmlObject(
            'import QtQuick; NumberAnimation { property: "progress"; from: 0; to: 1; duration: ' + 
            pathAnimation.duration + '; running: true }',
            pauseTimer
        );
        
        // Connect to the progress animation
        progressAnimation.runningChanged.connect(function() {
            if (!progressAnimation.running) {
                progressAnimation.destroy();
            }
        });
        
        // Monitor progress for pause points
        progressAnimation.onProgressChanged.connect(function() {
            // Check if we should pause at any point
            var segmentSize = 1.0 / (pathPoints.length - 1);
            var currentSegment = Math.floor(progressAnimation.progress / segmentSize);
            
            // If we've reached a pause point and we're not already paused
            if (currentSegment < currentSegmentPauses.length && 
                currentSegmentPauses[currentSegment] && 
                pathAnimation.running && 
                !pauseTimer.running) {
                
                // Pause the animation
                pathAnimation.pause();
                
                // Set up the timer to resume
                pauseTimer.currentPauseSegment = currentSegment;
                pauseTimer.interval = pauseDuration + (Math.random() * 150);
                pauseTimer.start();
                
                // Mark this pause as used so we don't pause here again
                currentSegmentPauses[currentSegment] = false;
            }
        });
        
        // Clean up the connection when done
        pathAnimation.runningChanged.connect(function() {
            if (!pathAnimation.running) {
                progressAnimation.stop();
                if (progressAnimation) {
                    progressAnimation.destroy();
                }
            }
        });
    }
    
    // Calculate the appropriate movement duration based on distance
    function calculateMoveDuration() {
        // Base formula:
        // - For short movements (1-3 steps): slower speed
        // - For medium movements (4-7 steps): medium speed
        // - For long movements (8+ steps): faster speed
        if (totalSteps <= 3) {
            currentMoveDuration = baseMoveDuration; // slow and deliberate
        } else if (totalSteps <= 7) {
            currentMoveDuration = baseMoveDuration * 0.9; // medium speed
        } else {
            currentMoveDuration = baseMoveDuration * 0.8; // faster movement
        }
        
        // Make sure we have a reasonable minimum speed
        currentMoveDuration = Math.max(currentMoveDuration, 100);
    }
    
    // Generate path for token movement based on chosen style
    function generatePath() {
        pathPoints = [];
        currentSegmentPauses = [];
        
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
            pathPoints.push({ x: startPos.x - width/2, y: startPos.y - height/2 });
            currentSegmentPauses.push(false); // No pause at start
        }
        
        // Add points based on animation style
        switch (animationStyle) {
            case animStyleStraight:
                generateStraightPath(current, boardSize);
                break;
            case animStyleCurved:
                generateCurvedPath(current, boardSize);
                break;
            case animStylePause:
                generatePausePath(current, boardSize);
                break;
            case animStyleZigzag:
                generateZigzagPath(current, boardSize);
                break;
            default:
                // Fallback to straight path
                generateStraightPath(current, boardSize);
                break;
        }
        
        // If not even the end position is available, we can't animate
        if (pathPoints.length <= 1) {
            console.error("Cannot generate path - missing tile positions");
            pathPoints = [];
            currentSegmentPauses = [];
        }
    }
    
    // Generate a simple straight-line path
    function generateStraightPath(current, boardSize) {
        // For a straight path, we simply connect each tile center directly
        for (var i = 1; i <= totalSteps; i++) {
            var nextPos = (current + 1) % boardSize;
            current = nextPos;
            
            // Check if we have position data for this tile
            if (nextPos < tilePositions.length && tilePositions[nextPos]) {
                var tilePos = tilePositions[nextPos];
                
                // Add the tile center
                pathPoints.push({
                    x: tilePos.x - width/2,
                    y: tilePos.y - height/2
                });
                
                // No pauses in straight path
                currentSegmentPauses.push(false);
            }
        }
    }
    
    // Generate a curved path with control points
    function generateCurvedPath(current, boardSize) {
        // For curved path, we use the same points as straight path
        // but the actual curvature will be added in createAnimationPath
        for (var i = 1; i <= totalSteps; i++) {
            var nextPos = (current + 1) % boardSize;
            current = nextPos;
            
            // Check if we have position data for this tile
            if (nextPos < tilePositions.length && tilePositions[nextPos]) {
                var tilePos = tilePositions[nextPos];
                
                // Optionally add random intermediate points
                if (useRandomPath && i < totalSteps && Math.random() > 0.5) {
                    var randomOffset = getRandomOffset(15);
                    pathPoints.push({
                        x: tilePos.x + randomOffset.x - width/2,
                        y: tilePos.y + randomOffset.y - height/2
                    });
                    currentSegmentPauses.push(false);
                }
                
                // Add the tile center
                pathPoints.push({
                    x: tilePos.x - width/2,
                    y: tilePos.y - height/2
                });
                
                // No pauses in curved path
                currentSegmentPauses.push(false);
            }
        }
    }
    
    // Generate a path with pause points
    function generatePausePath(current, boardSize) {
        // For a path with pauses, we add pause flags to some points
        for (var i = 1; i <= totalSteps; i++) {
            var nextPos = (current + 1) % boardSize;
            current = nextPos;
            
            // Check if we have position data for this tile
            if (nextPos < tilePositions.length && tilePositions[nextPos]) {
                var tilePos = tilePositions[nextPos];
                
                // Add random intermediate pause points
                if (i < totalSteps && Math.random() > 0.5) {
                    var randomOffset = getRandomOffset(10);
                    pathPoints.push({
                        x: tilePos.x + randomOffset.x - width/2,
                        y: tilePos.y + randomOffset.y - height/2
                    });
                    
                    // 40% chance for a pause at intermediate points
                    currentSegmentPauses.push(Math.random() < 0.4);
                }
                
                // Add the tile center
                pathPoints.push({
                    x: tilePos.x - width/2,
                    y: tilePos.y - height/2
                });
                
                // 60% chance for a pause on a tile (except final)
                var isPause = (i !== totalSteps) && (Math.random() < 0.6);
                currentSegmentPauses.push(isPause);
            }
        }
    }
    
    // Generate a zigzag erratic path
    function generateZigzagPath(current, boardSize) {
        // For a zigzag path, we add several intermediate points with intentional detours
        for (var i = 1; i <= totalSteps; i++) {
            var nextPos = (current + 1) % boardSize;
            current = nextPos;
            
            // Check if we have position data for this tile
            if (nextPos < tilePositions.length && tilePositions[nextPos]) {
                var tilePos = tilePositions[nextPos];
                
                // Add zigzag intermediate points
                if (i < totalSteps || Math.random() > 0.5) { // Even final position can have zigzag
                    // Add 1-3 zigzag points
                    var zigzagCount = 1 + Math.floor(Math.random() * 2);
                    for (var z = 0; z < zigzagCount; z++) {
                        // Create larger random offsets for more erratic movement
                        var zigzagOffset = getRandomOffset(20);
                        pathPoints.push({
                            x: tilePos.x + zigzagOffset.x - width/2,
                            y: tilePos.y + zigzagOffset.y - height/2
                        });
                        currentSegmentPauses.push(false);
                    }
                }
                
                // Always add the tile center at the end
                pathPoints.push({
                    x: tilePos.x - width/2,
                    y: tilePos.y - height/2
                });
                
                // No pauses in zigzag path
                currentSegmentPauses.push(false);
            }
        }
    }
    
    // Create the Path object for the animation from the path points
    function createAnimationPath() {
        // Clear any existing path
        while (motionPath.pathElements.length > 0) {
            motionPath.pathElements.pop();
        }
        
        if (pathPoints.length <= 1) {
            return;
        }
        
        // Set the start point
        motionPath.startX = pathPoints[0].x;
        motionPath.startY = pathPoints[0].y;
        
        // Add path elements based on animation style
        switch (animationStyle) {
            case animStyleCurved:
                createCurvedAnimationPath();
                break;
            case animStyleZigzag:
                createZigzagAnimationPath();
                break;
            case animStylePause:
                createPauseAnimationPath();
                break;
            case animStyleStraight:
            default:
                createStraightAnimationPath();
                break;
        }
    }
    
    // Create a straight-line animation path
    function createStraightAnimationPath() {
        // For straight path, use PathLine elements
        for (var i = 1; i < pathPoints.length; i++) {
            var line = Qt.createQmlObject(
                'import QtQuick; PathLine { x: ' + pathPoints[i].x + '; y: ' + pathPoints[i].y + ' }',
                motionPath
            );
            motionPath.pathElements.push(line);
        }
    }
    
    // Create a curved animation path
    function createCurvedAnimationPath() {
        // For curved path, use a mix of PathCubic and PathCurve elements
        for (var i = 1; i < pathPoints.length; i++) {
            var prevPoint = pathPoints[i-1];
            var currentPoint = pathPoints[i];
            
            if (i < pathPoints.length - 1 && pathPoints.length > 2) {
                // Use cubic curves for smoother paths when possible
                var nextPoint = pathPoints[i+1];
                
                // Calculate control points with randomness
                var controlX1 = prevPoint.x + (currentPoint.x - prevPoint.x) * 0.5 + getRandomOffset(15).x;
                var controlY1 = prevPoint.y + (currentPoint.y - prevPoint.y) * 0.5 + getRandomOffset(15).y;
                var controlX2 = currentPoint.x - (nextPoint.x - currentPoint.x) * 0.3 + getRandomOffset(15).x;
                var controlY2 = currentPoint.y - (nextPoint.y - currentPoint.y) * 0.3 + getRandomOffset(15).y;
                
                // Create cubic curve
                var curve = Qt.createQmlObject(
                    'import QtQuick; PathCubic { x: ' + currentPoint.x + '; y: ' + currentPoint.y + 
                    '; control1X: ' + controlX1 + '; control1Y: ' + controlY1 + 
                    '; control2X: ' + controlX2 + '; control2Y: ' + controlY2 + ' }',
                    motionPath
                );
                motionPath.pathElements.push(curve);
            } else {
                // For last point or simple paths, use a simple curve
                var simpleCurve = Qt.createQmlObject(
                    'import QtQuick; PathCurve { x: ' + currentPoint.x + '; y: ' + currentPoint.y + ' }',
                    motionPath
                );
                motionPath.pathElements.push(simpleCurve);
            }
        }
    }
    
    // Create a pause-friendly animation path
    function createPauseAnimationPath() {
        // For pause path, use a mix of lines and curves
        for (var i = 1; i < pathPoints.length; i++) {
            var currentPoint = pathPoints[i];
            
            // Use curves for intermediate points and lines for pause points
            if (currentSegmentPauses[i-1]) {
                // For pause points, use a line for cleaner pausing
                var line = Qt.createQmlObject(
                    'import QtQuick; PathLine { x: ' + currentPoint.x + '; y: ' + currentPoint.y + ' }',
                    motionPath
                );
                motionPath.pathElements.push(line);
            } else {
                // For non-pause points, use curves
                var curve = Qt.createQmlObject(
                    'import QtQuick; PathCurve { x: ' + currentPoint.x + '; y: ' + currentPoint.y + ' }',
                    motionPath
                );
                motionPath.pathElements.push(curve);
            }
        }
    }
    
    // Create a zigzag animation path
    function createZigzagAnimationPath() {
        // For zigzag path, use mostly PathLine elements with sharper turns
        for (var i = 1; i < pathPoints.length; i++) {
            var currentPoint = pathPoints[i];
            
            // For zigzag, always use lines for the sharp angles
            var line = Qt.createQmlObject(
                'import QtQuick; PathLine { x: ' + currentPoint.x + '; y: ' + currentPoint.y + ' }',
                motionPath
            );
            motionPath.pathElements.push(line);
        }
    }
    
    // Helper function to generate random offsets for path points
    function getRandomOffset(maxDistance) {
        var angle = Math.random() * Math.PI * 2; // Random angle in radians
        var distance = Math.random() * maxDistance; // Random distance up to maxDistance
        
        return {
            x: Math.cos(angle) * distance,
            y: Math.sin(angle) * distance
        };
    }
} 
