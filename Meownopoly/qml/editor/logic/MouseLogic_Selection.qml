import QtQuick 2.15
import "../tools/snapable"

MouseLogic_Base {
    id: mouseLogic
    property bool isDragging: false
    
    // Propriétés pour la sélection par rectangle
    property bool isRectangleSelecting: false
    property point rectangleStart: Qt.point(0, 0)
    property point rectangleCurrent: Qt.point(0, 0)

    function dragChanged(drag)
    {
        console.log("[LOGIC] drag changed")
        isDragging = drag.active
        
        // Si on est en mode sélection rectangle, empêcher le drag
        if (isRectangleSelecting) {
            drag.target = null
        }
    }

    function pressedLeft(mouse, drag)
    {
        mouse.accepted = true
        
        // Si aucun élément n'est cliqué, commencer la sélection par rectangle
        if (clickElement.length === 0) {
            isRectangleSelecting = true
            
            // Convertir les coordonnées de mainMa vers workArea
            var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
            rectangleStart = Qt.point(workAreaPos.x, workAreaPos.y)
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
            
            // Empêcher le drag de la carte pendant la sélection rectangle
            drag.target = null
            
            // Activer le rectangle de sélection
            if (logic.selectionRect) {
                logic.selectionRect.show()
                logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
            }
            return
        }
        
        // Si un élément est cliqué, utiliser la logique normale
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        drag.target = groupeSelection
        return
    }

    function pressedRight(mouse, drag)
    {
        drag.target = editorGrid
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
            clickElement = []
            //unselectAllElements()
        }
    }

    function clickedLeft(mouse, drag)
    {
        console.log("click left")
        mouse.accepted = true
        if (!(mouse.modifiers & Qt.ControlModifier))
        {
            if ((clickElement.length > 0 && selectedElements.length > 0) && clickElement[0] === selectedElements[0]) {   // unselect item
                console.log("[LOGIC] unselect item")
                unselectAllElements()
            }
            else if (clickElement.length > 0) { // unselect all and select clicked
                console.log("[LOGIC] unselect all and select clicked", clickElement[0])
                unselectAllElements()
                clickElement[0].elementPressed()
                clickElement[0].parent = groupeSelection
                drag.target = groupeSelection
                selectedElements.push(clickElement[0])
                
                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()
            }
            else
            {
                unselectAllElements()
            }
        }
        else
        {
            var deltaX = groupeSelection.x
            var deltaY = groupeSelection.y
            if (clickElement.length > 0) {
                if (!clickElement[0].isSelected)
                {
                    clickElement[0].elementPressed()
                    clickElement[0].parent = groupeSelection
                    clickElement[0].x = clickElement[0].x - deltaX
                    clickElement[0].y = clickElement[0].y - deltaY
                    selectedElements.push(clickElement[0])
                    
                    // Mettre à jour la configuration de case si applicable
                    updateCaseConfiguration()
                }
                else
                {
                    // unselect element
                    for (var i = 0; i < selectedElements.length; i++) {
                        if (selectedElements[i] === clickElement[0]) {
                            selectedElements[i].x = selectedElements[i].x + deltaX
                            selectedElements[i].y = selectedElements[i].y + deltaY
                            selectedElements[i].isSelected = false
                            selectedElements[i].parent = workArea
                            selectedElements[i].elementReleased()
                            selectedElements.splice(i,1)
                            break
                        }
                    }
                    
                    // Mettre à jour la configuration de case si applicable
                    updateCaseConfiguration()
                }
            }
            else
            {
                unselectSelectedElements()
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
        
        // Convertir les coordonnées de mainMa vers workArea
        var workAreaPos = mainMa.mapToItem(workArea, mouseX, mouseY)
        rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
        
        // Mettre à jour le rectangle visuel
        if (logic.selectionRect) {
            logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
        }
        
        // Détecter les éléments dans le rectangle et les sélectionner
        var elementsInRect = getElementsInRectangle(rectangleStart, rectangleCurrent)
        selectElementsInRectangle(elementsInRect)
    }
    
    // Fonction pour détecter les éléments dans le rectangle
    function getElementsInRectangle(start, current) {
        var elements = []
        
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
                elements.push(element)
            }
        }
        
        return elements
    }
    
    // Fonction pour sélectionner les éléments dans le rectangle
    function selectElementsInRectangle(elements) {
        // Désélectionner tous les éléments actuels
        unselectAllElements()
        
        // Sélectionner les nouveaux éléments
        for (var i = 0; i < elements.length; i++) {
            var element = elements[i]
            element.elementPressed()
            element.parent = groupeSelection
            selectedElements.push(element)
        }
    }
    
    // Fonction pour finaliser la sélection par rectangle
    function finalizeRectangleSelection() {
        var elementsInRect = getElementsInRectangle(rectangleStart, rectangleCurrent)
        selectElementsInRectangle(elementsInRect)
        
        // Mettre à jour la configuration de case si applicable
        updateCaseConfiguration()
    }


}
