import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import Game
import Case
import CaseRestArea
import CaseKibbleDispenser
import CaseCatNip
import CaseCardBoardBox
import CaseJail
import CaseToJail
import CaseCatDoor
import CaseFreeNap
import CaseCatDevice
import "tools"
import "tools/snapable"

Rectangle {
    id: root

    color: "lightblue"
    border.width: 0

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList
    property alias currentSelectedElement: logic.currentSelectedElement

    EditorLogic {
        id: logic
        workArea: workArea
        editorDynamicComponent: editorDynamicComponent
    }
    EditorDynamicComponent {
        id: editorDynamicComponent
        editorGrid: editorGrid
        logic: logic
        workArea: workArea
        caseConfigPanel: caseConfigPanel
        connectionsPanel: connectionsPanel
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid

        mmSize: 15
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        
        // Test de l'animation au démarrage
        Component.onCompleted: {
        }
        onGridPressed : function(position) {
            // Stocker la position du clic pour créer l'élément au bon endroit
            contextMenu.clickGridCoord = position
            contextMenu.popup()
        }
        onGridClicked:  function(position) {
            logic.deselectAllTiles()
        }
    }

    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid
    }
    
    // Gestionnaire de raccourcis clavier
    Keys.onPressed: function(event) {
    }
    
    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true
    



    // Menu contextuel pour la création d'éléments
    Menu {
        id: contextMenu

        property var clickGridCoord: Qt.point(0, 0)
        
        MenuItem {
            text: "Créer une Case"
            onTriggered: {
                console.log(contextMenu.clickGridCoord)
                logic.createNewTileAtPosition(Case.CS_KibbleDispenser, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, 0)
            }
        }

        MenuItem {
            text: "Créer un élément"
            onTriggered: {
                logic.createNewTileAtPosition(Case.CS_Unknow, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, 1)
            }
        }
    }


    // Panneau d'information sur l'élément sélectionné (nouveau composant)
    InfoPanel {
        id: infoPanel

        anchors {
            top: parent.top
            left: parent.left
            margins: 10
        }

        selectedElement: currentSelectedElement
        gridManager: editorGrid
        totalTilesCount: snapableTilesList.length
    }

    // Panneau de contrôle de la grille (composant séparé)
    GridControlPanel {
        id: gridControls
        anchors.fill: parent
        gridManager: editorGrid
        showControlPanel: false
        showInfoPanel: true
    }


    // Panneau de configuration des cases
    CaseConfigurationPanel {
        id: caseConfigPanel
        height: parent.height
        width: parent.width/2

        onConfigurationClosed: {
            console.log("Panneau de configuration fermé")
        }

        onRequestChangeType: function(newType)  {
            logic.changeCaseType(caseConfigPanel.targetSnapableCase, newType)
        }
    }

    // Panneau de configuration des connexions
    ConnectionsConfigurationPanel {
        id: connectionsPanel
        height: parent.height
        width: parent.width/2

        function selectElementToConnect(kind) {
            // Simple stratégie: utiliser l'élément actuellement sélectionné dans l'éditeur
            if (!currentSelectedElement || !connectionsPanel.targetElement) return
            if (currentSelectedElement === connectionsPanel.targetElement) return

            if (kind === "previous") {
                connectionsPanel.targetElement.connectionManager.addPreviousElement(currentSelectedElement)
            } else if (kind === "next") {
                connectionsPanel.targetElement.connectionManager.addNextElement(currentSelectedElement)
            }
        }
    }


    WheelHandler {
        onWheel: (wheel)=> {
             if (wheel.modifiers & Qt.ControlModifier) {
                 console.log(wheel.angleDelta)
                 if (wheel.angleDelta.y > 0)
                    editorGrid.updateSize(editorGrid.mmSize + 1)
                 else if (editorGrid.mmSize > 1)
                     editorGrid.updateSize(editorGrid.mmSize - 1)
                 for (var i = 0; i < root.snapableTilesList.length; i++) {
                     if (root.snapableTilesList[i]) {
                         root.snapableTilesList[i].isSelected = false
                         root.snapableTilesList[i].snapToGridFromGrid()
                     }
                 }
             }
         }
    }

}
