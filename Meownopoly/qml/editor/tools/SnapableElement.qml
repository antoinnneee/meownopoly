import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: snapableElement
    
    // Propriétés configurables
    property var gridManager: null
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
    
    // NOUVEAUTÉ: Timer pour throttler les mises à jour
    Timer {
        id: updateThrottleTimer
        interval: updateThrottleMs
        running: false
        repeat: false
        
        property var pendingUpdate: null
        
        onTriggered: {
            if (pendingUpdate) {
                pendingUpdate()
                pendingUpdate = null
            }
        }
        
        function scheduleUpdate(updateFunction) {
            pendingUpdate = updateFunction
            restart()
        }
    }
    
    // NOUVEAUTÉ: Rectangle de prévisualisation pendant le redimensionnement
    Rectangle {
        id: resizePreview
        visible: showResizePreview && useVisualFeedback
        color: "transparent"
        border.color: Qt.rgba(0.3, 0.6, 1.0, 0.8)
        border.width: 2
        z: 150
        
        x: previewRect.x
        y: previewRect.y
        width: previewRect.width
        height: previewRect.height
        
        // Style pointillé pour la prévisualisation
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.3, 0.6, 1.0, 0.1)
            border.color: "transparent"
        }
    }
    
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
            
            // Auto-snap si activé et gridManager disponible
            if (autoSnap && gridManager && gridManager.snapToGrid) {
                gridManager.snapElement(snapableElement)
                snapCompleted(snapableElement)
            }
            
            elementReleased(snapableElement)
            elementMoved(snapableElement, snapableElement.x, snapableElement.y)
        }
        
        onClicked: {
            isSelected = !isSelected
            elementClicked(snapableElement)
        }
        
        onPositionChanged: {
            if (drag.active && smoothResize) {
                // OPTIMISATION: Throttler les mises à jour de position
                updateThrottleTimer.scheduleUpdate(function() {
                    elementMoved(snapableElement, snapableElement.x, snapableElement.y)
                })
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
    function snapToGrid() {
        if (gridManager && gridManager.snapToGrid) {
            gridManager.snapElement(snapableElement)
            snapCompleted(snapableElement)
        }
    }
    
    // NOUVEAUTÉ: Fonction optimisée pour calculer la taille snappée
    function getSnappedSize(targetWidth, targetHeight) {
        if (!gridManager || !gridManager.snapToGrid) {
            return {
                width: Math.max(minWidth, targetWidth),
                height: Math.max(minHeight, targetHeight)
            }
        }
        
        var gridSize = gridManager.gridSize
        
        // Vérifier si on est déjà assez proche de la taille snappée
        var currentSnappedWidth = Math.round(targetWidth / gridSize) * gridSize
        var currentSnappedHeight = Math.round(targetHeight / gridSize) * gridSize
        
        // OPTIMISATION: Éviter les recalculs si on est dans la tolérance
        if (Math.abs(targetWidth - currentSnappedWidth) <= snapTolerance &&
            Math.abs(targetHeight - currentSnappedHeight) <= snapTolerance) {
            return { width: targetWidth, height: targetHeight }
        }
        
        // Dimensions minimales alignées sur la grille
        var minGridWidth = Math.max(gridSize, Math.ceil(minWidth / gridSize) * gridSize)
        var minGridHeight = Math.max(gridSize, Math.ceil(minHeight / gridSize) * gridSize)
        
        // Snap avec hystérésis améliorée
        var tolerance = 0.25 // Réduit pour plus de précision
        var snappedUnitsWidth = Math.floor(targetWidth / gridSize + tolerance)
        var snappedUnitsHeight = Math.floor(targetHeight / gridSize + tolerance)
        
        // S'assurer des minimums
        var minUnitsWidth = Math.ceil(minGridWidth / gridSize)
        var minUnitsHeight = Math.ceil(minGridHeight / gridSize)
        
        snappedUnitsWidth = Math.max(minUnitsWidth, snappedUnitsWidth)
        snappedUnitsHeight = Math.max(minUnitsHeight, snappedUnitsHeight)
        
        return {
            width: snappedUnitsWidth * gridSize,
            height: snappedUnitsHeight * gridSize
        }
    }
    
    // NOUVEAUTÉ: Fonction pour activer/désactiver le mode feedback visuel
    function setVisualFeedback(enabled) {
        useVisualFeedback = enabled
    }
    
    // NOUVEAUTÉ: Fonction pour optimiser les performances de redimensionnement
    function setPerformanceMode(enabled) {
        smoothResize = !enabled
        updateThrottleMs = enabled ? 32 : 16  // Moins de mises à jour en mode performance
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
    
    function randomizePosition() {
        if (parent) {
            x = Math.random() * (parent.width - width)
            y = Math.random() * (parent.height - height)
            if (autoSnap) {
                snapToGrid()
            }
        }
    }
    
    // Composant pour les poignées de redimensionnement (VERSION OPTIMISÉE)
    component ResizeHandle: Rectangle {
        id: handle
        
        required property string direction
        required property var gridManager
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
        
        // NOUVEAUTÉ: Timer pour throttler les mises à jour pendant le redimensionnement
        Timer {
            id: resizeUpdateTimer
            interval: targetElement.updateThrottleMs
            running: false
            repeat: false
            
            property var pendingResize: null
            
            onTriggered: {
                if (pendingResize) {
                    pendingResize()
                    pendingResize = null
                }
            }
        }
        
        MouseArea {
            id: handleMouseArea
            anchors.fill: parent
            cursorShape: parent.cursorShape
            hoverEnabled: true
            
            onPressed: {
                targetElement.isResizing = true
                targetElement.showResizePreview = targetElement.useVisualFeedback
                
                startMouseX = mouseX
                startMouseY = mouseY
                startWidth = targetElement.width
                startHeight = targetElement.height
                startElementX = targetElement.x
                startElementY = targetElement.y
                
                // Activer le mode visual de la grille
                if (gridManager && gridManager.enterResizeMode) {
                    gridManager.enterResizeMode()
                }
            }
            
            onReleased: {
                targetElement.isResizing = false
                targetElement.showResizePreview = false
                
                // Désactiver le mode visual de la grille
                if (gridManager && gridManager.exitResizeMode) {
                    gridManager.exitResizeMode()
                }
                
                // OPTIMISATION: Snap final uniquement si nécessaire
                if (gridManager && gridManager.snapToGrid) {
                    var snappedSize = targetElement.getSnappedSize(targetElement.width, targetElement.height)
                    
                    // Appliquer le snap final SEULEMENT si vraiment nécessaire
                    var needsSnap = Math.abs(targetElement.width - snappedSize.width) > targetElement.snapTolerance || 
                                   Math.abs(targetElement.height - snappedSize.height) > targetElement.snapTolerance
                    
                    if (needsSnap) {
                        targetElement.width = snappedSize.width
                        targetElement.height = snappedSize.height
                        targetElement.elementResized(targetElement, snappedSize.width, snappedSize.height)
                    }
                    
                    // Snap de la position
                    gridManager.snapElement(targetElement)
                }
                
                // Vider le timer si en attente
                resizeUpdateTimer.stop()
            }
            
            onPositionChanged: {
                if (pressed) {
                    var deltaX = mouseX - startMouseX
                    var deltaY = mouseY - startMouseY
                    
                    // OPTIMISATION: Calculer les nouvelles dimensions
                    var newDimensions = calculateNewDimensions(deltaX, deltaY)
                    
                    if (targetElement.smoothResize) {
                        // NOUVEAUTÉ: Mise à jour throttlée pour éviter le scintillement
                        resizeUpdateTimer.pendingResize = function() {
                            applyResize(newDimensions)
                        }
                        resizeUpdateTimer.restart()
                    } else {
                        // Mode performance : mise à jour directe
                        applyResize(newDimensions)
                    }
                }
            }
            
            // NOUVEAUTÉ: Fonction pour calculer les nouvelles dimensions (optimisée)
            function calculateNewDimensions(deltaX, deltaY) {
                var rawWidth = startWidth
                var rawHeight = startHeight
                var newX = startElementX
                var newY = startElementY
                
                // Calcul selon la direction
                switch(direction) {
                    case "nw":
                        rawWidth = Math.max(targetElement.minWidth, startWidth - deltaX)
                        rawHeight = Math.max(targetElement.minHeight, startHeight - deltaY)
                        newX = startElementX + (startWidth - rawWidth)
                        newY = startElementY + (startHeight - rawHeight)
                        break
                    case "ne":
                        rawWidth = Math.max(targetElement.minWidth, startWidth + deltaX)
                        rawHeight = Math.max(targetElement.minHeight, startHeight - deltaY)
                        newY = startElementY + (startHeight - rawHeight)
                        break
                    case "sw":
                        rawWidth = Math.max(targetElement.minWidth, startWidth - deltaX)
                        rawHeight = Math.max(targetElement.minHeight, startHeight + deltaY)
                        newX = startElementX + (startWidth - rawWidth)
                        break
                    case "se":
                        rawWidth = Math.max(targetElement.minWidth, startWidth + deltaX)
                        rawHeight = Math.max(targetElement.minHeight, startHeight + deltaY)
                        break
                    case "n":
                        rawHeight = Math.max(targetElement.minHeight, startHeight - deltaY)
                        newY = startElementY + (startHeight - rawHeight)
                        break
                    case "s":
                        rawHeight = Math.max(targetElement.minHeight, startHeight + deltaY)
                        break
                    case "w":
                        rawWidth = Math.max(targetElement.minWidth, startWidth - deltaX)
                        newX = startElementX + (startWidth - rawWidth)
                        break
                    case "e":
                        rawWidth = Math.max(targetElement.minWidth, startWidth + deltaX)
                        break
                }
                
                return {
                    width: rawWidth,
                    height: rawHeight,
                    x: newX,
                    y: newY
                }
            }
            
            // NOUVEAUTÉ: Fonction pour appliquer le redimensionnement (optimisée)
            function applyResize(dimensions) {
                if (targetElement.useVisualFeedback) {
                    // Mise à jour de la prévisualisation
                    targetElement.previewRect = Qt.rect(
                        dimensions.x, dimensions.y, 
                        dimensions.width, dimensions.height
                    )
                }
                
                // OPTIMISATION: Mise à jour groupée des propriétés
                targetElement.x = dimensions.x
                targetElement.y = dimensions.y
                targetElement.width = dimensions.width
                targetElement.height = dimensions.height
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
