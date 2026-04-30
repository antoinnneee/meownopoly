#include "zone_canvas_painter_renderer.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zone_canvas_painter.h"

#include <QtCanvasPainter/QCanvasPainter>
#include <QLineF>
#include <QVector>
#include <QtConcurrent/QtConcurrent>

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

    // Liste des constantes c (une par hachure)
    QVector<qreal> cValues;
    cValues.reserve(static_cast<int>((cMax - cMin) / spacing) + 2);
    for (qreal c = cMin; c <= cMax; c += spacing) {
        cValues.append(c);
    }
    if (cValues.isEmpty()) return;

    // Phase 1 (parallèle) : pour chaque c, calculer les intersections avec
    // les arêtes du polygone et générer les paires de segments visibles.
    // QCanvasPainter n'est pas thread-safe, donc seul le calcul est //isé,
    // pas le draw. Sous threshold (peu de hachures), le coût d'overhead
    // dépasse le gain — on tombe en mono-thread.
    auto pointsRef = m_points; // copie pour capture lambda thread-safe
    auto computeSegmentsForLine = [pointsRef, n](qreal c) -> QVector<QLineF> {
        QVector<QLineF> segs;
        QVarLengthArray<qreal, 16> xs;
        for (int i = 0; i < n; ++i) {
            const QPointF &p1 = pointsRef[i];
            const QPointF &p2 = pointsRef[(i + 1) % n];
            // Intersection segment p1-p2 avec y = x + c (paramétrage t∈[0,1]).
            const qreal dx = p2.x() - p1.x();
            const qreal dy = p2.y() - p1.y();
            const qreal denom = dy - dx;
            if (std::abs(denom) < 1e-9) continue; // arête parallèle
            const qreal t = (p1.x() - p1.y() + c) / denom;
            if (t < 0.0 || t > 1.0) continue;
            xs.append(p1.x() + t * dx);
        }
        if (xs.size() < 2) return segs;
        std::sort(xs.begin(), xs.end());
        for (int i = 0; i + 1 < xs.size(); i += 2) {
            const qreal x0 = xs[i];
            const qreal x1 = xs[i + 1];
            segs.append(QLineF(x0, x0 + c, x1, x1 + c));
        }
        return segs;
    };

    constexpr int kParallelThreshold = 32;
    QVector<QVector<QLineF>> allSegments;
    if (cValues.size() >= kParallelThreshold) {
        // QtConcurrent::blockingMapped distribue computeSegmentsForLine sur
        // QThreadPool::globalInstance() — gère le partage entre toutes les
        // zones rendues en parallèle, pas de saturation manuelle à faire.
        allSegments = QtConcurrent::blockingMapped<QVector<QVector<QLineF>>>(
            cValues, computeSegmentsForLine);
    } else {
        allSegments.reserve(cValues.size());
        for (qreal c : std::as_const(cValues)) {
            allSegments.append(computeSegmentsForLine(c));
        }
    }

    // Phase 2 (séquentielle, render thread) : un seul beginPath/stroke pour
    // toutes les hachures de la zone. Beaucoup plus efficace côté GPU que
    // beginPath+stroke par segment (un seul vertex buffer, un seul draw call).
    painter->setGlobalAlpha(0.6f);
    painter->setStrokeStyle(m_zoneColor);
    painter->setLineWidth(1.5f);
    painter->beginPath();
    for (const QVector<QLineF> &segs : std::as_const(allSegments)) {
        for (const QLineF &seg : segs) {
            painter->moveTo(seg.p1());
            painter->lineTo(seg.p2());
        }
    }
    painter->stroke();
}

#endif // MEOW_HAS_CANVAS_PAINTER
