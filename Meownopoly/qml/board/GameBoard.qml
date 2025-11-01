import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Layouts
import QtQml


import Logger
import Game
import Case
import MapTypes
import MapFileManager
import MapInfo
import EditorEnum
import DisplayParameter
import DecorationParameter
import ItemSnapable
import "logic"
import "../component"
import "../component/snapable"
import "../component/grid"

Rectangle {
    id: gameBoard

    color: "lightblue"
    border.width: 0

    Component.onCompleted: {

        Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        gameGrid.mmSize = 8
    }

    property alias snapableTilesList: logic.snapableTilesList
    property MapInfo mapInfo: MapInfo {
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

    GameLogic {
        id: logic
        anchors.fill: parent
        grid: gameGrid
    }
    Game_WheelHandler {}
    // Grille de l'éditeur
    GridManager {
        id: gameGrid
        mmSize: logic.mmSize
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        anchors.fill: parent
        z: 1
    }

    Background {
        id: background
        grid: gameGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? gameGrid : parent
        z: 0
    }
    Item{
        id: workArea
        anchors.fill: gameGrid
        Item {
            id: groupeSelection
            property int gridXPosition:  0
            property int gridYPosition:  0
        }

    }
    GlobalMa{
        id: mainMa
        mouseLogic: logic.mouseLogic
    }

    Connections{
        target: Game

        function onFoundItemSnapableTile(itemSnapableData){
            logic.tileLogic.createItemSnapable(itemSnapableData);
        }

        function onMapLoaded(map)
        {
            Logger.success("Map loaded", "MAP_LOADING")
            logic.tileLogic.builtConnections();
            // Copy properties from loaded map to preserve bindings
            if (map.mapInfo) {
                gameBoard.mapInfo.setMapInfo(map.mapInfo)
            }
        }
    }
}
