#include "zone_hatch_compute.h"

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QByteArray>
#include <QtConcurrent/QtConcurrent>
#include <QVarLengthArray>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <mutex>

namespace zone_painter {

namespace {

struct EdgeCoef {
    float x1;           // p1.x
    float dx;           // p2.x - p1.x
    float invDenom;     // 1.0 / (dy - dx) ; 0 si arête parallèle
    float numConst;     // p1.x - p1.y
};

// Pré-calcul des arêtes (séquentiel).
void buildEdgesSeq(const QList<QPointF> &pts,
                   QVarLengthArray<EdgeCoef, 128> &edges)
{
    const int n = pts.size();
    edges.clear();
    edges.reserve(n);
    float prevX = static_cast<float>(pts[n - 1].x());
    float prevY = static_cast<float>(pts[n - 1].y());
    for (int i = 0; i < n; ++i) {
        const float x2 = static_cast<float>(pts[i].x());
        const float y2 = static_cast<float>(pts[i].y());
        const float dx = x2 - prevX;
        const float dy = y2 - prevY;
        const float denom = dy - dx;
        EdgeCoef e;
        e.x1 = prevX;
        e.dx = dx;
        e.invDenom = (std::abs(denom) < 1e-6f) ? 0.0f : 1.0f / denom;
        e.numConst = prevX - prevY;
        edges.append(e);
        prevX = x2;
        prevY = y2;
    }
}

// Bbox + comptage de hachures partagés par toutes les variantes.
struct ScanContext {
    float cMinF = 0.0f;
    float spacingF = 0.0f;
    int hatchCount = 0;
    bool empty = true;
};

ScanContext makeScanContext(const QList<QPointF> &pts, qreal hatchSpacing)
{
    ScanContext c;
    const int n = pts.size();
    qreal minX = pts[0].x(), maxX = minX;
    qreal minY = pts[0].y(), maxY = minY;
    for (int i = 1; i < n; ++i) {
        const qreal x = pts[i].x();
        const qreal y = pts[i].y();
        if (x < minX) minX = x;
        else if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        else if (y > maxY) maxY = y;
    }
    static const qreal kSqrt2 = std::sqrt(2.0);
    const qreal spacing = hatchSpacing * kSqrt2;
    const qreal cMin = minY - maxX;
    const qreal cMax = maxY - minX;
    if (cMax - cMin < spacing) return c; // early-out (G3)
    const int hatchCount = static_cast<int>((cMax - cMin) / spacing) + 1;
    if (hatchCount <= 0) return c;
    c.cMinF = static_cast<float>(cMin);
    c.spacingF = static_cast<float>(spacing);
    c.hatchCount = hatchCount;
    c.empty = false;
    return c;
}

// Pour une scanline `c`, calcule les segments visibles (paires d'abscisses
// de l'intersection avec le polygone) et les pousse dans `out`. Format : 4
// floats par segment.
template <typename Edges>
inline void scanlineOne(const Edges &edges, float c,
                        QVarLengthArray<float, 4096> &out,
                        QVarLengthArray<float, 32> &xsScratch)
{
    xsScratch.clear();
    for (const EdgeCoef &e : edges) {
        if (e.invDenom == 0.0f) continue;
        const float t = (e.numConst + c) * e.invDenom;
        if (t < 0.0f || t > 1.0f) continue;
        xsScratch.append(e.x1 + t * e.dx);
    }
    const int sz = xsScratch.size();
    if (sz < 2) return;
    if (sz == 2) {
        const float a = xsScratch[0];
        const float b = xsScratch[1];
        const float x0 = a < b ? a : b;
        const float x1 = a < b ? b : a;
        out.append(x0); out.append(x0 + c);
        out.append(x1); out.append(x1 + c);
        return;
    }
    std::sort(xsScratch.begin(), xsScratch.end());
    for (int i = 0; i + 1 < sz; i += 2) {
        const float x0 = xsScratch[i];
        const float x1 = xsScratch[i + 1];
        out.append(x0); out.append(x0 + c);
        out.append(x1); out.append(x1 + c);
    }
}

QVector<float> finalize(const QVarLengthArray<float, 4096> &segs)
{
    QVector<float> out;
    out.resize(segs.size());
    if (!segs.isEmpty())
        std::memcpy(out.data(), segs.constData(), segs.size() * sizeof(float));
    return out;
}

} // namespace

ParallelMode currentParallelMode()
{
    static ParallelMode cached = []() {
        const QByteArray raw = qgetenv("MEOW_ZONE_PARALLEL_MODE");
        const QByteArray v = raw.toLower();
        if (v == "baseline") return ParallelMode::Baseline;
        if (v == "qtc-hatches") return ParallelMode::QtcHatches;
        if (v == "qtc-edges") return ParallelMode::QtcEdges;
        if (v == "precompute") return ParallelMode::Precompute;
        if (v == "precompute-async") return ParallelMode::PrecomputeAsync;
        // Default : PrecomputeAsync. Best across all bench scenarios
        // (frame mean -30 à -46% sur cas hatch-heavy, paint -10% en moyenne).
        // Bypass via MEOW_ZONE_PARALLEL_MODE=baseline.
        return ParallelMode::PrecomputeAsync;
    }();
    return cached;
}

const char *parallelModeName(ParallelMode m)
{
    switch (m) {
    case ParallelMode::Baseline: return "baseline";
    case ParallelMode::QtcHatches: return "qtc-hatches";
    case ParallelMode::QtcEdges: return "qtc-edges";
    case ParallelMode::Precompute: return "precompute";
    case ParallelMode::PrecomputeAsync: return "precompute-async";
    }
    return "?";
}

QVector<float> computeHatchSegments(const QList<QPointF> &pointsPx,
                                    qreal hatchSpacing)
{
    if (pointsPx.size() < 3) return {};
    const ScanContext ctx = makeScanContext(pointsPx, hatchSpacing);
    if (ctx.empty) return {};

    QVarLengthArray<EdgeCoef, 128> edges;
    buildEdgesSeq(pointsPx, edges);

    QVarLengthArray<float, 4096> segs;
    segs.reserve(ctx.hatchCount * 4);
    QVarLengthArray<float, 32> xs;

    for (int h = 0; h < ctx.hatchCount; ++h) {
        const float c = ctx.cMinF + h * ctx.spacingF;
        scanlineOne(edges, c, segs, xs);
    }
    return finalize(segs);
}

QVector<float> computeHatchSegments_QtcEdges(const QList<QPointF> &pointsPx,
                                             qreal hatchSpacing)
{
    if (pointsPx.size() < 3) return {};
    const ScanContext ctx = makeScanContext(pointsPx, hatchSpacing);
    if (ctx.empty) return {};

    const int n = pointsPx.size();
    // Pré-calcul des arêtes // via QtConcurrent.
    // On indexe les arêtes par l'indice du point d'arrivée ; le précédent
    // est `(i-1+n) % n` — pas de rolling possible en parallèle.
    QVector<EdgeCoef> edgesV(n);
    QtConcurrent::blockingMap(edgesV.begin(), edgesV.end(),
        [&pointsPx, n, &edgesV](EdgeCoef &e) {
            const int i = static_cast<int>(&e - edgesV.data());
            const int p = (i - 1 + n) % n;
            const float prevX = static_cast<float>(pointsPx[p].x());
            const float prevY = static_cast<float>(pointsPx[p].y());
            const float x2 = static_cast<float>(pointsPx[i].x());
            const float y2 = static_cast<float>(pointsPx[i].y());
            const float dx = x2 - prevX;
            const float dy = y2 - prevY;
            const float denom = dy - dx;
            e.x1 = prevX;
            e.dx = dx;
            e.invDenom = (std::abs(denom) < 1e-6f) ? 0.0f : 1.0f / denom;
            e.numConst = prevX - prevY;
        });

    QVarLengthArray<float, 4096> segs;
    segs.reserve(ctx.hatchCount * 4);
    QVarLengthArray<float, 32> xs;

    for (int h = 0; h < ctx.hatchCount; ++h) {
        const float c = ctx.cMinF + h * ctx.spacingF;
        scanlineOne(edgesV, c, segs, xs);
    }
    return finalize(segs);
}

QVector<float> computeHatchSegments_QtcHatches(const QList<QPointF> &pointsPx,
                                               qreal hatchSpacing)
{
    if (pointsPx.size() < 3) return {};
    const ScanContext ctx = makeScanContext(pointsPx, hatchSpacing);
    if (ctx.empty) return {};

    QVarLengthArray<EdgeCoef, 128> edges;
    buildEdgesSeq(pointsPx, edges);

    // Tasks : un index par hachure. Chaque task produit son sous-buffer
    // local (xs scratch + segs locaux), puis on merge en séquentiel.
    // QVarLengthArray ne se déplace pas → on utilise QVector dans la map.
    struct LocalBuf { QVector<float> v; };
    QVector<LocalBuf> bufs(ctx.hatchCount);

    QtConcurrent::blockingMap(bufs.begin(), bufs.end(),
        [&edges, &ctx, &bufs](LocalBuf &b) {
            const int h = static_cast<int>(&b - bufs.data());
            const float c = ctx.cMinF + h * ctx.spacingF;
            QVarLengthArray<float, 4096> tmp;
            QVarLengthArray<float, 32> xs;
            scanlineOne(edges, c, tmp, xs);
            b.v.resize(tmp.size());
            if (!tmp.isEmpty())
                std::memcpy(b.v.data(), tmp.constData(),
                            tmp.size() * sizeof(float));
        });

    int total = 0;
    for (const auto &b : bufs) total += b.v.size();
    QVector<float> out;
    out.reserve(total);
    for (const auto &b : bufs)
        out.append(b.v);
    return out;
}

} // namespace zone_painter

#endif // MEOW_HAS_CANVAS_PAINTER
