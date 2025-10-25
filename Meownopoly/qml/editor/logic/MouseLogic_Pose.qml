import QtQuick 2.15
import MapTypes

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
        // Ne pas sauvegarder ici, c'est trop tôt (avant la création de l'élément)
    }
    function clickedLeft(mouse, drag)
    {
        var realPos = mainMa.mapToItem(editorGrid, mouse.x, mouse.y)
        var gridPos = editorGrid.getGridPosition(realPos.x, realPos.y)
        console.log("Placing selected asset at:", gridPos)
        placeSelectedAsset(gridPos.x, gridPos.y)
        mouse.accepted = true
        // Sauvegarder APRÈS la création de l'élément
        logic.saveMap(MapTypes.UNDOREDO)
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
