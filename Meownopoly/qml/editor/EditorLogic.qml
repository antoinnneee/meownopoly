import QtQuick 2.15
import Game
import "tools/snapable"

QtObject {
    property list<SnapableElement> snapableTilesList
    property var currentSelectedElement
    required property var editorDynamicComponent
    required property var workArea
    property int nextTileId: 0
    
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
        console.log("create tile at", gridX, gridY )
        var newTile
        if (isDecoration) {
            newTile = editorDynamicComponent.snapableDecorationComponent.createObject(workArea, {
                                                          "gridRelativePositionX": gridX,
                                                          "gridRelativePositionY": gridY,
                                                      })
        }
        else {
            newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                                                                 "gridRelativePositionX": gridX,
                                                                 "gridRelativePositionY": gridY,
                                                                 "unitSizeWidth": 6,
                                                                 "unitSizeHeight": 6,
                                                                 "caseData": Game.getNewCaseType(caseType)
                                                             })
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

                newTile.zLayer = snapableCase.zLayer


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

}
