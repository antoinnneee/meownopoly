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
import EditorOpBus 1.0

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
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        newTile.applyVisualEffects(currentEffects)
        mainMa.elementClicked(newTile)
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
            // Phase 3: embarquer la sérialisation JSON complète pour permettre
            // le replay côté distant via ItemSnapableFactory.createItemSnapableFromJson.
            let itemJson = {}
            try {
                itemJson = JSON.parse(itemSnapableData.toJSON())
            } catch (e) {
                console.warn("TileLogic: toJSON parse error", e)
            }
            const createOp = {
                "op":     EditorOpType.CreateItem,
                "target": String(itemSnapableData.uniqueId),
                "item":   itemJson
            }
            const inverseOp = EditorOpBus.makeDeleteOp(String(itemSnapableData.uniqueId))
            EditorOpBus.submitOpWithUndo(createOp, inverseOp)
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
            // Phase 3+6 : capture le JSON complet AVANT destroy pour pouvoir
            // reconstruire en undo. L'op Delete elle-même n'embarque que
            // l'uuid pour rester légère ; l'inverse porte le JSON complet.
            const deletedUuid = element.snapableParameters
                                ? String(element.snapableParameters.uniqueId)
                                : ""
            let capturedJson = {}
            if (element.snapableParameters) {
                try {
                    capturedJson = JSON.parse(element.snapableParameters.toJSON())
                } catch (e) {
                    console.warn("TileLogic: toJSON pré-delete erreur", e)
                }
            }
            const deleteOp = EditorOpBus.makeDeleteOp(deletedUuid)
            const inverseCreate = {
                "op":     EditorOpType.CreateItem,
                "target": deletedUuid,
                "item":   capturedJson
            }
            EditorOpBus.submitOpWithUndo(deleteOp, inverseCreate)

            // Supprimer l'élément de la liste
            snapableTilesList.splice(index, 1)
            logic.snapableTilesListUpdated()

            // Si c'était l'élément sélectionné, le désélectionner
            logic.mouseLogic.unselectSelectedElements()

            // Détruire l'objet QML
            var pItemSnapable = element.snapableParameters
            element.destroy()
            pItemSnapable.destroy()

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

        // Phase 3+6 : op + inverse pour undo. Le bus loggue, envoie, et push.
        const srcUuid = source.snapableParameters ? String(source.snapableParameters.uniqueId) : ""
        const dstUuid = target.snapableParameters ? String(target.snapableParameters.uniqueId) : ""
        EditorOpBus.submitOpWithUndo(
            EditorOpBus.makeLinkOp(srcUuid, dstUuid, kind),
            EditorOpBus.makeUnlinkOp(srcUuid, dstUuid, kind))

        // Sauvegarder après création de la connexion
        logic.saveMap(MapTypes.UNDOREDO)
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


