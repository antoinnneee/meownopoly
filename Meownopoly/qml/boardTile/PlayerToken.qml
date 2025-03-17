import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 20
    height: 20
    radius: width / 2
    
    property string playerColor: "#7f8c8d"
    property string playerName: ""
    property bool isCurrentPlayer: false
    property int playerIndex: 0
    
    // Arrange tokens in a circular pattern if multiple players on same tile
    property int totalTokens: 1
    property int tokenIndex: 0
    
    color: playerColor
    border {
        width: isCurrentPlayer ? 2 : 1
        color: isCurrentPlayer ? "white" : "black"
    }
    
    // Glowing effect for the current player
    Rectangle {
        visible: isCurrentPlayer
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border {
            width: 4
            color: Qt.lighter(root.color, 1.3)
        }
        opacity: 0.7
    }
    
    // Player initial
    Text {
        anchors.centerIn: parent
        text: playerName.charAt(0).toUpperCase()
        color: "white"
        font {
            bold: true
            pixelSize: parent.width * 0.6
        }
        style: Text.Outline
        styleColor: "black"
    }
    
    // Tooltip with player name
    ToolTip {
        delay: 500
        text: playerName
        visible: playerMouseArea.containsMouse
        font.pixelSize: 12
    }
    
    MouseArea {
        id: playerMouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onClicked: function(mouse) {
            // Handle click on token if needed
            mouse.accepted = false; // Allow click to pass through
        }
    }
} 