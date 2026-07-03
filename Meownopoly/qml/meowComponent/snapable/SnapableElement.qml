import QtQuick 2.15
import QtQuick.Controls
import "."
import "../"
import "../grid"

import ItemSnapable
import TileType
import DisplayParameter
import DecorationParameter
import Case
import ItemSnapableFactory

import MapTypes
import MapFileManager
import EditorSession 1.0
import theme

Rectangle {
    id: snapableElement

    // --- Required Properties ---
    // Connexion au GridManager du parent (Editor)
    required property GridManager gridManager
    required property ItemSnapable snapableParameters

    // --- Properties ---
    // Propriétés configurables
    property bool isResizable: true
    property bool blockConnections: false
    property bool autoSnap: true
    property color elementColor: "transparent"
    property color borderColor: "gray"
    property int borderWidth: 0

    // Propriétés d'état
    property bool isDragging: false
    property bool isResizing: false
    property bool isSelected: false

    property var generalMA: null
    property bool displayLinkEnable: false

    // Calcul des coordonnées globales du centre dans le référentiel workArea
    // Si on est dans groupeSelection, on ajoute sa position pour obtenir les coordonnées dans workArea
    property point globalCenter: {
        var centerX = x + width / 2
        var centerY = y + height / 2
        return Qt.point(centerX, centerY)
    }

    readonly property int globalCenterX: globalCenter.x
    readonly property int globalCenterY: globalCenter.y

    // --- Aliases ---
    property alias dragArea: dragArea
    property alias connectionManager: connectionManager

    // --- Signals ---
    signal elementClicked()
    signal elementPressed()

    onElementPressed: {
        isDragging = true
        isSelected = true
    }

    signal elementReleased()
    onElementReleased: {
        isDragging = false
        updateRelativePosition()
        if (autoSnap && gridManager && gridManager.snapToGrid) {
            snapToGrid()
        }
    }

    signal elementUnselected()
    onElementUnselected: {
        isSelected = false
        elementReleased()
    }

    signal elementResized(var element, real newWidth, real newHeight)
    signal snapCompleted(var element)

    signal elementDeleted(var element)  // sent after delete

    // --- Component.onCompleted ---
    Component.onCompleted: {
        // Si snapableParameters n'a pas été fourni, créer une instance par défaut
        if (!snapableParameters) {
            console.log("null snapable")
            snapableParameters = ItemSnapableFactory.createItemSnapable()
        }

        snapToGrid()

        //Check if we are restoring state from undo/redo
        if (MapFileManager.currentMap ? MapFileManager.currentMap.canSave : true)
            createAnimation.start()

        snapableParameters.displayParameterChanged()
    }

    // --- Bindings ---
    // Propriété pour stocker la valeur z originale
    z:  (isSelected && !isDragging) ? snapableParameters.displayParameter.zOrder + 11 : snapableParameters.displayParameter.zOrder + snapableParameters.displayParameter.zLayer

    // Positions calculées à partir des coordonnées relatives
    x: snapableParameters.displayParameter.gridRelativePositionX * gridManager.gridSize
    y: snapableParameters.displayParameter.gridRelativePositionY * gridManager.gridSize

    width:  gridManager.gridSize * snapableParameters.displayParameter.unitSizeWidth
    height:  gridManager.gridSize * snapableParameters.displayParameter.unitSizeHeight

    color: elementColor
    border.color: isSelected ? Qt.lighter(borderColor, 1.5) : borderColor
    border.width: isSelected ? borderWidth + 2 : borderWidth

    // Effet de survol avec transition optimisée
    scale: 1.0

    // --- Items ---
    SnapableElementConnections {
        id: connectionManager
        parentElement: snapableElement
        anchors.fill: snapableElement
        z: 40
        parent: snapableElement.parent

        onNextElementAdded:function(element) {
            if (root.blockConnections) return
            console.log("Next element added:", element)
            // Synchroniser avec les données C++ : ajouter la case suivante
            if (element && element.snapableParameters && root.snapableParameters) {
                root.snapableParameters.addNext(element.snapableParameters)
                console.log("Added next case:", element.snapableParameters.caseData.name, "to", root.snapableParameters.caseData.name)
            }
        }
        onPreviousElementAdded:function(element) {
            if (root.blockConnections) return
            console.log("Previous element added:", element)
            // Synchroniser avec les données C++ : ajouter la case précédente
            if (element && element.snapableParameters && root.snapableParameters) {
                root.snapableParameters.addPrev(element.snapableParameters)
                console.log("Added previous case:", element.snapableParameters.caseData.name, "to", root.snapableParameters.caseData.name)
            }
        }
        onNextElementRemoved:function(element) {
            if (root.blockConnections) return
            console.log("Next element removed:", element)
            // Synchroniser avec les données C++ : supprimer la case suivante
            if (element && element.snapableParameters && root.snapableParameters) {
                root.snapableParameters.removeNext(element.snapableParameters)
                console.log("Removed next case:", element.snapableParameters.caseData.name, "from", root.snapableParameters.caseData.name)
            }
        }
        onPreviousElementRemoved: function(element) {
            if (root.blockConnections) return
            console.log("Previous element removed:", element)
            // Synchroniser avec les données C++ : supprimer la case précédente
            if (element && element.snapableParameters && root.snapableParameters) {
                root.snapableParameters.removePrev(element.snapableParameters)
                console.log("Removed previous case:", element.snapableParameters.caseData.name, "from", root.snapableParameters.caseData.name)

            }
        }
    }

    SnapableElementDeleteAnimation {
        id: deleteAnimation
        onFinished: {
            elementDeleted(snapableElement)
            // La save est orchestrée par Game.updateMap/commitTransaction.
        }
    }
    SnapableElementCreateAnimation {
        id: createAnimation
    }

    // Zone de drag & drop
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: !isResizing

        propagateComposedEvents: true
        preventStealing: true

        z: 50  // Au-dessus du contenu mais sous les poignées

        onPressed: function(mouse) {
            if (generalMA)
            {
                if (!isTransparent(mouse)){
                    generalMA.elementClicked(snapableElement)
                    }
            }
            mouse.accepted = false
        }

        onReleased: function(mouse) {
            console.log("snap release");
        }

        onPositionChanged: function(mouse) { }
    }

    // Contrôles de l'élément (boutons de plan et suppression)
    SnapableElementControl {
        id: elementControls
        targetElement: snapableElement
        isVisible: isSelected
        zLayer: snapableParameters.displayParameter.zLayer
        onLayerChanged: function(newLayer) {snapableParameters.displayParameter.zLayer = newLayer}

        anchors.left: snapableElement.right
        anchors.top: snapableElement.top
        parent: snapableElement.parent

    }

    // Poignées de redimensionnement
    SnapableElementResizeHandles {
        id: resizeHandles
        anchors.fill: snapableElement
        parent: snapableElement.parent
        z: 100
    }

    // --- Functions ---
    function deleteRequest(saveAfter)
    {
        deleteAnimation.start()
    }

    function isTransparent(mouse){
        return false
    }

    // Fonctions utilitaires améliorées
    function updateRelativePosition() {
        if (!gridManager || gridManager.gridSize === 0) return
        var newGridX = Math.round(x / gridManager.gridSize)
        var newGridY = Math.round(y / gridManager.gridSize)

        snapableParameters.displayParameter.gridRelativePositionX = newGridX
        snapableParameters.displayParameter.gridRelativePositionY = newGridY
    }

    function snapToGrid() {
        if (!gridManager || !gridManager.snapToGrid) return


        // Calculer les positions snappées en unités de grille
        var snappedGridX = Math.round(x / gridManager.gridSize)
        var snappedGridY = Math.round(y / gridManager.gridSize)

        // Mettre à jour les positions relatives (qui vont automatiquement mettre à jour x et y)
        snapableParameters.displayParameter.gridRelativePositionX = snappedGridX
        snapableParameters.displayParameter.gridRelativePositionY = snappedGridY


        gridManager.snapElement2(snapableElement)
        snapCompleted(snapableElement)
    }

    function snapToGridFromGridPos() {
        if (!gridManager || !gridManager.snapToGrid) return

        gridManager.snapElement2(snapableElement)
        snapCompleted(snapableElement)
    }

    // selection tools
    function select() { isSelected = true }
    function deselect() { isSelected = false }

    // Functions to reset effects
    function resetColorEffects() {
        snapableParameters.displayParameter.effectBrightness = 0.0
        snapableParameters.displayParameter.effectContrast = 0.0
        snapableParameters.displayParameter.effectSaturation = 0.0
        snapableParameters.displayParameter.effectColorization = 0.0
        snapableParameters.displayParameter.effectColorizationColor = "#ffffff"
    }

    function resetBlurEffect() {
        snapableParameters.displayParameter.effectBlurEnabled = false
        snapableParameters.displayParameter.effectBlur = 0.0
        snapableParameters.displayParameter.effectBlurMax = 32
        snapableParameters.displayParameter.effectBlurMultiplier = 1.0
    }

    function resetShadowEffect() {
        snapableParameters.displayParameter.effectShadowEnabled = false
        snapableParameters.displayParameter.effectShadowBlur = 1.0
        snapableParameters.displayParameter.effectShadowColor = Qt.rgba(0.0, 0.0, 0.0, 1.0)
        snapableParameters.displayParameter.effectShadowHorizontalOffset = 0.0
        snapableParameters.displayParameter.effectShadowVerticalOffset = 0.0
        snapableParameters.displayParameter.effectShadowOpacity = 1.0
        snapableParameters.displayParameter.effectShadowScale = 1.0
    }

    function resetAllEffects() {
        resetColorEffects()
        resetBlurEffect()
        resetShadowEffect()
    }

    // Functions to reset transforms
    function resetRotation() {
        snapableParameters.displayParameter.rotationAngle = 0.0
    }

    function resetMirror() {
        snapableParameters.displayParameter.mirrorHorizontal = false
        snapableParameters.displayParameter.mirrorVertical = false
    }

    function resetAllTransforms() {
        resetRotation()
        resetMirror()
    }

    function applyVisualEffects(effects)    // generate from VisualEffectsPanel@getCurrentEffects()
    {
        // Apply color effects
        snapableParameters.displayParameter.effectBrightness = effects.brightness
        snapableParameters.displayParameter.effectContrast = effects.contrast
        snapableParameters.displayParameter.effectSaturation = effects.saturation
        snapableParameters.displayParameter.effectColorization = effects.colorization
        snapableParameters.displayParameter.effectColorizationColor = effects.colorizationColor

        // Apply advanced effects
        snapableParameters.displayParameter.effectBlurEnabled = effects.blurEnabled
        snapableParameters.displayParameter.effectBlur = effects.blur
        snapableParameters.displayParameter.effectShadowEnabled = effects.shadowEnabled
        snapableParameters.displayParameter.effectShadowBlur = effects.shadowBlur

        // Apply transform effects
        snapableParameters.displayParameter.rotationAngle = effects.rotationAngle
        snapableParameters.displayParameter.mirrorHorizontal = effects.mirrorHorizontal
        snapableParameters.displayParameter.mirrorVertical = effects.mirrorVertical
    }

    function applyPhysicSettings(physicSettings) {
        snapableParameters.zoneParameter.zoneName = physicSettings.zoneName
        snapableParameters.zoneParameter.exclusion = physicSettings.exclusion
        snapableParameters.zoneParameter.speedMultiplier = physicSettings.speedMultiplier
        snapableParameters.zoneParameter.velocityDirection = Qt.vector2d(physicSettings.velocityDirectionX, physicSettings.velocityDirectionY)
        snapableParameters.zoneParameter.velocityStrength = physicSettings.velocityStrength
        snapableParameters.zoneParameter.frictionStrength = physicSettings.frictionStrength
        snapableParameters.zoneParameter.accelerationMultiplier = physicSettings.accelerationMultiplier
        // Effet visuel de zone (référence vers MapInfo.screenEffects). Garde
        // undefined pour ne pas écraser sur d'anciens appelants sans ce champ.
        if (physicSettings.screenEffectId !== undefined)
            snapableParameters.zoneParameter.screenEffectId = physicSettings.screenEffectId
        // Déclencheur "plaque de pression" (mêmes gardes undefined).
        if (physicSettings.triggerMode !== undefined)
            snapableParameters.zoneParameter.triggerMode = physicSettings.triggerMode
        if (physicSettings.triggerOnce !== undefined)
            snapableParameters.zoneParameter.triggerOnce = physicSettings.triggerOnce
        if (physicSettings.rewardCurrency !== undefined)
            snapableParameters.zoneParameter.rewardCurrency = physicSettings.rewardCurrency
        if (physicSettings.rewardItemName !== undefined)
            snapableParameters.zoneParameter.rewardItemName = physicSettings.rewardItemName
        if (physicSettings.rewardItemQuantity !== undefined)
            snapableParameters.zoneParameter.rewardItemQuantity = physicSettings.rewardItemQuantity
    }

    // ─── liserés des sélections distantes ───────────────────────
    //
    // Recalculé sur remoteSelectionsChanged (NOTIFY de la Q_PROPERTY C++).
    // Retourne la liste des playerIds qui ont cette tuile dans leur sélection.
    readonly property var _foreignSelectors: {
        if (!snapableParameters) return []
        if (!EditorSession.active) return []
        const myUuid = String(snapableParameters.uniqueId)
        const rs = EditorSession.remoteSelections
        const result = []
        for (const pid in rs) {
            const uuids = rs[pid] || []
            for (let i = 0; i < uuids.length; i++) {
                if (uuids[i] === myUuid) { result.push(pid); break }
            }
        }
        return result
    }

    function _foreignColor(pid) {
        let h = 0
        for (let i = 0; i < pid.length; i++) h = (h * 131 + pid.charCodeAt(i)) & 0xFFFF
        return Qt.hsla((h % 360) / 360.0, 0.7, 0.55, 1.0)
    }

    Repeater {
        model: snapableElement._foreignSelectors
        delegate: Rectangle {
            anchors.fill: parent
            anchors.margins: -(2 + 3 * index)
            color: "transparent"
            border.width: 2
            border.color: snapableElement._foreignColor(modelData)
            radius: Theme.radiusS
            z: 50 + index
            visible: EditorSession.active
        }
    }
}
