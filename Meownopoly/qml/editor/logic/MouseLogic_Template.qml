import QtQuick 2.15
import QtCore

import "../../component"
import "../../component/snapable"

import EditorEnum
import MapTypes


MouseLogic_Selection {
    id: mouseLogic
    property list<SnapableElement> snapableTemplateTileList
    
    // Signal émis quand les éléments sélectionnés changent (pour le template)
    signal templateSelectionChanged()
    
    // Rectangle englobant visuel
    property var boundingRectVisual: null
    
    // Couleur du rectangle englobant
    // property color boundingColor: "#4A90E2"
    property color boundingColor: "lime"

    // Positions initiales pour le déplacement du rectangle englobant
    property point boundingRectStartPos: Qt.point(0, 0)
    property point groupeSelectionStartPos: Qt.point(0, 0)
    
    Component.onCompleted: console.log("MouseLogic_Template loaded")
    
    function addToList(selectedTiles) {
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

    // Nouvelles propriétés pour détecter le mouvement
    property point pressPosition: Qt.point(0, 0)
    property bool hadPressWithoutElement: false

    function dragChanged(mouseX, mouseY, drag) {
        isDragging = drag.active
        if (drag.active && drag.target) {
            dragStartPos = Qt.point(mouseX, mouseY)
            targetStartPos = Qt.point(drag.target.x, drag.target.y)
            
            // Stocker les positions initiales pour le déplacement du rectangle englobant
            if (boundingRectVisual) {
                boundingRectStartPos = Qt.point(boundingRectVisual.x, boundingRectVisual.y)
            }
            groupeSelectionStartPos = Qt.point(groupeSelection.x, groupeSelection.y)
        }
        if (isRectangleSelecting) {
            drag.target = null
        }
    }

    function pressedLeft(mouse, drag) {
        mouse.accepted = true

        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        pressPosition = Qt.point(workAreaPos.x, workAreaPos.y)

        // Si aucun élément n'est cliqué, commencer la sélection par rectangle
        if (clickElement.length === 0) {
            hadPressWithoutElement = true
            isRectangleSelecting = true

            rectangleStart = Qt.point(workAreaPos.x, workAreaPos.y)
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)

            if (logic.selectionRect) {
                logic.selectionRect.show()
                logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
            }
            drag.target = null
            return
        }

        hadPressWithoutElement = false
        
        // Permettre le déplacement groupé des éléments sélectionnés
        drag.target = groupeSelection
    }

    function pressedRight(mouse, drag) {
        drag.target = grid
        mouse.accepted = true
    }

    function release(mouse, drag) {
        // Finaliser la sélection par rectangle si active
        if (isRectangleSelecting) {
            finalizeRectangleSelection()
            isRectangleSelecting = false
            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }
            drag.target = null
            
            // Mettre à jour le rectangle englobant
            updateBoundingRectangle()
            templateSelectionChanged()
            return
        }
        
        // Gérer la fin du déplacement
        if (isDragging) {
            // Mettre à jour les positions de tous les éléments sélectionnés AVANT la sauvegarde
            if (drag.target === groupeSelection) {
                console.log("[TEMPLATE][DRAG] Updating positions for", selectedElements.length, "element(s) before save")
                for (var i = 0; i < selectedElements.length; i++) {
                    if (selectedElements[i] && selectedElements[i].updateRelativePosition) {
                        selectedElements[i].updateRelativePosition()
                    }
                }
                // Sauvegarder avec les positions mises à jour
                logic.saveMap(MapTypes.UNDOREDO)
                
                // Mettre à jour le rectangle englobant après le déplacement
                updateBoundingRectangle()
            }
            clickElement = []
        }
    }

    function clickedLeft(mouse, drag) {
        mouse.accepted = true
        
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        var deltaX = Math.abs(workAreaPos.x - pressPosition.x)
        var deltaY = Math.abs(workAreaPos.y - pressPosition.y)
        var hasMoved = (deltaX > 5 || deltaY > 5)

        // Sélection par rectangle (clic sans élément + mouvement)
        if (hadPressWithoutElement && hasMoved) {
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
            finalizeRectangleSelection()

            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }

            isRectangleSelecting = false
            hadPressWithoutElement = false
            clickElement = []
            
            updateBoundingRectangle()
            templateSelectionChanged()
            return
        }

        isRectangleSelecting = false
        hadPressWithoutElement = false

        if (logic.selectionRect) {
            logic.selectionRect.hide()
        }

        // Clic sur espace vide = désélectionner tout
        if (clickElement.length === 0) {
            unselectSelectedElements()
            return
        }

        // Si on a bougé (déplacement), ne pas toggle la sélection
        if (hasMoved) {
            clickElement = []
            return
        }

        // Toggle selection: clic sur un élément = sélectionner/désélectionner
        var element = clickElement[0]
        var isAlreadySelected = selectedElements.indexOf(element) !== -1

        if (isAlreadySelected) {
            // Désélectionner cet élément
            deselectElement(element)
        } else {
            // Sélectionner cet élément (SANS désélectionner les autres)
            selectElement(element)
        }

        clickElement = []
        
        // Mettre à jour le rectangle englobant automatiquement
        updateBoundingRectangle()
        templateSelectionChanged()
    }

    function clickedRight(mouse, drag) {
        mouse.accepted = true
    }

    function pressAndHold(mouse, drag) {
        if (drag.active === true) {
            return
        }
    }

    // Override de positionChanged pour mettre à jour le rectangle englobant pendant le drag
    function positionChanged(mouse, drag) {
        // Appeler la logique de base pour la sélection rectangle et le snap
        if (mouseLogic.isRectangleSelecting) {
            mouseLogic.updateRectangleSelection(mouse.x, mouse.y)
        }
        
        // Gérer le snap pendant le drag
        if (drag.active && drag.target && grid.snapToGrid) {
            var deltaX = mouse.x - dragStartPos.x
            var deltaY = mouse.y - dragStartPos.y
            
            var newX = targetStartPos.x + deltaX
            var newY = targetStartPos.y + deltaY
            if (drag.target == groupeSelection) {
                // Snapper aux positions de la grille
                var snappedX = Math.round(newX / grid.gridSize) * grid.gridSize
                var snappedY = Math.round(newY / grid.gridSize) * grid.gridSize

                drag.target.x = snappedX
                drag.target.y = snappedY
            }
        }
        
        // Mettre à jour la position du rectangle englobant pendant le drag
        if (isDragging && boundingRectVisual && drag.target === groupeSelection) {
            var deltaXRect = groupeSelection.x - groupeSelectionStartPos.x
            var deltaYRect = groupeSelection.y - groupeSelectionStartPos.y
            
            boundingRectVisual.x = boundingRectStartPos.x + deltaXRect
            boundingRectVisual.y = boundingRectStartPos.y + deltaYRect
        }
        
        updateCameraPosition()
    }

    // ==================== FONCTIONS DE SÉLECTION ====================

    // Sélectionne un élément
    function selectElement(element) {
        if (!element) return
        if (element.isSelected) return
        
        element.elementPressed()
        element.elementTemplateSelected()
        createBindingsForElement(element)
        selectedElements.push(element)
        
        console.log("Element sélectionné, total:", selectedElements.length)
    }

    // Désélectionne un élément
    function deselectElement(element) {
        if (!element) return
        
        var index = selectedElements.indexOf(element)
        if (index === -1) return
        
        element.isSelected = false
        element.elementReleased()
        destroyBindingsForElement(element)
        selectedElements.splice(index, 1)
        
        console.log("Element désélectionné, total:", selectedElements.length)
    }

    // Désélectionne tous les éléments
    function unselectSelectedElements() {
        for (var i = 0; i < selectedElements.length; i++) {
            if (selectedElements[i]) {
                selectedElements[i].isSelected = false
                selectedElements[i].elementReleased()
                destroyBindingsForElement(selectedElements[i])
            }
        }
        selectedElements = []
        
        // Supprimer le rectangle englobant
        clearBoundingRectangle()
        templateSelectionChanged()
        
        console.log("Tous les éléments désélectionnés")
    }

    // ==================== FONCTIONS RECTANGLE ====================

    function updateRectangleSelection(mouseX, mouseY) {
        if (!isRectangleSelecting) return

        var workAreaPos = mainMa.mapToItem(workArea, mouseX, mouseY)
        rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)

        if (logic.selectionRect) {
            logic.selectionRect.updateGeometry(rectangleStart, rectangleCurrent)
        }

        var elementsResult = getElementsInRectangle(rectangleStart, rectangleCurrent)
        selectElementsInRectangle(elementsResult)
    }

    function getElementsInRectangle(start, current) {
        var elementsInRect = []
        var elementsOutRect = []

        var rectLeft = Math.min(start.x, current.x)
        var rectRight = Math.max(start.x, current.x)
        var rectTop = Math.min(start.y, current.y)
        var rectBottom = Math.max(start.y, current.y)

        for (var i = 0; i < logic.snapableTilesList.length; i++) {
            var element = logic.snapableTilesList[i]
            if (!element) continue

            var elementLeft = element.x
            var elementRight = element.x + element.width
            var elementTop = element.y
            var elementBottom = element.y + element.height

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

    function selectElementsInRectangle(elements) {
        var elementsIn = elements.inRectangle
        var elementsOut = elements.outRectangle
        
        for (var j = 0; j < elementsOut.length; j++) {
            var elementOut = elementsOut[j]
            if (elementOut.isSelected) {
                deselectElement(elementOut)
            }
        }
        
        for (var i = 0; i < elementsIn.length; i++) {
            var elementIn = elementsIn[i]
            if (!elementIn.isSelected) {
                selectElement(elementIn)
            }
        }
    }

    function finalizeRectangleSelection() {
        var elementsResult = getElementsInRectangle(rectangleStart, rectangleCurrent)
        selectElementsInRectangle(elementsResult)
    }

    // ==================== RECTANGLE ENGLOBANT ====================

    // Calcule le rectangle englobant tous les éléments sélectionnés
    function calculateBoundingRectangle() {
        if (selectedElements.length === 0) {
            return { x: 0, y: 0, width: 0, height: 0 }
        }

        var minX = Number.MAX_VALUE
        var minY = Number.MAX_VALUE
        var maxX = -Number.MAX_VALUE
        var maxY = -Number.MAX_VALUE

        for (var i = 0; i < selectedElements.length; i++) {
            var element = selectedElements[i]
            if (!element) continue

            var elementLeft = element.x
            var elementTop = element.y
            var elementRight = element.x + element.width
            var elementBottom = element.y + element.height

            if (elementLeft < minX) minX = elementLeft
            if (elementTop < minY) minY = elementTop
            if (elementRight > maxX) maxX = elementRight
            if (elementBottom > maxY) maxY = elementBottom
        }

        return {
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY,
            centerX: (minX + maxX) / 2,
            centerY: (minY + maxY) / 2
        }
    }

    // Met à jour le rectangle englobant visuel automatiquement
    function updateBoundingRectangle() {
        // Supprimer l'ancien rectangle
        clearBoundingRectangle()
        
        // Ne rien afficher si moins de 1 élément
        if (selectedElements.length < 1) {
            return
        }

        var boundingRect = calculateBoundingRectangle()
        
        // Créer le nouveau rectangle visuel
        createBoundingRectVisual(boundingRect)
    }

    // Crée le rectangle englobant visuel
    function createBoundingRectVisual(boundingRect) {
        var padding = 8
        
        var rectComponent = Qt.createQmlObject('
            import QtQuick 2.15
            Rectangle {
                color: "transparent"
                border.color: "lime"
                border.width: 3
                radius: 8
                z: 1000
                
                // Coins décoratifs
                Rectangle {
                    width: 12; height: 12
                    color: "lime"
                    radius: 2
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: -3
                }
                Rectangle {
                    width: 12; height: 12
                    color: "lime"
                    radius: 2
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -3
                }
                Rectangle {
                    width: 12; height: 12
                    color: "lime"
                    radius: 2
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: -3
                }
                Rectangle {
                    width: 12; height: 12
                    color: "lime"
                    radius: 2
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -3
                }
            }
        ', workArea, "boundingRect")

        if (rectComponent) {
            rectComponent.x = boundingRect.x - padding
            rectComponent.y = boundingRect.y - padding
            rectComponent.width = boundingRect.width + padding * 2
            rectComponent.height = boundingRect.height + padding * 2
            boundingRectVisual = rectComponent
        }
    }

    // Supprime le rectangle englobant visuel
    function clearBoundingRectangle() {
        if (boundingRectVisual) {
            boundingRectVisual.destroy()
            boundingRectVisual = null
        }
    }

    // Obtient les informations de tous les éléments sélectionnés
    function getSelectedElementsInfo() {
        var infos = []
        
        for (var i = 0; i < selectedElements.length; i++) {
            var element = selectedElements[i]
            if (!element) continue
            
            infos.push({
                uniqueId: element.uniqueId,
                x: element.x,
                y: element.y,
                width: element.width,
                height: element.height,
                centerX: element.x + element.width / 2,
                centerY: element.y + element.height / 2,
                parameters: element.snapableParameters
            })
        }
        
        return infos
    }
}
