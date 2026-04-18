import QtQuick 2.15
import "../../meowComponent/snapable"

import MapTypes
import EditorOpBus 1.0

MouseLogic_Base {
    id: mouseLogic
    
    // Propriétés pour la sélection par rectangle
    property bool isRectangleSelecting: false
    property point rectangleStart: Qt.point(0, 0)
    property point rectangleCurrent: Qt.point(0, 0)
    
    // Nouvelles propriétés pour détecter le mouvement même lors d'un "clic"
    property point pressPosition: Qt.point(0, 0)
    property bool hadPressWithoutElement: false

    function dragChanged(mouseX, mouseY, drag)
    {
        isDragging = drag.active
        if (drag.active && drag.target) {
            // Sauvegarder les positions de départ
            dragStartPos = Qt.point(mouseX, mouseY)
            targetStartPos = Qt.point(drag.target.x, drag.target.y)
        }
        // Si on est en mode sélection rectangle, empêcher le drag
        if (isRectangleSelecting) {
            drag.target = null
        }
    }

    function pressedLeft(mouse, drag)
    {
        mouse.accepted = true
        
        // Convertir les coordonnées de mainMa vers workArea
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        
        // Stocker la position de presse pour détecter le mouvement plus tard
        pressPosition = Qt.point(workAreaPos.x, workAreaPos.y)
        
        // Si aucun élément n'est cliqué, commencer la sélection par rectangle
        if (clickElement.length === 0) {
            hadPressWithoutElement = true
            isRectangleSelecting = true
            
            rectangleStart = Qt.point(workAreaPos.x, workAreaPos.y)
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
            
            // Activer le rectangle de sélection
            if (logic.selectionRect) {
                logic.selectionRect.show()
                logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
            }
            drag.target = null
            return
        }
        
        hadPressWithoutElement = false
        
        // Si un élément est cliqué, utiliser la logique normale
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        drag.target = groupeSelection
        return
    }

    function pressedRight(mouse, drag)
    {
        drag.target = grid
        mouse.accepted = true
    }

    function release(mouse, drag)
    {
        
        // Finaliser la sélection par rectangle si active
        if (isRectangleSelecting) {
            finalizeRectangleSelection()
            isRectangleSelecting = false
            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }
            // Réinitialiser le drag pour les prochaines interactions
            drag.target = null
        }
        
        if (isDragging)
        {
            // IMPORTANT: Update positions of all selected elements BEFORE saving
            // The visual positions (x, y) have changed via bindings, but the data positions
            // (gridRelativePositionX/Y) need to be explicitly updated
            if (drag.target === groupeSelection) {
                console.log("[UNDO][DRAG] Updating positions for", selectedElements.length, "element(s) before save")
                for (var i = 0; i < selectedElements.length; i++) {
                    if (selectedElements[i] && selectedElements[i].updateRelativePosition) {
                        selectedElements[i].updateRelativePosition()
                    }
                }
                // Phase 2: un MoveItem par élément déplacé (log-only, avant le saveMap).
                for (var mi = 0; mi < selectedElements.length; mi++) {
                    const el = selectedElements[mi]
                    if (el && el.snapableParameters) {
                        EditorOpBus.recordOp(EditorOpBus.makeMoveOp(
                            String(el.snapableParameters.uniqueId),
                            el.snapableParameters.displayParameter.gridRelativePositionX,
                            el.snapableParameters.displayParameter.gridRelativePositionY,
                            -1))
                    }
                }
                // Now save with the updated positions
                logic.saveMap(MapTypes.UNDOREDO)
            }
            clickElement = []
        }
    }

    function clickedLeft(mouse, drag)
    {
        mouse.accepted = true
        
        // Calculer la distance parcourue entre press et release
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        var deltaX = Math.abs(workAreaPos.x - pressPosition.x)
        var deltaY = Math.abs(workAreaPos.y - pressPosition.y)
        var hasMoved = (deltaX > 5 || deltaY > 5)  // Seuil de 5 pixels
        
        // Si on a appuyé sans élément et qu'on a bougé, c'est une sélection rectangle
        if (hadPressWithoutElement && hasMoved) {
            // console.log("Détection de sélection rectangle via clic rapide")
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
            finalizeRectangleSelection()
            
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

        if (clickElement.length === 0) {
            unselectSelectedElements()
            return
        }

        if (!(mouse.modifiers & Qt.ControlModifier))    // CTRL is not pressed => normal selection mode
        {
            if (clickElement[0] === selectedElements[0]) {
                unselectSelectedElements()
            }
            else if (clickElement[0] !== selectedElements[0]) { // unselect all and select clicked
                // console.log("[LOGIC] unselect all and select clicked", clickElement[0])
                unselectSelectedElements()
                clickElement[0].elementPressed()

                createBindingsForElement(clickElement[0])
                drag.target = groupeSelection
                selectedElements.push(clickElement[0])
                
                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()
                updateSidePanel(selectedElements[0].snapableParameters)
            }
        }
        else    // CTRL is pressed => add to selection
        {
            if (!clickElement[0].isSelected)
            {
                clickElement[0].elementPressed()

                createBindingsForElement(clickElement[0])
                selectedElements.push(clickElement[0])
                
                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()

                updateSidePanel(clickElement[0].snapableParameters)
            }
            else
            {
                // unselect element
                for (var i = 0; i < selectedElements.length; i++) {
                    if (selectedElements[i] === clickElement[0]) {
                        selectedElements[i].isSelected = false
                        selectedElements[i].elementReleased()
                        // Détruire les bindings au lieu de changer le parent
                        destroyBindingsForElement(selectedElements[i])
                        selectedElements.splice(i,1)
                        break
                    }
                }
                
                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()
            }
            
        }
        clickElement = []
    }

    function clickedRight(mouse, drag) {
        // Menu contextuel supprimé - pas d'action sur clic droit
        mouse.accepted = true
    }

    function pressAndHold(mouse, drag)
    {
        if (drag.active === true) {
            return
        }
    }
    
    // Fonction pour mettre à jour la sélection par rectangle
    function updateRectangleSelection(mouseX, mouseY) {
        if (!isRectangleSelecting) return
        // console.log("update RectangleSelection")
        
        // Convertir les coordonnées de mainMa vers workArea
        var workAreaPos = mainMa.mapToItem(workArea, mouseX, mouseY)
        rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
        
        // Mettre à jour le rectangle visuel
        if (logic.selectionRect) {
            logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
            // console.log("update updateGeometry")
        }
        
        // Détecter les éléments dans le rectangle et les sélectionner
        var elementsResult = getElementsInRectangle(rectangleStart, rectangleCurrent)
        selectElementsInRectangle(elementsResult)
    }
    
    // Fonction pour détecter les éléments dans le rectangle
    function getElementsInRectangle(start, current) {
        var elementsInRect = []
        var elementsOutRect = []
        
        // Calculer les limites du rectangle
        var rectLeft = Math.min(start.x, current.x)
        var rectRight = Math.max(start.x, current.x)
        var rectTop = Math.min(start.y, current.y)
        var rectBottom = Math.max(start.y, current.y)
        
        // Parcourir tous les éléments snapables
        for (var i = 0; i < logic.snapableTilesList.length; i++) {
            var element = logic.snapableTilesList[i]
            if (!element) continue
            
            // Calculer les limites de l'élément
            var elementLeft = element.x
            var elementRight = element.x + element.width
            var elementTop = element.y
            var elementBottom = element.y + element.height
            
            // Vérifier l'intersection
            if (!(elementRight < rectLeft || elementLeft > rectRight ||
                  elementBottom < rectTop || elementTop > rectBottom)) {
                elementsInRect.push(element)
            } else {
                elementsOutRect.push(element)
            }
        }
        
        return {
            inRectangle: elementsInRect,
            outRectangle: elementsOutRect
        }
    }
    
    // Fonction pour sélectionner les éléments dans le rectangle
    function selectElementsInRectangle(elements) {
        var elementsIn = elements.inRectangle
        var elementsOut = elements.outRectangle
        for (var j = 0; j < elementsOut.length; j++) {
            var elementOut = elementsOut[j]
            if (elementOut.isSelected)
            {
                elementOut.elementUnselected()
                destroyBindingsForElement(elementOut)
                var selectElementIndex = selectedElements.indexOf(elementOut)
                if (selectElementIndex !== -1)
                {
                    selectedElements.splice(selectElementIndex, 1)
                }
            }
        }
        // Sélectionner les nouveaux éléments
        for (var i = 0; i < elementsIn.length; i++) {
            var elementIn = elementsIn[i]
            if (!elementIn.isSelected)
            {
                elementIn.elementPressed()
                // Ne plus changer le parent, créer les bindings à la place
                createBindingsForElement(elementIn)
                selectedElements.push(elementIn)
            }
        }
    }
    
    // Fonction pour finaliser la sélection par rectangle
    function finalizeRectangleSelection() {
        var elementsResult = getElementsInRectangle(rectangleStart, rectangleCurrent)
        selectElementsInRectangle(elementsResult)
        
        // Mettre à jour la configuration de case si applicable
        updateCaseConfiguration()
    }

}
