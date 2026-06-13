import QtQuick 2.15
import QtQuick.Controls
import ".."
import "../grid"
import MapTypes
import Game
import EditDelta 1.0
import theme

Rectangle {
    id: handle

    required property string direction
    required property GridManager gridManager
    required property var targetElement

    width: 10
    height: 10
    color: Theme.accent
    border.color: "white"
    border.width: 2
    radius: Theme.radiusXS
    z: 20
    
    // Curseur selon la direction
    property string cursorShape: {
        switch(direction) {
        case "nw": case "se": return "SizeFDiagCursor"
                   case "ne": case "sw": return "SizeBDiagCursor"
                              case "n": case "s": return "SizeVerCursor"
                                        case "e": case "w": return "SizeHorCursor"
                                                  default: return "ArrowCursor"
        }
    }
    
    // Variables pour le redimensionnement
    property real startMouseX: 0
    property real startMouseY: 0
    property real startWidth: 0
    property real startHeight: 0
    property real startElementX: 0
    property real startElementY: 0
    property real startGlobalMouseX: 0
    property real startGlobalMouseY: 0

    MouseArea {
        id: handleMouseArea
        anchors.fill: parent
        cursorShape: parent.cursorShape
        hoverEnabled: true
        
        onPressed: {
            targetElement.isResizing = true
            
            startMouseX = mouseX
            startMouseY = mouseY
            startWidth = targetElement.width
            startHeight = targetElement.height
            startElementX = targetElement.x
            startElementY = targetElement.y
            
            // Capturer la position globale initiale de la souris
            var globalPos = targetElement.mapToItem(gridManager, handle.x + mouseX, handle.y + mouseY)
            startGlobalMouseX = globalPos.x
            startGlobalMouseY = globalPos.y
            
            // Activer le mode visual de la grille
            if (gridManager && gridManager.enterResizeMode) {
                gridManager.enterResizeMode()
            }
        }
        
        onReleased: {
            targetElement.isResizing = false

            // Mettre à jour les positions relatives après redimensionnement
            targetElement.updateRelativePosition()

            // Recréer le binding vers groupeSelection si l'élément est sélectionné,
            // car l'assignation directe de x/y pendant le resize casse le Qt.binding
            if (targetElement.isSelected && logic.mouseLogic && logic.mouseLogic.rebindElement) {
                logic.mouseLogic.rebindElement(targetElement)
            }

            // Désactiver le mode visual de la grille
            if (gridManager && gridManager.exitResizeMode) {
                gridManager.exitResizeMode()
            }

            // Save + broadcast réseau (si collab) orchestrés par Game.updateMap
            Game.updateMap(EditDelta.TileModified, targetElement.snapableParameters)
        }
        
        onPositionChanged: {
            if (pressed) {
                // Calculer la position globale actuelle de la souris
                var currentGlobalPos = targetElement.mapToItem(gridManager, handle.x + mouseX, handle.y + mouseY)
                
                // Calculer le delta en pixels depuis le début
                var globalDeltaX = currentGlobalPos.x - startGlobalMouseX
                var globalDeltaY = currentGlobalPos.y - startGlobalMouseY
                
                // Convertir en unités de grille
                var deltaUnitsX = Math.round(globalDeltaX / targetElement.gridManager.gridSize)
                var deltaUnitsY = Math.round(globalDeltaY / targetElement.gridManager.gridSize)
                
                switch (direction) {
                case "e":
                {
                    var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                    var newUnitWidth = startUnitWidth + deltaUnitsX
                    if (newUnitWidth >= 1) {
                        targetElement.snapableParameters.displayParameter.unitSizeWidth = newUnitWidth
                    }
                    break
                }
                case "s":
                {
                    var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                    var newUnitHeight = startUnitHeight + deltaUnitsY
                    if (newUnitHeight >= 1) {
                        targetElement.snapableParameters.displayParameter.unitSizeHeight = newUnitHeight
                    }
                    break
                }
                case "w":
                {
                    // Pour redimensionner vers la gauche :
                    // 1. Calculer les unités de départ (référence fixe)
                    var startUnitWidth = Math.round(startWidth / gridManager.gridSize)

                    // 2. Calculer la nouvelle largeur basée sur le déplacement depuis le début
                    var newUnitWidth = startUnitWidth - deltaUnitsX


                    // S'assurer qu'on a au minimum 1 unité de largeur
                    if (newUnitWidth >= 1) {
                        // 3. Déplacer l'élément vers la gauche et ajuster la largeur
                        targetElement.x = startElementX + (deltaUnitsX * gridManager.gridSize)
                        targetElement.snapableParameters.displayParameter.unitSizeWidth = newUnitWidth
                    }
                    break
                }
                case "n":
                {
                    var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                    var newUnitHeight = startUnitHeight - deltaUnitsY
                    if (newUnitHeight >= 1) {
                        targetElement.y = startElementY + (deltaUnitsY * gridManager.gridSize)
                        targetElement.snapableParameters.displayParameter.unitSizeHeight = newUnitHeight
                    }
                    break;
                }
                case "nw": // Nord-Ouest (coin haut-gauche)
                {
                    var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                    var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                    var newUnitWidth = startUnitWidth - deltaUnitsX
                    var newUnitHeight = startUnitHeight - deltaUnitsY


                    if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                        // Déplacer en x et y, changer largeur et hauteur
                        targetElement.x = startElementX + (deltaUnitsX * gridManager.gridSize)
                        targetElement.y = startElementY + (deltaUnitsY * gridManager.gridSize)
                        targetElement.snapableParameters.displayParameter.unitSizeWidth = newUnitWidth
                        targetElement.snapableParameters.displayParameter.unitSizeHeight = newUnitHeight
                    }
                    break;
                }
                case "ne": // Nord-Est (coin haut-droite)
                {
                    var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                    var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                    var newUnitWidth = startUnitWidth + deltaUnitsX
                    var newUnitHeight = startUnitHeight - deltaUnitsY

                    if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                        // Déplacer seulement en y, changer largeur et hauteur
                        targetElement.y = startElementY + (deltaUnitsY * gridManager.gridSize)
                        targetElement.snapableParameters.displayParameter.unitSizeWidth = newUnitWidth
                        targetElement.snapableParameters.displayParameter.unitSizeHeight = newUnitHeight
                    }
                    break;
                }
                case "sw": // Sud-Ouest (coin bas-gauche)
                {
                    var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                    var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                    var newUnitWidth = startUnitWidth - deltaUnitsX
                    var newUnitHeight = startUnitHeight + deltaUnitsY

                    if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                        // Déplacer seulement en x, changer largeur et hauteur
                        targetElement.x = startElementX + (deltaUnitsX * gridManager.gridSize)
                        targetElement.snapableParameters.displayParameter.unitSizeWidth = newUnitWidth
                        targetElement.snapableParameters.displayParameter.unitSizeHeight = newUnitHeight
                    }
                    break;
                }
                case "se": // Sud-Est (coin bas-droite)
                {
                    var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                    var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                    var newUnitWidth = startUnitWidth + deltaUnitsX
                    var newUnitHeight = startUnitHeight + deltaUnitsY

                    if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                        // Pas de déplacement, juste changer largeur et hauteur
                        targetElement.snapableParameters.displayParameter.unitSizeWidth = newUnitWidth
                        targetElement.snapableParameters.displayParameter.unitSizeHeight = newUnitHeight
                    }
                    break;
                }
                }
            }
        }
    }
    
    // Effet de survol optimisé
    states: State {
        name: "hovered"
        when: handleMouseArea.containsMouse && !targetElement.isResizing
        PropertyChanges {
            target: handle
            scale: 1.2
            color: Theme.hover(Theme.accent)
        }
    }
    
    transitions: Transition {
        NumberAnimation {
            properties: "scale,color"
            duration: 120
            easing.type: Easing.OutQuad
        }
    }
}
