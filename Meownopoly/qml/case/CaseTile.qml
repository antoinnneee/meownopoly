import QtQuick
import Game
import Case
import Player
import MeowStyle

import "."

Item {
    id: root
    // color: "#ecf0f1"
    // border.color: "#bdc3c7"
    // border.width: 1
    // radius: 4

    required property Case caseData

    // Properties
    property var tileIndex: (caseData != undefined) ? caseData.uniqueId : ""
    property int tileType: (caseData != undefined) ? caseData.type : 0
    property string tileName: (caseData != undefined) ? caseData.name : ""
    property bool isHovered: false
    property alias mouseArea: mouseArea

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
        enabled: true
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
        visible: (root.caseData != undefined && root.caseData.owner != undefined) ? true: false
        ribbonColor: (root.caseData != undefined && root.caseData.owner != undefined) ?root.caseData.owner.color : "#7f8c8d"
    }
}
