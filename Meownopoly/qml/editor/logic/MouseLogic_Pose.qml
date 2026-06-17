import QtQuick 2.15
import MapTypes
import Game
import EditDelta 1.0

MouseLogic_Base {
    id: mouseLogic

    function pressedLeft(mouse, drag)
    {
    }

    function pressedRight(mouse, drag)
    {
        logic.clearAssetSelection()
        drag.target = grid
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
        var realPos = mainMa.mapToItem(grid, mouse.x, mouse.y)
        var gridPos = grid.getGridPosition(realPos.x, realPos.y)
        var placed = logic.tileLogic.placeSelectedAsset(gridPos.x, gridPos.y)
        mouse.accepted = true
        if (placed && placed.snapableParameters)
            Game.updateMap(EditDelta.TileAdded, placed.snapableParameters)
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
