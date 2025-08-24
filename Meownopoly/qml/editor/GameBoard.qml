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
    property int currentPlanDisplayed : 1
    
    // Propriétés pour la sélection par rectangle
    property bool isSelectionActive: false
    property point selectionStart: Qt.point(0, 0)
    property point selectionCurrent: Qt.point(0, 0)
    property bool isSelectingArea: false
    property int defaultCaseType: Case.CS_KibbleDispenser
    
    // Propriétés pour la taille des éléments créés
    property int currentElementWidth: 6
    property int currentElementHeight: 6

    color: isEditing ? "#B3B3D0D8" : "lightblue"
    enum TileType {
        Case,
        Personnage,
        Decoration
    }

    onIsEditingChanged:{
        console.log("Édition:", isEditing)
        if (!isEditing)
            for (var i = 0; i < snapableTilesList.length; i++) {
                if (snapableTilesList[i]) {
                    snapableTilesList[i].enabled = true
                    snapableTilesList[i].visible = true
                }
            }
    }

    onCurrentPlanDisplayedChanged: {
        if (isEditing){
            console.log("Changement de plan affiché:", currentPlanDisplayed)
            for (var i = 0; i < snapableTilesList.length; i++) {
                if (snapableTilesList[i]) {
                    var currentTile = snapableTilesList[i]
                    if (currentTile.z < currentPlanDisplayed) {
                        currentTile.enabled = false
                        currentTile.visible = false
                    }
                    else {
                        currentTile.enabled = true
                        currentTile.visible = true
                    }
                }
            }
        }
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        property alias isEdit : root.isEditing
        property alias currentPlan : root.currentPlanDisplayed
        property alias isSelectionActive : root.isSelectionActive


        mmSize: 15
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true

        onGridClicked:  function(position) {
            if (!isSelectionActive) {
                deselectAllTiles()
            }
        }
        onGridPressed : function(position) {
            if (!isEditing || !isSelectionActive) {
                // Comportement original: menu contextuel uniquement si pas en mode sélection
                contextMenu.clickGridCoord = position
                contextMenu.popup()
            }
            // Sinon, la sélection est gérée par selectionMouseArea
        }
    }
    
    // Rectangle de sélection
    Rectangle {
        id: selectionRect
        parent: workArea
        visible: false
        color: "#C7E8FF" // Bleu semi-transparent
        border.width: 2
        border.color: "#3498db"
        opacity: 0.7
        z: 100 // S'assurer qu'il est au-dessus des autres éléments
    }


    // Assurer que l'éditeur peut recevoir le focus pour les raccourcis clavier
    focus: true

    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid
        
        // MouseArea pour gérer la sélection par rectangle
        MouseArea {
            id: selectionMouseArea
            anchors.fill: parent
            enabled: isEditing && isSelectionActive
            hoverEnabled: true
            z: 99 // Juste en-dessous du rectangle de sélection
            preventStealing: true // Empêche le vol d'événements par d'autres MouseArea
            
            onPressed: {
                if (isEditing && isSelectionActive) {
                    // Vérifier si le clic est sur un élément existant
                    var clickedOnElement = false
                    for (var i = 0; i < snapableTilesList.length; i++) {
                        if (snapableTilesList[i]) {
                            var element = snapableTilesList[i]
                            var mousePos = mapToItem(element, mouse.x, mouse.y)
                            if (mousePos.x >= 0 && mousePos.x <= element.width && 
                                mousePos.y >= 0 && mousePos.y <= element.height) {
                                clickedOnElement = true
                                break
                            }
                        }
                    }
                    
                    if (!clickedOnElement) {
                        // Si le clic n'est pas sur un élément, commencer la sélection par rectangle
                        console.log("Début de la sélection par rectangle")
                        isSelectingArea = true
                        var gridPos = editorGrid.getGridPosition(mouse.x, mouse.y)
                        selectionStart = gridPos
                        selectionCurrent = gridPos
                        selectionRect.visible = true
                        updateSelectionRect()
                        mouse.accepted = true // Important pour éviter la propagation
                    } else {
                        // Si le clic est sur un élément, propager l'événement
                        console.log("Clic sur un élément existant, propagation de l'événement")
                        mouse.accepted = false
                    }
                }
            }
            
            onPositionChanged: {
                if (isSelectingArea) {
                    console.log("Mise à jour de la sélection")
                    // Mettre à jour la position courante
                    var gridPos = editorGrid.getGridPosition(mouse.x, mouse.y)
                    selectionCurrent = gridPos
                    updateSelectionRect()
                    mouse.accepted = true
                }
            }
            
            onReleased: {
                if (isSelectingArea) {
                    console.log("Finalisation de la sélection")
                    finishSelection()
                    mouse.accepted = true
                }
            }
            
            onCanceled: {
                console.log("Annulation de la sélection")
                cancelSelection()
            }
        }

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
                onElementPressed:  function(element) {
                    deselectAllTiles()
                    element.isSelected = true
                    currentSelectedElement = element

                }

            }
        }
    }

    // Le bouton de sélection est maintenant dans GridControlPanel

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
        showControlPanel: true
        showInfoPanel: true
        property alias isEdit : root.isEditing
        property alias currentWidth: root.currentElementWidth
        property alias currentHeight: root.currentElementHeight

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
                currentSelectedElement.changeToLayer(1)
                event.accepted = true
                break
            case Qt.Key_2:
                currentSelectedElement.changeToLayer(2)
                event.accepted = true
                break
            case Qt.Key_3:
                currentSelectedElement.changeToLayer(3)
                event.accepted = true
                break
            case Qt.Key_4:
                currentSelectedElement.changeToLayer(4)
                event.accepted = true
                break
            case Qt.Key_5:
                currentSelectedElement.changeToLayer(5)
                event.accepted = true
                break
            case Qt.Key_PageUp:
                // Monter d'un plan
                if (currentSelectedElement.z < 10) {
                    currentSelectedElement.changeToLayer(currentSelectedElement.z + 1)
                }
                event.accepted = true
                break
            case Qt.Key_PageDown:
                // Descendre d'un plan
                if (currentSelectedElement.z > 1) {
                    currentSelectedElement.changeToLayer(currentSelectedElement.z - 1)
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
    // Fonction pour mettre à jour l'apparence du rectangle de sélection
    function updateSelectionRect() {
        if (!isSelectingArea) return
        
        // Calculer les coordonnées et dimensions en pixels
        var startX = selectionStart.x * editorGrid.gridSize
        var startY = selectionStart.y * editorGrid.gridSize
        var currentX = selectionCurrent.x * editorGrid.gridSize
        var currentY = selectionCurrent.y * editorGrid.gridSize
        
        // Assurer que le rectangle est correctement positionné peu importe la direction du drag
        var x = Math.min(startX, currentX)
        var y = Math.min(startY, currentY)
        var width = Math.abs(currentX - startX)
        var height = Math.abs(currentY - startY)
        
        // Mise à jour du rectangle de sélection
        selectionRect.x = x
        selectionRect.y = y
        selectionRect.width = width
        selectionRect.height = height
    }
    
    // Fonction pour finaliser la sélection et créer une case
    function finishSelection() {
        if (!isSelectingArea) return
        
        // Normaliser les coordonnées pour avoir le coin supérieur gauche
        var startX = Math.min(selectionStart.x, selectionCurrent.x)
        var startY = Math.min(selectionStart.y, selectionCurrent.y)
        var width = Math.abs(selectionCurrent.x - selectionStart.x)
        var height = Math.abs(selectionCurrent.y - selectionStart.y)
        
        // Créer les cases aux dimensions calculées
        if (width >= 1 && height >= 1) {
            // Ajouter +1 car la sélection est inclusive (le point de fin est inclus)
            width = Math.max(1, width)
            height = Math.max(1, height)
            
            // Utiliser la nouvelle fonction pour remplir avec plusieurs éléments
            fillSelectionWithTiles(startX, startY, width, height)
        }
        
        // Réinitialiser l'état de sélection
        isSelectingArea = false
        selectionRect.visible = false
    }
    
    // Fonction pour annuler la sélection en cours
    function cancelSelection() {
        isSelectingArea = false
        selectionRect.visible = false
    }
    
    // Fonction pour créer une case à partir d'une sélection
    function createTileFromSelection(gridX, gridY, unitWidth, unitHeight) {
        console.log("Création d'une case à partir de la sélection:", gridX, gridY, unitWidth, unitHeight)
        
        var newTile = snapableCaseTile.createObject(workArea, {
            "gridRelativePositionX": gridX,
            "gridRelativePositionY": gridY,
            "unitSizeWidth": unitWidth,
            "unitSizeHeight": unitHeight,
            "caseData": Game.getNewCaseType(defaultCaseType),
            "z": currentPlanDisplayed
        })
        
        if (newTile) {
            snapableTilesList.push(newTile)
            nextTileId++
            
            // Désélectionner tout et sélectionner le nouveau tile
            deselectAllTiles()
            newTile.isSelected = true
            currentSelectedElement = newTile
            newTile.snapToGridFromGrid()
        }
        
        return newTile
    }
    
    function createNewTileAtPosition(caseType, gridX, gridY, isDecoration) {
        console.log("create tile at", gridX, gridY )
        var newTile
        switch (isDecoration){
        case GameBoard.TileType.Decoration:
            newTile = snapableDecoration.createObject(workArea, {
                                                          "gridRelativePositionX": gridX,
                                                          "gridRelativePositionY": gridY,
                                                          "z": currentPlanDisplayed
                                                      })
            break
        case GameBoard.TileType.Personnage:
            newTile = snapableCharacter.createObject(workArea, {
                                                         "gridRelativePositionX": gridX,
                                                         "gridRelativePositionY": gridY,
                                                         "playerData": Game.getNewPlayer(),
                                                         "z": currentPlanDisplayed
                                                     })
            break
        case GameBoard.TileType.Case:
            newTile = snapableCaseTile.createObject(workArea, {
                                                        "gridRelativePositionX": gridX,
                                                        "gridRelativePositionY": gridY,
                                                        "unitSizeWidth": currentElementWidth,
                                                        "unitSizeHeight": currentElementHeight,
                                                        "caseData": Game.getNewCaseType(caseType),
                                                        "z": currentPlanDisplayed
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
    
    // Fonction pour remplir une zone sélectionnée avec plusieurs éléments
    function fillSelectionWithTiles(startX, startY, width, height) {
        console.log("Remplissage de la zone sélectionnée:", startX, startY, width, height)
        console.log("Dimensions des éléments:", currentElementWidth, currentElementHeight)
        
        // Vérifier si les dimensions sont valides
        if (currentElementWidth <= 0 || currentElementHeight <= 0) {
            console.error("Dimensions d'élément invalides")
            return
        }
        
        // Calculer combien d'éléments peuvent tenir horizontalement et verticalement
        var tilesPlaced = 0
        var lastTile = null
        
        // Balayer de haut en bas, de gauche à droite
        for (var y = startY; y <= startY + height - currentElementHeight; y++) {
            for (var x = startX; x <= startX + width - currentElementWidth; x++) {
                // Vérifier si la position est libre
                var positionOccupied = false
                
                // Vérifier si cette position chevauche un élément existant
                for (var i = 0; i < snapableTilesList.length; i++) {
                    var tile = snapableTilesList[i]
                    if (!tile) continue
                    
                    // Calculer les limites de l'élément existant
                    var tileLeft = tile.gridRelativePositionX
                    var tileRight = tileLeft + tile.unitSizeWidth
                    var tileTop = tile.gridRelativePositionY
                    var tileBottom = tileTop + tile.unitSizeHeight
                    
                    // Calculer les limites du nouvel élément
                    var newTileLeft = x
                    var newTileRight = x + currentElementWidth
                    var newTileTop = y
                    var newTileBottom = y + currentElementHeight
                    
                    // Vérifier s'il y a chevauchement
                    if (!(newTileRight <= tileLeft || newTileLeft >= tileRight ||
                          newTileBottom <= tileTop || newTileTop >= tileBottom)) {
                        positionOccupied = true
                        break
                    }
                }
                
                // Si la position est libre, créer un élément
                if (!positionOccupied) {
                    lastTile = createNewTileAtPosition(defaultCaseType, x, y, GameBoard.TileType.Case)
                    tilesPlaced++;
                    
                    // Avancer horizontalement de la taille de l'élément
                    x += currentElementWidth - 1; // -1 car la boucle incrémente x
                }
            }
        }
        
        console.log("Éléments placés:", tilesPlaced)
        
        // Si au moins un élément a été placé, le dernier reste sélectionné
        if (tilesPlaced > 0 && lastTile) {
            deselectAllTiles()
            lastTile.isSelected = true
            currentSelectedElement = lastTile
        }
    }
}
