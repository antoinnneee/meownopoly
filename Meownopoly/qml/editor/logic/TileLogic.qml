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

    // Propriétés pour la taille des éléments créés
    property int currentElementWidth: 3
    property int currentElementHeight: 4

    property real currentZOrder: 0.00001

    // Fonction pour désélectionner tous les tiles
    function deselectAllTiles() {
        // Désélectionner tous les tiles dans la liste
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i].isSelected) {
                snapableTilesList[i].elementUnselected()
            }
        }
        if (logic.mouseLogic && logic.mouseLogic.selectedElements.length)
        logic.mouseLogic.selectedElements = []
    }


    // Fonction pour créer un nouveau SnapableCaseTile à une position spécifique


    function createNewTileAtPosition(caseType, gridX, gridY, isDecoration) {
        var newTile
        currentZOrder = currentZOrder + 0.00001
        switch (isDecoration){
        case ItemSnapable.DecorationTile:
            newTile = editorDynamicComponent.snapableDecorationComponent.createObject(workArea, {
                                                                                          "displaySettings.gridRelativePositionX": gridX,
                                                                                          "displaySettings.gridRelativePositionY": gridY,
                                                                                          "displaySettings.unitSizeWidth": currentElementWidth,
                                                                                          "displaySettings.unitSizeHeight": currentElementHeight,
                                                                                          "displaySettings.zLayer": 5,
                                                                                          "displaySettings.zOrder": currentZOrder,
                                                                                          "generalMA": mainMa
                                                                                      })
            break
        case ItemSnapable.CaseTile:
            newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                                                                                        "displaySettings.gridRelativePositionX": gridX,
                                                                                        "displaySettings.gridRelativePositionY": gridY,
                                                                                        "displaySettings.unitSizeWidth": currentElementWidth,
                                                                                        "displaySettings.unitSizeHeight": currentElementHeight,
                                                                                        "displaySettings.zOrder": currentZOrder,
                                                                                        "snapableParameters.caseData": Game.getNewCaseType(caseType),
                                                                                        "generalMA": mainMa
                                                                                    })
            break
        default:
            break
        }
        if (newTile) {
            snapableTilesList.push(newTile)
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()

            //logic.currentSelectedElement = newTile
            newTile.snapToGridFromGridPos()
        }
        return newTile
    }

    function changeCaseType(snapableCase, newType)  {
        var newTile = createNewTileAtPosition(newType, snapableCase.snapableParameters.displayParameter.gridRelativePositionX, snapableCase.snapableParameters.displayParameter.gridRelativePositionY, ItemSnapable.CaseTile)
        newTile.snapableParameters.displayParameter.unitSizeWidth = snapableCase.snapableParameters.displayParameter.unitSizeWidth
        newTile.snapableParameters.displayParameter.unitSizeHeight = snapableCase.snapableParameters.displayParameter.unitSizeHeight
        newTile.snapableParameters.caseData.name = snapableCase.snapableParameters.caseData.name

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

    function createItemSnapable(itemSnapableData) {
        currentZOrder = currentZOrder + 0.00001
        console.log("data:",itemSnapableData)
        itemSnapableData.print()
        
        // Créer le bon type de tile selon le tileType
        // On passe directement itemSnapableData pour conserver les références next/prev
        var newTile
        if (itemSnapableData.tileType === ItemSnapable.CaseTile) {
            newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                "generalMA": mainMa,
                "snapableParameters": itemSnapableData
            })
        } else if (itemSnapableData.tileType === ItemSnapable.DecorationTile) {
            newTile = editorDynamicComponent.snapableDecorationComponent.createObject(workArea, {
                "generalMA": mainMa,
                "snapableParameters": itemSnapableData
            })
        }
        
        if (newTile) {
            console.log("created item")
            newTile.snapableParameters.print()
            
            snapableTilesList.push(newTile)
            newTile.snapToGridFromGridPos()
        }
        return newTile
    }

    // Fonction pour créer un case tile à partir d'un caseData et d'un displaySettings
    function createCaseTile(dispSettings, caseData) {
        currentZOrder = currentZOrder + 0.00001
        dispSettings.zOrder = currentZOrder
        var newTile = editorDynamicComponent.snapableCaseTileComponent.createObject(workArea, {
                                                                                        "displaySettings": dispSettings,
                                                                                        "snapableParameters.caseData": caseData,
                                                                                        "generalMA": mainMa
                                                                                    })

        if (newTile) {
            snapableTilesList.push(newTile)
            newTile.snapToGridFromGridPos()
        }
        return newTile
    }

    function createDecorationTile(dispSettings, decorationParameter) {
        currentZOrder = currentZOrder + 0.00001
        dispSettings.zOrder = currentZOrder
        var newTile = editorDynamicComponent.snapableDecorationComponent.createObject(workArea, {
                                                                                        "displaySettings": dispSettings,
                                                                                        "snapableParameters.decorationParameter": decorationParameter,
                                                                                        "generalMA": mainMa
                                                                                    })
        if (newTile) {
            snapableTilesList.push(newTile)
            newTile.snapToGridFromGridPos()
        }
        return newTile
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
            logic.mouseLogic.unselectSelectedElements()

            // Détruire l'objet QML
            element.destroy()
        } else {
            console.log("Erreur: Élément non trouvé dans la liste")
        }
    }



 /*
============================
====== Gestion des connections ======
============================
*/
    function createSnapableLink(source, target, kind)
    {
        if (!source || !target) {
            return
        }
        if (source === target) {
            return
        }

        if (kind === "previous") {
            source.connectionManager.addPreviousElement(target)
        } else if (kind === "next") {
            source.connectionManager.addNextElement(target)
        }
    }

    function builtConnections()
    {
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            if (tile ) {
                tile.blockConnections = true
                var nextList = tile.snapableParameters.getNextList()
                for (var j = 0; j < nextList.length; j++) {
                    var nextElCaseData = nextList[j]
                    var nextEl = snapableTilesList.find(function(tile) {
                        return tile.snapableParameters === nextElCaseData
                    })
                    if (nextEl) {
                        nextEl.blockConnections = true
                        tile.connectionManager.addNextElement(nextEl)
                        nextEl.connectionManager.addPreviousElement(tile)
                        nextEl.blockConnections = false
                    }
                }
                tile.blockConnections = false
            }
        }
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
        var p_prevs = element.connectionManager.previousElements || []
        for (var p_j = 0; j < p_prevs.length; j++) {
            var p_prevEl = p_prevs[p_j]
            // itere sur les segments de connexion prevEl->element
            var p_nexts = p_prevEl.connectionManager.nextElements || []
            for (var p_k = 0; p_k < p_nexts.length; p_k++) {
                var p_nextEl = p_nexts[p_k]
                if (p_nextEl === element) {
                    p_prevEl.connectionManager.removeNextElement(element)
                }
            }
        }
    }

}


