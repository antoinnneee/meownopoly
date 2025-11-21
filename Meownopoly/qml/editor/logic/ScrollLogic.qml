import QtQuick 2.15
import "../../component"
import "../../component/grid"
import CursorManager

QtObject {
    property GridManager editorGrid
    property var logic

    function scrollGrid(wheel, deltaSize) {
        if (wheel.modifiers & Qt.ControlModifier) {
            // Sauvegarder les valeurs actuelles
            logic.mouseLogic.lastGridPos = Qt.point(editorGrid.x, editorGrid.y)
            var oldMmSize = logic.mmSize;
            var oldWidth = logic.tileLogic.currentElementWidth;
            var oldHeight = logic.tileLogic.currentElementHeight;
            
            // Sauvegarder le ratio largeur/hauteur
            var aspectRatio = oldWidth / oldHeight;
            
            // Calculer la position de grille avant le zoom
            var realPos = parent.mapToItem(editorGrid, wheel.x, wheel.y)
            var gridPosition = editorGrid.getGridRealPosition(realPos.x, realPos.y)
            
            // Mettre à jour mmSize
            var newMmSize = oldMmSize + deltaSize;
            
            // Ajuster les dimensions inversement proportionnelles pour garder le ratio visuel
            if (newMmSize > 0) {
                editorGrid.mmSize = newMmSize
                // On calcule d'abord la largeur, puis on dérive la hauteur pour maintenir le ratio
                var newWidth = oldWidth * oldMmSize / newMmSize;
                var newHeight = newWidth / aspectRatio;
                
                // Arrondir en maintenant le ratio
                logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth));
                logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight));
                
                // Calculer la nouvelle position de grille après le zoom

                var rootEditor = logic.parent

                var centerViewX = rootEditor.width / 2
                var centerViewY = (rootEditor.availableHeight) / 2

                var centerViewGlobalX = centerViewX + rootEditor.appPositionX
                var centerViewGlobalY = centerViewY + rootEditor.appPositionY

//                var newRealPos = parent.mapToItem(editorGrid, wheel.x, wheel.y)
                var newRealPos = parent.mapToItem(editorGrid, centerViewX, centerViewY)
                var newGridPosition = editorGrid.getGridRealPosition(newRealPos.x, newRealPos.y)
                CursorManager.setPos(centerViewGlobalX, centerViewGlobalY)
                
                // Calculer le décalage nécessaire pour maintenir la même position de grille
                var deltaX = (gridPosition.x - newGridPosition.x) * editorGrid.gridSize
                var deltaY = (gridPosition.y - newGridPosition.y) * editorGrid.gridSize
                // Appliquer le décalage à la grille
                editorGrid.x -= deltaX
                editorGrid.y -= deltaY
                logic.mouseLogic.updateCameraPosition()


            }
        }
    }

    function scrollUp(wheel) {
        scrollGrid(wheel, 1);
    }
    
    function scrollDown(wheel) {
        scrollGrid(wheel, -1);
    }
    function scrollLeft(wheel) {
        console.log("scrollLeft")
    }
    function scrollRight(wheel) {
        console.log("scrollRight")
    }

}
