import QtQuick 2.15
import QtQuick.Controls
import Game
import Case
import Player

import ItemSnapable

import "../../case"
import "snapable"

SnapableElement {
    id: root
    type : ItemSnapable.CaseTile

    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true
    connectionManager.onNextElementAdded:function(element) {
        if (root.blockConnections) return
        console.log("Next element added:", element)
        // Synchroniser avec les données C++ : ajouter la case suivante
        if (element && element.caseData && root.caseData) {
            root.caseData.addNext(element.caseData)
            console.log("Added next case:", element.caseData.name, "to", root.caseData.name)
        }
    }
    connectionManager.onPreviousElementAdded:function(element) {
        if (root.blockConnections) return
        console.log("Previous element added:", element)
        // Synchroniser avec les données C++ : ajouter la case précédente
        if (element && element.caseData && root.caseData) {
            root.caseData.addPrev(element.caseData)
            console.log("Added previous case:", element.caseData.name, "to", root.caseData.name)
        }
    }
    connectionManager.onNextElementRemoved:function(element) {
        if (root.blockConnections) return
        console.log("Next element removed:", element)
        // Synchroniser avec les données C++ : supprimer la case suivante
        if (element && element.caseData && root.caseData) {
            root.caseData.removeNext(element.caseData)
            console.log("Removed next case:", element.caseData.name, "from", root.caseData.name)
        }
    }
    connectionManager.onPreviousElementRemoved:function(element) {
        if (root.blockConnections) return
        console.log("Previous element removed:", element)
        // Synchroniser avec les données C++ : supprimer la case précédente
        if (element && element.caseData && root.caseData) {
            root.caseData.removePrev(element.caseData)
            console.log("Removed previous case:", element.caseData.name, "from", root.caseData.name)
        }
    }

    Component.onCompleted: {
        // Synchroniser les connexions existantes depuis les données C++ vers l'interface
        syncConnectionsFromCaseData()
    }

    // Fonction pour synchroniser les connexions depuis les données C++ vers l'interface QML
    function syncConnectionsFromCaseData() {
        if (!root.caseData) return
        
        // Cette fonction pourrait être appelée pour synchroniser les connexions existantes
        // depuis les données C++ vers l'interface QML si nécessaire
        console.log("Syncing connections for case:", root.caseData.name)
        console.log("- Next cases count:", root.caseData.next ? root.caseData.next.length : 0)
        console.log("- Previous cases count:", root.caseData.prev ? root.caseData.prev.length : 0)
    }

    CaseTile {
        id: caseTile
        anchors.fill: parent
        caseData: root.caseData
        mouseArea.enabled: false
        z: 1  // Assurer que le contenu est sous les poignées
    }
    
    // Gestion simplifiée des signaux de redimensionnement
    onElementResized: function(element, newWidth, newHeight) {
    }
    
    onSnapCompleted: function(element) {
    }


}
