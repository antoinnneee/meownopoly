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
    WheelHandler {
        onWheel: (wheel)=> {
                     if (wheel.angleDelta.y > 0)
                     {
                         logic.scrollLogic.scrollUp(wheel)
                     }
                     else if (wheel.angleDelta.y < 0)
                     {
                         logic.scrollLogic.scrollDown(wheel)
                     }
                     if (wheel.angleDelta.x > 0)
                     {
                         logic.scrollLogic.scrollRight(wheel)
                     }
                     else if (wheel.angleDelta.x < 0)
                     {
                         logic.scrollLogic.scrollLeft(wheel)
                     }
                     for (var i = 0; i < logic.snapableTilesList.length; i++) {
                         if (logic.snapableTilesList[i]) {
                             logic.snapableTilesList[i].isSelected = false
                             logic.snapableTilesList[i].snapToGridFromGridPos()
                         }
                     }

                 }
    }
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

    MouseArea{
        id: mainMa
        z:0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        pressAndHoldInterval: 300
        drag.target: null
        drag.axis: Drag.XAndYAxis
        drag.smoothed: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property list<SnapableElement> clickElement:[]
        property list<var> elementInitialPosition:[]

        drag.onActiveChanged: {
            logic.mouseLogic.dragChanged(mouseX, mouseY, drag)
        }

        function elementClicked(tile)
        {
            console.log("element clicked")
            logic.mouseLogic.elementClicked(tile, drag)
        }

        onPressed: function (mouse) {
            if (mouse.button === Qt.LeftButton) {
                logic.mouseLogic.pressedLeft(mouse, drag)
            }
            else if (mouse.button === Qt.MiddleButton) {
                logic.mouseLogic.pressedMiddle(mouse, drag)
            }
            else if (mouse.button === Qt.RightButton) {
                logic.mouseLogic.pressedRight(mouse, drag)
            }
        }

        onReleased: function(mouse) {
            logic.mouseLogic.release(mouse, drag)
        }

        onPositionChanged: function(mouse) {
            logic.mouseLogic.positionChanged(mouse, drag)
        }

        onPressAndHold: function (mouse) {
            logic.mouseLogic.pressedAndHold(mouse)

        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                logic.mouseLogic.clickedLeft(mouse, drag)
            }
            else if (mouse.button === Qt.RightButton) {
                logic.mouseLogic.clickedRight(mouse, drag)
            }
            else if (mouse.button === Qt.MiddleButton) {
                logic.mouseLogic.clickedMiddle(mouse, drag)
            }
            return;
        }
    }
}
