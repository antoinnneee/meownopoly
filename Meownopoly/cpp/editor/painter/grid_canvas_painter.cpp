#include "grid_canvas_painter.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "grid_canvas_painter_renderer.h"

GridCanvasPainter::GridCanvasPainter(QQuickItem *parent)
    : QCanvasPainterItem(parent)
{
    // Cf. ZoneCanvasPainter : par défaut alphaBlending=false, le canvas
    // est traité comme opaque et rempli de noir. Activer pour rendu
    // transparent par-dessus le background du board.
    setAlphaBlending(true);
    setFillColor(Qt::transparent);
}

GridCanvasPainter::~GridCanvasPainter() = default;

QCanvasPainterItemRenderer *GridCanvasPainter::createItemRenderer() const
{
    return new GridCanvasPainterRenderer;
}

void GridCanvasPainter::setCroisillons(int v)
{
    if (m_croisillons == v) return;
    m_croisillons = v;
    emit croisillonsChanged();
    update();
}

void GridCanvasPainter::setGridSize(qreal v)
{
    if (qFuzzyCompare(m_gridSize, v)) return;
    m_gridSize = v;
    emit gridSizeChanged();
    update();
}

void GridCanvasPainter::setGridColor(const QColor &v)
{
    if (m_gridColor == v) return;
    m_gridColor = v;
    emit gridColorChanged();
    update();
}

void GridCanvasPainter::setGridOpacity(qreal v)
{
    if (qFuzzyCompare(m_gridOpacity, v)) return;
    m_gridOpacity = v;
    emit gridOpacityChanged();
    update();
}

void GridCanvasPainter::setLineWidth(qreal v)
{
    if (qFuzzyCompare(m_lineWidth, v)) return;
    m_lineWidth = v;
    emit lineWidthChanged();
    update();
}

void GridCanvasPainter::setResizeMode(bool v)
{
    if (m_resizeMode == v) return;
    m_resizeMode = v;
    emit resizeModeChanged();
    update();
}

void GridCanvasPainter::setShowGrid(bool v)
{
    if (m_showGrid == v) return;
    m_showGrid = v;
    emit showGridChanged();
    update();
}

void GridCanvasPainter::setViewportOffsetX(qreal v)
{
    if (qFuzzyCompare(m_viewportOffsetX, v)) return;
    m_viewportOffsetX = v;
    emit viewportOffsetXChanged();
    update();
}

void GridCanvasPainter::setViewportOffsetY(qreal v)
{
    if (qFuzzyCompare(m_viewportOffsetY, v)) return;
    m_viewportOffsetY = v;
    emit viewportOffsetYChanged();
    update();
}

#endif // MEOW_HAS_CANVAS_PAINTER
