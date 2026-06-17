import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import CursorManager
import "../../meowComponent/snapable"
import "../../meowComponent/grid"

QtObject {
    id: mouseLogic
    property bool isDragging: false
    property list<SnapableElement> clickElement:[]
    property var clickPosition
    property list<var> elementInitialPosition:[]
    property var logic
    property GridManager grid
    property list<SnapableElement> selectedElements: []

    property bool isControlPressed : false

    property point dragStartPos: Qt.point(0, 0)
    property point targetStartPos: Qt.point(0, 0)

    // Reference to View3D for camera synchronization
    property var view3D: logic && logic.parent ? logic.parent.view3D : null
    property point lastGridPos: Qt.point(0,0)

    Component.onCompleted: {
        if (grid) {
            lastGridPos = Qt.point(grid.x, grid.y)
        }
        // view3D = logic.parent.view3D
    }

    // Propriété pour stocker le point 3D sous la souris avant le zoom
    property vector3d zoomPointStart

    function prepareZoom(mouseX, mouseY) {
        if (!view3D) return
        // Capturer le point du monde 3D qui est actuellement sous la souris
        zoomPointStart = view3D.mapTo3DScene(Qt.point(mouseX, mouseY))
    }

    function applyZoom(mouseX, mouseY) {
        if (!view3D || !view3D.camera || !grid) return
        
        // 1. Calculer où est le point sous la souris MAINTENANT (après changement de magnification)
        var zoomPointEnd = view3D.mapTo3DScene(Qt.point(mouseX, mouseY))
        
        // 2. Calculer le décalage
        // On voulait que zoomPointStart soit toujours sous la souris.
        // Mais actuellement c'est zoomPointEnd qui est sous la souris.
        // La différence est le glissement dû au zoom centré sur la caméra.
        var worldCorrection = zoomPointEnd.minus(zoomPointStart)
        
        // 3. Corriger la position de la caméra
        var cam = view3D.camera
        cam.x -= worldCorrection.x
        cam.y -= worldCorrection.y
        cam.z -= worldCorrection.z // Correction Z nécessaire car la caméra est inclinée
        
        // 4. Mettre à jour lastGridPos pour ignorer le mouvement "fake" de la grille 2D
        // La grille 2D a bougé pour compenser le zoom 2D.
        // La caméra a bougé (ci-dessus) pour compenser le zoom 3D.
        // On ne veut PAS que updateCameraPosition (qui compare grid.x vs lastGridPos)
        // applique un déplacement supplémentaire.
        lastGridPos = Qt.point(grid.x, grid.y)
    }
    
    function updateCameraPosition(zoomRatio) {
        if (!view3D || !grid) return
        if (zoomRatio === undefined) zoomRatio = 1.0

        // 1. Calculer le déplacement en pixels à l'écran
        var dx = grid.x - lastGridPos.x
        var dy = grid.y - lastGridPos.y

        if (dx === 0 && dy === 0) return

        // 2. Convertir ce vecteur 2D (écran) en vecteur 3D (monde)
        // On prend deux points pour avoir le vecteur "droit" et "haut" de la caméra projeté au sol
        // Note: mapTo3DScene renvoie un point sur le plan proche ou loin, ou sur un plan spécifique ?
        // Par défaut c'est une projection rayon -> monde.
        
        var center = Qt.point(view3D.width / 2, view3D.height / 2)
        var target = Qt.point(center.x - dx, center.y - dy) // On veut déplacer la vue vers (x-dx, y-dy)
        
        // On utilise mapTo3DScene pour projeter ces points 2D dans l'espace 3D
        // Cela prend en compte AUTOMATIQUEMENT la rotation de la caméra
        var pCenter = view3D.mapTo3DScene(center)
        var pTarget = view3D.mapTo3DScene(target)
        
        // 3. Calculer le delta monde
        var worldDelta = pTarget.minus(pCenter)
        
        // Appliquer le déplacement
        var cam = view3D.camera
        if (cam) {
            cam.x += worldDelta.x
            cam.y += worldDelta.y
            cam.z += worldDelta.z
        }

        lastGridPos = Qt.point(grid.x, grid.y)
    }

    function dragChanged(mouseX, mouseY, drag) {
        isDragging = drag.active
        if (drag.active && drag.target) {
            // Sauvegarder les positions de départ
            dragStartPos = Qt.point(mouseX, mouseY)
            targetStartPos = Qt.point(drag.target.x, drag.target.y)
        }
        // Mettre à jour la position de référence au début du drag
        if (grid) {
             lastGridPos = Qt.point(grid.x, grid.y)
        }
    }
    
    function positionChanged(mouse, drag)
    {

        // Mettre à jour la sélection par rectangle si active
        if (mouseLogic.isRectangleSelecting) {
            mouseLogic.updateRectangleSelection(mouse.x, mouse.y)
        }
        
        // Gérer le snap pendant le drag
        if (drag.active && drag.target && grid.snapToGrid) {
            var deltaX = mouse.x - dragStartPos.x
            var deltaY = mouse.y - dragStartPos.y
            
            var newX = targetStartPos.x + deltaX
            var newY = targetStartPos.y + deltaY
            if (drag.target == groupeSelection)
            {
                // Snapper aux positions de la grille
                var snappedX = Math.round(newX / grid.gridSize) * grid.gridSize
                var snappedY = Math.round(newY / grid.gridSize) * grid.gridSize

                drag.target.x = snappedX
                drag.target.y = snappedY
            }
        }
        updateCameraPosition()
    }

    function unselectSelectedElements()
    {
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].elementUnselected()
            destroyBindingsForElement(selectedElements[i])
        }
        selectedElements = []
        groupeSelection.x = 0
        groupeSelection.y = 0

        // Effacer la configuration de case
        clearCaseConfiguration()
    }

    // Fonction pour effacer la configuration de case
    function clearCaseConfiguration() {
        // Accéder au CaseConfigurationPanelSection via le SelectionPanel
        var caseConfigPanel = logic.editorSidePanel.caseConfigurationPanel
        if (!caseConfigPanel) {
            console.log("[LOGIC] caseConfigPanel not available")
            return
        }

        caseConfigPanel.clearTarget()
    }
    function changeMouseMode(mode)
    {

        // Masquer la prévisualisation du lien si on change de mode
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            console.log("hideLinkPreview")
            logic.mouseLogic.hideLinkPreview()
        }

        logic.editorMouseMode = mode
    }

    function elementClicked(tile)
    {
        clickElement.push(tile)
        var realPos = mainMa.mapToItem(grid, tile.x, tile.y)
        var pos = Qt.point(realPos.x, realPos.y)
        elementInitialPosition.push(pos)
        console.log("Add element to list")
    }

    function pressedLeft(mouse, drag)
    {

        console.log("main MA pressed LEFT : ", clickElement.length, " elements")
        mouse.accepted = true

    }

    function pressedRight(mouse, drag)
    {

        console.log("main MA pressed RIGHT : ", clickElement.length, " elements")
        mouse.accepted = true

    }
    function pressedMiddle(mouse, drag)
    {
        console.log("main MA pressed MIDDLE : ", clickElement.length, " elements")
        mouse.accepted = true
    }

    function release(mouse, drag)
    {
        console.log("main MA released : ", clickElement.length, " elements")
        clickElement = []
        elementInitialPosition = []
    }

    function pressedAndHold(mouse, drag)
    {
        console.log("main MA pressed and hold : ", clickElement.length, " elements")

        var realPos = mainMa.mapToItem(grid, mouse.x, mouse.y)
        var gridPos = grid.getGridPosition(realPos.x, realPos.y)
    }

    function clickedLeft(mouse, drag)
    {
        console.log("main MA clicked : ", clickElement.length, " elements")
    }

    function clickedRight(mouse, drag)
    {
        console.log("main MA clicked right : ", clickElement.length, " elements")
    }

    function clickedMiddle(mouse, drag)
    {

    }

    function clicked(mouse, drag)
    {
        console.log("main MA clicked : ", clickElement.length, " elements")
    }

    function updateSidePanel(snapableParameter)
    {
        var editorSidePanel = logic.editorSidePanel
        if (!editorSidePanel) {
            console.log("[LOGIC] editorSidePanel not available")
            return
        }
        editorSidePanel.updateSidePanel(snapableParameter)
    }
    // Fonction pour mettre à jour la configuration de case dans le panneau
    function updateCaseConfiguration() {

        // Accéder au CaseConfigurationPanelSection via le SelectionPanel
        var caseConfigPanel = logic.editorSidePanel.caseConfigurationPanel
        if (!caseConfigPanel) {
            console.log("[LOGIC] caseConfigPanel not available")
            return
        }

        var configLinkPanel = logic.editorSidePanel.connectionsConfigurationPanel
        if (!configLinkPanel) {
            console.log("[LOGIC] connectionConfigurationPanel not available")
            return
        }

        // Si un seul élément est sélectionné et que c'est une case, mettre à jour la configuration
        if (selectedElements.length === 1) {
            var element = selectedElements[0]
            if (configLinkPanel)
            {
                configLinkPanel.setTargetElement(element)
            }
            if (element.snapableParameters.caseData) {
                console.log("[LOGIC EDITOR] Updating case configuration for:", element.snapableParameters.caseData.name)
                if (caseConfigPanel)
                {
                    caseConfigPanel.setTargetCase(element)
                }

            } else {
                // Ce n'est pas une case, effacer la configuration
                caseConfigPanel.clearTarget()
            }
        } else {
            // Plusieurs éléments sélectionnés ou aucun, effacer la configuration
            caseConfigPanel.clearTarget()
        }
    }

    function setSelectedElementList(selectedList)
    {
        selectedElements = selectedList
        for (var i = 0; i < selectedElements.length; i++) {
            selectedElements[i].elementPressed()
            createBindingsForElement(selectedElements[i])
        }
    }

    // Propriétés pour gérer les positions initiales sans changer le parent
    property var elementInitialPositions: ({})  // Map: element -> {x: initialX, y: initialY}
    property var elementBindings: ({})  // Map: element -> {xBinding: Binding, yBinding: Binding}

    // Fonction pour créer les bindings pour un élément
    function createBindingsForElement(element) {
        if (!element) return

        var initialX = element.x - groupeSelection.x
        var initialY = element.y - groupeSelection.y
        elementInitialPositions[element] = {x: initialX, y: initialY}

        var bindingInitialX = initialX
        var bindingInitialY = initialY

        console.log("[BINDING][create] element.x=" + element.x
                    + " groupeSelection.x=" + groupeSelection.x
                    + " initialX=" + initialX)

        element.x = Qt.binding(function() {
            return groupeSelection.x + bindingInitialX
        })
        element.y = Qt.binding(function() {
            return groupeSelection.y + bindingInitialY
        })

        elementBindings[element] = true
    }

    // Fonction pour détruire les bindings pour un élément
    function destroyBindingsForElement(element) {
        if (!element) return

        if (elementBindings[element]) {
            var currentX = element.x
            var currentY = element.y
            var gridX = element.snapableParameters
                        ? element.snapableParameters.displayParameter.gridRelativePositionX
                        : "N/A"


            element.x = Qt.binding(function() {
                return element.snapableParameters.displayParameter.gridRelativePositionX * element.gridManager.gridSize
            })
            element.y = Qt.binding(function() {
                return element.snapableParameters.displayParameter.gridRelativePositionY * element.gridManager.gridSize
            })

            delete elementBindings[element]
        }

        if (elementInitialPositions[element])
            delete elementInitialPositions[element]
    }

    // Fonction pour déplacer la souris au centre de la fenêtre
    function moveMouseToWindowCenter() {
        var rootEditor = logic.parent

        var centerX = rootEditor.width / 2 + rootEditor.appPositionX
        var centerY = rootEditor.height / 2 + rootEditor.appPositionY
        
        
        // Déplacer le curseur au centre de la fenêtre via le singleton CursorManager
        CursorManager.setPos(centerX, centerY)
        
        return Qt.point(centerX, centerY)
    }

    // Fonction pour recréer les bindings d'un élément après un snap (appelée via signal)
    function rebindElement(element) {
        if (!element) return

        // Vérifier que l'élément est bien dans la liste des éléments sélectionnés
        var found = false
        for (var i = 0; i < selectedElements.length; i++) {
            if (selectedElements[i] === element) {
                found = true
                break
            }
        }
        if (!found) return

        // Recalculer les offsets avec la nouvelle position
        var newInitialX = element.x - groupeSelection.x
        var newInitialY = element.y - groupeSelection.y
        elementInitialPositions[element] = {x: newInitialX, y: newInitialY}

        // Recréer les bindings avec les nouveaux offsets
        var bindingInitialX = newInitialX
        var bindingInitialY = newInitialY

        element.x = Qt.binding(function() {
            return groupeSelection.x + bindingInitialX
        })
        element.y = Qt.binding(function() {
            return groupeSelection.y + bindingInitialY
        })

        elementBindings[element] = true
    }

    // Fonction pour recréer les bindings de tous les éléments sélectionnés après un zoom
    function rebindAllSelectedElements() {
        for (var i = 0; i < selectedElements.length; i++) {
            rebindElement(selectedElements[i])
        }
    }

}
