import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window


import Logger
import Game
import MapTypes
import MapInfo
import "../editor/logic"
import "../component"
import "../component/snapable"
import "../component/grid"

Rectangle {
    id: gameBoard

    color: "lightblue"
    border.width: 0

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

    Item {
        id: logic
        anchors.fill: parent

        property int mmSize : 10
        function updateSize(mm) {
            if (mm > 0)
                mmSize = mm
        }
        property list<SnapableElement> snapableTilesList
        property MouseLogic_Base mouseLogic

        TileLogic{
            id: tileLogic
            logic: logic
            snapableTilesList: logic.snapableTilesList
            dynamicComponent: gameDynamicComponent
        }

    }
    GameDynamicComponent {
        id: gameDynamicComponent
        gameGrid: gameGrid
        logic: logic
    }  

    // Grille de l'éditeur
    GridManager {
        id: gameGrid
        logic: logic
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
    }


    Background {
        id: background
        grid: gameGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? gameGrid : parent
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
        property point dragStartPos: Qt.point(0, 0)
        property point targetStartPos: Qt.point(0, 0)
        
        drag.onActiveChanged: {
            // console.log("drag changed", drag.active);
            if (drag.active && drag.target) {
                // Sauvegarder les positions de départ
                dragStartPos = Qt.point(mouseX, mouseY)
                targetStartPos = Qt.point(drag.target.x, drag.target.y)
            }
            logic.mouseLogic.dragChanged(drag)
        }

        function elementClicked(tile)
        {
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
