import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: snapableElement
    
    // Propriétés configurables
    // Connexion au GridManager du parent (Editor)
    required property GridManager gridManager
    property bool isDraggable: true
    property bool isResizable: true
    property bool autoSnap: true
    property color elementColor: "lightgray"
    property color borderColor: "gray"
    property int borderWidth: 1
    property real elementOpacity: 1.0
    property int minWidth: 40
    property int minHeight: 40

    
    // NOUVEAUTÉ: Propriétés pour l'optimisation anti-scintillement
    property bool smoothResize: true
    property int updateThrottleMs: 16  // ~60fps max pour éviter la surcharge
    property bool useVisualFeedback: true
    property int snapTolerance: 3  // pixels de tolérance avant snap
    
    // Propriétés d'état
    property bool isDragging: false
    property bool isResizing: false
    property bool isSelected: false
    
    // NOUVEAUTÉ: Propriétés pour le feedback visuel pendant redimensionnement
    property bool showResizePreview: false
    property rect previewRect: Qt.rect(0, 0, 0, 0)

    property int unitSizeWidth: 3
    onUnitSizeWidthChanged: {
        console.log("================unit size width updated " + unitSizeWidth + " ================" )
    }

    property int unitSizeHeight: 3


    property int gridRelativePositionX: 3
    property int gridRelativePositionY: 3
    
    // Positions calculées à partir des coordonnées relatives
    x: gridRelativePositionX * gridManager.gridSize
    y: gridRelativePositionY * gridManager.gridSize

    width:  gridManager.gridSize * unitSizeWidth
    height:  gridManager.gridSize * unitSizeHeight
    
    // Mettre à jour les positions relatives quand les positions absolues changent (drag)
    property bool updatingFromRelative: false

    // Signaux
    signal elementClicked(var element)
    signal elementPressed(var element)
    signal elementReleased(var element)
    signal elementMoved(var element, real newX, real newY)
    signal elementResized(var element, real newWidth, real newHeight)
    signal snapCompleted(var element)
    
    // Apparence par défaut avec optimisation anti-scintillement
    color: elementColor
    border.color: isSelected ? Qt.lighter(borderColor, 1.5) : borderColor
    border.width: isSelected ? borderWidth + 1 : borderWidth
    opacity: elementOpacity
    
    // Effet de survol avec transition optimisée
    scale: isDragging ? 1.05 : 1.0
    
    // OPTIMISATION: Réduire la durée des animations pour moins de charge CPU
    Behavior on scale {
        NumberAnimation { duration: smoothResize ? 100 : 0 }
    }
    
    Behavior on border.width {
        NumberAnimation { duration: smoothResize ? 80 : 0 }
    }

