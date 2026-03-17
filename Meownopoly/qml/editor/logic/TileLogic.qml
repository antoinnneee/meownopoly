import QtQuick 2.15
import ItemSnapable
import Game
import "../../meowComponent"
import "../../meowComponent/snapable"
import "../../meowComponent/grid"
import "../../meowComponent/preview"
import ".."
import MapTypes
import ItemSnapableFactory
import EditDelta 1.0

QtObject {
    required property var snapableTilesList
    required property var logic

    required property var dynamicComponent

    // Propriétés pour la taille des éléments créés
    property int currentElementWidth: 3
    property int currentElementHeight: 4

    property real currentZOrder: 0.00001

    property bool displayLinkEnable :false
        
    function placeSelectedAsset(gridX, gridY) {
        var snapableParameters
        gridX = gridX - Math.trunc(currentElementWidth/2)
        gridY = gridY - Math.trunc(currentElementHeight/2)
        if (!root.isAssetSelected) {    // place case
            if (selectionPanel.caseTypeSelected == -1){ //no type selected
                return
            }
            snapableParameters = ItemSnapableFactory.createItemSnapable(selectionPanel.caseTypeSelected)
        }
        else    // place decoration
        {
            snapableParameters = ItemSnapableFactory.createItemSnapable()
        }
        snapableParameters.displayParameter.gridRelativePositionX = gridX
        snapableParameters.displayParameter.gridRelativePositionY = gridY
        snapableParameters.displayParameter.unitSizeWidth = currentElementWidth
        snapableParameters.displayParameter.unitSizeHeight = currentElementHeight
        snapableParameters.displayParameter.zLayer = 5
        snapableParameters.decorationParameter.decorationCategory = selectionPanel.currentSelectedAssetCategory
        snapableParameters.decorationParameter.decorationType = selectionPanel.currentSelectedAssetType
        snapableParameters.decorationParameter.decorationId = selectionPanel.currentSelectedAssetId

        var newTile = createItemSnapableTile(snapableParameters)

        var visualEffectsPanel = editorSidePanel.visualEffectsPanel
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return newTile

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        newTile.applyVisualEffects(currentEffects)
        mainMa.elementClicked(newTile)
        return newTile
    }

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


    function createItemSnapableTile(itemSnapableData) {
        currentZOrder = currentZOrder + 0.00001
        itemSnapableData.displayParameter.zOrder  = currentZOrder;
        // Choisir le bon composant selon le tileType
        var tileComponent
        if (itemSnapableData.tileType === ItemSnapable.CaseTile) {
            tileComponent = dynamicComponent.snapableCaseTileComponent
        } else if (itemSnapableData.tileType === ItemSnapable.DecorationTile) {
            tileComponent = dynamicComponent.snapableDecorationComponent
        } else if (itemSnapableData.tileType === ItemSnapable.PhysicZoneTile) {
            tileComponent = dynamicComponent.snapablePhysicZoneComponent
        }
        var newTile = tileComponent ? tileComponent.createObject(workArea, {
            "generalMA": mainMa,
            "snapableParameters": itemSnapableData
        }) : null

        if (newTile) {            
            snapableTilesList.push(newTile)
            logic.snapableTilesListUpdated()
            if (newTile.snapToGridFromGridPos) {
                newTile.snapToGridFromGridPos()
            }
        }
        return newTile
    }

    // Fonction pour supprimer un élément
    function deleteElement(element) {
        // console.log("Suppression de l'élément:", element)

        // Trouver l'index de l'élément dans la liste
        var index = -1
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i] === element) {
                index = i
                break
            }
        }

        if (index !== -1) {
            snapableTilesList.splice(index, 1)
            logic.snapableTilesListUpdated()

            logic.mouseLogic.unselectSelectedElements()

            // Capturer l'uuid avant destroy() (après, snapableParameters peut être null)
            var uuid = element.snapableParameters ? element.snapableParameters.uniqueId : null
            element.destroy()
            // Le C++ gère la suppression de l'ItemSnapable via deleteLater()
            if (uuid) Game.removeMapTile(uuid)

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
        
        // Enregistrer la modification de connexion dans l'historique undo
        if (source.snapableParameters)
            Game.updateEditState(EditDelta.TileModified, source.snapableParameters)
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


