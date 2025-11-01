import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window
import ".."


/**
 * GridManager simple et réactif pour l'éditeur
 */
Item {
    id: gridManager

    required property var logic



    property int mmSize: logic.mmSize
    property int gridSize: Screen.pixelDensity * mmSize
    property int boardSize:  gridSize * 600 // 600 croisillons
    // Propriétés configurables
    width: boardSize
    height: boardSize

    onGridSizeChanged: {
        console.log("gridsize change :", mmSize, boardSize)
        console.log("width height :", width, height)
       var newVerticalLinesCount = (gridManager.showGrid) ? Math.ceil(width / gridManager.gridSize) + 1
                                                            : 0
       var newHorizontalLinesCount = (gridManager.showGrid) ? Math.ceil(height / gridManager.gridSize) + 1
                                                            : 0
        if (newVerticalLinesCount > gridContainer.verticalLinesCount || newHorizontalLinesCount > gridContainer.horizontalLinesCount) {
            gridContainer.verticalLinesCount = newVerticalLinesCount
            gridContainer.horizontalLinesCount = newHorizontalLinesCount
        }
        console.log("gridsize change :", newVerticalLinesCount, newHorizontalLinesCount, mmSize)
    }

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
    property bool isSelectionActive: false
    
    // Signal émis quand les paramètres changent
    signal gridSettingsChanged()
    signal gridPressed(var position)
    signal gridClicked(var position)
    signal gridRightClicked(var position)


    // Fonction alternative qui snap directement un élément (plus pratique)
    function snapElement2(element) {
        if (!snapToGrid) return
        var posGridX = element.snapableParameters.displayParameter.gridRelativePositionX * gridSize
        var posGridY = element.snapableParameters.displayParameter.gridRelativePositionY * gridSize
        var elementWidth = element.snapableParameters.displayParameter.unitSizeWidth * gridSize
        var elementHeight = element.snapableParameters.displayParameter.unitSizeHeight * gridSize
        element.x = posGridX
        element.y = posGridY
    }

    // Fonction pour obtenir la position de grille la plus proche
    function getGridPosition(x, y) {
        return Qt.point(
            Math.floor(x / gridSize),
            Math.floor(y / gridSize)
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

        property int verticalLinesCount: (gridManager.showGrid) ? Math.ceil(width / gridManager.gridSize) + 1
                                                                : 0
        property int horizontalLinesCount: (gridManager.showGrid) ? Math.ceil(height / gridManager.gridSize) + 1
                                                                  :0

        Repeater {
            id: gridLinesRepeater
            model:  parent.verticalLinesCount + parent.horizontalLinesCount

            Rectangle {
                // Propriétés communes
                color: gridManager.resizeMode ? gridContainer.lightColor: gridManager.gridColor
                opacity: gridManager.resizeMode ? 1 : gridManager.gridOpacity
                visible: gridManager.showGrid

                // Déterminer si c'est une ligne verticale ou horizontale
                readonly property bool isVertical: index < gridContainer.verticalLinesCount
                readonly property int verticalIndex: isVertical ? index : -1
                readonly property int horizontalIndex: isVertical ? -1 : index - gridContainer.verticalLinesCount

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
