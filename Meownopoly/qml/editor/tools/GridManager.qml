import QtQuick 2.15
import QtQuick.Controls
import ".."


/**
 * GridManager simple et réactif pour l'éditeur
 */
Item {
    id: gridManager
    
    // Propriétés configurables
    required property var logic
    property int mmSize: logic.mmSize
    onMmSizeChanged: {
        console.log("mmSize changed:", mmSize)
        gridSize = Screen.pixelDensity * mmSize
    }
    
    function updateSize(mm) {
        if (mm > 0)
            mmSize = mm
    }

    property int gridSize: Screen.pixelDensity * mmSize
    onGridSizeChanged: {
        console.log("gridSize changed:", gridSize)
        // Les Repeater se mettent à jour automatiquement quand gridSize change
    }

    property int boardSize:  gridSize * 600 // 600 croisillons
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


    width: boardSize
    height: boardSize
    
    // Fonction pour snapper une coordonnée à la grille
    function snapToGridCoord(value) {
        if (!snapToGrid) return value
        return Math.round(value / gridSize) * gridSize
    }
    
    // Fonction pour snapper un point (x, y) à la grille
    function snapPoint(x, y) {
        return Qt.point(snapToGridCoord(x), snapToGridCoord(y))
    }
    
    // Fonction alternative qui snap directement un élément (plus pratique)
    function snapElement2(element) {
        if (!snapToGrid) return
        var posGridX = element.displaySettings.gridRelativePositionX * gridSize
        var posGridY = element.displaySettings.gridRelativePositionY * gridSize
        var elementWidth = element.displaySettings.unitSizeWidth * gridSize
        var elementHeight = element.displaySettings.unitSizeHeight * gridSize
        element.x = posGridX
        element.y =posGridY
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

    // Fonction pour centrer la vue sur un élément donné
    function centeredOnElement(element) {
        if (!element) return

        // Calculer la position centrale de l'élément
        var elementCenterX = element.x + element.width / 2
        var elementCenterY = element.y + element.height / 2

        // Calculer la position du GridManager pour centrer l'élément dans la vue
        // Supposer que la vue parent a une taille connue (peut être ajustée selon le contexte)
        var parentCenterX = parent ? parent.width / 2 : width / 2
        var parentCenterY = parent ? parent.height / 2 : height / 2

        // Calculer le décalage nécessaire pour centrer l'élément
        var offsetX = parentCenterX - elementCenterX
        var offsetY = parentCenterY - elementCenterY

        // Appliquer le décalage au GridManager
        gridManager.x = offsetX
        gridManager.y = offsetY

        console.log("GridManager moved to:", gridManager.x, gridManager.y)
    }

    // Fonction pour centrer la vue sur un élément donné
    function moveToConfigElement(element) {
        if (!element) return

        // Calculer la position centrale de l'élément
        var elementCenterX = element.x + element.width / 2
        var elementCenterY = element.y + element.height / 2

        // Calculer la position du GridManager pour centrer l'élément dans la vue
        // Supposer que la vue parent a une taille connue (peut être ajustée selon le contexte)
        var parentCenterX = parent ? parent.width * 0.75 : width / 2
        var parentCenterY = parent ? parent.height / 2 : height / 2

        // Calculer le décalage nécessaire pour centrer l'élément
        var offsetX = parentCenterX - elementCenterX
        var offsetY = parentCenterY - elementCenterY

        // Appliquer le décalage au GridManager
        gridManager.x = offsetX
        gridManager.y = offsetY

        console.log("GridManager moved to:", gridManager.x, gridManager.y)
    }
    
    function moveToGridCenter()
    {

        // Appliquer le décalage au GridManager
        var parentCenterX = parent ? parent.width / 2 : width / 2
        var parentCenterY = parent ? parent.height / 2 : height / 2
        gridManager.x = parentCenterX - width/2
        gridManager.y = parentCenterY - height/2
        console.log("GridManager moved to:", gridManager.x, gridManager.y)
    }


    // Grille ultra-optimisée avec un seul Repeater
    Item {
        id: gridContainer
        anchors.fill: parent

        property int verticalLinesCount: Math.ceil(width / gridManager.gridSize) + 1
        property int horizontalLinesCount: Math.ceil(height / gridManager.gridSize) + 1

        Repeater {
            id: gridLinesRepeater
            model: parent.verticalLinesCount + parent.horizontalLinesCount

            Rectangle {
                // Propriétés communes
                color: gridManager.resizeMode ? Qt.lighter(gridManager.gridColor, 1.2) : gridManager.gridColor
                opacity: gridManager.resizeMode ? Math.min(1.0, gridManager.gridOpacity + 0.3) : gridManager.gridOpacity
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

                // Masquer les lignes qui dépassent les limites
                // visible: visible && (isVertical ? x < parent.width : y < parent.height)
            }
        }
    }

    // Les propriétés se mettent à jour automatiquement via les bindings QML
    // Pas besoin de Connections supplémentaires avec l'approche Repeater
    MouseArea{
        anchors.fill: parent
        drag.target: isEdit ? null : gridManager
        pressAndHoldInterval: 200
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton){
                console.log("click location : ", mouseX, mouseY)
                console.log("grid location : ", gridManager.getGridPosition(mouseX, mouseY))
                gridManager.gridClicked(gridManager.getGridPosition(mouseX, mouseY))
            }
            if (mouse.button === Qt.RightButton){
                gridManager.gridRightClicked(gridManager.getGridPosition(mouseX, mouseY))
            }
        }

        onPressAndHold: {
            console.log("click location : ", mouseX, mouseY)
            console.log("grid location : ", gridManager.getGridPosition(mouseX, mouseY))
            gridManager.gridPressed(gridManager.getGridPosition(mouseX, mouseY))
        }
    }

}
