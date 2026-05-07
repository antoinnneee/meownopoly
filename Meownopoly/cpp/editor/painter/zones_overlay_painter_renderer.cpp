#include "zones_overlay_painter_renderer.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zones_overlay_painter.h"
#include "zone_hatch_compute.h"

#include <QElapsedTimer>
#include <QtCanvasPainter/QCanvasPainter>

#include <algorithm>
#include <cmath>

std::atomic<std::int64_t> ZonesOverlayPainterRenderer::s_totalPaintNs{0};
std::atomic<int> ZonesOverlayPainterRenderer::s_paintCalls{0};
std::atomic<int> ZonesOverlayPainterRenderer::s_zonesDrawn{0};
std::atomic<int> ZonesOverlayPainterRenderer::s_zonesCulled{0};

ZonesOverlayPainterRenderer::ZonesOverlayPainterRenderer() = default;

namespace {

// Accept either QPointF natif ou QVariantMap{x,y} JS — même tolérance que
// ZoneCanvasPainter::rebuildGridCache.
QPointF pointFromVariant(const QVariant &v)
{
    if (v.canConvert<QPointF>()) return v.toPointF();
    const QVariantMap m = v.toMap();
    return QPointF(m.value("x").toReal(), m.value("y").toReal());
}

} // namespace

void ZonesOverlayPainterRenderer::synchronize(QCanvasPainterItem *item)
{
    auto *overlay = static_cast<ZonesOverlayPainter *>(item);
    m_gridSize = overlay->gridSize();
    m_viewportOffsetX = overlay->viewportOffsetX();
    m_viewportOffsetY = overlay->viewportOffsetY();
    m_itemWidth = overlay->width();
    m_itemHeight = overlay->height();

    // Decode zones once. Chaque entrée est un QVariantMap.
    const QVariantList raw = overlay->zones();
    m_zones.resize(raw.size());
    for (int i = 0; i < raw.size(); ++i) {
        const QVariantMap z = raw[i].toMap();
        ZoneDraw &out = m_zones[i];
        out.posGridX = z.value("posGridX").toReal();
        out.posGridY = z.value("posGridY").toReal();
        const QVariantList pts = z.value("points").toList();
        out.pointsGrid.clear();
        out.pointsGrid.reserve(pts.size());
        for (const QVariant &pv : pts)
            out.pointsGrid.append(pointFromVariant(pv));
        out.color = z.value("color").value<QColor>();
        if (!out.color.isValid()) out.color = QColor("#FF5722");
        out.strokeColor = z.value("strokeColor").value<QColor>();
        if (!out.strokeColor.isValid())
            out.strokeColor = out.color.darker(130);
        out.strokeWidth = z.contains("strokeWidth")
                          ? z.value("strokeWidth").toReal() : 2.0;
        out.hatchSpacing = z.contains("hatchSpacing")
                          ? z.value("hatchSpacing").toReal() : 12.0;
        out.opacity = z.contains("opacity")
                      ? z.value("opacity").toReal() : 1.0;
    }
}

void ZonesOverlayPainterRenderer::paint(QCanvasPainter *painter)
{
    if (m_zones.isEmpty()) return;
    if (m_gridSize <= 0.0) return;
    if (m_itemWidth <= 0.0 || m_itemHeight <= 0.0) return;

    QElapsedTimer t;
    t.start();

    const qreal gs = m_gridSize;
    const qreal offX = m_viewportOffsetX;
    const qreal offY = m_viewportOffsetY;

    int drawn = 0;
    int culled = 0;

    for (const ZoneDraw &z : m_zones) {
        if (z.pointsGrid.size() < 3) { ++culled; continue; }

        // Compute bbox en coords canvas-local (= coords écran) :
        //   pixel = viewportOffset + (posGrid + p) * gridSize
        qreal minX = std::numeric_limits<qreal>::infinity();
        qreal minY = std::numeric_limits<qreal>::infinity();
        qreal maxX = -std::numeric_limits<qreal>::infinity();
        qreal maxY = -std::numeric_limits<qreal>::infinity();

        QList<QPointF> pointsPx;
        pointsPx.reserve(z.pointsGrid.size());
        for (const QPointF &p : z.pointsGrid) {
            const qreal x = offX + (z.posGridX + p.x()) * gs;
            const qreal y = offY + (z.posGridY + p.y()) * gs;
            pointsPx.append(QPointF(x, y));
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
        }

        // Viewport cull : skip si la bbox est entièrement hors-écran. On
        // garde une marge de strokeWidth pour ne pas rogner les contours
        // qui dépassent légèrement.
        const qreal margin = z.strokeWidth + 1.0;
        if (maxX < -margin || maxY < -margin
            || minX > m_itemWidth + margin || minY > m_itemHeight + margin) {
            ++culled;
            continue;
        }
        ++drawn;

        // Path du polygone : moveTo + lineTo + closePath.
        painter->beginPath();
        painter->moveTo(pointsPx[0]);
        for (int i = 1; i < pointsPx.size(); ++i)
            painter->lineTo(pointsPx[i]);
        painter->closePath();

        // 1. Fill teinté.
        painter->setGlobalAlpha(static_cast<float>(0.15 * z.opacity));
        painter->setFillStyle(z.color);
        painter->fill();

        // 2. Stroke contour opaque.
        painter->setGlobalAlpha(static_cast<float>(z.opacity));
        painter->setStrokeStyle(z.strokeColor);
        painter->setLineWidth(static_cast<float>(z.strokeWidth));
        painter->setLineCap(QCanvasPainter::LineCap::Round);
        painter->setLineJoin(QCanvasPainter::LineJoin::Round);
        painter->stroke();

        // 3. Hachures — compute synchrone à partir du polygone PIXEL absolu.
        // Pas de cache async ici : la liste de zones change peu souvent
        // (création/déplacement) mais surtout, gridSize change à chaque cran
        // de zoom → invalidation systématique. Async ne gagne donc pas grand
        // chose et complexifie. Les hachures elles-mêmes sont rapides
        // (~0.1 ms par zone modeste).
        m_segBuf = zone_painter::computeHatchSegments(pointsPx, z.hatchSpacing);
        const int segCount = m_segBuf.size() / 4;
        if (segCount > 0) {
            painter->beginPath();
            const float *p = m_segBuf.constData();
            for (int i = 0; i < segCount; ++i) {
                const float *s = p + i * 4;
                painter->moveTo(QPointF(s[0], s[1]));
                painter->lineTo(QPointF(s[2], s[3]));
            }
            painter->setGlobalAlpha(static_cast<float>(0.6 * z.opacity));
            painter->setStrokeStyle(z.color);
            painter->setLineWidth(1.5f);
            painter->stroke();
        }
    }

    painter->setGlobalAlpha(1.0f);

    s_zonesDrawn.fetch_add(drawn, std::memory_order_relaxed);
    s_zonesCulled.fetch_add(culled, std::memory_order_relaxed);
    s_totalPaintNs.fetch_add(t.nsecsElapsed(), std::memory_order_relaxed);
    s_paintCalls.fetch_add(1, std::memory_order_relaxed);
}

#endif // MEOW_HAS_CANVAS_PAINTER
