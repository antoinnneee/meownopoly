import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window
import ".."


/**
 * GridManager simple et réactif pour l'éditeur
 */
Item {
    id: gridManager

    property int croisillons: 600
    property int mmSize: 12
    property real defaultMmSize: 12.0
    property real scaleLevel: mmSize / defaultMmSize
    property int gridSizeCalc: Screen.pixelDensity * mmSize
    property int gridSize: gridSizeCalc

    property int boardSize:  gridSize * croisillons // 600 croisillons
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

    // Grille ultra-optimisée avec un seul Repeater
    Item {
        id: gridContainer
        anchors.fill: parent

        property color lightColor:  Qt.lighter(gridManager.gridColor, 1.2)

        property int verticalLinesCount: (gridManager.showGrid) ? croisillons + 1
                                                                : 0
        property int horizontalLinesCount: (gridManager.showGrid) ? croisillons + 1
                                                                  :0

        property int totalLineCount:verticalLinesCount+horizontalLinesCount

        Repeater {
            id: gridLinesRepeater
            model:  gridContainer.totalLineCount

            Rectangle {
                // Propriétés communes
                color: gridManager.resizeMode ? gridContainer.lightColor: gridManager.gridColor
                opacity: gridManager.resizeMode ? 1 : gridManager.gridOpacity
                visible: gridManager.showGrid

                // Déterminer si c'est une ligne verticale ou horizontale
                readonly property bool isVertical: index < gridContainer.verticalLinesCount
                readonly property int verticalIndex: isVertical ? index : 0
                readonly property int horizontalIndex: isVertical ? 0 : index - gridContainer.verticalLinesCount

                // Position et taille selon le type de ligne
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
