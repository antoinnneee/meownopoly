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

    required property Case caseData

    // Properties
    property int tileIndex: caseData.position
    property int tileType: caseData.type
    property string tileName: caseData.name
    property bool isHovered: false

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
/*
    // Function to update ownership indicator
    function updateOwnershipStatus() {
        try {
            var hasOwner = false;
            var ownerName = "";

            // Check if this case has an owner (mainly for RestArea type)
            if (caseData && caseData.owner) {
                hasOwner = true;
                ownerName = caseData.owner.name || caseData.owner;
            }

            // Update ownership indicator visibility and color
            if (ownershipIndicator) {
                ownershipIndicator.visible = hasOwner;
                
                if (hasOwner) {
                    ownershipIndicator.setOwnerColor(getOwnerColor(ownerName));
                }
            }
        } catch (e) {
            console.error("Error updating ownership status in CaseTile:", e);
        }
    }
*/
    // Helper function to get owner color
    function getOwnerColor(ownerName) {
        try {
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
        return "#7f8c8d";
    }
/*
    // Monitor caseData changes to update ownership
    onCaseDataChanged: {
        Qt.callLater(updateOwnershipStatus);
    }

    Component.onCompleted: {
        Qt.callLater(updateOwnershipStatus);
    }
    */

    TileContent {
        id: tileContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        caseData: root.caseData
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
        caseData: root.caseData
        familyColors: root.familyColors
    }

    // Ownership indicator - ribbon at bottom left
    OwnershipIndicator {
        id: ownershipIndicator
        visible: (root.caseData.owner != undefined) ? true: false
        ribbonColor: (root.caseData.owner != undefined) ?root.caseData.owner.color : "#7f8c8d"

    }

}
