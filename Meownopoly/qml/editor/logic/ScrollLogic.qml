import QtQuick 2.15
import "../tools"

QtObject {
    property GridManager editorGrid
    property var logic

    function scrollUp(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            // Sauvegarder les valeurs actuelles
            var oldMmSize = logic.mmSize;
            var oldWidth = logic.tileLogic.currentElementWidth;
            var oldHeight = logic.tileLogic.currentElementHeight;
            
            // Sauvegarder le ratio largeur/hauteur
            var aspectRatio = oldWidth / oldHeight;
            
            // Mettre à jour mmSize (zoom in)
            var newMmSize = oldMmSize + 1;
            logic.updateSize(newMmSize);
            
            // Ajuster les dimensions inversement proportionnelles pour garder le ratio visuel
            // On calcule d'abord la largeur, puis on dérive la hauteur pour maintenir le ratio
            var newWidth = oldWidth * oldMmSize / newMmSize;
            var newHeight = newWidth / aspectRatio;
            
            // Arrondir en maintenant le ratio
            logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth));
            logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight));
        }
    }
    function scrollDown(wheel) {
        if (wheel.modifiers & Qt.ControlModifier) {
            // Sauvegarder les valeurs actuelles
            var oldMmSize = logic.mmSize;
            var oldWidth = logic.tileLogic.currentElementWidth;
            var oldHeight = logic.tileLogic.currentElementHeight;
            
            // Sauvegarder le ratio largeur/hauteur
            var aspectRatio = oldWidth / oldHeight;
            
            // Mettre à jour mmSize (zoom out)
            var newMmSize = oldMmSize - 1;
            logic.updateSize(newMmSize);
            
            // Ajuster les dimensions inversement proportionnelles pour garder le ratio visuel
            if (newMmSize > 0) {
                // On calcule d'abord la largeur, puis on dérive la hauteur pour maintenir le ratio
                var newWidth = oldWidth * oldMmSize / newMmSize;
                var newHeight = newWidth / aspectRatio;
                
                // Arrondir en maintenant le ratio
                logic.tileLogic.currentElementWidth = Math.max(1, Math.round(newWidth));
                logic.tileLogic.currentElementHeight = Math.max(1, Math.round(newHeight));
            }
        }
    }
    function scrollLeft(wheel) {
        console.log("scrollLeft")
    }
    function scrollRight(wheel) {
        console.log("scrollRight")
    }

}
