import QtQuick 2.15
import "../tools"
import "../tools/grid"

QtObject {
    property GridManager editorGrid
    property var logic

    function scrollGrid(wheel, deltaSize) {
        if (wheel.modifiers & Qt.ControlModifier) {
            // Sauvegarder les valeurs actuelles
            var oldMmSize = logic.mmSize;
            var oldWidth = logic.tileLogic.currentElementWidth;
            var oldHeight = logic.tileLogic.currentElementHeight;
            
            // Sauvegarder le ratio largeur/hauteur
            var aspectRatio = oldWidth / oldHeight;
            
            // Calculer la position de grille avant le zoom
            var realPos = parent.mapToItem(editorGrid, wheel.x, wheel.y)
            var gridPosition = editorGrid.getGridPosition(realPos.x, realPos.y)
            console.log("Position avant zoom:", gridPosition)
            
            // Mettre à jour mmSize
            var newMmSize = oldMmSize + deltaSize;
            logic.updateSize(newMmSize);
            
            // Ajuster les dimensions inversement proportionnelles pour garder le ratio visuel
            if (newMmSize > 0) {
                // On calcule d'abord la largeur, puis on dérive la hauteur pour maintenir le ratio
                var newWidth = oldWidth * oldMmSize / newMmSize;
                var newHeight = newWidth / aspectRatio;
                
                // Arrondir en maintenant le ratio
                logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth));
                logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight));
                
                // Calculer la nouvelle position de grille après le zoom
                var newRealPos = parent.mapToItem(editorGrid, wheel.x, wheel.y)
                var newGridPosition = editorGrid.getGridPosition(newRealPos.x, newRealPos.y)
                console.log("Position après zoom:", newGridPosition)
                
                // Calculer le décalage nécessaire pour maintenir la même position de grille
                var deltaX = (gridPosition.x - newGridPosition.x) * editorGrid.gridSize
                var deltaY = (gridPosition.y - newGridPosition.y) * editorGrid.gridSize
                
                // Appliquer le décalage à la grille
                editorGrid.x -= deltaX
                editorGrid.y -= deltaY
                
                console.log("Décalage appliqué:", deltaX, deltaY)
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
