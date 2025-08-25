import QtQuick 2.15
import Game
import Case
import "tools/snapable"

QtObject {
    property list<SnapableElement> snapableTilesList
    property var currentSelectedElement
    required property var editorDynamicComponent
    required property var workArea
    required property var editorGrid
    required property var selectionRect
    property int nextTileId: 0


    property bool isEditing : false
    property int currentPlanDisplayed : 5


    // Propriétés pour la sélection par rectangle
    property bool isSelectionActive: false
    property point selectionStart: Qt.point(0, 0)
    property point selectionCurrent: Qt.point(0, 0)
    property bool isSelectingArea: false
    property int defaultCaseType: Case.CS_KibbleDispenser

    // Propriétés pour la taille des éléments créés
    property int currentElementWidth: 6
    property int currentElementHeight: 6
    
    property string mapName
    property int mmSize : 20

    onIsEditingChanged:{
        console.log("Édition:", isEditing)
        if (!isEditing)
            for (var i = 0; i < snapableTilesList.length; i++) {
                if (snapableTilesList[i]) {
                    snapableTilesList[i].enabled = true
                    snapableTilesList[i].visible = true
                }
            }
    }

    onCurrentPlanDisplayedChanged: {
        if (isEditing){
            console.log("Changement de plan affiché:", currentPlanDisplayed)
            for (var i = 0; i < snapableTilesList.length; i++) {
                if (snapableTilesList[i]) {
                    var currentTile = snapableTilesList[i]
                    if (currentTile.z < currentPlanDisplayed) {
                        currentTile.enabled = false
                        currentTile.visible = false
                    }
                    else {
                        currentTile.enabled = true
                        currentTile.visible = true
                    }
                }
            }
        }
    }

    function saveMap(){
        var infoMap = [];
        var caseList = [];
        var caseDisplayInfo = [];
        var decoList = [];

        infoMap.push({"name":mapName});

        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile) {
                if (tile.type === 0){
                    var caseData = tile.caseData;
                    var displayInfo = {"unitSizeWidth": tile.unitSizeWidth, "unitSizeHeight": tile.unitSizeHeight, "gridRelativePositionX": tile.gridRelativePositionX, "gridRelativePositionY": tile.gridRelativePositionY, "zLayer": tile.z}
                    if (caseData){
                        caseList.push(caseData)
                        caseDisplayInfo.push(displayInfo)
                    }
                }
                // else if (tile.type === 1){
                //     decoList.push({tile})
                // }
            }
        }
        Game.saveMap(infoMap, caseList, caseDisplayInfo, decoList)
    }

    // Fonction pour désélectionner tous les tiles
    function deselectAllTiles() {
        // Désélectionner tous les tiles dans la liste
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i]) {
                snapableTilesList[i].isSelected = false
            }
        }
        currentSelectedElement = null
    }

    function deleteElementsConnections(element) {
        var nexts = element.connectionManager.nextElements || []
        // itere sur les segments de connexion element->next
        for (var j = 0; j < nexts.length; j++) {
            var nextEl = nexts[j]
            // itere sur les segments de connexion nextEl->element
            var prevs = nextEl.connectionManager.previousElements || []
            for (var k = 0; k < prevs.length; k++) {
                var prevEl = prevs[k]
                if (prevEl === element) {
                    nextEl.connectionManager.removePreviousElement(element)
                }
            }
        }
        // itere sur les segments de connexion element->prev
        var prevs = element.connectionManager.previousElements || []
        for (var j = 0; j < prevs.length; j++) {
            var prevEl = prevs[j]
            // itere sur les segments de connexion prevEl->element
            var nexts = prevEl.connectionManager.nextElements || []
            for (var k = 0; k < nexts.length; k++) {
                var nextEl = nexts[k]
                if (nextEl === element) {
                    prevEl.connectionManager.removeNextElement(element)
                }
            }
        }
    }

    // Fonction pour supprimer un élément
    function deleteElement(element) {
        console.log("Suppression de l'élément:", element)

        // Trouver l'index de l'élément dans la liste
        var index = -1
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i] === element) {
                index = i
                break
            }
        }

        if (index !== -1) {
            // Supprimer l'élément de la liste
            snapableTilesList.splice(index, 1)

            // Si c'était l'élément sélectionné, le désélectionner
            if (currentSelectedElement === element) {
                currentSelectedElement = null
            }

            // Détruire l'objet QML
            element.destroy()
        } else {
            console.log("Erreur: Élément non trouvé dans la liste")
        }
    }

    // Fonction pour créer un nouveau SnapableCaseTile à une position spécifique
    function createNewTileAtPosition(caseType, gridX, gridY, isDecoration) {
        var newTile
        switch (isDecoration){
        case GameBoard.TileType.Decoration:
            newTile = editorDynamicComponent.snapableDecorationComponent.createObject(workArea, {
                                                                                          "gridRelativePositionX": gridX,
                                                                                          "gridRelativePositionY": gridY,
                                                                                          "z": currentPlanDisplayed
                                                                                      })
            break
        case GameBoard.TileType.Personnage:
            newTile = editorDynamicComponent.snapableCharacterComponent.createObject(workArea, {
                                                                                         "gridRelativePositionX": gridX,
                                                                                         "gridRelativePositionY": gridY,
                                                                                         "playerData": Game.getNewPlayer(),
                                                                                         "z": currentPlanDisplayed
                                                                                     })
            break
        case GameBoard.TileType.Case:
            newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                                                                                        "gridRelativePositionX": gridX,
                                                                                        "gridRelativePositionY": gridY,
                                                                                        "unitSizeWidth": currentElementWidth,
                                                                                        "unitSizeHeight": currentElementHeight,
                                                                                        "caseData": Game.getNewCaseType(caseType),
                                                                                        "z": currentPlanDisplayed
                                                                                    })
            break

        default:
            break
        }
        if (newTile) {
            snapableTilesList.push(newTile)
            nextTileId++
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
            newTile.isSelected = true
            currentSelectedElement = newTile
            newTile.snapToGridFromGrid()
        }
        return newTile
    }

    function changeCaseType(snapableCase, newType)  {
        var newTile = logic.createNewTileAtPosition(newType, snapableCase.gridRelativePositionX, snapableCase.gridRelativePositionY, 0)
        newTile.unitSizeWidth = snapableCase.unitSizeWidth
        newTile.unitSizeHeight = snapableCase.unitSizeHeight



        for (var i = 0; i < snapableCase.connectionManager.previousElements.length; i++) {
            var prevEl = snapableCase.connectionManager.previousElements[i]
            if (prevEl) {
                prevEl.connectionManager.addNextElement(newTile)
            }
        }
        for (var i = 0; i < snapableCase.connectionManager.nextElements.length; i++) {
            var nextEl = snapableCase.connectionManager.nextElements[i]
            if (nextEl) {
                nextEl.connectionManager.addPreviousElement(newTile)
            }
        }


        newTile.caseData.name = snapableCase.caseData.name


        snapableCase.elementDeleted(snapableCase)
        snapableCase.connectionManager.deleteLinkedConnection()

        newTile.isSelected = true
        newTile.elementConfigurationRequested(newTile)

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
                                                                                        "z": currentPlanDisplayed
                                                                                    })

        if (newTile) {
            snapableTilesList.push(newTile)
            nextTileId++

            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
            newTile.isSelected = true
            currentSelectedElement = newTile
            newTile.snapToGridFromGrid()
        }

        return newTile
    }


    // Fonction pour remplir une zone sélectionnée avec plusieurs éléments
    function fillSelectionWithTiles(startX, startY, width, height) {
        console.log("Remplissage de la zone sélectionnée:", startX, startY, width, height)
        console.log("Dimensions des éléments:", currentElementWidth, currentElementHeight)

        // Vérifier si les dimensions sont valides
        if (currentElementWidth <= 0 || currentElementHeight <= 0) {
            console.error("Dimensions d'élément invalides")
            return
        }

        // Calculer combien d'éléments peuvent tenir horizontalement et verticalement
        var tilesPlaced = 0
        var lastTile = null

        // Balayer de haut en bas, de gauche à droite
        for (var y = startY; y <= startY + height - currentElementHeight; y++) {
            for (var x = startX; x <= startX + width - currentElementWidth; x++) {
                console.log(x, y)
                // Vérifier si la position est libre
                var positionOccupied = false

                // Vérifier si cette position chevauche un élément existant
                for (var i = 0; i < snapableTilesList.length; i++) {
                    var tile = snapableTilesList[i]
                    if (!tile) continue

                    // Calculer les limites de l'élément existant
                    var tileLeft = tile.gridRelativePositionX
                    var tileRight = tileLeft + tile.unitSizeWidth
                    var tileTop = tile.gridRelativePositionY
                    var tileBottom = tileTop + tile.unitSizeHeight

                    // Calculer les limites du nouvel élément
                    var newTileLeft = x
                    var newTileRight = x + currentElementWidth
                    var newTileTop = y
                    var newTileBottom = y + currentElementHeight

                    // Vérifier s'il y a chevauchement
                    if (!(newTileRight <= tileLeft || newTileLeft >= tileRight ||
                          newTileBottom <= tileTop || newTileTop >= tileBottom)) {
                        positionOccupied = true
                        break
                    }
                }

                // Si la position est libre, créer un élément
                if (!positionOccupied) {
                    lastTile = createNewTileAtPosition(defaultCaseType, x, y, GameBoard.TileType.Case)
                    tilesPlaced++;

                    // Avancer horizontalement de la taille de l'élément
                    x += currentElementWidth - 1; // -1 car la boucle incrémente x
                }
            }
        }

        console.log("Éléments placés:", tilesPlaced)

        // Si au moins un élément a été placé, le dernier reste sélectionné
        if (tilesPlaced > 0 && lastTile) {
            deselectAllTiles()
            lastTile.isSelected = true
            currentSelectedElement = lastTile
        }
    }

    function startSelection(mouse)
    {
        if (isEditing && isSelectionActive) {
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
