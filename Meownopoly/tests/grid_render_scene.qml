// Scène QML pilotée par tst_grid_render_perf. Mesure isolément le coût
// du Repeater (legacy) vs GridCanvasPainter — ne dépend PAS de
// GridManager.qml pour rester portable hors-tree (le chemin relatif vers
// les sources QML serait fragile).
//
// Le toggle entre les deux renderers est piloté par le context property
// `_gridRendererUseCanvas` posé par le test C++ avant chargement.
//
// Architecture : un viewport (root, 1280×720) qui clip un Item
// gridManager virtuel (boardSize × boardSize). Le gridManager peut être
// translaté via gridX/gridY (= scroll/pan). Le rendu de la grille est
// soit (a) le Repeater direct enfant du gridManager, soit (b) un
// GridCanvasPainter dont l'item couvre le viewport visible et reçoit
// les paramètres + offset.
import QtQuick
import MeowPainter 1.0

Item {
    id: root
    width: 1280
    height: 720

    // Pilotés par le test C++ via setProperty.
    property int croisillons: 600
    property int mmSize: 12
    property color gridColor: "#80808080"
    property real gridOpacity: 0.5
    property int lineWidth: 1
    property bool resizeMode: false
    property bool showGrid: true
    property real gridX: 0
    property real gridY: 0

    // Reproduit le calcul de GridManager (Screen.pixelDensity * mmSize).
    // En offscreen, la pixel density peut varier selon la machine ;
    // pour un bench reproductible on prend une valeur fixe = mmSize.
    readonly property int gridSize: mmSize
    readonly property int boardSize: gridSize * croisillons

    readonly property bool useCanvas:
        (typeof _gridRendererUseCanvas !== "undefined") && _gridRendererUseCanvas

    Item {
        id: viewportClip
        anchors.fill: parent
        clip: true

        // GridManager virtuel : container des lignes (mode Repeater) +
        // ancre pour positionner le canvas (mode Canvas).
        Item {
            id: gridManager
            x: root.gridX
            y: root.gridY
            width: root.boardSize
            height: root.boardSize

            // ─── Mode Canvas ───────────────────────────────────────────
            // Le canvas couvre le viewport visible, est positionné en
            // -gridManager.x/-gridManager.y pour rester aligné au viewport.
            GridCanvasPainter {
                id: gridCanvas
                visible: root.useCanvas && root.showGrid

                x: -gridManager.x
                y: -gridManager.y
                width: viewportClip.width
                height: viewportClip.height

                croisillons: root.croisillons
                gridSize: root.gridSize
                gridColor: root.gridColor
                gridOpacity: root.gridOpacity
                lineWidth: root.lineWidth
                resizeMode: root.resizeMode
                showGrid: root.showGrid
                viewportOffsetX: gridManager.x
                viewportOffsetY: gridManager.y
            }

            // ─── Mode Repeater (legacy) ────────────────────────────────
            Item {
                id: gridContainer
                anchors.fill: parent
                visible: !root.useCanvas

                property color lightColor: Qt.lighter(root.gridColor, 1.2)

                // Identique à GridManager.qml : génère 1202 Rectangle
                // pour 600 croisillons. Quand useCanvas est true, on ne
                // crée AUCUN Rectangle (model = 0).
                property int verticalLinesCount:
                    (root.showGrid && !root.useCanvas) ? root.croisillons + 1 : 0
                property int horizontalLinesCount:
                    (root.showGrid && !root.useCanvas) ? root.croisillons + 1 : 0
                property int totalLineCount: verticalLinesCount + horizontalLinesCount

                Repeater {
                    model: gridContainer.totalLineCount

                    Rectangle {
                        color: root.resizeMode ? gridContainer.lightColor : root.gridColor
                        opacity: root.resizeMode ? 1 : root.gridOpacity
                        visible: root.showGrid

                        readonly property bool isVertical: index < gridContainer.verticalLinesCount
                        readonly property int verticalIndex: isVertical ? index : 0
                        readonly property int horizontalIndex: isVertical ? 0 : index - gridContainer.verticalLinesCount

                        x: isVertical ? verticalIndex * root.gridSize : 0
                        y: isVertical ? 0 : horizontalIndex * root.gridSize

                        width: isVertical ?
                               (root.resizeMode ? root.lineWidth + 1 : root.lineWidth) :
                               parent.width
                        height: isVertical ?
                                parent.height :
                                (root.resizeMode ? root.lineWidth + 1 : root.lineWidth)
                    }
                }
            }
        }
    }
}
