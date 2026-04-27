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
        // Lamport tick — zOrder unique monotone + jitter sub-1.0 par peer
        // pour désambigüer les ticks concurrents en collab.
        snapableParameters.displayParameter.zOrder = Game.tickLamport()
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
        // Le zOrder est désormais fixé par l'appelant (placeSelectedAsset,
        // placeTemplateAtCursor, applyRemoteDelta, loadMap…) via Game.tickLamport()
        // ou la valeur transportée dans les ops/fichier. On n'écrase plus ici :
        // sinon la pose de template perdait l'ordre relatif sauvé (bug observé
        // où les tiles prenaient l'ordre de sélection au lieu du zOrder d'origine).
        // Choisir le bon composant selon le tileType
        var tileComponent
        if (itemSnapableData.tileType === ItemSnapable.CaseTile) {
            tileComponent = dynamicComponent.snapableCaseTileComponent
        } else if (itemSnapableData.tileType === ItemSnapable.DecorationTile) {
            tileComponent = dynamicComponent.snapableDecorationComponent
        } else if (itemSnapableData.tileType === ItemSnapable.PhysicZoneTile) {
            tileComponent = dynamicComponent.snapablePhysicZoneComponent
        } else if (itemSnapableData.tileType === ItemSnapable.PhysicalObjectTile) {
            tileComponent = dynamicComponent.snapablePhysicalObjectComponent
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
            // Broadcast réseau (si collab) piloté par Game.updateMap du côté appelant.
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
            // Le C++ finalise la destruction de l'ItemSnapable (deleteLater).
            // m_tiles a déjà été mis à jour par Game.updateMap(TileDeleted).
            if (uuid) Game.finalizeDeletedTile(uuid)

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

        // Enregistrer la modification de connexion dans l'historique undo.
        // rewireLinks côté C++ restaurera symétriquement target.prev sur undo.
        // Broadcast réseau (si collab) orchestré par Game.updateMap.
        if (source.snapableParameters)
            Game.updateMap(EditDelta.TileModified, source.snapableParameters)
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
    /**
     * @brief Resynchronise les connectionManager QML des tiles listées à partir
     *        de l'état C++ (appelé après un undo/redo via Game.afterRestoration).
     * @param tileIds QList<QUuid> — tiles affectées par le batch de restauration.
     */
    function rebuildConnectionsFor(tileIds) {
        if (!tileIds || tileIds.length === 0) return
        var set = {}
        for (var i = 0; i < tileIds.length; i++) set[tileIds[i].toString()] = true

        var affected = []
        for (var i = 0; i < snapableTilesList.length; i++) {
            var t = snapableTilesList[i]
            if (t && t.snapableParameters && set[t.snapableParameters.uniqueId.toString()])
                affected.push(t)
        }
        if (affected.length === 0) return

        // Phase 1 : vider les listes QML des tiles affectées
        for (var a = 0; a < affected.length; a++) {
            var at = affected[a]
            at.blockConnections = true
            at.connectionManager.nextElements = []
            at.connectionManager.previousElements = []
        }

        // Phase 2 : rebuild depuis l'état C++ (forward ; addNextElement
        // ajoute symétriquement target.previousElements)
        for (var a2 = 0; a2 < affected.length; a2++) {
            var srcTile = affected[a2]
            var cppNextList = srcTile.snapableParameters.getNextList()
            for (var j = 0; j < cppNextList.length; j++) {
                var cppNext = cppNextList[j]
                var qmlNext = null
                for (var k = 0; k < snapableTilesList.length; k++) {
                    if (snapableTilesList[k] && snapableTilesList[k].snapableParameters === cppNext) {
                        qmlNext = snapableTilesList[k]
                        break
                    }
                }
                if (qmlNext) {
                    var wasBlocked = qmlNext.blockConnections
                    qmlNext.blockConnections = true
                    srcTile.connectionManager.addNextElement(qmlNext)
                    if (!wasBlocked) qmlNext.blockConnections = false
                }
            }
        }

        for (var a3 = 0; a3 < affected.length; a3++) affected[a3].blockConnections = false
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


