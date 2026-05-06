#include "zone_canvas_painter.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zone_canvas_painter_renderer.h"

#include <QPointF>

ZoneCanvasPainter::ZoneCanvasPainter(QQuickItem *parent)
    : QCanvasPainterItem(parent)
{
    // QQuickRhiItem.alphaBlending défaut = false → le rendu est traité
    // comme opaque et le canvas est rempli avec fillColor (= Qt::black par
    // défaut). Activer pour avoir un vrai rendu transparent par-dessus le
    // scene graph QML.
    setAlphaBlending(true);

    // Clear color du canvas en transparent (en plus de alphaBlending).
    setFillColor(Qt::transparent);
}

QCanvasPainterItemRenderer *ZoneCanvasPainter::createItemRenderer() const
{
    return new ZoneCanvasPainterRenderer;
}

void ZoneCanvasPainter::rebuildGridCache()
{
    m_pointsGrid.clear();
    m_pointsGrid.reserve(m_polygonPoints.size());
    for (const QVariant &v : m_polygonPoints) {
        // Accepte point Qt natif (QPointF) ou QVariantMap {x, y} JS.
        if (v.canConvert<QPointF>()) {
            m_pointsGrid.append(v.toPointF());
        } else {
            const QVariantMap m = v.toMap();
            m_pointsGrid.append(QPointF(m.value("x").toReal(),
                                        m.value("y").toReal()));
        }
    }
}

QList<QPointF> ZoneCanvasPainter::polygonPointsPx() const
{
    // Multiplie le cache grille par m_gridSize. Évite de retraverser les
    // QVariant à chaque sync (test canConvert + lookup map = ~60 ns/point).
    QList<QPointF> out;
    const int n = m_pointsGrid.size();
    out.reserve(n);
    const qreal g = m_gridSize;
    for (int i = 0; i < n; ++i) {
        const QPointF &p = m_pointsGrid[i];
        out.append(QPointF(p.x() * g, p.y() * g));
    }
    return out;
}

void ZoneCanvasPainter::setPolygonPoints(const QVariantList &v)
{
    if (m_polygonPoints == v) return;
    m_polygonPoints = v;
    rebuildGridCache();
    emit polygonPointsChanged();
    update();
}

void ZoneCanvasPainter::setGridSize(qreal v)
{
    if (qFuzzyCompare(m_gridSize, v)) return;
    m_gridSize = v;
    emit gridSizeChanged();
    update();
}

void ZoneCanvasPainter::setZoneColor(const QColor &v)
{
    if (m_zoneColor == v) return;
    m_zoneColor = v;
    emit zoneColorChanged();
    update();
}

void ZoneCanvasPainter::setStrokeColor(const QColor &v)
{
    if (m_strokeColor == v) return;
    m_strokeColor = v;
    emit strokeColorChanged();
    update();
}

void ZoneCanvasPainter::setStrokeWidth(qreal v)
{
    if (qFuzzyCompare(m_strokeWidth, v)) return;
    m_strokeWidth = v;
    emit strokeWidthChanged();
    update();
}

void ZoneCanvasPainter::setHatchSpacing(qreal v)
{
    if (qFuzzyCompare(m_hatchSpacing, v)) return;
    m_hatchSpacing = v;
    emit hatchSpacingChanged();
    update();
}

#endif // MEOW_HAS_CANVAS_PAINTER
