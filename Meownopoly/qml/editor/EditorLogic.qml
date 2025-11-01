import QtQuick 2.15
import Game
import Case
import ItemSnapable
import TileType
import "../component"
import "../component/snapable"
import "../component/grid"
import MapInfo
import EditorEnum
import "logic"
import Logger
import UndoRedoManager 1.0
import MapTypes

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
            grid: _grid
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
            grid: _grid
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
        property var _grid: editorGrid
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
        snapableTilesList: logic.snapableTilesList
        dynamicComponent: logic.editorDynamicComponent
    }


    // Propriétés pour la sélection par rectangle
    property bool isSelectionActive: false
    property point selectionStart: Qt.point(0, 0)
    property point selectionCurrent: Qt.point(0, 0)
    property bool isSelectingArea: false
    property int defaultCaseType: Case.CS_KibbleDispenser


    function removeCurrentMap(){
            // Copier la liste car elle sera modifiée pendant la suppression
            var elementsToRemove = []
            for (var i = 0; i < snapableTilesList.length; i++) {
                elementsToRemove.push(snapableTilesList[i])
            }
            
            // Vider la liste principale d'abord
            snapableTilesList = []
            
            // Détruire les éléments directement sans animation ni sauvegarde
            for (var i = 0; i < elementsToRemove.length; i++) {
                if (elementsToRemove[i]) {
                    elementsToRemove[i].destroy()  // Destruction directe
                }
            }
        }


    function saveMap(isAutoSave){
        // Ne pas sauvegarder si on est en mode restauration
        if (isAutoSave === MapTypes.UNDOREDO && !UndoRedoManager.canSave()) {
            console.log("[SAVE] Blocked during restoration")
            return
        }
        
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

