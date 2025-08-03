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
            // print redRect location in grid coord
            var redRectLocation = editorGrid.mapFromGlobal(redRect.x, redRect.y)
            console.log("redRect location in grid coord: " , redRectLocation, editorGrid.getGridPosition(redRectLocation.x, redRectLocation.y))
            // print redRect location in global coord
            var redRectLocationGlobal = redRect.mapToItem(editorGrid, 0,0)
            console.log("redRect.mapToItem(editorGrid, 0,0) :  " , redRectLocationGlobal, editorGrid.getGridPosition(redRectLocationGlobal.x, redRectLocationGlobal.y))
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
    
    // Gestionnaire de raccourcis clavier
    Keys.onPressed: function(event) {
        if (currentSelectedElement) {
            switch(event.key) {
                case Qt.Key_1:
                    currentSelectedElement.changeToLayer(currentSelectedElement.zLayers.background)
                    event.accepted = true
                    break
                case Qt.Key_2:
                    currentSelectedElement.changeToLayer(currentSelectedElement.zLayers.middle)
                    event.accepted = true
                    break
                case Qt.Key_3:
                    currentSelectedElement.changeToLayer(currentSelectedElement.zLayers.foreground)
                    event.accepted = true
                    break
                case Qt.Key_PageUp:
                    // Monter d'un plan
                    if (currentSelectedElement.zLayer < 2) {
                        currentSelectedElement.changeToLayer(currentSelectedElement.zLayer + 1)
                    }
                    event.accepted = true
                    break
                case Qt.Key_PageDown:
                    // Descendre d'un plan
                    if (currentSelectedElement.zLayer > 0) {
                        currentSelectedElement.changeToLayer(currentSelectedElement.zLayer - 1)
                    }
                    event.accepted = true
                    break
            }
        }
    }
    
    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true
    
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
                
                // Gestion de la suppression
                onElementDeleted: function(element) {
                    deleteElement(element)
                }
                
                // Gestion de la configuration
                onElementConfigurationRequested: function(element) {
                    console.log("Configuration demandée pour:", element)
                    if (element.caseData) {
                        caseConfigPanel.openConfiguration(element.caseData)
                        editorGrid.moveToConfigElement(element)

                    }
                }
            }
        }
        // Composant dynamique pour créer des SnapableDecoration
        Component {
            id: snapableDecoration
            SnapableDecoration {
                gridManager: editorGrid

                // Gestion de la sélection
                onElementClicked: function(element) {
                    // Désélectionner tous les autres éléments
                    deselectAllTiles()
                    // Sélectionner l'élément cliqué
                    element.isSelected = true
                    currentSelectedElement = element
                }
                
                // Gestion de la suppression
                onElementDeleted: function(element) {
                    deleteElement(element)
                }
                
                // Gestion de la configuration
                onElementConfigurationRequested: function(element) {
                    console.log("Configuration demandée pour:", element)
                    if (element.caseData) {
                        caseConfigPanel.openConfiguration(element.caseData)
                    }
                }
            }
        }
    }
    
    // Menu contextuel pour la création d'éléments
    Menu {
        id: contextMenu

        property var clickGridCoord: Qt.point(0, 0)
        
        MenuItem {
            text: "Créer une Case"
            onTriggered: {
                console.log(contextMenu.clickGridCoord)
                createNewTileAtPosition(Case.CS_RestArea, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, 0)
            }
        }
        
        MenuItem {
            text: "Créer un élément"
            onTriggered: {
                createNewTileAtPosition(Case.CS_Unknow, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, 1)
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
    
    // Fonction pour supprimer un élément
    function deleteElement(element) {
        console.log("Suppression de l'élément:", element)
        
        // Trouver l'index de l'élément dans la liste
        var index = -1
        for (var i = 0; i < snapableTilesList.length; i++) {
            if (snapableTilesList[i] === element) {
                index = i
                break
            }
        }
        
        if (index !== -1) {
            // Supprimer l'élément de la liste
            snapableTilesList.splice(index, 1)
            console.log("Élément supprimé de la liste à l'index:", index)
            
            // Si c'était l'élément sélectionné, le désélectionner
            if (currentSelectedElement === element) {
                currentSelectedElement = null
            }
            
            // Détruire l'objet QML
            element.destroy()
            console.log("Objet QML détruit")
        } else {
            console.log("Erreur: Élément non trouvé dans la liste")
        }
    }

    // Fonction pour créer un nouveau SnapableCaseTile à une position spécifique
    function createNewTileAtPosition(caseType, gridX, gridY, isDecoration) {
        console.log("create tile at", gridX, gridY )
        var newTile
        if (isDecoration) {
            newTile = snapableDecoration.createObject(workArea, {
                "gridRelativePositionX": gridX,
                "gridRelativePositionY": gridY,
            })
        }
        else {
            newTile = snapableCaseTileComponent.createObject(workArea, {
                "gridRelativePositionX": gridX,
                "gridRelativePositionY": gridY,
                "unitSizeWidth": 6,
                "unitSizeHeight": 6,
                "caseData": Game.getNewCaseType(caseType)
            })
        }

        if (newTile) {
            snapableTilesList.push(newTile)
            nextTileId++
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
            newTile.isSelected = true
            currentSelectedElement = newTile
            newTile.snapToGridFromGrid()
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
    
    Rectangle{
        id: redRect
        color: "red"
        width: 10
        height: 10
        x:960
        y:360
    }

    // Panneau de configuration des cases
    CaseConfigurationPanel {
        id: caseConfigPanel
        height: parent.height
        width: parent.width/2

        onIsVisibleChanged: {
            console.log("=============")
            console.log(root.width, root.height)
            console.log("raw : ", parent.width * 0.75, parent.height/2)
            console.log("from global : ", editorGrid.mapFromGlobal(parent.width * 0.75, parent.height/2))
            console.log("to global: ", editorGrid.mapToGlobal(parent.width * 0.75, parent.height/2))
            console.log("from item workArea : ", editorGrid.mapFromItem(workArea, parent.width * 0.75, parent.height/2))
            console.log("to item workArea : ", editorGrid.mapToItem(workArea, parent.width * 0.75, parent.height/2))
            console.log("=============")
        }
        
        onConfigurationClosed: {
            console.log("Panneau de configuration fermé")
        }
        
        onConfigurationApplied: function(caseData) {
            console.log("Configuration appliquée pour la case:", caseData.name)
            // La case est déjà mise à jour via les bindings
        }
    }

}
