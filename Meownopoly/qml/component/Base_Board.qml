import QtQuick 2.15
import UiStyle
import MapInfo
import "./grid"

Rectangle {
    id: board


    property Base_logic logic
    onLogicChanged: {
        console.log("logic changed")
    }

    property MapInfo mapInfo: MapInfo{
        function setMapInfo(info){
            console.log("Setting map info:", info.mapName)
            console.log("this.backgroundPath " + this.backgroundPath)
            this.mapName = info.mapName
            this.mapDescription = info.mapDescription
            this.mapCreationDate = info.mapCreationDate
            this.mapLastModified = info.mapLastModified
            this.version = info.version
            this.backgroundPath = info.backgroundPath
            this.backgroundScaling = info.backgroundScaling
            this.backgroundTileSize = info.backgroundTileSize
            this.isBackgroundOnGrill = info.isBackgroundOnGrill
            this.musicPath = info.musicPath
        }
    }

    property WheelHandler wheelHandler


    property alias gameGrid:gameGrid
    GridManager {
        id: gameGrid
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        z: UiStyle.z_GRID
    }

    property alias background:background
    Background {
        id: background
        grid: gameGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? gameGrid : parent
        z: UiStyle.z_BACKGROUND
    }

    property alias mainMa: mainMa
    GlobalMa {
        id: mainMa
        mouseLogic: logic.mouseLogic
        anchors.fill: parent
        z: UiStyle.z_GLOBAL_MA
        Component.onCompleted: drag.target = gameGrid
    }
}
