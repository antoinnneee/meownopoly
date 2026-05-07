#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItemRenderer>
#include <QColor>
#include <QList>
#include <QPointF>
#include <QVariantList>
#include <QVector>
#include <atomic>
#include <cstdint>

class ZonesOverlayPainter;
class QCanvasPainter;

class ZonesOverlayPainterRenderer : public QCanvasPainterItemRenderer
{
public:
    ZonesOverlayPainterRenderer();

    void synchronize(QCanvasPainterItem *item) override;
    void paint(QCanvasPainter *painter) override;

    // Instrumentation perf.
    static std::atomic<std::int64_t> s_totalPaintNs;
    static std::atomic<int> s_paintCalls;
    static std::atomic<int> s_zonesDrawn;
    static std::atomic<int> s_zonesCulled;
    static void resetStats() {
        s_totalPaintNs.store(0, std::memory_order_relaxed);
        s_paintCalls.store(0, std::memory_order_relaxed);
        s_zonesDrawn.store(0, std::memory_order_relaxed);
        s_zonesCulled.store(0, std::memory_order_relaxed);
    }

private:
    // Une zone décodée prête pour le draw côté render thread (pas de
    // QVariantMap dans paint() pour éviter le coût d'accès).
    struct ZoneDraw {
        qreal posGridX = 0;
        qreal posGridY = 0;
        QList<QPointF> pointsGrid; // grille-locales, déjà décodés
        QColor color;
        QColor strokeColor;
        qreal strokeWidth = 2;
        qreal hatchSpacing = 12;
        qreal opacity = 1;
    };

    QVector<ZoneDraw> m_zones;
    qreal m_gridSize = 1.0;
    qreal m_viewportOffsetX = 0.0;
    qreal m_viewportOffsetY = 0.0;
    qreal m_itemWidth = 0.0;
    qreal m_itemHeight = 0.0;

    // Buffer recyclable pour éviter une alloc par paint() — un seul vecteur
    // partagé entre toutes les zones, vidé à chaque draw.
    QVector<float> m_segBuf;
};

#endif // MEOW_HAS_CANVAS_PAINTER
