import QtQuick 2.15
import QtCore

import "../../component"
import "../../component/snapable"

MouseLogic_Base {
    id: mouseLogic
    property list<SnapableElement> snapableTemplateTileList
    Component.onCompleted: console.log("MouseLogic_Template loaded")
    function addToList(selectedTiles)
    {
        for (var i = 0; i < selectedTiles.length; i++) {
            var element = selectedTiles[i]
            console.log("newElement add ", element)
            if (element)
                snapableTemplateTileList.push(element)
        }
    }

    // Propriétés pour la sélection par rectangle
    property bool isRectangleSelecting: false
    property point rectangleStart: Qt.point(0, 0)
    property point rectangleCurrent: Qt.point(0, 0)

    // Nouvelles propriétés pour détecter le mouvement même lors d'un "clic"
    property point pressPosition: Qt.point(0, 0)
    property bool hadPressWithoutElement: false

    function dragChanged(mouseX, mouseY, drag){
        logic.mouseLogic.dragChanged(mouseX, mouseY, drag)
    }

    function pressedLeft(mouse, drag){
        logic.mouseLogic.pressedLeft(mouse, drag)
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
            // IMPORTANT: Update positions of all selected elements BEFORE saving
            // The visual positions (x, y) have changed via bindings, but the data positions
            // (gridRelativePositionX/Y) need to be explicitly updated
            if (drag.target == groupeSelection) {
                console.log("[UNDO][DRAG] Updating positions for", selectedElements.length, "element(s) before save")
                for (var i = 0; i < selectedElements.length; i++) {
                    if (selectedElements[i] && selectedElements[i].updateRelativePosition) {
                        selectedElements[i].updateRelativePosition()
                    }
                }
                // Now save with the updated positions
                logic.saveMap(MapTypes.UNDOREDO)
            }
            clickElement = []
        }
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


     // --
    function clickedLeft(mouse, drag)
    {
        mouse.accepted = true

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
                updateVisualEffectPanel(selectedElements[0].snapableParameters.displayParameter)
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
                updateVisualEffectPanel(clickElement[0].snapableParameters.displayParameter)
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
        // addToList(clickElement)
        clickElement = []
    }


}
