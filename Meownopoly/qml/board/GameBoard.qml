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
import "../meowComponent"
import "../meowComponent/snapable"
import "../meowComponent/grid"
import utils

Base_Board {
    id: gameBoard

    color: "lightblue"
    border.width: 0

    Component.onCompleted: {
        Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        gameGrid.mmSize = 8
        // Passer la liste des tiles pour la collision avec les zones d'exclusion
        //EntityEngine.setTarget(entity, view3D, gameGrid, logic, snapableTilesList)
        EntityEngine.setContext(view3D, gameGrid, logic)
        EntityEngine.setZone(snapableTilesList)
    }

    Keys.onPressed: function(event) {
        // Pass to EntityEngine
        EntityEngine.keysHandler.Keys.pressed(event)
    }
    Keys.onReleased: function(event) {
        EntityEngine.keysHandler.Keys.released(event)
        logic.mouseLogic.isControlPressed = false
    }

    property alias snapableTilesList: logic.snapableTilesList

    logic : GameLogic {
        parent: gameBoard
        id: logic
        grid: gameGrid
    }
    wheelHandler: Game_WheelHandler {}
    // Grille de l'éditeur
    // Zone de travail de l'éditeur (par-dessus la grille)
    Base_WorkArea {
        id: workArea
        z: z_WORKAREA
        anchors.fill: gameGrid
        GameScene {
            id: gameScene
            x: -gameGrid.x
            y: -gameGrid.y
            width: gameBoard.width
            height: gameBoard.height
            z: 5.5 // Z-index relatif à workArea (au milieu des plans 2D)

            // Bind camera magnification to grid scale level
            cameraMagnification: gameGrid.scaleLevel
        }
    }

    Connections{
        target: Game

        function onFoundItemSnapableTile(itemSnapableData){
            logic.tileLogic.createItemSnapableTile(itemSnapableData);
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
