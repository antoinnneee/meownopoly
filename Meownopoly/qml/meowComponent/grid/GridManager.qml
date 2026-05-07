import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window
import ".."


/**
 * GridManager simple et réactif pour l'éditeur.
 *
 * Deux modes de rendu sont supportés via le context property
 * `_gridRendererUseCanvas` (set par qmlapp.cpp depuis l'env var
 * `MEOW_GRID_RENDERER` — défaut canvas, override repeater) :
 *   - canvas (défaut Qt 6.11+) : un seul GridCanvasPainter GPU + viewport
 *     culling. `O(1)` items dans le scene graph.
 *   - repeater (legacy, fallback Qt 6.10) : 1202 Rectangle pour 600
 *     croisillons, gérés par le scene graph standard. Plus lourd au resize
 *     et au panning, mais sans dépendance Qt 6.11.
 */
Item {
    id: gridManager

    property int croisillons: 600
    // mmSize est `real` pour permettre un zoom multiplicatif continu
    // (×1.1 par cran de molette). Avec `int`, l'arrondi à chaque cran
    // empêchait un zoom-in fluide au-delà de mmSize=12. Voir ScrollLogic.
    property real mmSize: 12.0
    property real defaultMmSize: 12.0
    property real scaleLevel: mmSize / defaultMmSize
    property real gridSizeCalc: Screen.pixelDensity * mmSize
    property real gridSize: gridSizeCalc

    property real boardSize:  gridSize * croisillons // 600 croisillons
    // Propriétés configurables
    width: boardSize
    height: boardSize

    property color gridColor: "#40808080"
    property real gridOpacity: 0.5
    property bool showGrid: true
    property bool snapToGrid: true
    property int lineWidth: 1

    // Propriété pour intensifier la grille pendant le redimensionnement
    property bool resizeMode: false

    // Propriétés en lecture seule pour accès externe
    readonly property int snapSize: gridSize

    property bool isEdit: false

    // Signal émis quand les paramètres changent
    signal gridSettingsChanged()
    signal gridPressed(var position)
    signal gridClicked(var position)
    signal gridRightClicked(var position)
    // Signal émis quand un élément sélectionné a été snappé (pour recréer les bindings)
    signal selectedElementSnapped(var element)


    // Fonction alternative qui snap directement un élément (plus pratique)
    function snapElement2(element) {
        if (!snapToGrid) return

        // Calculer la position snappée en pixels
        var snappedX = element.snapableParameters.displayParameter.gridRelativePositionX * gridSize
        var snappedY = element.snapableParameters.displayParameter.gridRelativePositionY * gridSize

        if (element.isSelected) {
            // Élément sélectionné : émettre un signal pour que MouseLogic recréée les bindings
            // après avoir mis à jour la position directement
            element.x = snappedX
            element.y = snappedY
            selectedElementSnapped(element)
        } else {
            // Élément non sélectionné : assigner directement
            element.x = snappedX
            element.y = snappedY
        }
    }

    // Fonction pour obtenir la position de grille la plus proche
    function getGridPosition(x, y) {
        return Qt.point(
            Math.floor(x / gridSize),
            Math.floor(y / gridSize)
        )
    }
    // Fonction pour obtenir la position de grille la plus proche
    function getGridRealPosition(x, y) {
        return Qt.point(
            x / gridSize,
            y / gridSize
        )
    }

    // Fonction pour obtenir la position de grille la plus proche
    function getGridPixelPosition(x, y) {
        return Qt.point(
            x * gridSize,
            y * gridSize
        )
    }

    // Fonctions pour activer/désactiver le mode redimensionnement
    function enterResizeMode() {
        resizeMode = true
    }

    function exitResizeMode() {
        resizeMode = false
    }

    // Le toggle de rendu vient d'un context property posé par qmlapp.cpp
    // (MEOW_GRID_RENDERER → bool). Si la property n'existe pas (ex: chargé
    // hors qmlapp), on retombe sur le mode legacy via `typeof`.
    readonly property bool _useCanvasGrid:
        (typeof _gridRendererUseCanvas !== "undefined") && _gridRendererUseCanvas

    // ─── Mode Canvas (défaut Qt 6.11+) ──────────────────────────────────
    // Le Loader est positionné pour COUVRIR le viewport visible (i.e. la
    // taille du parent du GridManager, qui est le Base_Board) ET aligné en
    // coords écran avec ce parent. Comme le Loader est enfant du GridManager
    // (qui peut être à `gridManager.x ≠ 0` après scroll/zoom), on contre
    // l'offset par `x: -gridManager.x` pour que le canvas couvre toujours
    // le viewport quoi qu'il arrive.
    //
    // Le tracé des lignes en coords canvas-locales utilise `viewportOffsetX/Y`
    // = `gridManager.x/y` pour positionner correctement les lignes par
    // rapport au viewport.
    Loader {
        id: canvasLoader
        active: gridManager._useCanvasGrid && gridManager.showGrid
        source: active ? "GridCanvasLayer.qml" : ""

        x: -gridManager.x
        y: -gridManager.y
        width: gridManager.parent ? gridManager.parent.width : 0
        height: gridManager.parent ? gridManager.parent.height : 0
    }

    // ─── Mode Repeater (legacy, fallback) ───────────────────────────────
    // Loader avec `active: !_useCanvasGrid` : quand le canvas est utilisé,
    // l'Item gridContainer ET ses 1202 Rectangle ne sont JAMAIS instanciés
    // (sourceComponent jamais évalué). Évite tout risque de superposition
    // canvas + Repeater pendant une transition de binding.
    Loader {
        id: repeaterLoader
        anchors.fill: parent
        active: !gridManager._useCanvasGrid && gridManager.showGrid
        sourceComponent: repeaterComponent
    }

    Component {
        id: repeaterComponent
        Item {
            id: gridContainer
            anchors.fill: parent

            property color lightColor:  Qt.lighter(gridManager.gridColor, 1.2)

            property int verticalLinesCount: croisillons + 1
            property int horizontalLinesCount: croisillons + 1
            property int totalLineCount: verticalLinesCount + horizontalLinesCount

            Repeater {
                id: gridLinesRepeater
                model: gridContainer.totalLineCount

                Rectangle {
                    color: gridManager.resizeMode ? gridContainer.lightColor : gridManager.gridColor
                    opacity: gridManager.resizeMode ? 1 : gridManager.gridOpacity
                    visible: gridManager.showGrid

                    readonly property bool isVertical: index < gridContainer.verticalLinesCount
                    readonly property int verticalIndex: isVertical ? index : 0
                    readonly property int horizontalIndex: isVertical ? 0 : index - gridContainer.verticalLinesCount

                    x: isVertical ? verticalIndex * gridManager.gridSize : 0
                    y: isVertical ? 0 : horizontalIndex * gridManager.gridSize

                    width: isVertical ?
                           (gridManager.resizeMode ? gridManager.lineWidth + 1 : gridManager.lineWidth) :
                           parent.width
                    height: isVertical ?
                            parent.height :
                            (gridManager.resizeMode ? gridManager.lineWidth + 1 : gridManager.lineWidth)
                }
            }
        }
    }
}
