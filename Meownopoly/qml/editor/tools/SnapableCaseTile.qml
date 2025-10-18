import QtQuick 2.15
import QtQuick.Controls
import Game
import Case
import Player

import ItemSnapable
import TileType
import "../../case"
import "snapable"

SnapableElement {
    id: root


    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true


    CaseTile {
        id: caseTile
        anchors.fill: parent
        caseData: root.snapableParameters.caseData
        mouseArea.enabled: false
        z: 1  // Assurer que le contenu est sous les poignées
    }
    
    // Gestion simplifiée des signaux de redimensionnement
    onElementResized: function(element, newWidth, newHeight) {
    }
    
    onSnapCompleted: function(element) {
    }


}
