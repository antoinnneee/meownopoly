import QtQuick 2.15
import Game
import MapTypes
import EditDelta 1.0

/**
 * MouseLogic pour le mode Template.
 * Permet de sélectionner des éléments pour créer un template.
 *
 * Comportements :
 * - Clic gauche sur élément : Toggle (ajouter/retirer de la sélection)
 * - Clic gauche dans le vide : Désélectionner tout
 * - Clic droit : Rien
 * - Drag gauche sans élément : Sélection rectangle
 * - Drag gauche sur élément : Déplacer les éléments sélectionnés
 * - Drag droit : Déplacer la carte
 */
MouseLogic_Selection {
    id: mouseLogic
    
    // ========== PROPRIÉTÉS SPÉCIFIQUES AU MODE TEMPLATE ==========
    
    // Liste des éléments sélectionnés pour le template
    property var templateSelectedElements: []
    
    // Liste des bounding boxes à afficher (pour le Repeater dans Trackers)
    property var templateBoundingBoxes: []
    
    // Flag pour savoir si on a cliqué dans la bounding box (pour le drag)
    property bool pressedInsideBoundingBox: false
    
    // ========== SOUS-MODE PLACEMENT ==========
    
    // Données du template en cours de placement
    property var placementTemplateData: null  // QJsonObject du template chargé
    property string placementTemplateName: ""
    
    // Flag de sous-mode
    property bool isPlacementMode: false  // true si template sélectionné pour placement
    
    // Position de la souris (pour le preview)
    property real previewMouseX: 0
    property real previewMouseY: 0
    
    // Pour distinguer clic vs drag droit
    property bool hadRightDrag: false
    
    // ========== FONCTIONS SURCHARGÉES ==========
    
    /**
     * Surcharge de pressedLeft : gérer le clic dans la bounding box pour drag
     */
    function pressedLeft(mouse, drag) {
        // ===== MODE PLACEMENT =====
        if (isPlacementMode) {
            // Neutraliser drag.target : sinon drag.target hérité (grid/
            // groupeSelection) absorbe le geste et onClicked n'est pas émis.
            drag.target = null
            hadPressWithoutElement = false
            isRectangleSelecting = false
            clickElement = []
            mouse.accepted = true
            return
        }
        
        // ===== MODE CRÉATION =====
        mouse.accepted = true
        
        // Convertir les coordonnées de mainMa vers workArea
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        
        // Stocker la position de presse pour détecter le mouvement plus tard
        pressPosition = Qt.point(workAreaPos.x, workAreaPos.y)
        
        // Si un élément est cliqué directement, comportement normal
        if (clickElement.length > 0) {
            hadPressWithoutElement = false
            pressedInsideBoundingBox = false
            drag.target = groupeSelection
            return
        }
        
        // Aucun élément cliqué directement...
        // Vérifier si le clic est dans la bounding box
        if (isInsideBoundingBox(workAreaPos.x, workAreaPos.y)) {
            console.log("[TEMPLATE] Pressed inside bounding box - enabling group drag")
            hadPressWithoutElement = false
            pressedInsideBoundingBox = true
            drag.target = groupeSelection
            
            // Sauvegarder les positions de départ pour le drag
            dragStartPos = Qt.point(mouse.x, mouse.y)
            targetStartPos = Qt.point(groupeSelection.x, groupeSelection.y)
            return
        }
        
        // Clic dans le vide (hors bounding box) → démarrer sélection rectangle
        hadPressWithoutElement = true
        pressedInsideBoundingBox = false
        isRectangleSelecting = true
        
        rectangleStart = Qt.point(workAreaPos.x, workAreaPos.y)
        rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
        
        // Activer le rectangle de sélection visuel
        if (logic.selectionRect) {
            logic.selectionRect.show()
            logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
        }
        drag.target = null
    }
    
    /**
     * Surcharge de clickedLeft : comportement toggle systématique
     */
    function clickedLeft(mouse, drag) {
        // ===== MODE PLACEMENT =====
        if (isPlacementMode) {
            // Source primaire : coord du clic mappées en workArea (fiable
            // même si le tracker n'a pas encore reçu de positionChanged).
            var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
            placeTemplateAtCursor(workAreaPos.x, workAreaPos.y)
            mouse.accepted = true
            return  // RESTE EN MODE PLACEMENT pour poser à nouveau
        }
        
        // ===== MODE CRÉATION =====
        mouse.accepted = true
        
        // Calculer la distance parcourue entre press et release
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        var deltaX = Math.abs(workAreaPos.x - pressPosition.x)
        var deltaY = Math.abs(workAreaPos.y - pressPosition.y)
        var hasMoved = (deltaX > 5 || deltaY > 5)  // Seuil de 5 pixels
        
        // Si sélection rectangle (press sans élément + mouvement), finaliser
        if (hadPressWithoutElement && hasMoved) {
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
            finalizeTemplateRectangleSelection()
            
            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }
            
            isRectangleSelecting = false
            hadPressWithoutElement = false
            clickElement = []
            return
        }
        
        // Réinitialiser les flags
        isRectangleSelecting = false
        hadPressWithoutElement = false
        
        if (logic.selectionRect) {
            logic.selectionRect.hide()
        }
        
        // ===== CLIC DANS LE VIDE =====
        if (clickElement.length === 0) {
            // Si on a cliqué dans la bounding box sans bouger, ne rien faire (juste un clic, pas de drag)
            if (pressedInsideBoundingBox && !hasMoved) {
                console.log("[TEMPLATE] Clicked inside bounding box without moving - keeping selection")
                pressedInsideBoundingBox = false
                return
            }
            
            // Clic vraiment dans le vide → Désélectionner tout
            unselectAllTemplateElements()
            clickElement = []
            pressedInsideBoundingBox = false
            return
        }
        
        // ===== CLIC SUR UN ÉLÉMENT → Toggle (ajouter/retirer) =====
        var element = clickElement[0]
        toggleTemplateElement(element)
        
        clickElement = []
    }
    
    /**
     * Surcharge de release : mettre à jour la bounding box après un drag
     */
    function release(mouse, drag) {
        // Détection d'un vrai drag de la grille (avec mouvement)
        if (drag.target === grid && drag.active) {
            hadRightDrag = true
        }
        
        // ===== MODE PLACEMENT =====
        if (isPlacementMode) {
            drag.target = null
            clickElement = []
            return
        }
        
        // ===== MODE CRÉATION =====
        // Finaliser la sélection par rectangle si active
        if (isRectangleSelecting) {
            finalizeTemplateRectangleSelection()
            isRectangleSelecting = false
            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }
            drag.target = null
        }
        
        // Gérer le drag d'éléments
        if (isDragging) {
            if (drag.target === groupeSelection) {
                console.log("[TEMPLATE] Updating positions for", selectedElements.length, "element(s) after drag")
                for (var i = 0; i < selectedElements.length; i++) {
                    if (selectedElements[i] && selectedElements[i].updateRelativePosition) {
                        selectedElements[i].updateRelativePosition()
                    }
                }
                // Enregistrer les nouvelles positions dans l'historique undo
                var txId = Game.beginTransaction()
                for (var j = 0; j < selectedElements.length; j++) {
                    if (selectedElements[j] && selectedElements[j].snapableParameters)
                        Game.updateMap(EditDelta.TileModified, selectedElements[j].snapableParameters, txId)
                }
                Game.commitTransaction()
            }
            clickElement = []
            
            // Mettre à jour la bounding box après le déplacement
            updateTemplateBoundingBox()
        }
    }
    
    /**
     * Surcharge de pressedRight : gestion du drag de la carte
     */
    function pressedRight(mouse, drag) {
        hadRightDrag = false
        
        if (isPlacementMode) {
            drag.target = grid
            mouse.accepted = true
            return
        }
        
        // Mode création : déplacer la carte
        drag.target = grid
        mouse.accepted = true
    }
    
    /**
     * Surcharge de clickedRight : sortie du mode placement si clic sans drag
     */
    function clickedRight(mouse, drag) {
        if (isPlacementMode && !hadRightDrag) {
            console.log("[TEMPLATE] Right click without drag -> exiting placement mode")
            exitPlacementMode()
        }
        hadRightDrag = false
        mouse.accepted = true
    }
    
    /**
     * Surcharge de positionChanged : mettre à jour la bounding box pendant le drag
     */
    function positionChanged(mouse, drag) {
        // Mettre à jour la sélection par rectangle si active
        if (mouseLogic.isRectangleSelecting) {
            mouseLogic.updateRectangleSelection(mouse.x, mouse.y)
        }
        
        // Gérer le snap pendant le drag (logique héritée du parent)
        if (drag.active && drag.target && grid.snapToGrid) {
            var deltaX = mouse.x - dragStartPos.x
            var deltaY = mouse.y - dragStartPos.y
            
            var newX = targetStartPos.x + deltaX
            var newY = targetStartPos.y + deltaY
            
            if (drag.target === groupeSelection) {
                // Snapper aux positions de la grille
                var snappedX = Math.round(newX / grid.gridSize) * grid.gridSize
                var snappedY = Math.round(newY / grid.gridSize) * grid.gridSize
                
                drag.target.x = snappedX
                drag.target.y = snappedY
            }
        }
        
        // Mettre à jour la position de la caméra 3D
        updateCameraPosition()
        
        // ===== MISE À JOUR EN TEMPS RÉEL DE LA BOUNDING BOX =====
        if (drag.active && drag.target === groupeSelection && templateSelectedElements.length > 0) {
            updateTemplateBoundingBox()
        }
    }
    
    // ========== NOUVELLES FONCTIONS ==========
    
    /**
     * Surcharge de changeMouseMode : sortir du mode placement si on change de mode
     */
    function changeMouseMode(mode) {
        if (isPlacementMode && mode !== EditorEnum.EM_TEMPLATE) {
            exitPlacementMode()
        }
        unselectSelectedElements()
        logic.editorMouseMode = mode
    }
    
    /**
     * Vérifie si une position (x, y) est à l'intérieur de la bounding box actuelle
     */
    function isInsideBoundingBox(x, y) {
        if (templateBoundingBoxes.length === 0) return false
        
        var box = templateBoundingBoxes[0]
        return x >= box.x && x <= box.x + box.width &&
                y >= box.y && y <= box.y + box.height
    }
    
    /**
     * Toggle un élément dans la sélection template
     */
    function toggleTemplateElement(element) {
        var index = templateSelectedElements.indexOf(element)
        
        if (index === -1) {
            // Ajouter à la sélection
            console.log("[TEMPLATE] Adding element to selection:", element)
            element.elementPressed()
            createBindingsForElement(element)
            templateSelectedElements.push(element)
            selectedElements.push(element)
        } else {
            // Retirer de la sélection
            console.log("[TEMPLATE] Removing element from selection:", element)
            element.elementUnselected()
            destroyBindingsForElement(element)
            templateSelectedElements.splice(index, 1)
            
            // Retirer aussi de selectedElements (pour le drag groupé)
            var selIndex = selectedElements.indexOf(element)
            if (selIndex !== -1) {
                selectedElements.splice(selIndex, 1)
            }
        }
        
        updateTemplateBoundingBox()
    }
    
    /**
     * Désélectionner tous les éléments template
     */
    function unselectAllTemplateElements() {
        console.log("[TEMPLATE] Unselecting all", templateSelectedElements.length, "elements")
        
        for (var i = 0; i < templateSelectedElements.length; i++) {
            if (templateSelectedElements[i] && templateSelectedElements[i].elementUnselected !== undefined){
                templateSelectedElements[i].elementUnselected()
                destroyBindingsForElement(templateSelectedElements[i])
            }
        }
        
        templateSelectedElements = []
        selectedElements = []
        groupeSelection.x = 0
        groupeSelection.y = 0
        
        updateTemplateBoundingBox()
    }
    
    /**
     * Finaliser la sélection rectangle pour le mode template
     */
    function finalizeTemplateRectangleSelection() {
        var elementsResult = getElementsInRectangle(rectangleStart, rectangleCurrent)
        
        // Ajouter les éléments dans le rectangle à la sélection template
        var elementsIn = elementsResult.inRectangle
        
        for (var i = 0; i < elementsIn.length; i++) {
            var element = elementsIn[i]
            
            // Vérifier si l'élément n'est pas déjà sélectionné
            if (templateSelectedElements.indexOf(element) === -1) {
                element.elementPressed()
                createBindingsForElement(element)
                templateSelectedElements.push(element)
                selectedElements.push(element)
            }
        }
        
        updateTemplateBoundingBox()
    }
    
    function removeElementFromTemplateSelection(element) {
        var index = templateSelectedElements.indexOf(element)
        var selIndex = selectedElements.indexOf(element)
        if (index !== -1) {
            templateSelectedElements.splice(index, 1)
        }
        if (selIndex !== -1) {
            selectedElements.splice(selIndex, 1)
        }
        updateTemplateBoundingBox()
    }

    /**
     * Calculer et mettre à jour la bounding box des éléments sélectionnés
     */
    function updateTemplateBoundingBox() {
        if (templateSelectedElements.length === 0) {
            templateBoundingBoxes = []
            return
        }
        
        var minX = Infinity, minY = Infinity
        var maxX = -Infinity, maxY = -Infinity
        
        for (var i = 0; i < templateSelectedElements.length; i++) {
            var el = templateSelectedElements[i]
            minX = Math.min(minX, el.x)
            minY = Math.min(minY, el.y)
            maxX = Math.max(maxX, el.x + el.width)
            maxY = Math.max(maxY, el.y + el.height)
        }
        
        templateBoundingBoxes = [{
                                     x: minX,
                                     y: minY,
                                     width: maxX - minX,
                                     height: maxY - minY
                                 }]
        
        console.log("[TEMPLATE] Bounding box updated:", JSON.stringify(templateBoundingBoxes[0]))
    }
    
    /**
     * Obtenir les éléments sélectionnés pour le template
     */
    function getTemplateSelectedElements() {
        return templateSelectedElements
    }
    
    /**
     * Vider la sélection template (appelé quand on quitte le mode)
     */
    function clearTemplateSelection() {
        unselectAllTemplateElements()
    }
    
    // ========== FONCTIONS MODE PLACEMENT ==========
    
    /**
     * Entrer en mode placement avec un template spécifique
     */
    function enterPlacementMode(templateName) {
        // Nettoyer la sélection création
        unselectAllTemplateElements()

        // force reload model
        placementTemplateData = []
        // Charger le template
        var templateData = Game.loadTemplate(templateName)
        if (!templateData || !templateData.elements) {
            console.error("[TEMPLATE] Failed to load template:", templateName)
            return false
        }

        placementTemplateData = templateData
        placementTemplateName = templateName
        isPlacementMode = true

        return true
    }
    
    /**
     * Sortir du mode placement
     */
    function exitPlacementMode() {
        console.log("[TEMPLATE] Exiting PLACEMENT mode")
        isPlacementMode = false
        placementTemplateData = null
        placementTemplateName = ""
    }
    
    /**
     * Placer le template à la position du curseur.
     * @param workAreaX/Y coord workArea (optionnel — fallback sur previewMouseX/Y)
     */
    function placeTemplateAtCursor(workAreaX, workAreaY) {
        if (!placementTemplateData || !placementTemplateName) return
        if (!placementTemplateData.templateInfo) return

        // Fallback sur previewMouseX/Y si workAreaX/Y non fournis
        var px = (workAreaX !== undefined) ? workAreaX : previewMouseX
        var py = (workAreaY !== undefined) ? workAreaY : previewMouseY
        var gridPos = grid.getGridPosition(px, py)

        // Utiliser le même calcul de centrage que TemplatePreviewCursor.updateGridPosition()
        var adjustedGridX = gridPos.x - Math.trunc(placementTemplateData.templateInfo.boundingBoxWidth / 2)
        var adjustedGridY = gridPos.y - Math.trunc(placementTemplateData.templateInfo.boundingBoxHeight / 2)

        var elementsArray = Game.getTemplateElementsForPlacement(placementTemplateName, adjustedGridX, adjustedGridY)
        if (!elementsArray || elementsArray.length === 0) return

        var jsonObj = { "snapableTiles": elementsArray }
        var itemSnapableList = Game.generateItems(jsonObj)

        var txId = Game.beginTransaction()
        for (var i = 0; i < itemSnapableList.length; i++) {
            logic.tileLogic.createItemSnapableTile(itemSnapableList[i])
            if (itemSnapableList[i])
                Game.updateMap(EditDelta.TileAdded, itemSnapableList[i], txId)
        }
        Game.commitTransaction()
    }
    
}
