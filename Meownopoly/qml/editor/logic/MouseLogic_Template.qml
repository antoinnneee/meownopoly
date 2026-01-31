import QtQuick 2.15
import MapTypes

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
    
    // ========== FONCTIONS SURCHARGÉES ==========
    
    /**
     * Surcharge de clickedLeft : comportement toggle systématique
     */
    function clickedLeft(mouse, drag) {
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
        
        // ===== CLIC DANS LE VIDE → Désélectionner tout =====
        if (clickElement.length === 0) {
            unselectAllTemplateElements()
            clickElement = []
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
                // Sauvegarder pour undo/redo
                logic.saveMap(MapTypes.UNDOREDO)
            }
            clickElement = []
            
            // Mettre à jour la bounding box après le déplacement
            updateTemplateBoundingBox()
        }
    }
    
    // ========== NOUVELLES FONCTIONS ==========
    
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
            templateSelectedElements[i].elementUnselected()
            destroyBindingsForElement(templateSelectedElements[i])
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
}
