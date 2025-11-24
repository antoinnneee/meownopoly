import QtQuick 2.15
import MapInfo
import "./grid"

Rectangle {
    id: board

    property real z_WORKAREA: 5000

    property real z_BACKGROUND: 3000
    property real z_GRID: 4000
    property real z_GLOBAL_MA: 4750


    property Base_logic logic
    onLogicChanged: {
        console.log("logic changed")
    }

    property MapInfo mapInfo: MapInfo{
        function setMapInfo(info){
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
        z: z_GRID
    }

    property alias background:background
    Background {
        id: background
        grid: gameGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? gameGrid : parent
        z: z_BACKGROUND
    }

    property alias mainMa: mainMa
    GlobalMa {
        id: mainMa
        drag.target: gameGrid
        mouseLogic: logic.mouseLogic
        anchors.fill: parent
        z: z_GLOBAL_MA
    }




}
