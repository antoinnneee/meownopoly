import QtQuick 2.15
import QtQuick.Controls
import Game
import Case
import Player

import ItemSnapable
import TileType
import "../case"

SnapableElement {
    id: root

    // --- Properties ---
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    // --- Signals ---
    // Gestion simplifiée des signaux de redimensionnement
    onElementResized: function(element, newWidth, newHeight) {
    }
    
    onSnapCompleted: function(element) {
    }

    // --- Items ---
    CaseTile {
        id: caseTile
        anchors.fill: parent
        caseData: root.snapableParameters.caseData
        mouseArea.enabled: false
        z: 1  // Assurer que le contenu est sous les poignées
    }
}