Component.onCompleted: snapToGrid()
    
    // Zone de drag & drop
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: isDraggable && !isResizing
        
        drag.target: isDraggable ? parent : null
        drag.axis: Drag.XAndYAxis

        z: 50  // Au-dessus du contenu mais sous les poignées
        
        onPressed: {

            isDragging = true
            isSelected = true
            elementPressed(snapableElement)
        }
        
        onReleased: {
            isDragging = false
            
            // Mettre à jour les positions relatives après le drag
            updateRelativePosition()
            
            // Auto-snap si activé et gridManager disponible
            if (autoSnap && gridManager && gridManager.snapToGrid) {
                snapToGrid()
            }
            
            elementReleased(snapableElement)
            elementMoved(snapableElement, snapableElement.x, snapableElement.y)
        }
        
        onClicked: {
            isSelected = true
            elementClicked(snapableElement)
        }
        
        onPositionChanged: {
            if (drag.active && smoothResize) {
            }
        }
    }
    
    // Poignées de redimensionnement
    Item {
        id: resizeHandles
        anchors.fill: parent
        visible: isSelected && isResizable
        z: 100  // Assurer que les poignées sont au-dessus de tout
        
        // Propriétés communes pour les poignées
        property int handleSize: 10
        property color handleColor: "#2196F3"
        property color handleBorderColor: "white"
        
        // Poignées aux 8 positions (coins + milieux des côtés)...
        ResizeHandle {
            id: topLeftHandle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: -parent.handleSize / 2
            direction: "nw"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: topRightHandle
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: -parent.handleSize / 2
            direction: "ne"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: bottomLeftHandle
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: -parent.handleSize / 2
            direction: "sw"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: bottomRightHandle
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: -parent.handleSize / 2
            direction: "se"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: topHandle
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: -parent.handleSize / 2
            direction: "n"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: bottomHandle
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: -parent.handleSize / 2
            direction: "s"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: leftHandle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: -parent.handleSize / 2
            direction: "w"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
        
        ResizeHandle {
            id: rightHandle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: -parent.handleSize / 2
            direction: "e"
            gridManager: snapableElement.gridManager
            targetElement: snapableElement
        }
    }
    
    // Fonctions utilitaires améliorées
    function updateRelativePosition() {
        if (!gridManager || gridManager.gridSize === 0) return
        
        updatingFromRelative = true
        
        // Calculer les nouvelles positions relatives basées sur les positions absolues
        gridRelativePositionX = Math.round(x / gridManager.gridSize)
        gridRelativePositionY = Math.round(y / gridManager.gridSize)

        
        updatingFromRelative = false
    }

    function snapToGrid() {
        if (!gridManager || !gridManager.snapToGrid) return

        updatingFromRelative = true

        // Calculer les positions snappées en unités de grille
        var snappedGridX = Math.round(x / gridManager.gridSize)
        var snappedGridY = Math.round(y / gridManager.gridSize)

        // Mettre à jour les positions relatives (qui vont automatiquement mettre à jour x et y)
        gridRelativePositionX = snappedGridX
        gridRelativePositionY = snappedGridY


        updatingFromRelative = false
        gridManager.snapElement2(snapableElement)
        snapCompleted(snapableElement)
    }

    function snapToGridFromGrid() {
        if (!gridManager || !gridManager.snapToGrid) return

        updatingFromRelative = false
        gridManager.snapElement2(snapableElement)
        snapCompleted(snapableElement)
    }

    function select() {
        isSelected = true
    }
    
    function deselect() {
        isSelected = false
    }
    
    function toggleSelection() {
        isSelected = !isSelected
    }

    
    // Composant pour les poignées de redimensionnement (VERSION OPTIMISÉE)
    component ResizeHandle: Rectangle {
        id: handle
        
        required property string direction
        required property GridManager gridManager
        required property var targetElement
        
        width: 10
        height: 10
        color: "#2196F3"
        border.color: "white"
        border.width: 2
        radius: 2
        z: 20
        
        // Curseur selon la direction
        property string cursorShape: {
            switch(direction) {
                case "nw": case "se": return "SizeFDiagCursor"
                case "ne": case "sw": return "SizeBDiagCursor"
                case "n": case "s": return "SizeVerCursor"
                case "e": case "w": return "SizeHorCursor"
                default: return "ArrowCursor"
            }
        }
        
        // Variables pour le redimensionnement
        property real startMouseX: 0
        property real startMouseY: 0
        property real startWidth: 0
        property real startHeight: 0
        property real startElementX: 0
        property real startElementY: 0
        property real startGlobalMouseX: 0
        property real startGlobalMouseY: 0

        MouseArea {
            id: handleMouseArea
            anchors.fill: parent
            cursorShape: parent.cursorShape
            hoverEnabled: true
            
            onPressed: {
                targetElement.isResizing = true
                
                startMouseX = mouseX
                startMouseY = mouseY
                startWidth = targetElement.width
                startHeight = targetElement.height
                startElementX = targetElement.x
                startElementY = targetElement.y
                
                // Capturer la position globale initiale de la souris
                var globalPos = snapableElement.mapToItem(gridManager, handle.x + mouseX, handle.y + mouseY)
                startGlobalMouseX = globalPos.x
                startGlobalMouseY = globalPos.y
                
                // Activer le mode visual de la grille
                if (gridManager && gridManager.enterResizeMode) {
                    gridManager.enterResizeMode()
                }
            }
            
            onReleased: {
                targetElement.isResizing = false
                
                // Mettre à jour les positions relatives après redimensionnement
                targetElement.updateRelativePosition()
                
                // Désactiver le mode visual de la grille
                if (gridManager && gridManager.exitResizeMode) {
                    gridManager.exitResizeMode()
                }
            }
            
            onPositionChanged: {
                if (pressed) {
                    // Calculer la position globale actuelle de la souris
                    var currentGlobalPos = snapableElement.mapToItem(gridManager, handle.x + mouseX, handle.y + mouseY)
                    
                    // Calculer le delta en pixels depuis le début
                    var globalDeltaX = currentGlobalPos.x - startGlobalMouseX
                    var globalDeltaY = currentGlobalPos.y - startGlobalMouseY
                    
                    // Convertir en unités de grille
                    var deltaUnitsX = Math.round(globalDeltaX / snapableElement.gridManager.gridSize)
                    var deltaUnitsY = Math.round(globalDeltaY / snapableElement.gridManager.gridSize)
                    
                    switch (direction) {
                        case "e":
                        {
                            var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                            var newUnitWidth = startUnitWidth + deltaUnitsX
                            if (newUnitWidth >= 1) {
                                targetElement.unitSizeWidth = newUnitWidth
                            }
                            break
                        }
                        case "s":
                        {
                            var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                            var newUnitHeight = startUnitHeight + deltaUnitsY
                            if (newUnitHeight >= 1) {
                                targetElement.unitSizeHeight = newUnitHeight
                            }
                            break
                        }
                        case "w":
                        {
                            // Pour redimensionner vers la gauche :
                            // 1. Calculer les unités de départ (référence fixe)
                            var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                            
                            // 2. Calculer la nouvelle largeur basée sur le déplacement depuis le début
                            var newUnitWidth = startUnitWidth - deltaUnitsX
                            
                            
                            // S'assurer qu'on a au minimum 1 unité de largeur
                            if (newUnitWidth >= 1) {
                                // 3. Déplacer l'élément vers la gauche et ajuster la largeur
                                targetElement.x = startElementX + (deltaUnitsX * gridManager.gridSize)
                                targetElement.unitSizeWidth = newUnitWidth
                            }
                            break
                        }
                        case "n":
                        {
                            var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                            var newUnitHeight = startUnitHeight - deltaUnitsY
                            if (newUnitHeight >= 1) {
                                targetElement.y = startElementY + (deltaUnitsY * gridManager.gridSize)
                                targetElement.unitSizeHeight = newUnitHeight
                            }
                            break;
                        }
                        case "nw": // Nord-Ouest (coin haut-gauche)
                        {
                            var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                            var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                            var newUnitWidth = startUnitWidth - deltaUnitsX
                            var newUnitHeight = startUnitHeight - deltaUnitsY
                            
                            
                            if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                                // Déplacer en x et y, changer largeur et hauteur
                                targetElement.x = startElementX + (deltaUnitsX * gridManager.gridSize)
                                targetElement.y = startElementY + (deltaUnitsY * gridManager.gridSize)
                                targetElement.unitSizeWidth = newUnitWidth
                                targetElement.unitSizeHeight = newUnitHeight
                            }
                            break;
                        }
                        case "ne": // Nord-Est (coin haut-droite)
                        {
                            var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                            var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                            var newUnitWidth = startUnitWidth + deltaUnitsX
                            var newUnitHeight = startUnitHeight - deltaUnitsY
                            
                            if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                                // Déplacer seulement en y, changer largeur et hauteur
                                targetElement.y = startElementY + (deltaUnitsY * gridManager.gridSize)
                                targetElement.unitSizeWidth = newUnitWidth
                                targetElement.unitSizeHeight = newUnitHeight
                            }
                            break;
                        }
                        case "sw": // Sud-Ouest (coin bas-gauche)
                        {
                            var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                            var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                            var newUnitWidth = startUnitWidth - deltaUnitsX
                            var newUnitHeight = startUnitHeight + deltaUnitsY
                            
                            if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                                // Déplacer seulement en x, changer largeur et hauteur
                                targetElement.x = startElementX + (deltaUnitsX * gridManager.gridSize)
                                targetElement.unitSizeWidth = newUnitWidth
                                targetElement.unitSizeHeight = newUnitHeight
                            }
                            break;
                        }
                        case "se": // Sud-Est (coin bas-droite)
                        {
                            var startUnitWidth = Math.round(startWidth / gridManager.gridSize)
                            var startUnitHeight = Math.round(startHeight / gridManager.gridSize)
                            var newUnitWidth = startUnitWidth + deltaUnitsX
                            var newUnitHeight = startUnitHeight + deltaUnitsY
                            
                            if (newUnitWidth >= 1 && newUnitHeight >= 1) {
                                // Pas de déplacement, juste changer largeur et hauteur
                                targetElement.unitSizeWidth = newUnitWidth
                                targetElement.unitSizeHeight = newUnitHeight
                            }
                            break;
                        }
                    }


                }
            }
        }
        
        // Effet de survol optimisé
        states: State {
            name: "hovered"
            when: handleMouseArea.containsMouse && !targetElement.isResizing
            PropertyChanges { 
                target: handle
                scale: 1.2
                color: Qt.lighter("#2196F3", 1.2) 
            }
        }
        
        transitions: Transition {
            NumberAnimation { 
                properties: "scale,color"
                duration: targetElement.smoothResize ? 120 : 0
                easing.type: Easing.OutQuad
            }
        }
    }
} 
