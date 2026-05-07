// Scène QML pilotée par tst_combined_render_perf. Combine la grille
// (GridCanvasPainter ou Repeater legacy) ET les zones d'exclusion
// (ZoneCanvasPainter) dans une même scène — reproduit le contexte réel
// de l'éditeur pour mesurer le coût combiné, à partir d'une map JSON
// chargée et parsée côté C++.
//
// Le toggle de la grille est piloté par le context property
// `_gridRendererUseCanvas` posé par le test C++ avant chargement.
import QtQuick
import MeowPainter 1.0

Item {
    id: root
    width: 1280
    height: 720

    // Pilotés par le test C++ via setProperty.
    property int croisillons: 600
    // mmSize en real pour permettre le zoom multiplicatif (×1.2 par cran).
    property real mmSize: 12.0
    property real gridX: 0
    property real gridY: 0

    // Liste de zones : [{ posX, posY, w, h, points: [{x,y}, ...], color }, ...]
    // Posx/posY/w/h sont en pixels (déjà multipliés par gridSize côté C++).
    property var zonesData: []

    readonly property real gridSize: mmSize
    readonly property real boardSize: gridSize * croisillons

    readonly property bool useCanvas:
        (typeof _gridRendererUseCanvas !== "undefined") && _gridRendererUseCanvas

    Item {
        id: viewportClip
        anchors.fill: parent
        clip: true

        Item {
            id: gridManager
            x: root.gridX
            y: root.gridY
            width: root.boardSize
            height: root.boardSize

            // ─── Grille : mode Canvas ───────────────────────────────────
            GridCanvasPainter {
                id: gridCanvas
                visible: root.useCanvas

                x: -gridManager.x
                y: -gridManager.y
                width: viewportClip.width
                height: viewportClip.height

                croisillons: root.croisillons
                gridSize: root.gridSize
                gridColor: "#80808080"
                gridOpacity: 0.5
                lineWidth: 1
                showGrid: true
                viewportOffsetX: gridManager.x
                viewportOffsetY: gridManager.y
            }

            // ─── Grille : mode Repeater (legacy) ───────────────────────
            Item {
                id: gridContainer
                anchors.fill: parent
                visible: !root.useCanvas

                property int linesCount: root.useCanvas ? 0 : (root.croisillons + 1)
                property int totalLineCount: linesCount * 2

                Repeater {
                    model: gridContainer.totalLineCount
                    Rectangle {
                        color: "#80808080"
                        opacity: 0.5
                        readonly property bool isVertical: index < gridContainer.linesCount
                        readonly property int verticalIndex: isVertical ? index : 0
                        readonly property int horizontalIndex: isVertical ? 0 : index - gridContainer.linesCount
                        x: isVertical ? verticalIndex * root.gridSize : 0
                        y: isVertical ? 0 : horizontalIndex * root.gridSize
                        width: isVertical ? 1 : parent.width
                        height: isVertical ? parent.height : 1
                    }
                }
            }

            // ─── Zones d'exclusion (issues de test_map.json) ───────────
            Repeater {
                model: root.zonesData
                delegate: ZoneCanvasPainter {
                    x: modelData.posX
                    y: modelData.posY
                    width: modelData.w
                    height: modelData.h
                    polygonPoints: modelData.points
                    gridSize: root.gridSize
                    zoneColor: modelData.color
                    strokeColor: Qt.darker(modelData.color, 1.3)
                    strokeWidth: 2
                    hatchSpacing: 12
                }
            }
        }
    }
}
