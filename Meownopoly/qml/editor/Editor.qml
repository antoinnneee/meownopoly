import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
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

Rectangle {
    id: root

    color: "lightblue"
    anchors.fill: parent
    border.width: 0
    
    // Liste pour stocker tous les SnapableCaseTile créés
    property list<SnapableElement> snapableTilesList


    property int nextTileId: 0
    property var currentSelectedElement: null
    
    // Grille de l'éditeur
    GridManager {
        id: editorGrid

        mmSize: 20
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        
        // Test de l'animation au démarrage
        Component.onCompleted: {
        }
    }

    WheelHandler {
        onWheel: (wheel)=> {
            if (wheel.modifiers & Qt.ControlModifier) {
                //console.log(wheel.angleDelta)
                if (wheel.angleDelta.y > 0)
                    editorGrid.updateSize(editorGrid.mmSize + 1)
                else if (editorGrid.mmSize > 1)
                    editorGrid.updateSize(editorGrid.mmSize - 1)
                 for (var i = 0; i < snapableTilesList.length; i++) {
                     if (snapableTilesList[i]) {
                         snapableTilesList[i].isSelected = false
                         snapableTilesList[i].snapToGridFromGrid()
                     }
                 }
            }
        }
    }
    
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid

        // Composant dynamique pour créer des SnapableCaseTile
        Component {
            id: snapableCaseTileComponent
            SnapableCaseTile {
                gridManager: editorGrid
                
                // Gestion de la sélection
                onElementClicked: function(element) {
                    // Désélectionner tous les autres éléments
                    deselectAllTiles()
                    // Sélectionner l'élément cliqué
                    element.isSelected = true
                    currentSelectedElement = element
                }
            }
        }
    }
    
    // Fonction pour désélectionner tous les tiles
    function deselectAllTiles() {
        // Désélectionner tous les tiles dans la liste
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i]) {
                snapableTilesList[i].isSelected = false
            }
        }
        currentSelectedElement = null
    }
    
    // Fonction pour créer un nouveau SnapableCaseTile
    function createNewTile(caseType) {
        var newTile = snapableCaseTileComponent.createObject(workArea, {
            "gridRelativePositionX": 5 + (nextTileId % 32) * 4,
            "gridRelativePositionY": 5 + Math.floor(nextTileId / 32) * 4,
            "unitSizeWidth": 3,
            "unitSizeHeight": 3,
            "caseData": Game.getNewCaseType(caseType)
        })
        
        if (newTile) {
            snapableTilesList.push(newTile)
            nextTileId++
            console.log("Nouveau tile créé:", newTile.caseData.name, "Type:", caseType)
            
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
            newTile.isSelected = true
            currentSelectedElement = newTile
            
            // Déclencher l'animation de feedback sur le panneau de création
            creationPanel.triggerCreateFeedback()
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
    
    // Panneau de création de nouveaux tiles (nouveau composant)
    CreationPanel {
        id: creationPanel
        
        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }
        
        snapableTilesList: root.snapableTilesList
        
        onCreateTileRequested: function(caseType) {
            createNewTile(caseType)

        }
    }
    
    // Panneau de contrôle de la grille (composant séparé)

    GridControlPanel {
        id: gridControls
        anchors.fill: parent
        gridManager: editorGrid
        showControlPanel: false
        showInfoPanel: true
    }

}
