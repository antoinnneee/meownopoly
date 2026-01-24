import QtQuick 2.15
import QtCore

import Game
import Case
import ItemSnapable
import TileType
import meowComponent

import bottomMainPanel

import MapInfo
import EditorEnum
import Logger
import UndoRedoManager
import MapTypes
import MapFileManager

import "logic"

Base_logic {
    id: logic
    property list<SnapableElement> snapableTilesList
    required property GridManager editorGrid
    required property var selectionRect
    required property MapInfo mapInfo
    required property var workArea

    property var selectionPanel: null  // Référence au SelectionPanel pour la configuration des cases
    property var editorSidePanel: null
    property var polygonPreview: null  // Référence au composant de prévisualisation du polygone
    property EditorMouseMode editorMouseMode : EditorEnum.EM_NORMAL


    property alias planLogic: planLogic
    property alias tileLogic: tileLogic

    PlanLogic {
        id: planLogic
        logic: parent
        editorGrid: logic.editorGrid
        snapableTilesList: logic.snapableTilesList
    }


    Loader {
        id: mouseLogicLoader
        onSourceComponentChanged: {
            console.log("MouseLogicLoader - Loaded component for mode:", logic.editorMouseMode)
        }
        sourceComponent: (logic.editorMouseMode === EditorEnum.EM_NORMAL) ? editorDynamicComponent.mouseLogic_selection_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_POSE) ? editorDynamicComponent.mouseLogic_pose_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_GAME) ? editorDynamicComponent.mouseLogic_game_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON) ? editorDynamicComponent.mouseLogic_drawPolygon_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_TEMPLATE) ? editorDynamicComponent.mouseLogic_temp_comp
                                    : editorDynamicComponent.mouseLogic_selectionLink_comp
        property var _logic : parent
        property var _grid: editorGrid
        property var _polygonPreview: logic.polygonPreview
    }

    Loader {
        id: scrollLogicLoader
        sourceComponent: (logic.editorMouseMode === EditorEnum.EM_NORMAL) ? editorDynamicComponent.scrollLogic_normal_comp
                                                                         : editorDynamicComponent.scrollLogic_pose_comp
        property GridManager _editorGrid : parent.editorGrid
        property var _logic : parent
    }


    TileLogic{
        id: tileLogic
        logic: logic
        snapableTilesList: logic.snapableTilesList
        dynamicComponent: editorDynamicComponent
    }

    EditorDynamicComponent {
        id: editorDynamicComponent
        gameGrid: logic.editorGrid
        logic: logic
    }

    // Connexion au signal de snap pour recréer les bindings des éléments sélectionnés
    Connections {
        target: editorGrid
        function onSelectedElementSnapped(element) {
            console.log("Selected element snapped : ", element, mouseLogicLoader.item, mouseLogicLoader.item.rebindElement)
            if (mouseLogicLoader.item && mouseLogicLoader.item.rebindElement) {
                mouseLogicLoader.item.rebindElement(element)
            }
        }
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

    function saveMap(saveType){
        // Ne pas sauvegarder si on est en mode restauration
        if (saveType === MapTypes.UNDOREDO && !UndoRedoManager.canSave()) {
            console.log("[UNDO][SAVE] Blocked during restoration - canSave() returned false")
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

        if (saveType === MapTypes.UNDOREDO) {
            console.log("[UNDO][SAVE] Saving new state with", snapableTilesList.length, "elements")
        }
        Game.saveMap(mapInfo, itemSnapableList, saveType)
    }

    function deleteMap(mapName){
        if (mapName === mapInfo.autosaveMapName){
            if (Game.deleteMap(mapName, MapTypes.AUTOSAVE))
                MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
        }
        else {
            Game.deleteMap(mapName, MapTypes.CUSTOM)
        }
    }

    function createMap(mapName, mapType){
        MapFileManager.createMapFile(mapName, mapType)
    }


    Settings {
        id: stEnableAutoSave
        category: "Editor/SaveConfig"
        property var currentMap : value("currentMap", mapInfo.autosaveMapName)
        property int saveEvent: value("saveEvent", "0")
        // onCurrentMapChanged: console.log("currentMap :", currentMap, " saveEvent:", saveEvent)
    }
}




