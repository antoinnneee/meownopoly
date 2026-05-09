import QtQuick 2.15
import QtQuick.Controls
import "../grid"

import ItemSnapable
import ZoneParameter
import MeowPainter 1.0

/**
 * Zone d'exclusion polygonale avec hachures.
 * Visible uniquement en mode édition. Hérite de SnapableElement pour être
 * compatible avec snapableTilesList.
 *
 * Le rendu (fill + contour + hachures) est délégué à un ZoneCanvasPainter
 * (C++, QtCanvasPainter Qt 6.11+) interne — rendu GPU natif via QRhi avec
 * hachures pré-calculées en parallèle (QtConcurrent). Pas de cache, pas
 * de timer débounce : le composant se met à jour automatiquement quand
 * polygonPoints, gridSize ou les couleurs changent.
 */
SnapableElement {
    id: root

    // Désactiver le redimensionnement classique (on utilise les points du polygone)
    isResizable: false
    autoSnap: false

    // Visibilité conditionnelle : uniquement en mode édition
    visible: gridManager.isEdit
    opacity: isSelected ? 1.0 : 0.7

    // Couleur transparente pour le rectangle de base
    elementColor: "transparent"
    borderWidth: 0

    // Propriétés de style
    property color zoneColor: snapableParameters.zoneParameter ?
                              snapableParameters.zoneParameter.zoneColor : "#FF5722"
    property color strokeColor: Qt.darker(zoneColor, 1.3)
    property int zoneStrokeWidth: isSelected ? 3 : 2
    property real hatchSpacing: 12

    // Position de grille de l'élément
    property real gridPosX: snapableParameters.displayParameter.gridRelativePositionX
    property real gridPosY: snapableParameters.displayParameter.gridRelativePositionY

    // ─── Rendu GPU ──────────────────────────────────────────────────────
    // Délégué à un `ZonesOverlayPainter` global instancié dans Editor.qml :
    // un seul canvas viewport-cullé pour TOUTES les zones, au lieu d'un
    // par tile. Sans ça, à mmSize élevé chaque ZoneCanvasPainter alloue
    // un backing texture énorme (zone × gridSize) que Qt re-alloue à
    // chaque cran de zoom → freezes ponctuels.
    //
    // Le ZoneCanvasPainter local est conservé sous Loader pour les
    // contextes hors-éditeur (preview cursors, game runtime) ET comme
    // fallback `MEOW_ZONES_RENDERER=per-tile`. Important : utiliser un
    // Loader (pas juste `visible: false`) pour ne PAS instancier l'item
    // quand l'overlay est actif — un canvas painter invisible mais
    // existant continue de réallouer son backing texture au zoom (`width`
    // suit `gridSize`), ce qui annulerait le gain de l'overlay.
    // Override pour forcer le rendu local (preview cursors hors snapableTilesList,
    // que l'overlay global ne voit pas).
    property bool forceLocalRenderer: false
    readonly property bool _useGlobalOverlay:
        !forceLocalRenderer && (typeof _useZonesOverlay !== "undefined") && _useZonesOverlay

    Loader {
        id: zonePainterLoader
        anchors.fill: parent
        z: 0
        active: !root._useGlobalOverlay
        sourceComponent: zonePainterComponent
    }

    Component {
        id: zonePainterComponent
        ZoneCanvasPainter {
            anchors.fill: parent
            polygonPoints: snapableParameters.zoneParameter
                           ? snapableParameters.zoneParameter.polygonPoints
                           : []
            gridSize: gridManager.gridSize
            zoneColor: root.zoneColor
            strokeColor: root.strokeColor
            strokeWidth: root.zoneStrokeWidth
            hatchSpacing: root.hatchSpacing
        }
    }

    // ─── Hit-testing ────────────────────────────────────────────────────
    // Override isTransparent pour utiliser la détection polygonale
    function isTransparent(mouse) {
        return !isPointInPolygon(mouse.x, mouse.y)
    }

    // Ray casting sur les points en pixels locaux. Recalcule à la volée
    // (pas de cache) — appelée seulement au clic, pas hot path.
    function isPointInPolygon(px, py) {
        var zp = snapableParameters.zoneParameter
        if (!zp) return false
        var gridPoints = zp.polygonPoints
        var n = gridPoints.length
        if (n < 3) return false
        var gs = gridManager.gridSize

        var inside = false
        var j = n - 1
        for (var i = 0; i < n; i++) {
            var xi = gridPoints[i].x * gs, yi = gridPoints[i].y * gs
            var xj = gridPoints[j].x * gs, yj = gridPoints[j].y * gs
            if (((yi > py) !== (yj > py)) &&
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    // Bounds pixel min du polygone (pour le label de zone). Bindé sur
    // polygonPoints + gridSize → se met à jour automatiquement. Calculé
    // seulement quand le label est visible (isSelected).
    readonly property point polygonMinPx: {
        var zp = snapableParameters.zoneParameter
        if (!zp) return Qt.point(0, 0)
        var pts = zp.polygonPoints
        var n = pts.length
        if (n === 0) return Qt.point(0, 0)
        var gs = gridManager.gridSize
        var mnx = pts[0].x, mny = pts[0].y
        for (var i = 1; i < n; i++) {
            if (pts[i].x < mnx) mnx = pts[i].x
            if (pts[i].y < mny) mny = pts[i].y
        }
        return Qt.point(mnx * gs, mny * gs)
    }

    // ─── Points de contrôle pour l'édition ──────────────────────────────
    Repeater {
        id: controlPointsRepeater
        model: root.isSelected ? root.getPointCount() : 0

        delegate: Rectangle {
            id: controlPoint

            readonly property int pointIndex: index
            property real pointGridX: root.getPointX(pointIndex)
            property real pointGridY: root.getPointY(pointIndex)
            property bool isDragging: false

            width: 12
            height: 12
            radius: 6
            color: isDragging ? Qt.lighter(root.zoneColor, 1.3) : root.zoneColor
            border.color: "white"
            border.width: 2
            z: 100

            x: isDragging ? x : (pointGridX * root.gridManager.gridSize - width / 2)
            y: isDragging ? y : (pointGridY * root.gridManager.gridSize - height / 2)

            Drag.active: dragArea.drag.active

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                drag.target: parent
                drag.threshold: 0

                onPressed: function(mouse) {
                    controlPoint.isDragging = true
                    mouse.accepted = true
                }

                onReleased: function(mouse) {
                    if (controlPoint.isDragging) {
                        var newLocalX = controlPoint.x + controlPoint.width / 2
                        var newLocalY = controlPoint.y + controlPoint.height / 2
                        var newGridX = newLocalX / root.gridManager.gridSize
                        var newGridY = newLocalY / root.gridManager.gridSize
                        root.updatePointPosition(controlPoint.pointIndex, newGridX, newGridY)
                        controlPoint.isDragging = false
                    }
                }
            }
        }
    }

    // ─── Helpers d'accès aux points (utilisés par le Repeater) ──────────
    function getPointCount() {
        if (!snapableParameters.zoneParameter) return 0
        return snapableParameters.zoneParameter.polygonPoints.length
    }

    function getPointX(idx) {
        if (!snapableParameters.zoneParameter) return 0
        var points = snapableParameters.zoneParameter.polygonPoints
        if (idx >= 0 && idx < points.length) {
            return points[idx].x
        }
        return 0
    }

    function getPointY(idx) {
        if (!snapableParameters.zoneParameter) return 0
        var points = snapableParameters.zoneParameter.polygonPoints
        if (idx >= 0 && idx < points.length) {
            return points[idx].y
        }
        return 0
    }

    function updatePointPosition(idx, newX, newY) {
        if (!snapableParameters.zoneParameter) return
        var points = snapableParameters.zoneParameter.polygonPoints
        if (idx >= 0 && idx < points.length) {
            var newPoints = []
            for (var i = 0; i < points.length; i++) {
                if (i === idx) {
                    newPoints.push({ x: newX, y: newY })
                } else {
                    newPoints.push({ x: points[i].x, y: points[i].y })
                }
            }
            snapableParameters.zoneParameter.polygonPoints = newPoints
            updateDisplayBounds()
            snapToGridFromGridPos(gridPosX, gridPosY)
        }
    }

    // Mettre à jour les bounds du displayParameter après modification des points
    function updateDisplayBounds() {
        if (!snapableParameters.zoneParameter) return
        var points = snapableParameters.zoneParameter.polygonPoints
        if (points.length === 0) return

        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y

        for (var i = 1; i < points.length; i++) {
            minX = Math.min(minX, points[i].x)
            maxX = Math.max(maxX, points[i].x)
            minY = Math.min(minY, points[i].y)
            maxY = Math.max(maxY, points[i].y)
        }

        var shiftX = Math.floor(minX)
        var shiftY = Math.floor(minY)
        if (shiftX !== 0 || shiftY !== 0) {
            snapableParameters.displayParameter.gridRelativePositionX += shiftX
            snapableParameters.displayParameter.gridRelativePositionY += shiftY
            var newPoints = []
            for (var i = 0; i < points.length; i++) {
                newPoints.push({ x: points[i].x - shiftX, y: points[i].y - shiftY })
            }
            snapableParameters.zoneParameter.polygonPoints = newPoints
            minX -= shiftX
            maxX -= shiftX
            minY -= shiftY
            maxY -= shiftY
        }

        snapableParameters.displayParameter.unitSizeWidth = Math.ceil(maxX) - Math.floor(minX)
        snapableParameters.displayParameter.unitSizeHeight = Math.ceil(maxY) - Math.floor(minY)
    }

    // ─── Label de zone (visible quand sélectionné) ──────────────────────
    Text {
        id: zoneLabel
        visible: root.isSelected && root.snapableParameters.zoneParameter &&
                 root.snapableParameters.zoneParameter.zoneName !== ""
        text: root.snapableParameters.zoneParameter ? root.snapableParameters.zoneParameter.zoneName : ""
        color: "white"
        font.pixelSize: 14
        font.bold: true
        z: 101

        x: root.polygonMinPx.x + 5
        y: root.polygonMinPx.y + 5

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            color: Qt.rgba(0, 0, 0, 0.6)
            radius: 3
            z: -1
        }
    }
}
