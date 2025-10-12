import QtQuick 2.15
import "../tools/snapable"
QtObject {
    property list<SnapableElement> clickElement:[]
    property var clickPosition
    property list<var> elementInitialPosition:[]
    property var logic
    property list<SnapableElement> selectedElements: []

    function unselectAllElements()
    {
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].x = selectedElements[i].x + deltaX
            selectedElements[i].y = selectedElements[i].y + deltaY
            selectedElements[i].parent = workArea
            selectedElements[i].elementReleased()
        }
        selectedElements = []
        groupeSelection.x = 0
        groupeSelection.y = 0
        logic.tileLogic.deselectAllTiles() // can be improved
        
        // Effacer la configuration de case
        clearCaseConfiguration()
    }

    function unselectSelectedElements()
    {
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].x = selectedElements[i].x + deltaX
            selectedElements[i].y = selectedElements[i].y + deltaY
            selectedElements[i].parent = workArea
            selectedElements[i].elementUnselected()
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
        unselectAllElements()
        logic.editorMouseMode = mode
    }

    function elementClicked(tile)
    {
        clickElement.push(tile)
        var realPos = mainMa.mapToItem(editorGrid, tile.x, tile.y)
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

        var realPos = mainMa.mapToItem(editorGrid, mouse.x, mouse.y)
        var gridPos = editorGrid.getGridPosition(realPos.x, realPos.y)
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

    function dragChanged(drag)
    {

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
            if (element.caseData) {
                console.log("[LOGIC] Updating case configuration for:", element.caseData.name)
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
            console.log(selectedElements[i])
            selectedElements[i].parent = groupeSelection
            selectedElements[i].elementPressed()
            selectedElements[i].x = selectedElements[i].x - groupeSelection.x
            selectedElements[i].y = selectedElements[i].y - groupeSelection.y
        }
    }
}
