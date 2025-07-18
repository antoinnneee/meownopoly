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

    required property Case caseData

    // Properties
    property int tileIndex: caseData.position
    property int tileType: caseData.type
    property string tileName: caseData.name
    property string tileColor: "#ecf0f1"
    property string tileIcon: ""
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
            top: parent.top//            top: tileType === 1 ? colorBar.bottom : parent.top
            bottom: parent.bottom
            margins: tileType === 1 ? 0 : 4
        }
        tileData: root.caseData
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
        tileData: root.caseData
        familyColors: root.familyColors
    }

}
