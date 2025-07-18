import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Case
import "."

Rectangle {
    id: root
    color: "#ecf0f1"
    border.color: "#bdc3c7"
    border.width: 1
    radius: 4

    // Flag to prevent concurrent updates
    property bool isUpdatingOwnership: false

    // Properties
    property int tileIndex: 0
    property int tileType: Case.CS_RestArea  // 0: Kibble, 1: RestArea, 2: CardBoard, etc.
    property string tileName: ""
    property string tileColor: "#ecf0f1"
    property string tileIcon: ""
    property var tileData: null  // Additional data for the tile
    property bool isHovered: false

    // Force update when tileData changes
    onTileDataChanged: {
        // Use a timer to avoid concurrent updates
        if (!isUpdatingOwnership) {
            ownershipUpdateTimer.restart();
        }
    }

    // Timer to handle ownership updates
    Timer {
        id: ownershipUpdateTimer
        interval: 100 // Short delay
        repeat: false
        onTriggered: {
            updateOwnershipStatus();
        }
    }

    // Timer to clear update flag
    Timer {
        id: ownershipFlagClearTimer
        interval: 200
        repeat: false
        onTriggered: {
            isUpdatingOwnership = false;
        }
    }

    // Update ownership properties with error handling
    function updateOwnershipStatus() {
        if (isUpdatingOwnership) {
            console.log("Ownership update already in progress for tile " + tileIndex);
            return;
        }

        isUpdatingOwnership = true;

        try {
            var hasOwner = false;
            var ownerName = "";

            // Safe access to tileData with proper type checking
            if (tileType === 1 && tileData && typeof tileData === 'object' && tileData.owner) {
                hasOwner = true;
                ownerName = tileData.owner;
            }

            // Only update UI if the element exists
            if (ownershipIndicator) {
                ownershipIndicator.visible = hasOwner;

                if (hasOwner) {
                    try {
                        ownershipIndicator.color = getOwnerColor(ownerName);
                        ownershipIndicator.border.color = Qt.darker(ownershipIndicator.color, 1.2);

                        // Safe access to nested objects
                        if (ownershipGlow) {
                            ownershipGlow.border.color = Qt.lighter(ownershipIndicator.color, 1.3);
                        }
                    } catch (e) {
                        console.error("Error setting ownership indicator properties:", e);
                        // Set a default color in case of error
                        ownershipIndicator.color = "#7f8c8d";
                    }
                }
            }

            console.log("Tile " + tileIndex + " ownership updated: " +
                        (hasOwner ? "Owner: " + ownerName : "No owner"));
        } catch (e) {
            console.error("Error updating ownership status for tile " + tileIndex + ":", e);
        } finally {
            // Clear the update flag after a short delay
            ownershipFlagClearTimer.restart();
        }
    }

    // Colors for different family types
    property var familyColors: [
        "#ecf0f1",  // None
        "#795548",  // Brown
        "#81D4FA",  // Light Blue
        "#F48FB1",  // Pink
        "#FF9800",  // Orange
        "#e74c3c",  // Red
        "#F9E155",  // Yellow
        "#66BB6A",  // Green
        "#006064"   // Dark Blue
    ]

    // Scale transform for hover effect
    transform: Scale {
        id: tileScale
        origin.x: root.width/2
        origin.y: root.height/2
        xScale: root.isHovered ? 1.5 : 1.0
        yScale: root.isHovered ? 1.5 : 1.0

        Behavior on xScale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
        Behavior on yScale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }

    // Shadow effect for hover
    Rectangle {
        id: shadow
        anchors.fill: parent
        radius: parent.radius
        color: "black"
        opacity: root.isHovered ? 0.3 : 0
        z: -1

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        id: colorBar
        visible: tileType === 1  // Only visible for Rest Area tiles
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: parent.height * 0.2
        color: tileData && tileData.family ? familyColors[tileData.family] : "#ecf0f1"
        radius: 4
        Rectangle {
            width: parent.width
            height: parent.radius
            color: parent.color
            anchors.bottom: parent.bottom
        }
    }

    // Ownership indicator - diagonal line at bottom left
    Rectangle {
        id: ownershipIndicator
        visible: false // Initially invisible, updated by updateOwnershipStatus
        width: parent.width * 0.4
        height: 6 // Slightly thicker for better visibility
        color: "#7f8c8d" // Default color, will be updated
        radius: 2
        z: 2 // Ensure it's above other elements
        anchors {
            bottom: parent.bottom
            left: parent.left
            bottomMargin: 4
            leftMargin: 4
        }
        transform: Rotation {
            origin.x: 0
            origin.y: ownershipIndicator.height / 2
            angle: 45
        }
        // Add a border to make it more visible against any background
        border.width: 1
        border.color: Qt.darker(color, 1.2)

        // Add small glow effect to make it stand out
        Rectangle {
            id: ownershipGlow
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: Qt.lighter(parent.color, 1.3)
            opacity: 0.7
        }
    }

    TileContent {
        id: tileContent
        anchors {
            left: parent.left
            right: parent.right
            top: tileType === 1 ? colorBar.bottom : parent.top
            bottom: parent.bottom
            margins: tileType === 1 ? 0 : 4
        }
        tileType: root.tileType
        tileName: root.tileName
        tileData: root.tileData
    }

    // Player tokens container
    PlayerTokenContainer {
        id: playerTokens
        anchors.fill: parent
        tilePosition: root.tileIndex

        z: 5  // Make sure tokens appear above the tile content
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        z: 100

        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        onClicked: tileDetailsPopup.open()
    }

    TileDetailsPopup {
        id: tileDetailsPopup
        tileType: root.tileType
        tileName: root.tileName
        tileData: root.tileData
        familyColors: root.familyColors
    }

    // Raise z-index when hovered
    states: State {
        name: "hovered"
        when: root.isHovered
        PropertyChanges {
            target: root
            z: 10
        }
    }

    Component.onCompleted: {
        try {
            // Initialize ownership status when component is fully loaded
            // Use timer to ensure component is fully created
            Qt.callLater(function() {
                ownershipUpdateTimer.start();
            });
        } catch (e) {
            console.error("Error in BoardTile onCompleted:", e);
        }
    }

    // Helper function to get the color from the owner name with error handling
    function getOwnerColor(ownerName) {
        try {
            // If no owner name provided, return default
            if (!ownerName) return "#7f8c8d";

            // Find the player with matching name and get their color
            for (let i = 0; i < Game.players.length; i++) {
                let player = Game.players[i];
                if (player && player.name === ownerName) {
                    return player.color || "#7f8c8d";
                }
            }
        } catch (e) {
            console.error("Error getting owner color:", e);
        }

        // Default color if owner not found or error occurred
        return "#7f8c8d";
    }
}
