import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import UndoRedoManager
import meowComponent

import bottomMainPanel

QtObject {
    id: mouseLogic
    property bool isDragging: false
    property list<SnapableElement> clickElement:[]
    property var clickPosition
    property list<var> elementInitialPosition:[]
    property var logic
    property GridManager grid
    property list<SnapableElement> selectedElements: []

    property bool isControlPressed : false

    property point dragStartPos: Qt.point(0, 0)
    property point targetStartPos: Qt.point(0, 0)

    function dragChanged(mouseX, mouseY, drag) {
        isDragging = drag.active
        if (drag.active && drag.target) {
            // Sauvegarder les positions de départ
            dragStartPos = Qt.point(mouseX, mouseY)
            targetStartPos = Qt.point(drag.target.x, drag.target.y)
        }

    }
    function positionChanged(mouse, drag)
    {
        // Mettre à jour la sélection par rectangle si active
        if (mouseLogic.isRectangleSelecting) {
            mouseLogic.updateRectangleSelection(mouse.x, mouse.y)
        }
        
        // Gérer le snap pendant le drag
        if (drag.active && drag.target && grid.snapToGrid) {
            var deltaX = mouse.x - dragStartPos.x
            var deltaY = mouse.y - dragStartPos.y
            
            var newX = targetStartPos.x + deltaX
            var newY = targetStartPos.y + deltaY
            if (drag.target == groupeSelection)
            {
                // Snapper aux positions de la grille
                var snappedX = Math.round(newX / grid.gridSize) * grid.gridSize
                var snappedY = Math.round(newY / grid.gridSize) * grid.gridSize

                drag.target.x = snappedX
                drag.target.y = snappedY
            }
        }
    }

    function unselectSelectedElements()
    {
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].elementUnselected()
            destroyBindingsForElement(selectedElements[i])
        }
        selectedElements = []
        groupeSelection.x = 0
        groupeSelection.y = 0

        // Effacer la configuration de case
        clearCaseConfiguration()
    }

    // Fonction pour effacer la configuration de case
    function clearCaseConfiguration() {
        if (!logic.selectionPanel) {
            return
        }

        var casePanel = logic.selectionPanel.casePanel
        if (!casePanel) {
            return
        }

        var contentArea = casePanel.contentArea
        if (!contentArea) {
            return
        }

        var configPanel = contentArea.caseConfigurationPanelSection
        if (!configPanel) {
            return
        }

        configPanel.clearTarget()
    }
    function changeMouseMode(mode)
    {
        unselectSelectedElements()

        // Masquer la prévisualisation du lien si on change de mode
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            console.log("hideLinkPreview")
            logic.mouseLogic.hideLinkPreview()
        }

        logic.editorMouseMode = mode
    }

    function elementClicked(tile)
    {
        clickElement.push(tile)
        var realPos = mainMa.mapToItem(grid, tile.x, tile.y)
        var pos = Qt.point(realPos.x, realPos.y)
        elementInitialPosition.push(pos)
        console.log("Add element to list")
    }

    function pressedLeft(mouse, drag)
    {

        console.log("main MA pressed LEFT : ", clickElement.length, " elements")
        mouse.accepted = true

    }

    function pressedRight(mouse, drag)
    {

        console.log("main MA pressed RIGHT : ", clickElement.length, " elements")
        mouse.accepted = true

    }
    function pressedMiddle(mouse, drag)
    {
        console.log("main MA pressed MIDDLE : ", clickElement.length, " elements")
        mouse.accepted = true
    }

    function release(mouse, drag)
    {
        console.log("main MA released : ", clickElement.length, " elements")
        clickElement = []
        elementInitialPosition = []
    }

    function pressedAndHold(mouse, drag)
    {
        console.log("main MA pressed and hold : ", clickElement.length, " elements")

        var realPos = mainMa.mapToItem(grid, mouse.x, mouse.y)
        var gridPos = grid.getGridPosition(realPos.x, realPos.y)
    }

    function clickedLeft(mouse, drag)
    {
        console.log("main MA clicked : ", clickElement.length, " elements")
    }

    function clickedRight(mouse, drag)
    {
        console.log("main MA clicked right : ", clickElement.length, " elements")
    }

    function clickedMiddle(mouse, drag)
    {

    }

    function clicked(mouse, drag)
    {
        console.log("main MA clicked : ", clickElement.length, " elements")
    }

    // Fonction pour mettre à jour la configuration de case dans le panneau
    function updateCaseConfiguration() {
        if (!logic.selectionPanel) {
            console.log("[LOGIC] selectionPanel not available")
            return
        }

        // Accéder au CaseConfigurationPanelSection via le SelectionPanel
        var casePanel = logic.selectionPanel.casePanel
        if (!casePanel) {
            console.log("[LOGIC] casePanel not available")
            return
        }

        var contentArea = casePanel.csp_contentArea
        if (!contentArea) {
            console.log("[LOGIC] contentArea not available")
            return
        }

        var configPanel = contentArea.caseConfigurationPanelSection
        if (!configPanel) {
            console.log("[LOGIC] caseConfigurationPanelSection not available")
            return
        }
        var configLinkPanel = contentArea.connectionsConfigSection
        if (!configLinkPanel) {
            console.log("[LOGIC] connectionConfigurationPanel not available")
            return
        }

        // Si un seul élément est sélectionné et que c'est une case, mettre à jour la configuration
        if (selectedElements.length === 1) {
            var element = selectedElements[0]
            if (configLinkPanel)
            {
                configLinkPanel.setTargetElement(element)
            }
            if (element.snapableParameters.caseData) {
                console.log("[LOGIC] Updating case configuration for:", element.snapableParameters.caseData.name)
                if (configPanel)
                {
                    configPanel.setTargetCase(element)
                }

            } else {
                // Ce n'est pas une case, effacer la configuration
                configPanel.clearTarget()
            }
        } else {
            // Plusieurs éléments sélectionnés ou aucun, effacer la configuration
            configPanel.clearTarget()
        }
    }

    function setSelectedElementList(selectedList)
    {
        selectedElements = selectedList
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].elementPressed()
            createBindingsForElement(selectedElements[i])
        }
    }

    // Propriétés pour gérer les positions initiales sans changer le parent
    property var elementInitialPositions: ({})  // Map: element -> {x: initialX, y: initialY}
    property var elementBindings: ({})  // Map: element -> {xBinding: Binding, yBinding: Binding}

    // Fonction pour créer les bindings pour un élément
    function createBindingsForElement(element) {
        if (!element) return

        // Stocker la position initiale relative
        var initialX = element.x - groupeSelection.x
        var initialY = element.y - groupeSelection.y
        elementInitialPositions[element] = {x: initialX, y: initialY}

        // Créer les bindings dynamiquement en utilisant Qt.binding()
        // Stocker les valeurs initiales dans des variables accessibles via closure
        var bindingInitialX = initialX
        var bindingInitialY = initialY

        // Créer les bindings
        element.x = Qt.binding(function() {
            return groupeSelection.x + bindingInitialX
        })
        element.y = Qt.binding(function() {
            return groupeSelection.y + bindingInitialY
        })

        // Marquer l'élément comme ayant des bindings actifs
        elementBindings[element] = true
    }

    // Fonction pour détruire les bindings pour un élément
    function destroyBindingsForElement(element) {
        if (!element) return

        if (elementBindings[element]) {
            // Récupérer la position actuelle avant de casser les bindings
            var currentX = element.x
            var currentY = element.y

            // Casser les bindings en assignant des valeurs fixes
            element.x = currentX
            element.y = currentY

            delete elementBindings[element]
        }

        if (elementInitialPositions[element])
            delete elementInitialPositions[element]
    }

}
