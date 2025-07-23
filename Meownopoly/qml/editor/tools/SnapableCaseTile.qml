import QtQuick 2.15
import QtQuick.Controls
import Game
import Case
import Player
import "../../case"

SnapableElement {
    id: root
    required property Case caseData

    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true
    
    // Connexion au GridManager du parent (Editor)
    gridManager: {
        var current = parent
        while (current && !current.hasOwnProperty('editorGrid')) {
            current = current.parent
        }
        return current ? current.editorGrid : null
    }
    
    // Dimensions minimales alignées sur la grille (restaurées)
    minWidth: gridManager ? Math.max(60, Math.ceil(60 / gridManager.gridSize) * gridManager.gridSize) : 60
    minHeight: gridManager ? Math.max(60, Math.ceil(60 / gridManager.gridSize) * gridManager.gridSize) : 60
    
    // S'assurer que les dimensions initiales sont alignées sur la grille
    Component.onCompleted: {
        if (gridManager && gridManager.snapToGrid) {
            var gridSize = gridManager.gridSize
            width = Math.max(minWidth, Math.round(width / gridSize) * gridSize)
            height = Math.max(minHeight, Math.round(height / gridSize) * gridSize)
        }
    }
    
    CaseTile {
        id: caseTile
        anchors.fill: parent
        caseData: root.caseData
        z: 1  // Assurer que le contenu est sous les poignées
    }
    
    // Gestion simplifiée des signaux de redimensionnement
    onElementResized: function(element, newWidth, newHeight) {
        console.log("Case redimensionnée:", newWidth, "x", newHeight, "- Grille:", gridManager ? gridManager.gridSize : "N/A")
    }
    
    onSnapCompleted: function(element) {
        console.log("Snap terminé à la position:", element.x, element.y)
    }
}
