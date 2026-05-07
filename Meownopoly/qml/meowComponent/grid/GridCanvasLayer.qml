// Layer GPU pour la grille de l'éditeur. Chargé par GridManager.qml via
// Loader conditionnel uniquement quand `_gridRendererUseCanvas` est true
// (= Qt 6.11+ avec MEOW_HAS_CANVAS_PAINTER ET MEOW_GRID_RENDERER!=repeater).
//
// Isoler l'import MeowPainter dans un fichier séparé évite que Qt 6.10
// fail-fast sur l'import au chargement de GridManager.
//
// Le canvas est positionné par le Loader parent pour COUVRIR le viewport
// visible (Base_Board parent du GridManager), pas la grille entière —
// boardSize peut atteindre 7200×7200 px, un backing store de cette taille
// saturerait la VRAM.
//
// La référence au GridManager est obtenue via `parent.parent` : le Loader
// (parent direct) est lui-même enfant du GridManager.
import QtQuick 2.15
import MeowPainter 1.0

GridCanvasPainter {
    id: layer
    // Loader = parent direct ; GridManager = grandparent.
    readonly property var gridManager: parent && parent.parent ? parent.parent : null

    anchors.fill: parent

    croisillons: gridManager ? gridManager.croisillons : 0
    gridSize: gridManager ? gridManager.gridSize : 1
    gridColor: gridManager ? gridManager.gridColor : "#80808080"
    gridOpacity: gridManager ? gridManager.gridOpacity : 0.5
    lineWidth: gridManager ? gridManager.lineWidth : 1
    resizeMode: gridManager ? gridManager.resizeMode : false
    showGrid: gridManager ? gridManager.showGrid : true

    // Position du GridManager dans son parent — sert d'offset au tracé en
    // coords canvas-locales. Quand l'utilisateur drag/scroll, gridManager.x
    // change → ce binding propage instantanément.
    viewportOffsetX: gridManager ? gridManager.x : 0
    viewportOffsetY: gridManager ? gridManager.y : 0
}
