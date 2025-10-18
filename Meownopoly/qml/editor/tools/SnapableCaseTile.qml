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

    Connections{
        target: root.snapableParameters.caseData
        function onTypeChanged()
        {
            console.log("qml type changed")
        }
    }

    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true
    connectionManager.onNextElementAdded:function(element) {
        if (root.blockConnections) return
        console.log("Next element added:", element)
        // Synchroniser avec les données C++ : ajouter la case suivante
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.addNext(element.snapableParameters)
            console.log("Added next case:", element.snapableParameters.caseData.name, "to", root.snapableParameters.caseData.name)
        }
    }
    connectionManager.onPreviousElementAdded:function(element) {
        if (root.blockConnections) return
        console.log("Previous element added:", element)
        // Synchroniser avec les données C++ : ajouter la case précédente
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.addPrev(element.snapableParameters)
            console.log("Added previous case:", element.snapableParameters.caseData.name, "to", root.snapableParameters.caseData.name)
        }
    }
    connectionManager.onNextElementRemoved:function(element) {
        if (root.blockConnections) return
        console.log("Next element removed:", element)
        // Synchroniser avec les données C++ : supprimer la case suivante
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.removeNext(element.snapableParameters)
            console.log("Removed next case:", element.snapableParameters.caseData.name, "from", root.snapableParameters.caseData.name)
        }
    }
    connectionManager.onPreviousElementRemoved:function(element) {
        if (root.blockConnections) return
        console.log("Previous element removed:", element)
        // Synchroniser avec les données C++ : supprimer la case précédente
        if (element && element.snapableParameters && root.snapableParameters) {
            root.snapableParameters.removePrev(element.snapableParameters)
            console.log("Removed previous case:", element.snapableParameters.caseData.name, "from", root.snapableParameters.caseData.name)
        }
    }

    Component.onCompleted: {
        // Synchroniser les connexions existantes depuis les données C++ vers l'interface
        syncConnectionsFromCaseData()
    }

    // Fonction pour synchroniser les connexions depuis les données C++ vers l'interface QML
    function syncConnectionsFromCaseData() {
        if (!root.snapableParameters) return
        
        // Cette fonction pourrait être appelée pour synchroniser les connexions existantes
        // depuis les données C++ vers l'interface QML si nécessaire
        console.log("Syncing connections for case:", root.snapableParameters.caseData.name)
        console.log("- Next cases count:", root.snapableParameters.next ? root.snapableParameters.next.length : 0)
        console.log("- Previous cases count:", root.snapableParameters.prev ? root.snapableParameters.prev.length : 0)
    }

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
