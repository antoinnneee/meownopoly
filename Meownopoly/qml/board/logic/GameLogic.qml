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
import "../"
import "../../component"
import "../../component/snapable"
import "../../component/grid"

Item {
    id: logic

    required property GridManager grid

    property alias tileLogic: tileLogic

    
    property int mmSize : 12
    function updateSize(mm) {
        if (mm > 0)
            mmSize = mm
    }
    property list<SnapableElement> snapableTilesList
    property MouseLogic_Base mouseLogic
    property ScrollLogic scrollLogic
    
    Component{
        id: scrollLogic_normal_comp
        ScrollLogic {
            id: scrollLogic_normal
            editorGrid: _grid
            logic: _logic
            Component.onCompleted: {
                logic.scrollLogic = scrollLogic_normal
            }
        }
    }
    
    
    Loader {
        id: scrollLogicLoader
        sourceComponent: scrollLogic_normal_comp
        property GridManager _grid : grid
        property var _logic : parent
    }

    Component {
        id: mouseLogic_selection_comp
        MouseLogic_Base {
            id: mouseLogic_selection
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_selection
            }
        }
    }
    
    Loader {
        id: mouseLogicLoader
        sourceComponent: mouseLogic_selection_comp
        property var _logic : parent
        property var _grid: grid
    }

    TileLogic{
        id: tileLogic
        logic: logic
        snapableTilesList: logic.snapableTilesList
        dynamicComponent: gameDynamicComponent
    }

    GameDynamicComponent {
        id: gameDynamicComponent
        gameGrid: grid
        logic: logic
    }
}
