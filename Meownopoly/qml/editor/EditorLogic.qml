import QtQuick
import QtCore

import Game
import Case
import ItemSnapable
import TileType
import MapInfo
import EditorEnum
import Logger
import UndoRedoManager
import MapTypes

import "tools"
import "tools/snapable"
import "tools/grid"
import "logic"

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


    // Fonction helper pour collecter les données de snapableTilesList
    function collectItemSnapableList() {
        var itemSnapableList = [];
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile) {
                itemSnapableList.push(tile.snapableParameters)
            }
        }
        return itemSnapableList
    }

    function saveMap(isAutoSave){
        // Vérifier si on est en mode sauvegarde sur modification
        var isSaveOnModification = stEnableAutoSave.saveEvent === 3
        
        // Ne pas sauvegarder UNDOREDO si on est en mode restauration
        var canSaveUndoRedo = !(isAutoSave === MapTypes.UNDOREDO && !UndoRedoManager.canSave())
        
        // Si UNDOREDO est bloqué mais qu'on est en mode sauvegarde sur modification,
        // on peut quand même sauvegarder directement vers AUTOSAVE/CUSTOM
        if (!canSaveUndoRedo) {
            console.log("[SAVE] UNDOREDO blocked during restoration")
            
            // Si on est en mode sauvegarde sur modification, sauvegarder directement
            if (isSaveOnModification && isAutoSave === MapTypes.UNDOREDO) {
                // Collecter les données juste avant la sauvegarde pour garantir la cohérence
                var itemSnapableList = collectItemSnapableList()
                
                // Vérifier qu'il y a des données à sauvegarder
                if (itemSnapableList.length > 0) {
                    console.log("[SAVE ON MODIFICATION] Direct save (UNDOREDO blocked)")
                    var mapType = mapInfo.mapName === mapInfo.autosaveMapName ? MapTypes.AUTOSAVE : MapTypes.CUSTOM
                    Game.saveMap(mapInfo, itemSnapableList, mapType)
                } else {
                    console.log("[SAVE ON MODIFICATION] Skipped - no data to save")
                }
            }
            return
        }
        
        // Collecter les données juste avant la sauvegarde UNDOREDO pour garantir la cohérence
        var itemSnapableList = collectItemSnapableList()
        
        // Sauvegarder vers UNDOREDO
        Game.saveMap(mapInfo, itemSnapableList, isAutoSave)
        
        // Si on est en mode sauvegarde sur modification, sauvegarder aussi vers fichier
        if (isSaveOnModification && isAutoSave === MapTypes.UNDOREDO) {
            // Vérifier qu'il y a des données à sauvegarder
            if (itemSnapableList.length > 0) {
                // Collecter à nouveau les données juste avant cette sauvegarde pour garantir la cohérence
                // (en cas de modifications entre les deux sauvegardes)
                var itemSnapableListForFile = collectItemSnapableList()
                
                if (itemSnapableListForFile.length > 0) {
                    console.log("[SAVE ON MODIFICATION] Triggered after UNDOREDO save")
                    var mapType = mapInfo.mapName === mapInfo.autosaveMapName ? MapTypes.AUTOSAVE : MapTypes.CUSTOM
                    Game.saveMap(mapInfo, itemSnapableListForFile, mapType)
                } else {
                    console.log("[SAVE ON MODIFICATION] Skipped - no data to save")
                }
            } else {
                console.log("[SAVE ON MODIFICATION] Skipped - no data to save")
            }
        }
    }
    Settings {
        id: stEnableAutoSave
        category: "Editor/SaveConfig"
        property var currentMap : value("currentMap", mapInfo.autosaveMapName)
        property int saveEvent: value("saveEvent", "0")
        // onCurrentMapChanged: console.log("currentMap :", currentMap, " saveEvent:", saveEvent)
    }
}




