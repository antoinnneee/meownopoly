import QtQuick 2.15
import Game
import Case
import ItemSnapable
import TileType
import "tools"
import "tools/snapable"
import "tools/grid"
import MapInfo
import EditorEnum
import "logic"
import Logger

Item {
    id: logic
    property list<SnapableElement> snapableTilesList
    required property EditorDynamicComponent editorDynamicComponent
    required property GridManager editorGrid
    required property var selectionRect
    required property MapInfo mapInfo
    required property var workArea

    property var selectionPanel: null  // Référence au SelectionPanel pour la configuration des cases

    property EditorMouseMode editorMouseMode : EditorEnum.EM_NORMAL

    onEditorMouseModeChanged: {
    }

    property alias planLogic: planLogic
    property alias tileLogic: tileLogic

    PlanLogic {
        id: planLogic
        logic: parent
        editorGrid: logic.editorGrid
        snapableTilesList: logic.snapableTilesList
    }

    property MouseLogic_Base mouseLogic

    Component {
        id: mouseLogic_selection_comp
        MouseLogic_Selection {
            id: mouseLogic_selection
            logic: _logic
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_selection
            }
        }
    }

    Component {
        id: mouseLogic_pose_comp
        MouseLogic_Pose {
            id: mouseLogic_pose
            logic: _logic
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_pose
            }
        }
    }

    Component {
        id: mouseLogic_selectionLink_comp
        MouseLogic_Selection_link {
            id: mouseLogic_selectionLink
            logic: _logic
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_selectionLink
            }
        }
    }

    Loader {
        id: mouseLogicLoader
        sourceComponent: (logic.editorMouseMode === EditorEnum.EM_NORMAL) ? mouseLogic_selection_comp
                        : (logic.editorMouseMode === EditorEnum.EM_POSE) ? mouseLogic_pose_comp
                        : mouseLogic_selectionLink_comp
        property var _logic : parent
    }
    property ScrollLogic scrollLogic

    Component{
        id: scrollLogic_normal_comp
        ScrollLogic {
            id: scrollLogic_normal
            editorGrid: _editorGrid
            logic: _logic
            Component.onCompleted: {
                logic.scrollLogic = scrollLogic_normal
            }
        }
    }

    Component{
        id: scrollLogic_pose_comp
        ScrollLogic_POSE {
            id: scrollLogic_pose
            editorGrid: _editorGrid
            logic: _logic
            Component.onCompleted: {
                logic.scrollLogic = scrollLogic_pose
            }
        }
    }

    Loader {
        id: scrollLogicLoader
        sourceComponent: (logic.editorMouseMode === EditorEnum.EM_NORMAL) ? scrollLogic_normal_comp
                                                                         : scrollLogic_pose_comp
        property GridManager _editorGrid : parent.editorGrid
        property var _logic : parent
    }

    TileLogic{
        id: tileLogic
        logic: logic
        editorGrid: logic.editorGrid
        snapableTilesList: logic.snapableTilesList
        editorDynamicComponent: logic.editorDynamicComponent
    }


    // Propriétés pour la sélection par rectangle
    property bool isSelectionActive: false
    property point selectionStart: Qt.point(0, 0)
    property point selectionCurrent: Qt.point(0, 0)
    property bool isSelectingArea: false
    property int defaultCaseType: Case.CS_KibbleDispenser

    property int mmSize : 10
    function updateSize(mm) {
        if (mm > 0)
            mmSize = mm
    }

    function removeCurrentMap(){
            // Make a copy of the list since it will be modified during deletion
            var elementsToRemove = []
            for (var i = 0; i < snapableTilesList.length; i++) {
                elementsToRemove.push(snapableTilesList[i])
            }

            // Process each element in the copied list
            for (var i = 0; i < elementsToRemove.length; i++) {
                // Find the SnapableElementControl for this element and emit deleteRequested
                if (elementsToRemove[i]) {
                    // The deleteAnimation will automatically call elementDeleted when finished
                    elementsToRemove[i].deleteRequest()
                }
            }
        }


    function saveMap(isAutoSave){
        var itemSnapableList = [];

        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile) {
                var displayInfo = tile.snapableParameters.displayParameter
                itemSnapableList.push(tile.snapableParameters)
            }
        }
        Game.saveMap(mapInfo, itemSnapableList, isAutoSave)
    }
}

