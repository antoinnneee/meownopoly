import QtQuick 2.15

MouseLogic_Base {
    id: mouseLogic

    function pressedLeft(mouse, drag)
    {
    }

    function pressedRight(mouse, drag)
    {
        selectionPanel.clearAssetSelection()
        drag.target = editorGrid
        mouse.accepted = false  // to cancel right click on other mode
    }

    function clickRight(mouse, drag)
    {
        mouse.accepted = true
    }

    function release(mouse, drag)
    {
        drag.target = null
        clickElement = []
    }
    function clickedLeft(mouse, drag)
    {
        var realPos = mainMa.mapToItem(editorGrid, mouse.x, mouse.y)
        var gridPos = editorGrid.getGridPosition(realPos.x, realPos.y)
        console.log("Placing selected asset at:", gridPos)
        placeSelectedAsset(gridPos.x, gridPos.y)
        mouse.accepted = true
    }

    function pressAndHold(mouse, drag)
    {
        mouse.accepted = true
    }

    function changeMouseMode(mode)
    {
        unselectSelectedElements()
        logic.editorMouseMode = mode
    }


}
