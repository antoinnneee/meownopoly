import QtQuick
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
