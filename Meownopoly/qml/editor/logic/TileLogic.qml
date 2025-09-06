import QtQuick 2.15
import ItemSnapable
import Game
import "../tools"
import "../tools/snapable"
import ".."

QtObject {
    required property var snapableTilesList
    required property GridManager editorGrid
    required property var logic

    required property EditorDynamicComponent editorDynamicComponent

    // Fonction pour désélectionner tous les tiles
    function deselectAllTiles() {
        // Désélectionner tous les tiles dans la liste
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i]) {
                snapableTilesList[i].isSelected = false
            }
        }
        logic.currentSelectedElement = null
    }


    // Fonction pour créer un nouveau SnapableCaseTile à une position spécifique
    function createNewTileAtPosition(caseType, gridX, gridY, isDecoration) {
        var newTile
        switch (isDecoration){
        case ItemSnapable.DecorationTile:
            newTile = editorDynamicComponent.snapableDecorationComponent.createObject(workArea, {
                                                                                          "displaySettings.gridRelativePositionX": gridX,
                                                                                          "displaySettings.gridRelativePositionY": gridY,
                                                                                          "displaySettings.unitSizeWidth": logic.currentElementWidth,
                                                                                          "displaySettings.unitSizeHeight": logic.currentElementHeight,
                                                                                          "displaySettings.zLayer": 5
                                                                                      })
            break
        case ItemSnapable.CaseTile:
            newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                                                                                        "displaySettings.gridRelativePositionX": gridX,
                                                                                        "displaySettings.gridRelativePositionY": gridY,
                                                                                        "displaySettings.unitSizeWidth": logic.currentElementWidth,
                                                                                        "displaySettings.unitSizeHeight": logic.currentElementHeight,
                                                                                        "caseData": Game.getNewCaseType(caseType),
                                                                                    })
            break
        default:
            break
        }
        if (newTile) {
            snapableTilesList.push(newTile)
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
//            newTile.isSelected = true
            logic.currentSelectedElement = newTile
            newTile.snapToGridFromGrid()
        }
        return newTile
    }

    function changeCaseType(snapableCase, newType)  {
        var newTile = createNewTileAtPosition(newType, snapableCase.displaySettings.gridRelativePositionX, snapableCase.displaySettings.gridRelativePositionY, ItemSnapable.CaseTile)
        newTile.displaySettings.unitSizeWidth = snapableCase.displaySettings.unitSizeWidth
        newTile.displaySettings.unitSizeHeight = snapableCase.displaySettings.unitSizeHeight
        newTile.caseData.name = snapableCase.caseData.name

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


        snapableCase.elementDeleted(snapableCase)
        snapableCase.connectionManager.deleteLinkedConnection()

        newTile.isSelected = true
        newTile.elementConfigurationRequested(newTile)
    }

}


