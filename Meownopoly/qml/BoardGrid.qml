import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Game

import "boardTile/"

Item {
    id: root

    property int tileSpace: 2
    property int tileSize: (parent.width / 10) - tileSpace*3

    // Bottom row (0-9)
    RowLayout {
        id: bottomRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: root.tileSize
        spacing: 2
        Component.onCompleted:{
            console.log("board", width, height)
        }

        Repeater {
            model: 10
            BoardTile {
                tileIndex: 9-index
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
            }
        }
    }

    // Top row (18-27)
    RowLayout {
        id: topRow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: root.tileSize
        spacing: 2

        Repeater {
            model: 10
            BoardTile {
                tileIndex: 18 + index
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
            }
        }
    }

    // 10 - 17
    ColumnLayout {
        id: leftColumn
        anchors {
            top: topRow.bottom
            topMargin: 2

            bottom: bottomRow.top
            bottomMargin: 2
            left: parent.left
        }
        width: root.tileSize
        spacing: 2

        Repeater {
            model: 8
            BoardTile {
                tileIndex: 17 - index
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
            }
        }
    }

    // Right column (28-35)
    ColumnLayout {
        id: rightColumn
        anchors {
            top: topRow.bottom
            topMargin: 2

            bottom: bottomRow.top
            bottomMargin: 2
            right: parent.right
        }
        width: root.tileSize
        spacing: 2

        Repeater {
            model: 8
            BoardTile {
                tileIndex: 28 + index
                onIsHoveredChanged: parent.z = (isHovered) ? 1: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileName: root.getBoardTileName(tileIndex)
                tileType: root.getBoardTileType(tileIndex)
                tileData: root.getBoardTileData(tileIndex)
            }
        }
    }

    // Center area (logo)
    Rectangle {
        anchors {
            left: leftColumn.right
            right: rightColumn.left
            top: topRow.bottom
            bottom: bottomRow.top
            margins: 2
        }
        color: "#34495e"
        radius: 8
        visible: true
        z: -1
        BoardTile {
            tileIndex: 32
            width: 200
            height: 200
            anchors.centerIn: parent
            tileName: root.getBoardTileName(tileIndex)
            tileType: root.getBoardTileType(tileIndex)
            tileData: root.getBoardTileData(tileIndex)
        }

        Text {
            anchors.centerIn: parent
            text: "MEOWNOPOLY"
            color: "#ecf0f1"
            visible: false
            font {
                pixelSize: 40
                bold: true
                family: "Arial"
            }
            rotation: -45
        }
    }

    // Helper functions
    function getBoardTileType(index) {
        if (index < 0 || index >= Game.boardSize) return -1;
        var boardCase = Game.getCaseAt(index);
        return boardCase ? boardCase.type : -1;
    }

    function getBoardTileName(index) {
        if (index < 0 || index >= Game.boardSize) return "Empty";
        var boardCase = Game.getCaseAt(index);
        return boardCase ? boardCase.name : "Unknown";
    }

    function getBoardTileData(index) {
        if (index < 0 || index >= Game.boardSize)
        {
            console.log("index issue", index)
            return null

        };
        var boardCase = Game.getCaseAt(index);
        if (!boardCase)        {
            console.log("case unknow", index)
            return null

        };

        var data = {};
        data.position = index;

        if (boardCase.type === 1) {
            data.family = boardCase.family;
            data.restQuality = boardCase.restQuality;
            data.owner = boardCase.owner ? boardCase.owner.name : null;
            data.price = boardCase.price;
            data.prices = boardCase.prices;
        } else if (boardCase.type === 0) {
            data.reward = boardCase.reward;
            data = null
        } else if (boardCase.type === 4) {
            data.fine = boardCase.fine;
            data = null
        }
        else
        {
            console.log(" unknow type", index, boardCase.type)
            data = null

        }

        return data;
    }
} 
