#include "zones_overlay_painter.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zones_overlay_painter_renderer.h"

ZonesOverlayPainter::ZonesOverlayPainter(QQuickItem *parent)
    : QCanvasPainterItem(parent)
{
    // Cf. ZoneCanvasPainter / GridCanvasPainter : alphaBlending=true +
    // fillColor transparent pour dessiner par-dessus la grille sans
    // remplir le canvas en noir opaque.
    setAlphaBlending(true);
    setFillColor(Qt::transparent);
}

ZonesOverlayPainter::~ZonesOverlayPainter() = default;

QCanvasPainterItemRenderer *ZonesOverlayPainter::createItemRenderer() const
{
    return new ZonesOverlayPainterRenderer;
}

void ZonesOverlayPainter::setZones(const QVariantList &v)
{
    if (m_zones == v) return;
    m_zones = v;
    emit zonesChanged();
    update();
}

void ZonesOverlayPainter::setGridSize(qreal v)
{
    if (qFuzzyCompare(m_gridSize, v)) return;
    m_gridSize = v;
    emit gridSizeChanged();
    update();
}

void ZonesOverlayPainter::setViewportOffsetX(qreal v)
{
    if (qFuzzyCompare(m_viewportOffsetX, v)) return;
    m_viewportOffsetX = v;
    emit viewportOffsetXChanged();
    update();
}

void ZonesOverlayPainter::setViewportOffsetY(qreal v)
{
    if (qFuzzyCompare(m_viewportOffsetY, v)) return;
    m_viewportOffsetY = v;
    emit viewportOffsetYChanged();
    update();
}

#endif // MEOW_HAS_CANVAS_PAINTER
