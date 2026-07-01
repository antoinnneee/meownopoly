import QtQuick 2.15
import QtCore

import Game
import AssetManager
import Case
import ItemSnapable
import TileType
import meowComponent

// import bottomMainPanel

import MapInfo
import EditorEnum
import Logger
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

    // D3d — état « sélection de pose » (asset/case armé), détenu par logic.
    // Consommé par AssetPreviewCursor, TileLogic, MouseLogic_Pose, EditorController.
    // Pendant la transition (deco/case encore dans le SelectionPanel legacy), ces
    // valeurs sont alimentées par binding depuis selectionPanel (cf. Editor.qml) ;
    // les conteneurs bespoke (D3d-2/D3e) les écriront ensuite directement.
    property string currentSelectedAssetCategory: ""
    property string currentSelectedAssetType: ""
    property string currentSelectedAssetId: ""
    property int caseTypeSelected: -1
    readonly property bool isAssetSelected:
        currentSelectedAssetCategory !== "" && currentSelectedAssetType !== "" && currentSelectedAssetId !== ""

    // Pose PNJ armée (module "npc"). Prioritaire sur asset/case dans
    // TileLogic.placeSelectedAsset. npcPoseConfig porte les valeurs saisies
    // dans le NPCPanel : { npcName, visualKind, modelName, triggerMode,
    // spriteCategory, spriteType, spriteId }.
    property bool npcPoseArmed: false
    property var npcPoseConfig: ({})

    // Modes "spécialisés" : on n'y force pas EM_POSE/EM_NORMAL sur (dé)sélection
    // (reprend les gardes des anciens handlers du SelectionPanel).
    function _isSpecializedMode() {
        return editorMouseMode === EditorEnum.EM_TEMPLATE
            || editorMouseMode === EditorEnum.EM_DRAW_POLYGON
            || editorMouseMode === EditorEnum.EM_SELECTION_LINK
            || editorMouseMode === EditorEnum.EM_GAME
    }

    // Arme la pose d'un PNJ. Désarme asset/case (mutuellement exclusifs).
    function armNpcPose(config) {
        currentSelectedAssetCategory = ""
        currentSelectedAssetType = ""
        currentSelectedAssetId = ""
        caseTypeSelected = -1
        npcPoseConfig = config || ({})
        npcPoseArmed = true
        if (!_isSpecializedMode() && mouseLogic)
            mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
    }

    // Arme un asset (décoration) pour la pose. Re-sélectionner le même = toggle off.
    // Armer un asset désarme toute case (sélections mutuellement exclusives).
    function updateSelectedAsset(category, type, id) {
        if (isAssetSelected && currentSelectedAssetCategory === category
                && currentSelectedAssetType === type && currentSelectedAssetId === id) {
            clearAssetSelection()
            return
        }
        npcPoseArmed = false
        caseTypeSelected = -1
        currentSelectedAssetCategory = category
        currentSelectedAssetType = type
        currentSelectedAssetId = id
        const asset = AssetManager.getAssetById(category, type, id)
        if (asset && asset.id && tileLogic)
            tileLogic.adjustToNativeRatio(asset.ratioWidth || 1, asset.ratioHeight || 1)
        if (!_isSpecializedMode() && mouseLogic)
            mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
    }

    // Efface toute sélection de pose (asset + case + PNJ) et revient en mode normal.
    function clearAssetSelection() {
        currentSelectedAssetCategory = ""
        currentSelectedAssetType = ""
        currentSelectedAssetId = ""
        caseTypeSelected = -1
        npcPoseArmed = false
        if (!_isSpecializedMode() && mouseLogic)
            mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
    }

    // Arme (type >= 0) ou désarme (type === -1) un type de case pour la pose.
    // Armer une case désarme tout asset (sélections mutuellement exclusives).
    function setCaseType(type) {
        if (type !== -1) {
            currentSelectedAssetCategory = ""
            currentSelectedAssetType = ""
            currentSelectedAssetId = ""
            npcPoseArmed = false
        }
        caseTypeSelected = type
        if (!_isSpecializedMode() && mouseLogic)
            mouseLogic.changeMouseMode(type !== -1 ? EditorEnum.EM_POSE : EditorEnum.EM_NORMAL)
    }
    property var polygonPreview: null  // Référence au composant de prévisualisation du polygone
    property EditorMouseMode editorMouseMode : EditorEnum.EM_NORMAL

    signal snapableTilesListUpdated()


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
        sourceComponent: (logic.editorMouseMode === EditorEnum.EM_NORMAL) ? editorDynamicComponent.mouseLogic_selection_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_POSE) ? editorDynamicComponent.mouseLogic_pose_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_GAME) ? editorDynamicComponent.mouseLogic_game_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON) ? editorDynamicComponent.mouseLogic_drawPolygon_comp
                                    : (logic.editorMouseMode === EditorEnum.EM_TEMPLATE) ? editorDynamicComponent.mouseLogic_template_comp
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
            snapableTilesListUpdated()

            // Détruire les éléments directement sans animation ni sauvegarde
            for (var i = 0; i < elementsToRemove.length; i++) {
                if (elementsToRemove[i]) {
                    elementsToRemove[i].destroy()  // Destruction directe
                }
            }
        }

    function saveMap(saveType){
        if (saveType === MapTypes.UNDOREDO) {
            // UNDOREDO est géré individuellement par Game.updateMap()
            console.log("Sauvegarde UNDOREDO : gérée par Game.updateMap(), ne devrait pas être appelée ici.")
            return
        }

        // Vérifier si on peut sauvegarder (pas en cours de restauration)
        if (!(MapFileManager.currentMap ? MapFileManager.currentMap.canSave : true)) {
            console.log("Sauvegarde impossible : une restauration est en cours.")
            return
        }

        var itemSnapableList = []
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile)
                itemSnapableList.push(tile.snapableParameters)
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
}




