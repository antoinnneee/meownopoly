import QtQuick 2.15

MouseLogic_Base {
    id: mouseLogic

    function pressedLeft(mouse, drag)
    {
        // propagate pressed to first clicked element
        if (clickElement.length > 0) {
            clickElement[0].elementPressed(clickElement[0])
            clickElement[0].parent = groupeSelection
            drag.target = clickElement[0]   // solution temporaire, ne permet pas de déplacer un groupe d'element
        }
        else
        {
            logic.tileLogic.deselectAllTiles()
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
        var deltaX = 0
        var deltaY = 0
        deltaX = groupeSelection.x
        deltaY = groupeSelection.y
        for (var i = clickElement.length - 1; i >= 0; i--) {
            // getting new grid position
            var newGridPos = editorGrid.getGridPosition(clickElement[i].x + deltaX, clickElement[i].y + deltaY)
            clickElement[i].x = clickElement[i].x + deltaX
            clickElement[i].y = clickElement[i].y + deltaY
            clickElement[i].parent = workArea
            clickElement[i].elementReleased(clickElement[i])
            if (drag.active)
                clickElement[i].isSelected = false
        }
        groupeSelection.x = 0
        groupeSelection.y = 0
        if ( clickElement.length === 0)
            logic.tileLogic.deselectAllTiles()
        drag.target = null
        clickElement = []
    }

    function clicked(mouse, drag)
    {
        mouse.accepted = true
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
