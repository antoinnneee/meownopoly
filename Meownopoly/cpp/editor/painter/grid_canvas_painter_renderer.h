#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItemRenderer>
#include <QColor>
#include <atomic>
#include <cstdint>

class GridCanvasPainter;
class QCanvasPainter;

class GridCanvasPainterRenderer : public QCanvasPainterItemRenderer
{
public:
    GridCanvasPainterRenderer();

    void synchronize(QCanvasPainterItem *item) override;
    void paint(QCanvasPainter *painter) override;

    // Instrumentation perf — comme pour ZoneCanvasPainter, atomic 64 bits
    // accumulés par toutes les instances. Le bench peut reset puis mesurer.
    static std::atomic<std::int64_t> s_totalPaintNs;
    static std::atomic<int> s_paintCalls;
    static std::atomic<std::int64_t> s_totalSyncNs;
    static std::atomic<int> s_syncCalls;
    // Compteurs auxiliaires : nombre de lignes effectivement émises par
    // paint() après culling. Utile pour vérifier que le culling marche.
    static std::atomic<std::int64_t> s_totalLinesEmitted;

    static void resetStats() {
        s_totalPaintNs.store(0, std::memory_order_relaxed);
        s_paintCalls.store(0, std::memory_order_relaxed);
        s_totalSyncNs.store(0, std::memory_order_relaxed);
        s_syncCalls.store(0, std::memory_order_relaxed);
        s_totalLinesEmitted.store(0, std::memory_order_relaxed);
    }

private:
    int m_croisillons = 600;
    qreal m_gridSize = 1.0;
    QColor m_gridColor;
    qreal m_gridOpacity = 0.5;
    qreal m_lineWidth = 1.0;
    bool m_resizeMode = false;
    bool m_showGrid = true;
    qreal m_viewportOffsetX = 0.0;
    qreal m_viewportOffsetY = 0.0;
    qreal m_itemWidth = 0.0;
    qreal m_itemHeight = 0.0;
};

#endif // MEOW_HAS_CANVAS_PAINTER
