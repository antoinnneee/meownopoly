import QtQuick 2.15
import QtQuick.Controls
import Game
import Case
import Player

import ItemSnapable

import "../../case"

SnapableElement {
    id: root
    required property Case caseData

    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true



    CaseTile {
        id: caseTile
        anchors.fill: parent
        caseData: root.caseData
        z: 1  // Assurer que le contenu est sous les poignées
    }
    
    // Gestion simplifiée des signaux de redimensionnement
    onElementResized: function(element, newWidth, newHeight) {
    }
    
    onSnapCompleted: function(element) {
    }
}
