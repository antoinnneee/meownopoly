#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItemRenderer>
#include <QColor>
#include <QList>
#include <QPointF>
#include <QVector>
#include <atomic>
#include <cstdint>

class ZoneCanvasPainter;
class QCanvasPainter;

class ZoneCanvasPainterRenderer : public QCanvasPainterItemRenderer
{
public:
    ZoneCanvasPainterRenderer();

    void synchronize(QCanvasPainterItem *item) override;
    void paint(QCanvasPainter *painter) override;

    // Instrumentation perf : compteur CPU global de tous les paint() en cours.
    // Utilisé par tst_zone_render_perf pour mesurer indépendamment du vsync.
    // Pas thread-safe au sens strict (lecture/reset depuis un autre thread)
    // mais atomic 64 bits sur x86-64 = OK.
    static std::atomic<std::int64_t> s_totalPaintNs;
    static std::atomic<int> s_paintCalls;
    static std::atomic<std::int64_t> s_totalSyncNs;
    static std::atomic<int> s_syncCalls;
    static void resetPaintStats() {
        s_totalPaintNs.store(0, std::memory_order_relaxed);
        s_paintCalls.store(0, std::memory_order_relaxed);
        s_totalSyncNs.store(0, std::memory_order_relaxed);
        s_syncCalls.store(0, std::memory_order_relaxed);
    }

private:
    // Construit le path du polygone dans `painter` (beginPath + moveTo +
    // lineTo + closePath). Réutilisé pour fill puis stroke.
    void buildPolygonPath(QCanvasPainter *painter) const;

    // Trace les hachures sur le painter à partir d'un buffer plat de segments
    // (4 floats par segment). Utilisé par tous les modes — la différence est
    // juste où le buffer a été calculé (intra-paint vs cache item).
    void strokeSegments(QCanvasPainter *painter,
                        const float *segs, int segCount) const;

    QList<QPointF> m_points;
    QColor m_zoneColor;
    QColor m_strokeColor;
    qreal m_strokeWidth = 2.0;
    qreal m_hatchSpacing = 12.0;
    // Buffer de segments à dessiner pour cette frame. En mode Precompute /
    // PrecomputeAsync, copié depuis l'item dans synchronize(). En mode
    // Baseline / Qtc*, calculé dans paint() et stocké ici juste pour éviter
    // une allocation locale.
    QVector<float> m_segments;
    bool m_segmentsFromItem = false;
};

#endif // MEOW_HAS_CANVAS_PAINTER
