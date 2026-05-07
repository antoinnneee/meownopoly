#include "zone_canvas_painter_renderer.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zone_canvas_painter.h"
#include "zone_hatch_compute.h"

#include <QElapsedTimer>
#include <QtCanvasPainter/QCanvasPainter>

#include <cmath>

std::atomic<std::int64_t> ZoneCanvasPainterRenderer::s_totalPaintNs{0};
std::atomic<int> ZoneCanvasPainterRenderer::s_paintCalls{0};
std::atomic<std::int64_t> ZoneCanvasPainterRenderer::s_totalSyncNs{0};
std::atomic<int> ZoneCanvasPainterRenderer::s_syncCalls{0};

ZoneCanvasPainterRenderer::ZoneCanvasPainterRenderer() = default;

void ZoneCanvasPainterRenderer::synchronize(QCanvasPainterItem *item)
{
    QElapsedTimer __syncTimer;
    __syncTimer.start();
    auto *zone = static_cast<ZoneCanvasPainter *>(item);
    m_points = zone->polygonPointsPx();
    m_zoneColor = zone->zoneColor();
    m_strokeColor = zone->strokeColor();
    m_strokeWidth = zone->strokeWidth();
    m_hatchSpacing = zone->hatchSpacing();

    // En mode precompute / precompute-async, le cache item est rempli AVANT
    // que update() soit émis (synchrone) ou via QFutureWatcher::finished
    // (async). Le sync() copie juste la référence — pas de recalcul.
    const auto mode = zone_painter::currentParallelMode();
    if ((mode == zone_painter::ParallelMode::Precompute ||
         mode == zone_painter::ParallelMode::PrecomputeAsync) &&
        zone->hasCachedSegments())
    {
        m_segments = zone->cachedHatchSegments();
        m_segmentsFromItem = true;
    } else {
        m_segments.clear();
        m_segmentsFromItem = false;
    }

    s_totalSyncNs.fetch_add(__syncTimer.nsecsElapsed(), std::memory_order_relaxed);
    s_syncCalls.fetch_add(1, std::memory_order_relaxed);
}

void ZoneCanvasPainterRenderer::buildPolygonPath(QCanvasPainter *painter) const
{
    const int n = m_points.size();
    if (n < 3) return;
    painter->beginPath();
    painter->moveTo(m_points[0]);
    for (int i = 1; i < n; ++i) {
        painter->lineTo(m_points[i]);
    }
    painter->closePath();
}

void ZoneCanvasPainterRenderer::strokeSegments(QCanvasPainter *painter,
                                               const float *segs,
                                               int segCount) const
{
    painter->beginPath();
    for (int i = 0; i < segCount; ++i) {
        const float *p = segs + i * 4;
        painter->moveTo(QPointF(p[0], p[1]));
        painter->lineTo(QPointF(p[2], p[3]));
    }
    painter->stroke();
}

void ZoneCanvasPainterRenderer::paint(QCanvasPainter *painter)
{
    if (m_points.size() < 3) return;

    QElapsedTimer __perfTimer;
    __perfTimer.start();

    // Path du polygone — fill + stroke partagés.
    buildPolygonPath(painter);

    // 1. Fill légèrement teinté
    painter->setGlobalAlpha(0.15f);
    painter->setFillStyle(m_zoneColor);
    painter->fill();

    // 2. Stroke contour opaque
    painter->setGlobalAlpha(1.0f);
    painter->setStrokeStyle(m_strokeColor);
    painter->setLineWidth(static_cast<float>(m_strokeWidth));
    painter->setLineCap(QCanvasPainter::LineCap::Round);
    painter->setLineJoin(QCanvasPainter::LineJoin::Round);
    painter->stroke();

    // 3. Hachures — selon mode, on lit le cache OU on calcule maintenant.
    const auto mode = zone_painter::currentParallelMode();
    int segCount = 0;
    const float *segPtr = nullptr;

    if (m_segmentsFromItem) {
        // Cache déjà rempli côté item (Precompute / PrecomputeAsync).
        segPtr = m_segments.constData();
        segCount = m_segments.size() / 4;
    } else {
        // Modes intra-paint : on calcule à la volée. m_segments sert de
        // buffer recyclable d'une frame à l'autre.
        switch (mode) {
        case zone_painter::ParallelMode::QtcHatches:
            m_segments = zone_painter::computeHatchSegments_QtcHatches(
                m_points, m_hatchSpacing);
            break;
        case zone_painter::ParallelMode::QtcEdges:
            m_segments = zone_painter::computeHatchSegments_QtcEdges(
                m_points, m_hatchSpacing);
            break;
        default:
            m_segments = zone_painter::computeHatchSegments(
                m_points, m_hatchSpacing);
            break;
        }
        segPtr = m_segments.constData();
        segCount = m_segments.size() / 4;
    }

    if (segCount > 0) {
        painter->setGlobalAlpha(0.6f);
        painter->setStrokeStyle(m_zoneColor);
        painter->setLineWidth(1.5f);
        strokeSegments(painter, segPtr, segCount);
    }

    // Restaurer alpha
    painter->setGlobalAlpha(1.0f);

    s_totalPaintNs.fetch_add(__perfTimer.nsecsElapsed(), std::memory_order_relaxed);
    s_paintCalls.fetch_add(1, std::memory_order_relaxed);
}

#endif // MEOW_HAS_CANVAS_PAINTER
