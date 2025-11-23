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

Base_Board {
    id: gameBoard

    color: "lightblue"
    border.width: 0

    Component.onCompleted: {
        Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        gameGrid.mmSize = 8
    }

    property alias snapableTilesList: logic.snapableTilesList

    property GameLogic logic : GameLogic {
        parent: gameBoard
        id: logic
        grid: gameGrid
    }
    wheelHandler: Game_WheelHandler {}
    // Grille de l'éditeur
    Item{
        id: workArea
        anchors.fill: gameGrid
        Item {
            id: groupeSelection
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
