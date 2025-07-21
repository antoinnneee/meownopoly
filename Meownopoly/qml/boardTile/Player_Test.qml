import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Player


Rectangle {
    id: playerToken

    property int oldPosition: 0
    property Player playerInfo: Player {
        onPositionChanged: {
            if (listCaseTile.length > playerInfo.position) {
                if (oldPosition !== playerInfo.position && listCaseTile.length > oldPosition) {
                    listCaseTile[oldPosition].caseData.onLeave(playerInfo)
                }                
                updatePosition()
                listCaseTile[playerInfo.position].caseData.onLand(playerInfo)
                oldPosition = playerInfo.position
            }
        }
    }

    Component.onCompleted: updatePosition()


    
        function updatePosition() {
        var tile = listCaseTile[playerInfo.position]
        var centerPos = tile.mapToItem(parent, tile.width/2, tile.height/2)
        x = centerPos.x - width/2  // Centrer horizontalement
        y = centerPos.y - height/2 // Centrer verticalement
    }

    // Visual properties
    width: 20
    height: 20
    radius: 10
    color: playerInfo.color  // Use the dynamic color from playerInfo
    border.color: playerInfo.color
    border.width: 2
    // Player label
    Text {
        anchors.centerIn: parent
        text: "P"
        color: "white"
        font.pixelSize: 12
        font.bold: true
    }
}
