import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import "."

Rectangle {
    id: root
    color: "#ecf0f1"
    border.color: "#bdc3c7"
    border.width: 1
    radius: 4

    // Properties
    property int tileIndex: 0
    property int tileType: -1  // 0: Kibble, 1: RestArea, 2: CardBoard, etc.
    property string tileName: ""
    property string tileColor: "#ecf0f1"
    property string tileIcon: ""
    property var tileData: null  // Additional data for the tile
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
} 
