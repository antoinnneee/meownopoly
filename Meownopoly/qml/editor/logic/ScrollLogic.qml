import QtQuick 2.15
import "../../meowComponent"
import "../../meowComponent/grid"
import CursorManager

QtObject {
    property GridManager editorGrid
    property var logic

    // Facteur multiplicatif appliqué à mmSize par cran de molette.
    // 1.1 = +10% par cran : confortable, ~7 crans pour doubler le zoom.
    // Borne inférieure pour éviter des mmSize ridiculement petits qui
    // rendraient gridSize sub-pixel.
    readonly property real zoomFactor: 1.1
    readonly property real minMmSize: 0.5

    function scrollGrid(wheel, deltaSize) {
        if (wheel.modifiers & Qt.ControlModifier) {
            // Sauvegarder les valeurs actuelles pour la caméra
            logic.mouseLogic.lastGridPos = Qt.point(editorGrid.x, editorGrid.y)

            var oldMmSize = editorGrid.mmSize;
            var oldWidth = logic.tileLogic.currentElementWidth;
            var oldHeight = logic.tileLogic.currentElementHeight;

            // Sauvegarder le ratio largeur/hauteur
            var aspectRatio = oldWidth / oldHeight;

            // Mettre à jour mmSize de façon multiplicative — un cran molette
            // = ×zoomFactor ou ÷zoomFactor (zoom-in/out symétriques).
            // deltaSize > 0 = zoom in ; deltaSize < 0 = zoom out.
            var step = deltaSize > 0 ? zoomFactor : 1.0 / zoomFactor;
            var newMmSize = oldMmSize * step;
            if (newMmSize < minMmSize) newMmSize = minMmSize;

            if (newMmSize > 0) {
                // 0. Capturer l'état 3D AVANT le zoom
                logic.mouseLogic.prepareZoom(wheel.x, wheel.y)
                
                // Calcul du ratio de zoom
                var ratio = newMmSize / oldMmSize;

                // Position de la souris (centre du zoom)
                var mouseX = wheel.x
                var mouseY = wheel.y

                // Calculer la nouvelle position de la grille pour garder le point sous la souris fixe
                // Formule: NewGridPos = MousePos - (MousePos - OldGridPos) * Ratio
                var newGridX = mouseX - (mouseX - editorGrid.x) * ratio
                var newGridY = mouseY - (mouseY - editorGrid.y) * ratio

                // Appliquer les changements (ceci met à jour mmSize, donc scaleLevel, donc magnification caméra)
                editorGrid.mmSize = newMmSize
                editorGrid.x = newGridX
                editorGrid.y = newGridY

                // Ajuster les dimensions inversement proportionnelles pour garder le ratio visuel
                // On calcule d'abord la largeur, puis on dérive la hauteur pour maintenir le ratio
                var newWidth = oldWidth * oldMmSize / newMmSize;
                var newHeight = newWidth / aspectRatio;
                
                // Arrondir en maintenant le ratio
                logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth));
                logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight));
                
                // Appliquer la correction 3D et synchroniser la position "lastGridPos"
                // pour éviter que updateCameraPosition ne soit appelé inutilement par la suite
                logic.mouseLogic.applyZoom(wheel.x, wheel.y)
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
