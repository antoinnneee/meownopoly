import QtQuick 2.15
import "../../component"
import "../../component/grid"

QtObject {
    property GridManager gameGrid
    property var logic

    function scrollGrid(wheel, deltaSize) {
        if (wheel.modifiers & Qt.ControlModifier) {
            // Sauvegarder les valeurs actuelles
            var oldMmSize = gameGrid.mmSize;
            var oldWidth = logic.tileLogic.currentElementWidth;
            var oldHeight = logic.tileLogic.currentElementHeight;
            
            // Sauvegarder le ratio largeur/hauteur
            var aspectRatio = oldWidth / oldHeight;
            
            // Calculer la position de grille avant le zoom
            var realPos = parent.mapToItem(gameGrid, wheel.x, wheel.y)
            var gridPosition = gameGrid.getGridPosition(realPos.x, realPos.y)
            console.log("Position avant zoom:", gridPosition)
            
            // Mettre à jour mmSize
            var newMmSize = oldMmSize + deltaSize;
            gameGrid.mmSize = newMmSize
            // logic.updateSize(newMmSize);
            
            // Ajuster les dimensions inversement proportionnelles pour garder le ratio visuel
            if (newMmSize > 0) {
                // On calcule d'abord la largeur, puis on dérive la hauteur pour maintenir le ratio
                var newWidth = oldWidth * oldMmSize / newMmSize;
                var newHeight = newWidth / aspectRatio;
                
                // Arrondir en maintenant le ratio
                logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth));
                logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight));
                
                // Calculer la nouvelle position de grille après le zoom
                var newRealPos = parent.mapToItem(gameGrid, wheel.x, wheel.y)
                var newGridPosition = gameGrid.getGridPosition(newRealPos.x, newRealPos.y)
                console.log("Position après zoom:", newGridPosition)
                
                // Calculer le décalage nécessaire pour maintenir la même position de grille
                var deltaX = (gridPosition.x - newGridPosition.x) * gameGrid.gridSize
                var deltaY = (gridPosition.y - newGridPosition.y) * gameGrid.gridSize
                
                // Appliquer le décalage à la grille
                gameGrid.x -= deltaX
                gameGrid.y -= deltaY
                
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
