#include "zone_canvas_painter_renderer.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zone_canvas_painter.h"

#include <QtCanvasPainter/QCanvasPainter>

#include <algorithm>
#include <cmath>

ZoneCanvasPainterRenderer::ZoneCanvasPainterRenderer() = default;

void ZoneCanvasPainterRenderer::synchronize(QCanvasPainterItem *item)
{
    auto *zone = static_cast<ZoneCanvasPainter *>(item);
    // Conversion grille → pixels faite côté item (m_gridSize disponible),
    // le renderer reçoit directement les points en pixels locaux.
    m_points = zone->polygonPointsPx();
    m_zoneColor = zone->zoneColor();
    m_strokeColor = zone->strokeColor();
    m_strokeWidth = zone->strokeWidth();
    m_hatchSpacing = zone->hatchSpacing();
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

void ZoneCanvasPainterRenderer::paint(QCanvasPainter *painter)
{
    if (m_points.size() < 3) return;

    // Path du polygone construit une seule fois (réutilisé pour fill + stroke).
    // Le canvas est transparent par défaut (alphaBlending=true + fillColor
    // transparent dans le ctor) — donc seul l'intérieur du polygone reçoit
    // ce fill semi-transparent. Le reste du bounding rect de l'item reste
    // complètement transparent.
    buildPolygonPath(painter);

    // 1. Fill légèrement teinté à l'intérieur du polygone uniquement
    painter->setGlobalAlpha(0.15f);
    painter->setFillStyle(m_zoneColor);
    painter->fill();

    // 2. Stroke du contour (opaque)
    painter->setGlobalAlpha(1.0f);
    painter->setStrokeStyle(m_strokeColor);
    painter->setLineWidth(static_cast<float>(m_strokeWidth));
    painter->setLineCap(QCanvasPainter::LineCap::Round);
    painter->setLineJoin(QCanvasPainter::LineJoin::Round);
    painter->stroke();

    // 3. Hachures diagonales clippées au polygone (alpha 0.6 géré dedans).
    //    QCanvasPainter ne supporte pas clip(path) — on calcule manuellement
    //    les segments visibles via scanline algorithm (intersections de
    //    chaque ligne diagonale avec les arêtes du polygone, on dessine les
    //    paires d'intersections en alternance — règle even-odd).
    drawHatches(painter);

    // Restaurer l'alpha pour ne pas affecter d'autres draws si l'item est
    // réutilisé dans un même frame.
    painter->setGlobalAlpha(1.0f);
}

void ZoneCanvasPainterRenderer::drawHatches(QCanvasPainter *painter) const
{
    const int n = m_points.size();
    if (n < 3) return;

    // Bounding box du polygone (pixels locaux)
    qreal minX = m_points[0].x(), maxX = minX;
    qreal minY = m_points[0].y(), maxY = minY;
    for (int i = 1; i < n; ++i) {
        minX = std::min(minX, m_points[i].x());
        maxX = std::max(maxX, m_points[i].x());
        minY = std::min(minY, m_points[i].y());
        maxY = std::max(maxY, m_points[i].y());
    }

    // Hachures diagonales à 45° : direction (1,1), pente 1.
    // Une ligne diagonale s'écrit y = x + c ; on parcourt c de minY-maxX
    // à maxY-minX par pas de spacing*sqrt(2) (espacement perpendiculaire).
    const qreal spacing = m_hatchSpacing * std::sqrt(2.0);
    const qreal cMin = minY - maxX;
    const qreal cMax = maxY - minX;

    painter->setGlobalAlpha(0.6f);
    painter->setStrokeStyle(m_zoneColor);
    painter->setLineWidth(1.5f);

    // Pour chaque ligne diagonale, calculer ses intersections avec les
    // arêtes du polygone, trier par abscisse, puis tracer les segments
    // entre paires successives (même règle que ScanLine fill).
    for (qreal c = cMin; c <= cMax; c += spacing) {
        QList<qreal> xs;
        for (int i = 0; i < n; ++i) {
            const QPointF &p1 = m_points[i];
            const QPointF &p2 = m_points[(i + 1) % n];
            // Intersection segment p1-p2 avec y = x + c.
            // Paramétrer p = p1 + t(p2-p1), t ∈ [0,1].
            // (p1.y + t dy) = (p1.x + t dx) + c
            // t (dy - dx) = (p1.x - p1.y) + c
            const qreal dx = p2.x() - p1.x();
            const qreal dy = p2.y() - p1.y();
            const qreal denom = dy - dx;
            if (std::abs(denom) < 1e-9) continue; // arête parallèle
            const qreal t = (p1.x() - p1.y() + c) / denom;
            if (t < 0.0 || t > 1.0) continue;
            xs.append(p1.x() + t * dx);
        }
        if (xs.size() < 2) continue;
        std::sort(xs.begin(), xs.end());
        // Tracer segments par paires (i, i+1)
        for (int i = 0; i + 1 < xs.size(); i += 2) {
            const qreal x0 = xs[i];
            const qreal x1 = xs[i + 1];
            const qreal y0 = x0 + c;
            const qreal y1 = x1 + c;
            painter->beginPath();
            painter->moveTo(QPointF(x0, y0));
            painter->lineTo(QPointF(x1, y1));
            painter->stroke();
        }
    }
}

#endif // MEOW_HAS_CANVAS_PAINTER
