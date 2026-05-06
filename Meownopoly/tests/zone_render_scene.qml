// Scène QML pilotée par le test C++ tst_zone_render_perf. N'a pas vocation
// à être chargée depuis l'éditeur réel — c'est un harness isolé pour
// instancier N ZoneCanvasPainter et mesurer leur coût de rendu.
import QtQuick
import MeowPainter 1.0

Item {
    id: root
    width: 1280
    height: 720

    // Pilotés par le test C++ via setProperty / Q_INVOKABLE.
    property real gridSize: 30
    property var zonesData: []   // [{ posX, posY, w, h, points: [{x,y}, ...] }, ...]
    property color zoneColor: "#FF5722"
    property color strokeColor: "#B23F1A"
    property real strokeWidth: 2
    property real hatchSpacing: 12

    Repeater {
        model: root.zonesData
        delegate: ZoneCanvasPainter {
            x: modelData.posX
            y: modelData.posY
            width: modelData.w
            height: modelData.h
            polygonPoints: modelData.points
            gridSize: root.gridSize
            zoneColor: root.zoneColor
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            hatchSpacing: root.hatchSpacing
        }
    }
}
