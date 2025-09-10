import QtQuick 2.15
import "../tools/snapable"

MouseLogic_Base {
    id: mouseLogic
    property list<SnapableElement> selectedElements: []
    property bool isDragging: false

    function dragChanged(drag)
    {
        console.log("[LOGIC] drag changed")
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
        mouse.accepted = true
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        drag.target = groupeSelection
        return
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
        console.log("[LOGIC] release drag:", isDragging)
        if (isDragging)
        {
            clickElement = []
            //unselectAllElements()
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
        if (!(mouse.modifiers & Qt.ControlModifier))
        {
            if ((clickElement.length > 0 && selectedElements.length > 0) && clickElement[0] === selectedElements[0]) {   // unselect item
                console.log("[LOGIC] unselect item")
                unselectAllElements()
            }
            else if (clickElement.length > 0) { // unselect all and select clicked
                console.log("[LOGIC] unselect all and select clicked", clickElement[0])
                unselectAllElements()
                clickElement[0].elementPressed(clickElement[0])
                clickElement[0].parent = groupeSelection
                drag.target = groupeSelection
                selectedElements.push(clickElement[0])
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

                    clickElement[0].elementPressed(clickElement[0])
                    clickElement[0].parent = groupeSelection
                    clickElement[0].x = clickElement[0].x - deltaX
                    clickElement[0].y = clickElement[0].y - deltaY
                    selectedElements.push(clickElement[0])
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
                            selectedElements[i].elementReleased(selectedElements[i])
                            selectedElements.splice(i,1)
                            break
                        }
                    }
                }
            }

        }

        clickElement = []
    }
    function clickedRight(mouse, drag) {

        var realPos = mainMa.mapToItem(editorGrid, mouse.x, mouse.y)
        var gridPos = editorGrid.getGridPosition(realPos.x, realPos.y)
        contextMenu.clickGridCoord = gridPos
        contextMenu.popup()
        mouse.accepted = true
    }

    function pressAndHold(mouse, drag)
    {
        if (drag.active === true) {
            return
        }
    }

}
