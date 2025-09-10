import QtQuick 2.15
import "../tools/snapable"

MouseLogic_Base {
    id: mouseLogic
    property list<SnapableElement> selectedElements: []
    property bool isDragging: false

    function dragChanged(drag)
    {
        console.log("[LOGIC] drag changed")
        if (!drag.active)
        {
            unselectAllElements()
        }
        isDragging = drag.active
    }

    function unselectAllElements()
    {
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].x = selectedElements[i].x + deltaX
            selectedElements[i].y = selectedElements[i].y + deltaY
            selectedElements[i].parent = workArea
            selectedElements[i].elementReleased(selectedElements[i])
        }
        selectedElements = []
        groupeSelection.x = 0
        groupeSelection.y = 0
        logic.tileLogic.deselectAllTiles() // can be improved
    }

    function pressedLeft(mouse, drag)
    {
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        // propagate pressed to first clicked element
        if (mouse.modifiers & Qt.ControlModifier)
        {
            // multi selection
            console.log("[LOGIC] pressed left with control modifier")
            if (clickElement.length >= 0) {
                if (!clickElement[0].isSelected)
                {
                    clickElement[0].elementPressed(clickElement[0])
                    clickElement[0].parent = groupeSelection
                    clickElement[0].x = clickElement[0].x - deltaX
                    clickElement[0].y = clickElement[0].y - deltaY
                    selectedElements.push(clickElement[0])
                }
                else
                {
                    selectedElements[0].x = selectedElements[0].x + deltaX
                    selectedElements[0].y = selectedElements[0].y + deltaY
                    selectedElements[0].isSelected = false
                    selectedElements[0].parent = workArea
                    selectedElements[0].elementReleased(selectedElements[0])
                    selectedElements.splice(0,1)
                    logic.currentSelectedElement = null // todo use selectedElements instead of logic.currentSelectedElement

                }
            }
            drag.target = groupeSelection
        }
        else
        {
            console.log("[LOGIC] pressed left without control modifier")
            unselectAllElements()
            if (clickElement.length > 0) {
                clickElement[0].elementPressed(clickElement[0])
                clickElement[0].parent = groupeSelection
                drag.target = groupeSelection 
                selectedElements.push(clickElement[0])
            }
        }
        mouse.accepted = true
    }

    // multi selection : 
    /*
            console.log("main MA pressed : nb Element ", clickElement.length)
            mouse.accepted = true
            for (var i = clickElement.length - 1; i >= 0; i--) {
                clickElement[i].elementPressed(clickElement[i])
                clickElement[i].parent = groupeSelection
            }
            drag.target = groupeSelection
    */
    function pressedRight(mouse, drag)
    {
        drag.target = editorGrid
        mouse.accepted = true
    }

    function release(mouse, drag)
    {
        console.log("[LOGIC] release")
        if (isDragging)
        {
            unselectAllElements()
        }
    }

    function clickedLeft(mouse, drag)
    {
        console.log("[LOGIC] clicked left")
        mouse.accepted = true
        /*
        if (!(mouse.modifiers & Qt.ControlModifier))
        {
            unselectAllElements()
            if (clickElement.length > 0) {
                clickElement[0].elementPressed(clickElement[0])
                clickElement[0].parent = groupeSelection
                drag.target = groupeSelection 
                selectedElements.push(clickElement[0])
            }
        }
        */
        unselectAllElements()
        if (clickElement.length > 0) {
            clickElement[0].elementPressed(clickElement[0])
            clickElement[0].parent = groupeSelection
            drag.target = groupeSelection
            selectedElements.push(clickElement[0])
        }
        clickElement = []
    }

    function pressAndHold(mouse, drag)
    {
        if (drag.active === true) {
            return
        }
        var realPos = mainMa.mapToItem(editorGrid, mouse.x, mouse.y)
        var gridPos = editorGrid.getGridPosition(realPos.x, realPos.y)
        contextMenu.clickGridCoord = gridPos
        contextMenu.popup()
        mouse.accepted = true
    }

}
