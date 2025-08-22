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
    border.width: 0

    // Liste pour stocker tous les SnapableCaseTile créés
    property list<SnapableElement> snapableTilesList
    property int nextTileId: 0
    property var currentSelectedElement: null

    property bool isEditing : false
    property var selectionStartPoint: null
    property var selectionRect: null
    property bool isSelecting: false
    
    color: isEditing ? "#B3B3D0D8" : "lightblue"
    onIsEditingChanged: console.log("Édition:", isEditing)
    enum TileType {
        Case,
        Personnage,
        Decoration
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        property alias isEdit : root.isEditing
        mmSize: 15
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true

        // Test de l'animation au démarrage
        Component.onCompleted: {
        }
        // Remplacer onGridPressed par un MouseArea directement sur editorGrid
        MouseArea {
            id: gridMouseArea
            anchors.fill: parent
            hoverEnabled: true
            
            onPressed: function(mouse) {
                if (isEditing) {
                    // Supprimer tout rectangle de sélection précédent
                    if (selectionRect) {
                        selectionRect.destroy();
                        selectionRect = null;
                    }
                    
                    // Convertir la position du clic en position de grille
                    var gridPos = editorGrid.getGridPosition(mouse.x, mouse.y);
                    
                    // Enregistrer la position initiale de la sélection
                    selectionStartPoint = Qt.point(mouse.x, mouse.y);
                    
                    // Créer un nouveau rectangle de sélection
                    selectionRect = selectionRectComponent.createObject(workArea, {
                        x: selectionStartPoint.x,
                        y: selectionStartPoint.y,
                        width: 0,
                        height: 0
                    });
                    
                    // Activer le suivi de la souris pour ajuster la taille du rectangle
                    isSelecting = true;
                } else {
                    // Convertir la position du clic en position de grille
                    var gridPos = editorGrid.getGridPosition(mouse.x, mouse.y);
                    
                    // Stocker la position du clic pour créer l'élément au bon endroit
                    contextMenu.clickGridCoord = gridPos;
                    contextMenu.popup();
                }
            }
            
            onPositionChanged: function(mouse) {
                if (isSelecting && selectionRect) {
                    var currentX = mouse.x;
                    var currentY = mouse.y;
                    
                    // Calculer les dimensions du rectangle de sélection
                    var width = currentX - selectionStartPoint.x;
                    var height = currentY - selectionStartPoint.y;
                    
                    // Gérer les sélections dans toutes les directions
                    if (width < 0) {
                        selectionRect.x = selectionStartPoint.x + width;
                        selectionRect.width = -width;
                    } else {
                        selectionRect.width = width;
                    }
                    
                    if (height < 0) {
                        selectionRect.y = selectionStartPoint.y + height;
                        selectionRect.height = -height;
                    } else {
                        selectionRect.height = height;
                    }
                }
            }
            
            onReleased: function(mouse) {
                if (isSelecting && selectionRect) {
                    // Sélectionner tous les éléments qui se trouvent dans le rectangle
                    selectElementsInRectangle(selectionRect);
                    isSelecting = false;
                } else if (!isSelecting) {
                    // Si c'était un simple clic (pas de sélection), désélectionner tout
                    deselectAllTiles();
                }
            }
            
            // Autoriser la propagation des évènements au GridManager en-dessous
            propagateComposedEvents: true
        }
        onGridClicked:  function(position) {
            if (!isSelecting) {
                deselectAllTiles();
            }
        }
    }


    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true

    // Composant pour le rectangle de sélection
    Component {
        id: selectionRectComponent
        Rectangle {
            color: "#3089CFFA"
            border.color: "#0070BA"
            border.width: 1
            opacity: 0.5
            z: 1000 // S'assurer qu'il est au-dessus des autres éléments
        }
    }

    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid
        
        // Note: Le MouseArea de sélection est désormais géré directement par le GridManager

        Component {
            id: snapableCaseTile
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
                    deleteElementsConnections(element)
                    deleteElement(element)
                }

                // Gestion de la configuration
                onElementConfigurationRequested: function(element) {
                    console.log("Configuration demandée pour:", element)
                    if (element) {
                        caseConfigPanel.openConfiguration(element)
                        editorGrid.moveToConfigElement(element)

                    }
                }

                onElementConnectionsConfigurationRequested: function(element) {
                    if (element) {
                        connectionsPanel.targetElement = element
                        connectionsPanel.isVisible = true
                        editorGrid.moveToConfigElement(element)
                    }
                }
                onElementPressed: function(element) {
                    deselectAllTiles()
                    element.isSelected = true
                    currentSelectedElement = element
                }
            }
        }
        // Composant dynamique pour créer des SnapableCharacter
        Component {
            id: snapableCharacter
            SnapableCharacter {
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
                    deleteElementsConnections(element)
                    element.connectionManager.deleteLinkedConnection()
                    deleteElement(element)
                    rebuildConnectionSegments()
                }

                // Gestion de la configuration
                onElementConfigurationRequested: function(element) {
                    console.log("Configuration demandée pour:", element)
                    if (element.caseData) {
                        caseConfigPanel.openConfiguration(element)
                    }
                }

                onElementConnectionsConfigurationRequested: function(element) {
                    if (element) {
                        connectionsPanel.targetElement = element
                        connectionsPanel.isVisible = true
                        editorGrid.moveToConfigElement(element)
                    }
                }
                onElementPressed: {
                    deselectAllTiles()
                    element.isSelected = true
                    currentSelectedElement = element

                }

            }
        }
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
                    deleteElementsConnections(element)
                    element.connectionManager.deleteLinkedConnection()
                    deleteElement(element)
                    rebuildConnectionSegments()
                }

                // Gestion de la configuration
                onElementConfigurationRequested: function(element) {
                    console.log("Configuration demandée pour:", element)
                    if (element.caseData) {
                        caseConfigPanel.openConfiguration(element)
                    }
                }

                onElementConnectionsConfigurationRequested: function(element) {
                    if (element) {
                        connectionsPanel.targetElement = element
                        connectionsPanel.isVisible = true
                        editorGrid.moveToConfigElement(element)
                    }
                }
                onElementPressed: {
                    deselectAllTiles()
                    element.isSelected = true
                    currentSelectedElement = element

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
                createNewTileAtPosition(Case.CS_KibbleDispenser, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, GameBoard.TileType.Case)
            }
        }

        MenuItem {
            text: "Créer un Personnage"
            onTriggered: {
                createNewTileAtPosition(Case.CS_Unknow, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, GameBoard.TileType.Personnage)
            }
        }

        MenuItem {
            text: "Créer un Élément"
            onTriggered: {
                createNewTileAtPosition(Case.CS_Unknow, contextMenu.clickGridCoord.x, contextMenu.clickGridCoord.y, GameBoard.TileType.Decoration)
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
        property alias isEdit : root.isEditing
    }


    // Panneau de configuration des cases
    CaseConfigurationPanel {
        id: caseConfigPanel
        height: parent.height
        width: parent.width/2

        onIsVisibleChanged: {
        }

        onConfigurationClosed: {
            console.log("Panneau de configuration fermé")
        }

        onConfigurationApplied: function(caseData) {
            console.log("Configuration appliquée pour la case:", caseData.name)
            // La case est déjà mise à jour via les bindings
        }
        onRequestChangeType: function(newType)  {
            var newTile = createNewTileAtPosition(newType, caseConfigPanel.targetSnapableCase.gridRelativePositionX, caseConfigPanel.targetSnapableCase.gridRelativePositionY, 0)
            newTile.unitSizeWidth = caseConfigPanel.targetSnapableCase.unitSizeWidth
            newTile.unitSizeHeight = caseConfigPanel.targetSnapableCase.unitSizeHeight


            for (var i = 0; i < caseConfigPanel.targetSnapableCase.connectionManager.previousElements.length; i++) {
                var prevEl = caseConfigPanel.targetSnapableCase.connectionManager.previousElements[i]
                if (prevEl) {
                    prevEl.connectionManager.addNextElement(newTile)
                }
            }
            for (var i = 0; i < caseConfigPanel.targetSnapableCase.connectionManager.nextElements.length; i++) {
                var nextEl = caseConfigPanel.targetSnapableCase.connectionManager.nextElements[i]
                if (nextEl) {
                    nextEl.connectionManager.addPreviousElement(newTile)
                }
            }


            newTile.caseData.name = caseConfigPanel.targetSnapableCase.caseData.name


            caseConfigPanel.targetSnapableCase.elementDeleted(caseConfigPanel.targetSnapableCase)
            caseConfigPanel.targetSnapableCase.connectionManager.deleteLinkedConnection()

            newTile.isSelected = true
            newTile.elementConfigurationRequested(newTile)

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
                         // les chemins sont liés aux Items; pas besoin de rebuild ici
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

    function deleteElementsConnections(element) {
        var nexts = element.connectionManager.nextElements || []
        // itere sur les segments de connexion element->next
        for (var j = 0; j < nexts.length; j++) {
            var nextEl = nexts[j]
            // itere sur les segments de connexion nextEl->element
            var prevs = nextEl.connectionManager.previousElements || []
            for (var k = 0; k < prevs.length; k++) {
                var prevEl = prevs[k]
                if (prevEl === element) {
                    nextEl.connectionManager.removePreviousElement(element)
                }
            }
        }
        // itere sur les segments de connexion element->prev
        var prevs = element.connectionManager.previousElements || []
        for (var j = 0; j < prevs.length; j++) {
            var prevEl = prevs[j]
            // itere sur les segments de connexion prevEl->element
            var nexts = prevEl.connectionManager.nextElements || []
            for (var k = 0; k < nexts.length; k++) {
                var nextEl = nexts[k]
                if (nextEl === element) {
                    prevEl.connectionManager.removeNextElement(element)
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
    
    // Fonction pour sélectionner les éléments dans un rectangle
    function selectElementsInRectangle(rect) {
        // Désélectionner d'abord tous les éléments
        deselectAllTiles();
        
        // Pour chaque élément dans la liste
        var selectedElements = [];
        for (var i = 0; i < snapableTilesList.length; i++) {
            var element = snapableTilesList[i];
            if (!element) continue;
            
            // Vérifier si l'élément est à l'intérieur du rectangle de sélection
            var elementLeft = element.x;
            var elementRight = element.x + element.width;
            var elementTop = element.y;
            var elementBottom = element.y + element.height;
            
            if (elementRight >= rect.x && elementLeft <= rect.x + rect.width &&
                elementBottom >= rect.y && elementTop <= rect.y + rect.height) {
                // L'élément est dans la sélection
                element.isSelected = true;
                selectedElements.push(element);
            }
        }
        
        // Si un seul élément est sélectionné, le définir comme élément courant
        if (selectedElements.length === 1) {
            currentSelectedElement = selectedElements[0];
        }
        
        // Supprimer le rectangle de sélection
        if (rect) {
            rect.destroy();
            selectionRect = null;
        }
        
        console.log("Éléments sélectionnés:", selectedElements.length);
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

            // Si c'était l'élément sélectionné, le désélectionner
            if (currentSelectedElement === element) {
                currentSelectedElement = null
            }

            // Détruire l'objet QML
            element.destroy()
        } else {
            console.log("Erreur: Élément non trouvé dans la liste")
        }
    }

    // Fonction pour créer un nouveau SnapableCaseTile à une position spécifique
    function createNewTileAtPosition(caseType, gridX, gridY, isDecoration) {
        console.log("create tile at", gridX, gridY )
        var newTile
        switch (isDecoration){
        case GameBoard.TileType.Decoration:
            newTile = snapableDecoration.createObject(workArea, {
                                                          "gridRelativePositionX": gridX,
                                                          "gridRelativePositionY": gridY,
                                                      })

            break
        case GameBoard.TileType.Personnage:
            newTile = snapableCharacter.createObject(workArea, {
                                                         "gridRelativePositionX": gridX,
                                                         "gridRelativePositionY": gridY,
                                                         "playerData": Game.getNewPlayer()
                                                     })
            break
        case GameBoard.TileType.Case:
            newTile = snapableCaseTile.createObject(workArea, {
                                                        "gridRelativePositionX": gridX,
                                                        "gridRelativePositionY": gridY,
                                                        "unitSizeWidth": 6,
                                                        "unitSizeHeight": 6,
                                                        "caseData": Game.getNewCaseType(caseType)
                                                    })
            break

        default:
            break
        }
        if (newTile) {
            snapableTilesList.push(newTile)
            nextTileId++
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
            newTile.isSelected = true
            currentSelectedElement = newTile
            newTile.snapToGridFromGrid()
            //rebuildConnectionSegments()
        }
        return newTile
    }

}
