import QtQuick
import Game
import Case
import Player
import MeowStyle

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

    property list<Player> playerList
    property int maxPlayer : 4


    // Colors for different family types - utilise le singleton MeowStyle
    property var familyColors: MeowStyle.familyColors

    TileContent {
        id: tileContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        caseData: root.caseData
        familyColors: root.familyColors
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
