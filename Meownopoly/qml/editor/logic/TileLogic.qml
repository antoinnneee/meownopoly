import QtQuick 2.15
import ItemSnapable
import Game
import "../tools"
import "../tools/snapable"
import "../tools/grid"
import "../tools/preview"
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

    property bool displayLinkEnable :false
    
    /**
     * @brief Ajuste les dimensions de l'élément pour respecter le ratio natif de l'image
     * @param ratioWidth Largeur du ratio natif (ex: 4 pour 4:3)
     * @param ratioHeight Hauteur du ratio natif (ex: 3 pour 4:3)
     * @note Conserve la largeur actuelle et calcule la hauteur proportionnelle
     * @example Si sélecteur est 8x8 et image est 4:3 -> résultat sera 8x6
     */
    function adjustToNativeRatio(ratioWidth, ratioHeight) {
        if (!ratioWidth || !ratioHeight || ratioWidth <= 0 || ratioHeight <= 0) {
            console.warn("TileLogic: Ratio invalide", ratioWidth, ratioHeight)
            return
        }
        
        // Utiliser la largeur actuelle comme référence
        var referenceWidth = currentElementWidth
        
        // Calculer la nouvelle hauteur en respectant le ratio natif
        // ratio = width/height => height = width/ratio
        var nativeRatio = ratioWidth / ratioHeight
        var newHeight = Math.round(referenceWidth / nativeRatio)
        
        // S'assurer qu'on a au moins 1 de hauteur
        newHeight = Math.max(1, newHeight)
        
        console.log("TileLogic: Ajustement au ratio natif", ratioWidth + ":" + ratioHeight, 
                    "(" + nativeRatio.toFixed(2) + ")",
                    "de", currentElementWidth + "x" + currentElementHeight, 
                    "vers", referenceWidth + "x" + newHeight)
        
        currentElementHeight = newHeight
    }

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


    function createItemSnapable(itemSnapableData) {
        currentZOrder = currentZOrder + 0.00001
        console.log("data:",itemSnapableData)
        itemSnapableData.displayParameter.zOrder  = currentZOrder;
        // itemSnapableData.print()
        
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
            // console.log("created item")
            // newTile.snapableParameters.print()
            
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
        
        // Sauvegarder après création de la connexion
        logic.saveMap(MapTypes.UNDOREDO)
    }

    function builtConnections()
    {
        for (var i = 0; i < snapableTilesList.length; i++) {
            var tile = snapableTilesList[i]
            console.log("built tile connections", tile)
            if (tile ) {
                tile.blockConnections = true
                var nextList = tile.snapableParameters.getNextList()
                console.log("nextlist connections", nextList)
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


