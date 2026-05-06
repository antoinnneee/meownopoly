#include "zone_canvas_painter_renderer.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include "zone_canvas_painter.h"

#include <QElapsedTimer>
#include <QtCanvasPainter/QCanvasPainter>
#include <QLineF>
#include <QVarLengthArray>
#include <QVector>

#include <algorithm>
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
    // Conversion grille → pixels faite côté item (m_gridSize disponible),
    // le renderer reçoit directement les points en pixels locaux.
    m_points = zone->polygonPointsPx();
    m_zoneColor = zone->zoneColor();
    m_strokeColor = zone->strokeColor();
    m_strokeWidth = zone->strokeWidth();
    m_hatchSpacing = zone->hatchSpacing();
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

void ZoneCanvasPainterRenderer::paint(QCanvasPainter *painter)
{
    if (m_points.size() < 3) return;

    QElapsedTimer __perfTimer;
    __perfTimer.start();

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

    s_totalPaintNs.fetch_add(__perfTimer.nsecsElapsed(), std::memory_order_relaxed);
    s_paintCalls.fetch_add(1, std::memory_order_relaxed);
}

void ZoneCanvasPainterRenderer::drawHatches(QCanvasPainter *painter) const
{
    const int n = m_points.size();
    if (n < 3) return;

    // Bounding box du polygone (pixels locaux)
    qreal minX = m_points[0].x(), maxX = minX;
    qreal minY = m_points[0].y(), maxY = minY;
    for (int i = 1; i < n; ++i) {
        const qreal x = m_points[i].x();
        const qreal y = m_points[i].y();
        if (x < minX) minX = x;
        else if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        else if (y > maxY) maxY = y;
    }

    // Hachures diagonales à 45° : direction (1,1), pente 1.
    // Une ligne diagonale s'écrit y = x + c ; on parcourt c de minY-maxX
    // à maxY-minX par pas de spacing*sqrt(2) (espacement perpendiculaire).
    const qreal spacing = m_hatchSpacing * std::sqrt(2.0);
    const qreal cMin = minY - maxX;
    const qreal cMax = maxY - minX;
    const int hatchCount = static_cast<int>((cMax - cMin) / spacing) + 1;
    if (hatchCount <= 0) return;

    // Pré-calcul des arêtes : on stocke uniquement les 4 coefficients utilisés
    // dans l'intersection avec y = x + c. 32 octets/arête → tient dans une
    // ligne de cache pour 2 arêtes consécutives. Permet :
    //  - une seule passe O(n) au lieu de n par hachure
    //  - aucune copie de m_points dans la boucle
    //  - pas d'appels QPointF.x()/.y() virtuels répétés
    struct EdgeCoef {
        qreal x1;           // p1.x
        qreal dx;           // p2.x - p1.x
        qreal invDenom;     // 1.0 / (dy - dx) ; 0 si arête parallèle
        qreal numConst;     // p1.x - p1.y (partie indépendante de c)
    };
    QVarLengthArray<EdgeCoef, 64> edges;
    edges.reserve(n);
    for (int i = 0; i < n; ++i) {
        const QPointF &p1 = m_points[i];
        const QPointF &p2 = m_points[(i + 1) % n];
        const qreal dx = p2.x() - p1.x();
        const qreal dy = p2.y() - p1.y();
        const qreal denom = dy - dx;
        EdgeCoef e;
        e.x1 = p1.x();
        e.dx = dx;
        e.invDenom = (std::abs(denom) < 1e-9) ? 0.0 : 1.0 / denom;
        e.numConst = p1.x() - p1.y();
        edges.append(e);
    }

    // Buffer plat pour les segments : 4 reals par segment (x0,y0,x1,y1).
    // Pré-allouer pour le pire cas : (n/2) intersections × hachures = au
    // plus n/2 segments par hachure (en pratique 1 pour convexe).
    QVarLengthArray<qreal, 4096> segs;
    segs.reserve(hatchCount * 4);

    QVarLengthArray<qreal, 32> xs;
    for (int h = 0; h < hatchCount; ++h) {
        const qreal c = cMin + h * spacing;
        xs.clear();
        for (const EdgeCoef &e : edges) {
            if (e.invDenom == 0.0) continue;
            const qreal t = (e.numConst + c) * e.invDenom;
            if (t < 0.0 || t > 1.0) continue;
            xs.append(e.x1 + t * e.dx);
        }
        const int sz = xs.size();
        if (sz < 2) continue;
        // Fast path : polygone convexe → exactement 2 intersections, pas de tri
        // nécessaire (on sait juste qu'il faut min,max).
        if (sz == 2) {
            const qreal a = xs[0];
            const qreal b = xs[1];
            const qreal x0 = a < b ? a : b;
            const qreal x1 = a < b ? b : a;
            segs.append(x0); segs.append(x0 + c);
            segs.append(x1); segs.append(x1 + c);
            continue;
        }
        // Concave / multi-intersections : tri + paires
        std::sort(xs.begin(), xs.end());
        for (int i = 0; i + 1 < sz; i += 2) {
            const qreal x0 = xs[i];
            const qreal x1 = xs[i + 1];
            segs.append(x0); segs.append(x0 + c);
            segs.append(x1); segs.append(x1 + c);
        }
    }

    if (segs.isEmpty()) return;

    // Phase 2 (séquentielle, render thread) : un seul beginPath/stroke pour
    // toutes les hachures de la zone. Beaucoup plus efficace côté GPU que
    // beginPath+stroke par segment (un seul vertex buffer, un seul draw call).
    painter->setGlobalAlpha(0.6f);
    painter->setStrokeStyle(m_zoneColor);
    painter->setLineWidth(1.5f);
    painter->beginPath();
    const int segCount = segs.size() / 4;
    for (int i = 0; i < segCount; ++i) {
        const qreal *p = segs.data() + i * 4;
        painter->moveTo(QPointF(p[0], p[1]));
        painter->lineTo(QPointF(p[2], p[3]));
    }
    painter->stroke();
}

#endif // MEOW_HAS_CANVAS_PAINTER
