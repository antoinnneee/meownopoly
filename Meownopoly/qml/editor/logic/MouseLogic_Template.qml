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
    
    // Couleur de sélection pour le template
    property color selectionColor: "#4A90E2"
    
    // Rectangle englobant visuel (optionnel)
    property var boundingRectVisual: null
    
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

    // Nouvelles propriétés pour détecter le mouvement même lors d'un "clic"
    property point pressPosition: Qt.point(0, 0)
    property bool hadPressWithoutElement: false

    function dragChanged(mouseX, mouseY, drag) {
        console.log("drag changed")

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

    function pressedLeft(mouse, drag) {
        console.log("press left")

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

    function pressedRight(mouse, drag) {
        drag.target = grid
        mouse.accepted = true
    }

    function release(mouse, drag) {
        console.log("release")
        // Finaliser la sélection par rectangle si active
        if (isRectangleSelecting) {
            finalizeRectangleSelection()
            isRectangleSelecting = false
            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }
            // Réinitialiser le drag pour les prochaines interactions
            drag.target = null
            
            // Émettre le signal de changement
            templateSelectionChanged()
        }

        if (isDragging) {
            // IMPORTANT: Update positions of all selected elements BEFORE saving
            if (drag.target === groupeSelection) {
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

    function clickedLeft(mouse, drag) {
        console.log("clickedLeft")
        mouse.accepted = true
        // Calculer la distance parcourue entre press et release
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        var deltaX = Math.abs(workAreaPos.x - pressPosition.x)
        var deltaY = Math.abs(workAreaPos.y - pressPosition.y)
        var hasMoved = (deltaX > 5 || deltaY > 5)  // Seuil de 5 pixels

        // Si on a appuyé sans élément et qu'on a bougé, c'est une sélection rectangle
        if (hadPressWithoutElement && hasMoved) {
            rectangleCurrent = Qt.point(workAreaPos.x, workAreaPos.y)
            finalizeRectangleSelection()

            if (logic.selectionRect) {
                logic.selectionRect.hide()
            }

            isRectangleSelecting = false
            hadPressWithoutElement = false
            clickElement = []
            
            // Émettre le signal de changement
            templateSelectionChanged()
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
            templateSelectionChanged()
            return
        }

        // Si on a fait un drag (hasMoved), ne pas traiter comme un clic de sélection
        if (hasMoved) {
            clickElement = []
            return
        }

        if (!(mouse.modifiers & Qt.ControlModifier)) {
            // CTRL is not pressed => normal selection mode
            var isAlreadyInSelection = selectedElements.indexOf(clickElement[0]) !== -1

            if (isAlreadyInSelection) {
                // L'élément fait déjà partie de la sélection - désélectionner tout
                unselectSelectedElements()
            } else {
                // L'élément n'est PAS dans la sélection actuelle -> nouvelle sélection
                unselectSelectedElements()
                clickElement[0].elementPressed()

                if (clickElement[0])
                    clickElement[0].elementTemplateReversed()

                createBindingsForElement(clickElement[0])
                drag.target = groupeSelection
                selectedElements.push(clickElement[0])

                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()
                updateVisualEffectPanel(selectedElements[0].snapableParameters.displayParameter)
            }
        } else {
            // CTRL is pressed => add to selection
            if (!clickElement[0].isSelected) {
                clickElement[0].elementPressed()

                if (clickElement[0])
                    clickElement[0].elementTemplateSelected()

                createBindingsForElement(clickElement[0])
                selectedElements.push(clickElement[0])

                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()
                updateVisualEffectPanel(clickElement[0].snapableParameters.displayParameter)
            } else {
                // unselect element
                for (var i = 0; i < selectedElements.length; i++) {
                    if (selectedElements[i] === clickElement[0]) {
                        selectedElements[i].isSelected = false
                        selectedElements[i].elementReleased()
                        destroyBindingsForElement(selectedElements[i])
                        selectedElements.splice(i, 1)
                        break
                    }
                }

                // Mettre à jour la configuration de case si applicable
                updateCaseConfiguration()
            }
        }
        
        clickElement = []
        
        // Émettre le signal de changement
        templateSelectionChanged()
    }

    function clickedRight(mouse, drag) {
        // Menu contextuel supprimé - pas d'action sur clic droit
        mouse.accepted = true
    }

    function pressAndHold(mouse, drag) {
        console.log("press and hold")

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
            if (elementOut.isSelected) {
                elementOut.elementUnselected()
                destroyBindingsForElement(elementOut)
                var selectElementIndex = selectedElements.indexOf(elementOut)
                if (selectElementIndex !== -1) {
                    selectedElements.splice(selectElementIndex, 1)
                }
            }
        }
        
        // Sélectionner les nouveaux éléments
        for (var i = 0; i < elementsIn.length; i++) {
            var elementIn = elementsIn[i]
            if (!elementIn.isSelected) {
                elementIn.elementPressed()
                elementIn.elementTemplateSelected()

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

    // ==================== NOUVELLES FONCTIONS POUR TEMPLATE ====================

    // Calcule le rectangle englobant tous les éléments sélectionnés
    function calculateBoundingRectangle() {
        if (selectedElements.length === 0) {
            return { x: 0, y: 0, width: 0, height: 0 }
        }

        var minX = Number.MAX_VALUE
        var minY = Number.MAX_VALUE
        var maxX = Number.MIN_VALUE
        var maxY = Number.MIN_VALUE

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

    // Génère et affiche le rectangle englobant visuellement
    function generateBoundingRectangle(color) {
        if (selectedElements.length < 2) {
            console.log("Besoin d'au moins 2 éléments pour générer un rectangle englobant")
            return null
        }

        var boundingRect = calculateBoundingRectangle()
        
        console.log("Rectangle englobant calculé:")
        console.log("  Position: (" + boundingRect.x + ", " + boundingRect.y + ")")
        console.log("  Taille: " + boundingRect.width + " x " + boundingRect.height)
        console.log("  Centre: (" + boundingRect.centerX + ", " + boundingRect.centerY + ")")

        // Créer le rectangle visuel si nécessaire
        if (boundingRectVisual) {
            boundingRectVisual.destroy()
        }

        var component = Qt.createComponent("qrc:/qml/component/BoundingRectangle.qml")
        if (component.status === Component.Ready) {
            boundingRectVisual = component.createObject(workArea, {
                x: boundingRect.x - 5,
                y: boundingRect.y - 5,
                width: boundingRect.width + 10,
                height: boundingRect.height + 10,
                borderColor: color || selectionColor,
                borderWidth: 3
            })
        } else {
            // Fallback: créer un rectangle simple
            createSimpleBoundingRect(boundingRect, color)
        }

        return boundingRect
    }

    // Crée un rectangle simple comme fallback
    function createSimpleBoundingRect(boundingRect, color) {
        // Créer dynamiquement un rectangle
        var rectComponent = Qt.createQmlObject('
            import QtQuick 2.15
            Rectangle {
                color: "transparent"
                border.color: "' + (color || selectionColor) + '"
                border.width: 3
                radius: 8
                
                // Animation de pulsation
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
        ', workArea, "boundingRect")

        if (rectComponent) {
            rectComponent.x = boundingRect.x - 5
            rectComponent.y = boundingRect.y - 5
            rectComponent.width = boundingRect.width + 10
            rectComponent.height = boundingRect.height + 10
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

    // Met à jour la couleur de sélection
    function updateSelectionColor(color) {
        selectionColor = color
        
        // Mettre à jour le rectangle englobant s'il existe
        if (boundingRectVisual) {
            boundingRectVisual.border.color = color
        }
    }

    // Relie les éléments sélectionnés (crée des connexions entre eux)
    function linkSelectedElements() {
        if (selectedElements.length < 2) {
            console.log("Besoin d'au moins 2 éléments pour créer des liens")
            return []
        }

        var links = []
        
        // Créer des liens entre chaque paire d'éléments adjacents
        for (var i = 0; i < selectedElements.length - 1; i++) {
            var element1 = selectedElements[i]
            var element2 = selectedElements[i + 1]
            
            if (element1 && element2) {
                var link = {
                    from: element1.uniqueId,
                    to: element2.uniqueId,
                    fromCenter: {
                        x: element1.x + element1.width / 2,
                        y: element1.y + element1.height / 2
                    },
                    toCenter: {
                        x: element2.x + element2.width / 2,
                        y: element2.y + element2.height / 2
                    }
                }
                links.push(link)
                
                // Ajouter les liens aux éléments si la méthode existe
                if (element1.addNext) {
                    element1.addNext(element2)
                }
                if (element2.addPrev) {
                    element2.addPrev(element1)
                }
            }
        }

        console.log("Créé", links.length, "liens entre les éléments")
        return links
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

    // Désélectionne tous les éléments et nettoie
    function unselectSelectedElements() {
        for (var i = 0; i < selectedElements.length; i++) {
            if (selectedElements[i]) {
                selectedElements[i].isSelected = false
                selectedElements[i].elementReleased()
                destroyBindingsForElement(selectedElements[i])
            }
        }
        selectedElements = []
        
        // Nettoyer le rectangle englobant
        clearBoundingRectangle()
        
        // Émettre le signal de changement
        templateSelectionChanged()
    }
}
