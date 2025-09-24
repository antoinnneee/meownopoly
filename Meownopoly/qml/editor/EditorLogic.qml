import QtQuick 2.15
import Game
import Case
import ItemSnapable
import TileType
import "tools"
import "tools/snapable"
import MapInfo
import EditorEnum
import "logic"

Item {
    id: logic
    property list<SnapableElement> snapableTilesList
    required property EditorDynamicComponent editorDynamicComponent
    required property GridManager editorGrid
    required property var selectionRect
    required property MapInfo mapInfo
    required property var workArea

    property alias backgroundInfo : backgroundInfo


    property EditorMouseMode editorMouseMode : EditorEnum.EM_NORMAL

    onEditorMouseModeChanged: {
        console.log("mouse mode change : ", editorMouseMode)
    }

    property alias planLogic: planLogic
    property alias tileLogic: tileLogic

    BackgroundInfo {
        id: backgroundInfo
        backgroundPath: mapInfo.backgroundPath
    }

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
    
    Loader {
        id: mouseLogicLoader
        sourceComponent: (logic.editorMouseMode == EditorEnum.EM_NORMAL) ? mouseLogic_selection_comp
                                                                         : mouseLogic_pose_comp
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
        sourceComponent: (logic.editorMouseMode == EditorEnum.EM_NORMAL) ? scrollLogic_normal_comp
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

    function saveMap(){
        var caseList = [];
        var decoList = [];


        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile) {
                var displayInfo = tile.displaySettings

                if (tile.type === ItemSnapable.CaseTile){
                    var caseData = tile.caseData;
                    if (caseData){
                        var caseInfo = [caseData, displayInfo]
                        caseList.push(caseInfo)
                    }
                }
                else if (tile.type === ItemSnapable.DecorationTile){
                    var decorationInfoData = tile.decorationSettings
                    var decorationInfo = [decorationInfoData, displayInfo]
                    decoList.push(decorationInfo)
                }
            }
        }
        Game.registerMap(mapInfo, caseList, decoList)
    }

    // Fonction pour mettre à jour l'apparence du rectangle de sélection
    function updateSelectionRect() {
        if (!isSelectingArea) return

        // Calculer les coordonnées et dimensions en pixels
        var startX = selectionStart.x * editorGrid.gridSize
        var startY = selectionStart.y * editorGrid.gridSize
        var currentX = selectionCurrent.x * editorGrid.gridSize
        var currentY = selectionCurrent.y * editorGrid.gridSize

        // Assurer que le rectangle est correctement positionné peu importe la direction du drag
        var x = Math.min(startX, currentX)
        var y = Math.min(startY, currentY)
        var width = Math.abs(currentX - startX)
        var height = Math.abs(currentY - startY)

        // Mise à jour du rectangle de sélection
        selectionRect.x = x
        selectionRect.y = y
        selectionRect.width = width
        selectionRect.height = height
    }

    // Fonction pour finaliser la sélection et créer une case
    function finishSelection() {
        if (!isSelectingArea) return

        // Normaliser les coordonnées pour avoir le coin supérieur gauche
        var startX = Math.min(selectionStart.x, selectionCurrent.x)
        var startY = Math.min(selectionStart.y, selectionCurrent.y)
        var width = Math.abs(selectionCurrent.x - selectionStart.x)
        var height = Math.abs(selectionCurrent.y - selectionStart.y)

        // Créer les cases aux dimensions calculées
        if (width >= 1 && height >= 1) {
            // Ajouter +1 car la sélection est inclusive (le point de fin est inclus)
            width = Math.max(1, width)
            height = Math.max(1, height)

            // Utiliser la nouvelle fonction pour remplir avec plusieurs éléments
            fillSelectionWithTiles(startX, startY, width, height)
        }

        // Réinitialiser l'état de sélection
        isSelectingArea = false
        selectionRect.visible = false
    }

    // Fonction pour annuler la sélection en cours
    function cancelSelection() {
        isSelectingArea = false
        selectionRect.visible = false
    }

    // Fonction pour créer une case à partir d'une sélection
    function createTileFromSelection(gridX, gridY, unitWidth, unitHeight) {
        console.log("Création d'une case à partir de la sélection:", gridX, gridY, unitWidth, unitHeight)

        var newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                                                                                        "gridRelativePositionX": gridX,
                                                                                        "gridRelativePositionY": gridY,
                                                                                        "unitSizeWidth": unitWidth,
                                                                                        "unitSizeHeight": unitHeight,
                                                                                        "caseData": Game.getNewCaseType(defaultCaseType),
                                                                                        "z": planLogic.maxPlanDisplayed,
                                                                                        "generalMA": mainMa
                                                                                    })

        if (newTile) {
            snapableTilesList.push(newTile)

            // Désélectionner tout et sélectionner le nouveau tile
            tileLogic.deselectAllTiles()
            newTile.isSelected = true
            //currentSelectedElement = newTile
            newTile.snapToGridFromGridPos()
        }

        return newTile
    }


    // Fonction pour remplir une zone sélectionnée avec plusieurs éléments
    function fillSelectionWithTiles(startX, startY, width, height) {
        console.log("Remplissage de la zone sélectionnée:", startX, startY, width, height)
        console.log("Dimensions des éléments:", tileLogic.currentElementWidth, tileLogic.currentElementHeight)

        // Vérifier si les dimensions sont valides
        if (tileLogic.currentElementWidth <= 0 || tileLogic.currentElementHeight <= 0) {
            console.error("Dimensions d'élément invalides")
            return
        }

        // Calculer combien d'éléments peuvent tenir horizontalement et verticalement
        var tilesPlaced = 0
        var lastTile = null

        // Balayer de haut en bas, de gauche à droite
        for (var y = startY; y <= startY + height - tileLogic.currentElementHeight; y++) {
            for (var x = startX; x <= startX + width - tileLogic.currentElementWidth; x++) {
                console.log(x, y)
                // Vérifier si la position est libre
                var positionOccupied = false

                // Vérifier si cette position chevauche un élément existant
                for (var i = 0; i < snapableTilesList.length; i++) {
                    var tile = snapableTilesList[i]
                    if (!tile) continue

                    // Calculer les limites de l'élément existant
                    var tileLeft = tile.displaySettings.gridRelativePositionX
                    var tileRight = tileLeft + tile.displaySettings.unitSizeWidth
                    var tileTop = tile.displaySettings.gridRelativePositionY
                    var tileBottom = tileTop + tile.displaySettings.unitSizeHeight

                    // Calculer les limites du nouvel élément
                    var newTileLeft = x
                    var newTileRight = x + tileLogic.currentElementWidth
                    var newTileTop = y
                    var newTileBottom = y + tileLogic.currentElementHeight

                    // Vérifier s'il y a chevauchement
                    if (!(newTileRight <= tileLeft || newTileLeft >= tileRight ||
                          newTileBottom <= tileTop || newTileTop >= tileBottom)) {
                        positionOccupied = true
                        break
                    }
                }

                // Si la position est libre, créer un élément
                if (!positionOccupied) {
                    lastTile = tileLogic.createNewTileAtPosition(defaultCaseType, x, y, ItemSnapable.CaseTile)
                    tilesPlaced++;

                    // Avancer horizontalement de la taille de l'élément
                    x += tileLogic.currentElementWidth - 1; // -1 car la boucle incrémente x
                }
            }
        }

        console.log("Éléments placés:", tilesPlaced)

        // Si au moins un élément a été placé, le dernier reste sélectionné
        if (tilesPlaced > 0 && lastTile) {
            tileLogic.deselectAllTiles()
            lastTile.isSelected = true
            //currentSelectedElement = lastTile
        }
    }

    function startSelection(mouse)
    {
        if (isSelectionActive) {
            // Vérifier si le clic est sur un élément existant
            var clickedOnElement = false
            for (var i = 0; i < snapableTilesList.length; i++) {
                if (snapableTilesList[i]) {
                    var element = snapableTilesList[i]
                    var mousePos = mapToItem(element, mouse.x, mouse.y)
                    if (mousePos.x >= 0 && mousePos.x <= element.width &&
                            mousePos.y >= 0 && mousePos.y <= element.height) {
                        clickedOnElement = true
                        break
                    }
                }
            }

            if (!clickedOnElement) {
                // Si le clic n'est pas sur un élément, commencer la sélection par rectangle
                console.log("Début de la sélection par rectangle")
                isSelectingArea = true
                var gridPos = editorGrid.getGridPosition(mouse.x, mouse.y)
                selectionStart = gridPos
                selectionCurrent = gridPos
                selectionRect.visible = true
                logic.updateSelectionRect()
                mouse.accepted = true // Important pour éviter la propagation
            } else {
                // Si le clic est sur un élément, propager l'événement
                console.log("Clic sur un élément existant, propagation de l'événement")
                mouse.accepted = false
            }
        }
    }

    function updateSelection(mouseX, mouseY)
    {
        if (isSelectingArea) {
            //                    console.log("Mise à jour de la sélection")
            // Mettre à jour la position courante
            var gridPos = editorGrid.getGridPosition(mouseX, mouseY)
            selectionCurrent = gridPos
            logic.updateSelectionRect()
        }
    }

}
