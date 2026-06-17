import QtQuick 2.15
import QtCore

import Game
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

    // Délèguent au SelectionPanel legacy pendant la transition ; seront
    // redéfinies pour agir sur l'état local en D3d-2/D3e.
    function clearAssetSelection() {
        if (selectionPanel) selectionPanel.clearAssetSelection()
    }
    function updateSelectedAsset(category, type, id) {
        if (selectionPanel && selectionPanel.assetPanel)
            selectionPanel.assetPanel.updateSelectedAsset(category, type, id)
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




