#include "grid_canvas_painter_renderer.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "grid_canvas_painter.h"

#include <QElapsedTimer>
#include <QtCanvasPainter/QCanvasPainter>

#include <algorithm>
#include <cmath>

std::atomic<std::int64_t> GridCanvasPainterRenderer::s_totalPaintNs{0};
std::atomic<int> GridCanvasPainterRenderer::s_paintCalls{0};
std::atomic<std::int64_t> GridCanvasPainterRenderer::s_totalSyncNs{0};
std::atomic<int> GridCanvasPainterRenderer::s_syncCalls{0};
std::atomic<std::int64_t> GridCanvasPainterRenderer::s_totalLinesEmitted{0};

GridCanvasPainterRenderer::GridCanvasPainterRenderer() = default;

void GridCanvasPainterRenderer::synchronize(QCanvasPainterItem *item)
{
    QElapsedTimer t;
    t.start();
    auto *grid = static_cast<GridCanvasPainter *>(item);
    m_croisillons = grid->croisillons();
    m_gridSize = grid->gridSize();
    m_gridColor = grid->gridColor();
    m_gridOpacity = grid->gridOpacity();
    m_lineWidth = grid->lineWidth();
    m_resizeMode = grid->resizeMode();
    m_showGrid = grid->showGrid();
    m_viewportOffsetX = grid->viewportOffsetX();
    m_viewportOffsetY = grid->viewportOffsetY();
    m_itemWidth = grid->width();
    m_itemHeight = grid->height();
    s_totalSyncNs.fetch_add(t.nsecsElapsed(), std::memory_order_relaxed);
    s_syncCalls.fetch_add(1, std::memory_order_relaxed);
}

void GridCanvasPainterRenderer::paint(QCanvasPainter *painter)
{
    if (!m_showGrid) return;
    if (m_gridSize <= 0.0) return;
    if (m_itemWidth <= 0.0 || m_itemHeight <= 0.0) return;

    QElapsedTimer t;
    t.start();

    // Le canvas couvre le viewport visible en coords écran. La grille
    // commence à coords canvas-local (m_viewportOffsetX, m_viewportOffsetY)
    // — c'est-à-dire l'origine du GridManager dans son parent (Base_Board).
    //
    // Indice de la première ligne verticale visible dans le canvas :
    //   x_canvas = viewportOffsetX + i * gridSize
    //   visible si 0 <= x_canvas <= itemWidth
    //   → i in [-viewportOffsetX / gridSize, (itemWidth - viewportOffsetX) / gridSize]
    // Clamp avec [0, croisillons].
    const qreal gs = m_gridSize;
    const qreal offX = m_viewportOffsetX;
    const qreal offY = m_viewportOffsetY;

    const int firstX = std::max<int>(0,
        static_cast<int>(std::ceil((-offX) / gs)));
    const int lastX = std::min<int>(m_croisillons,
        static_cast<int>(std::floor((m_itemWidth - offX) / gs)));
    const int firstY = std::max<int>(0,
        static_cast<int>(std::ceil((-offY) / gs)));
    const int lastY = std::min<int>(m_croisillons,
        static_cast<int>(std::floor((m_itemHeight - offY) / gs)));

    if (firstX > lastX && firstY > lastY) {
        s_totalPaintNs.fetch_add(t.nsecsElapsed(), std::memory_order_relaxed);
        s_paintCalls.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    // En resize-mode on intensifie : couleur plus claire, opacité 1.0,
    // ligne +1px. Reproduit le comportement du Repeater historique.
    QColor col = m_gridColor;
    qreal alpha = m_gridOpacity;
    qreal lw = m_lineWidth;
    if (m_resizeMode) {
        col = col.lighter(120);
        alpha = 1.0;
        lw += 1.0;
    }

    painter->setGlobalAlpha(static_cast<float>(alpha));
    painter->setStrokeStyle(col);
    painter->setLineWidth(static_cast<float>(lw));
    painter->setLineCap(QCanvasPainter::LineCap::Butt);

    // Bords de la grille en coords canvas-locales : la grille occupe
    // [offX, offX + croisillons*gs] en x et [offY, offY + croisillons*gs]
    // en y. On clampe au viewport [0, itemWidth/Height] pour ne pas
    // déborder. Les lignes verticales sont tracées entre yTop/yBottom,
    // les horizontales entre xLeft/xRight — sinon les lignes au bord
    // (i=0, croisillons) traverseraient l'infini hors-grille (le
    // Repeater original ne le faisait pas car ses Rectangle étaient
    // enfants d'un gridContainer borné à boardSize×boardSize).
    const qreal gridMaxX = offX + m_croisillons * gs;
    const qreal gridMaxY = offY + m_croisillons * gs;
    const qreal yTop    = std::max<qreal>(0.0, offY);
    const qreal yBottom = std::min<qreal>(m_itemHeight, gridMaxY);
    const qreal xLeft   = std::max<qreal>(0.0, offX);
    const qreal xRight  = std::min<qreal>(m_itemWidth, gridMaxX);

    // Un seul beginPath/stroke pour toutes les lignes — un draw call GPU,
    // au lieu de N strokes coûteux.
    painter->beginPath();

    int linesEmitted = 0;
    if (yBottom > yTop) {
        for (int i = firstX; i <= lastX; ++i) {
            const qreal x = offX + i * gs;
            // Pixel-snap pour des lignes 1px nettes : .5 d'offset force un
            // remplissage centré sur la colonne pixel.
            const qreal xs = std::floor(x) + 0.5;
            painter->moveTo(QPointF(xs, yTop));
            painter->lineTo(QPointF(xs, yBottom));
            ++linesEmitted;
        }
    }
    if (xRight > xLeft) {
        for (int j = firstY; j <= lastY; ++j) {
            const qreal y = offY + j * gs;
            const qreal ys = std::floor(y) + 0.5;
            painter->moveTo(QPointF(xLeft, ys));
            painter->lineTo(QPointF(xRight, ys));
            ++linesEmitted;
        }
    }
    painter->stroke();

    painter->setGlobalAlpha(1.0f);

    s_totalLinesEmitted.fetch_add(linesEmitted, std::memory_order_relaxed);
    s_totalPaintNs.fetch_add(t.nsecsElapsed(), std::memory_order_relaxed);
    s_paintCalls.fetch_add(1, std::memory_order_relaxed);
}

#endif // MEOW_HAS_CANVAS_PAINTER
