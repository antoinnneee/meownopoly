// Benchmark de rendu pour SnapableExclusionZone / ZoneCanvasPainter.
// Mesure le frame time (mean / p50 / p95 / p99) en rendant N zones
// d'exclusion avec polygones de complexité variable. Sert à comparer
// objectivement plusieurs solutions d'optimisation.
//
// Compile uniquement si MEOW_HAS_CANVAS_PAINTER est défini (Qt 6.11+).
//
// Usage :
//   ctest -R tst_zone_render_perf -V
//   ou directement : ./tst_zone_render_perf -v2
//
// Pour comparer une autre implémentation : remplacer le contenu de
// zone_render_scene.qml par la version à tester (le test charge ce QML
// par chemin file-system).

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QObject>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QSignalSpy>
#include <QSurfaceFormat>
#include <QVariantList>
#include <QVariantMap>
#include <QtTest/QtTest>
#include <QString>
#include <algorithm>
#include <cmath>
#include <numeric>

#ifdef MEOW_HAS_CANVAS_PAINTER
#include "editor/painter/zone_canvas_painter.h"
#include "editor/painter/zone_canvas_painter_renderer.h"
#endif

namespace {

struct FrameStats {
    double meanMs;
    double p50Ms;
    double p95Ms;
    double p99Ms;
    double maxMs;
    int frames;
    // Métrique CPU pure : temps total passé dans paint() côté C++ pendant la
    // mesure, divisé par le nb de frames mesurées. Indépendant du vsync.
    double cpuMsPerFrame = 0.0;
    int paintCalls = 0;
    double syncMsPerFrame = 0.0;
    int syncCalls = 0;
};

FrameStats computeStats(QList<qint64> nsList)
{
    FrameStats s{};
    if (nsList.isEmpty()) return s;
    std::sort(nsList.begin(), nsList.end());
    const double sum = std::accumulate(nsList.begin(), nsList.end(), qint64(0));
    s.frames = nsList.size();
    s.meanMs = (sum / s.frames) / 1.0e6;
    s.p50Ms = nsList[s.frames * 50 / 100] / 1.0e6;
    s.p95Ms = nsList[std::min(s.frames - 1, s.frames * 95 / 100)] / 1.0e6;
    s.p99Ms = nsList[std::min(s.frames - 1, s.frames * 99 / 100)] / 1.0e6;
    s.maxMs = nsList.last() / 1.0e6;
    return s;
}

// Génère un polygone de N sommets régulièrement répartis autour d'un centre,
// avec un rayon de `radiusGrid` (en coordonnées grille). Sert à varier la
// complexité (nombre de vertices) et la taille des zones.
QVariantList makeCircularPolygon(int vertices, qreal radiusGrid)
{
    QVariantList pts;
    pts.reserve(vertices);
    for (int i = 0; i < vertices; ++i) {
        const qreal angle = (2.0 * M_PI * i) / vertices;
        QVariantMap m;
        m.insert(QStringLiteral("x"), radiusGrid * (1.0 + std::cos(angle)));
        m.insert(QStringLiteral("y"), radiusGrid * (1.0 + std::sin(angle)));
        pts.append(m);
    }
    return pts;
}

// Polygone en étoile : alterne rayon plein et rayon réduit. Polygone NON
// convexe → la fast-path "sz==2 → pas de sort" du scanline est déjouée et on
// stresse le std::sort. `points` doit être pair (autrement on fait +1).
QVariantList makeStarPolygon(int points, qreal outerRadius, qreal innerRadius)
{
    if (points < 4) points = 4;
    if (points & 1) ++points;
    const int n = points;
    QVariantList pts;
    pts.reserve(n);
    for (int i = 0; i < n; ++i) {
        const qreal angle = (2.0 * M_PI * i) / n;
        const qreal r = (i & 1) ? innerRadius : outerRadius;
        QVariantMap m;
        m.insert(QStringLiteral("x"), outerRadius + r * std::cos(angle));
        m.insert(QStringLiteral("y"), outerRadius + r * std::sin(angle));
        pts.append(m);
    }
    return pts;
}

QVariantList makeStarZonesGrid(int count, int starPoints, qreal outer, qreal inner,
                               qreal cellW, qreal cellH)
{
    QVariantList zones;
    zones.reserve(count);
    const int cols = std::max(1, static_cast<int>(std::sqrt(double(count))));
    for (int i = 0; i < count; ++i) {
        const int row = i / cols;
        const int col = i % cols;
        QVariantMap z;
        z.insert(QStringLiteral("posX"), col * cellW);
        z.insert(QStringLiteral("posY"), row * cellH);
        z.insert(QStringLiteral("w"), cellW);
        z.insert(QStringLiteral("h"), cellH);
        z.insert(QStringLiteral("points"),
                 makeStarPolygon(starPoints, outer, inner));
        zones.append(z);
    }
    return zones;
}

QVariantList makeZonesGrid(int count, int verticesPerPoly, qreal radiusGrid,
                           qreal cellWidthPx, qreal cellHeightPx)
{
    QVariantList zones;
    zones.reserve(count);
    const int cols = std::max(1, static_cast<int>(std::sqrt(double(count))));
    for (int i = 0; i < count; ++i) {
        const int row = i / cols;
        const int col = i % cols;
        QVariantMap z;
        z.insert(QStringLiteral("posX"), col * cellWidthPx);
        z.insert(QStringLiteral("posY"), row * cellHeightPx);
        z.insert(QStringLiteral("w"), cellWidthPx);
        z.insert(QStringLiteral("h"), cellHeightPx);
        z.insert(QStringLiteral("points"),
                 makeCircularPolygon(verticesPerPoly, radiusGrid));
        zones.append(z);
    }
    return zones;
}

void printStats(const QString &label, const FrameStats &s)
{
    qInfo().noquote() << QString::asprintf(
        "[%s] n=%d  mean=%.2f ms  p50=%.2f  p95=%.2f  p99=%.2f  max=%.2f  (~%.1f FPS)  paint=%.2f ms/fr (%d)  sync=%.2f ms/fr (%d)",
        qPrintable(label), s.frames, s.meanMs, s.p50Ms, s.p95Ms, s.p99Ms, s.maxMs,
        s.meanMs > 0.0 ? 1000.0 / s.meanMs : 0.0,
        s.cpuMsPerFrame, s.paintCalls,
        s.syncMsPerFrame, s.syncCalls);
}

} // namespace

class TstZoneRenderPerf : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();

    // Rendu N zones de complexité moyenne — compare le coût avec N croissant.
    void renderScaling_data();
    void renderScaling();

    // Polygones avec beaucoup de sommets (8 vs 20 vs 40) — coût des hachures.
    void hatchComplexity_data();
    void hatchComplexity();

    // Burst de zoom : change gridSize 30 fois rapidement, mesure le cumulé.
    void zoomBurst_data();
    void zoomBurst();

    // Cas réel le plus problématique : 1-3 zones GIGANTESQUES (couvrent tout
    // le viewport) avec zoom intense. Stresse drawHatches au max — la
    // bounding box détermine le nombre de hachures à calculer/dessiner.
    void hugeZoneZoom_data();
    void hugeZoneZoom();

    // Stresse le std::sort dans drawHatches : polygones en étoile (concaves)
    // → chaque scanline coupe 4-10+ arêtes au lieu de 2 → fast-path convexe
    // déjoué. Mesure le coût du tri et du multi-segments par scanline.
    void concaveStar_data();
    void concaveStar();

    // Combo extrême : beaucoup de zones, beaucoup de hachures, beaucoup de
    // vertices, polygones étoilés ET zoom rapide. Pour vérifier que l'éditeur
    // reste utilisable au pire cas raisonnable possible.
    void extremeCombo_data();
    void extremeCombo();

private:
    void loadScene();
    void setZones(const QVariantList &zones);
    void setGridSize(qreal gridSize);
    FrameStats measureFrames(int frameCount);

    QQuickView *m_view = nullptr;
    int m_tick = 0;  // compteur global pour produire des valeurs uniques
};

void TstZoneRenderPerf::initTestCase()
{
#ifndef MEOW_HAS_CANVAS_PAINTER
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini — Qt 6.11+ requis pour ZoneCanvasPainter.");
#else
    // Enregistrer le type C++ pour QML (le test linke directement zone_canvas_painter.cpp,
    // pas l'app entière, donc qmlapp.cpp::registerTypes n'est pas appelé).
    qmlRegisterType<ZoneCanvasPainter>("MeowPainter", 1, 0, "ZoneCanvasPainter");

    m_view = new QQuickView;
    m_view->setResizeMode(QQuickView::SizeRootObjectToView);
    m_view->resize(1280, 720);
    loadScene();
    m_view->show();

    // Attendre la première frame pour que la scène soit initialisée.
    QSignalSpy frameSpy(m_view, &QQuickWindow::frameSwapped);
    QVERIFY(frameSpy.wait(2000));
#endif
}

void TstZoneRenderPerf::cleanupTestCase()
{
    delete m_view;
    m_view = nullptr;
}

void TstZoneRenderPerf::loadScene()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    // Localiser le QML par rapport au fichier source de ce .cpp (Qt resolves
    // CMAKE_CURRENT_SOURCE_DIR au build, on peut juste chercher relativement).
    const QString qmlPath = QFINDTESTDATA("zone_render_scene.qml");
    QVERIFY(!qmlPath.isEmpty());
    m_view->setSource(QUrl::fromLocalFile(qmlPath));
    QStringList errs;
    for (const QQmlError &e : m_view->errors())
        errs << e.toString();
    QVERIFY2(m_view->status() == QQuickView::Ready, qPrintable(errs.join('\n')));
#endif
}

void TstZoneRenderPerf::setZones(const QVariantList &zones)
{
    if (m_view && m_view->rootObject()) {
        m_view->rootObject()->setProperty("zonesData", zones);
    }
}

void TstZoneRenderPerf::setGridSize(qreal gs)
{
    if (m_view && m_view->rootObject()) {
        m_view->rootObject()->setProperty("gridSize", gs);
    }
}

FrameStats TstZoneRenderPerf::measureFrames(int frameCount)
{
    QList<qint64> times;
    times.reserve(frameCount);

#ifdef MEOW_HAS_CANVAS_PAINTER
    ZoneCanvasPainterRenderer::resetPaintStats();
#endif

    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer timer;
    timer.start();
    qint64 lastNs = 0;
    int captured = 0;
    while (captured < frameCount) {
        // Valeur strictement croissante : Qt skippe le notify (et donc le
        // re-render) si la valeur est identique à la précédente. Une simple
        // alternance 2.0/2.0001 ne suffit pas car la valeur QML par défaut
        // est déjà 2 → premier setProperty est un no-op → aucune frame.
        ++m_tick;
        m_view->rootObject()->setProperty(
            "strokeWidth", 1.5 + 0.001 * m_tick);
        m_view->update();
        spy.clear();
        if (!spy.wait(2000)) break;
        const qint64 nowNs = timer.nsecsElapsed();
        if (lastNs > 0) {
            times.append(nowNs - lastNs);
            ++captured;
        }
        lastNs = nowNs;
    }
    FrameStats s = computeStats(times);
#ifdef MEOW_HAS_CANVAS_PAINTER
    const std::int64_t totalNs = ZoneCanvasPainterRenderer::s_totalPaintNs.load(
        std::memory_order_relaxed);
    const int calls = ZoneCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    s.paintCalls = calls;
    if (s.frames > 0)
        s.cpuMsPerFrame = (totalNs / 1.0e6) / s.frames;
#endif
    return s;
}

void TstZoneRenderPerf::renderScaling_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::newRow("10")    << 10;
    QTest::newRow("50")    << 50;
    QTest::newRow("100")   << 100;
    QTest::newRow("200")   << 200;
    QTest::newRow("500")   << 500;
    QTest::newRow("1000")  << 1000;
    QTest::newRow("2000")  << 2000;
}

void TstZoneRenderPerf::renderScaling()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    setZones(makeZonesGrid(zoneCount, /*verts*/8, /*radius*/2.0,
                           /*cellW*/120.0, /*cellH*/120.0));
    setGridSize(30.0);

    // Warmup
    measureFrames(15);
    // Mesure
    const FrameStats s = measureFrames(60);
    printStats(QString("renderScaling/%1").arg(zoneCount), s);

    // Pas d'assertion stricte — le test sert au profiling, on veut juste les chiffres.
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstZoneRenderPerf::hatchComplexity_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::addColumn<int>("vertices");
    QTest::addColumn<qreal>("radius");
    QTest::newRow("100x8 verts r2")  << 100 << 8  << 2.0;
    QTest::newRow("100x20 verts r2") << 100 << 20 << 2.0;
    QTest::newRow("100x40 verts r2") << 100 << 40 << 2.0;
    QTest::newRow("100x80 verts r2") << 100 << 80 << 2.0;   // stress vertex count
    QTest::newRow("200x40 verts r2") << 200 << 40 << 2.0;   // combo count + verts
    QTest::newRow("500x20 verts r2") << 500 << 20 << 2.0;   // beaucoup de petites
    QTest::newRow("50 grandes r8 20v") << 50 << 20 << 8.0;
    QTest::newRow("100 grandes r10 30v") << 100 << 30 << 10.0;
    QTest::newRow("200 grandes r10 40v") << 200 << 40 << 10.0; // worst combo
}

void TstZoneRenderPerf::hatchComplexity()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    QFETCH(int, vertices);
    QFETCH(qreal, radius);
    // Cell scaling : adapte la cell pour ne pas trop overlap quand radius bump.
    const qreal cell = std::max(120.0, radius * 30.0);
    setZones(makeZonesGrid(zoneCount, vertices, radius, cell, cell));
    setGridSize(30.0);

    measureFrames(15);
    const FrameStats s = measureFrames(60);
    printStats(QString("hatchComplexity/%1z %2v r%3")
                   .arg(zoneCount).arg(vertices).arg(int(radius)),
               s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstZoneRenderPerf::zoomBurst_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::newRow("50")    << 50;
    QTest::newRow("100")   << 100;
    QTest::newRow("200")   << 200;
    QTest::newRow("500")   << 500;
    QTest::newRow("1000")  << 1000;
}

void TstZoneRenderPerf::zoomBurst()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    setZones(makeZonesGrid(zoneCount, 12, 2.0, 120.0, 120.0));
    setGridSize(20.0);

    measureFrames(15); // warmup

    ZoneCanvasPainterRenderer::resetPaintStats();

    // Burst de 30 changements de gridSize comme un zoom utilisateur.
    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer t;
    QList<qint64> deltas;
    qint64 lastNs = 0;
    t.start();
    for (int i = 0; i < 30; ++i) {
        // Valeur monotone : éviter les no-ops setProperty quand la nouvelle
        // valeur égale la précédente (cf. measureFrames).
        setGridSize(20.0 + 0.5 * i);
        m_view->update();
        spy.clear();
        if (!spy.wait(2000)) break;
        const qint64 nowNs = t.nsecsElapsed();
        if (lastNs > 0) deltas.append(nowNs - lastNs);
        lastNs = nowNs;
    }
    FrameStats s = computeStats(deltas);
    const std::int64_t totalNs = ZoneCanvasPainterRenderer::s_totalPaintNs.load(
        std::memory_order_relaxed);
    s.paintCalls = ZoneCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) s.cpuMsPerFrame = (totalNs / 1.0e6) / s.frames;
    const std::int64_t syncNs = ZoneCanvasPainterRenderer::s_totalSyncNs.load(
        std::memory_order_relaxed);
    s.syncCalls = ZoneCanvasPainterRenderer::s_syncCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) s.syncMsPerFrame = (syncNs / 1.0e6) / s.frames;
    printStats(QString("zoomBurst/%1").arg(zoneCount), s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstZoneRenderPerf::hugeZoneZoom_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::addColumn<int>("vertices");
    QTest::addColumn<qreal>("radiusGrid");
    QTest::newRow("1x huge (radius=20, 30v)") << 1 << 30 << 20.0;
    QTest::newRow("3x huge (radius=15, 30v)") << 3 << 30 << 15.0;
    QTest::newRow("1x mega (radius=30, 40v)") << 1 << 40 << 30.0;
    // Stress maximum : zone qui couvre une zone immense avec beaucoup de
    // hachures à chaque frame (radius=80, gridSize=20-41 → 1600-3300 px).
    QTest::newRow("1x giga (radius=80, 60v)") << 1 << 60 << 80.0;
    QTest::newRow("2x giga (radius=80, 40v)") << 2 << 40 << 80.0;
}

void TstZoneRenderPerf::hugeZoneZoom()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    QFETCH(int, vertices);
    QFETCH(qreal, radiusGrid);

    // Cell size énorme pour bien étaler les zones
    const qreal cellPx = radiusGrid * 2.5 * 30.0; // gridSize ~30 → ~1500 px par zone
    setZones(makeZonesGrid(zoneCount, vertices, radiusGrid, cellPx, cellPx));
    setGridSize(20.0);

    measureFrames(15); // warmup

    ZoneCanvasPainterRenderer::resetPaintStats();

    // Burst de 30 zoom comme un utilisateur qui scroll-zoom.
    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer t;
    QList<qint64> deltas;
    qint64 lastNs = 0;
    t.start();
    for (int i = 0; i < 30; ++i) {
        setGridSize(20.0 + 0.7 * i);
        m_view->update();
        spy.clear();
        if (!spy.wait(2000)) break;
        const qint64 nowNs = t.nsecsElapsed();
        if (lastNs > 0) deltas.append(nowNs - lastNs);
        lastNs = nowNs;
    }
    FrameStats s = computeStats(deltas);
    const std::int64_t totalNs = ZoneCanvasPainterRenderer::s_totalPaintNs.load(
        std::memory_order_relaxed);
    s.paintCalls = ZoneCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) s.cpuMsPerFrame = (totalNs / 1.0e6) / s.frames;
    const std::int64_t syncNs = ZoneCanvasPainterRenderer::s_totalSyncNs.load(
        std::memory_order_relaxed);
    s.syncCalls = ZoneCanvasPainterRenderer::s_syncCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) s.syncMsPerFrame = (syncNs / 1.0e6) / s.frames;
    printStats(QString("hugeZoneZoom/%1z%2v r%3").arg(zoneCount).arg(vertices)
                   .arg(int(radiusGrid)),
               s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstZoneRenderPerf::concaveStar_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::addColumn<int>("starPoints");
    QTest::addColumn<qreal>("outer");
    QTest::addColumn<qreal>("inner");
    QTest::newRow("50z 5-pt small")     << 50  << 10 << 3.0  << 1.0;
    QTest::newRow("100z 5-pt small")    << 100 << 10 << 3.0  << 1.0;
    QTest::newRow("50z 8-pt big")       << 50  << 16 << 6.0  << 2.0;
    QTest::newRow("100z 10-pt big")     << 100 << 20 << 8.0  << 2.5;
    QTest::newRow("50z 12-pt huge")     << 50  << 24 << 15.0 << 4.0;
}

void TstZoneRenderPerf::concaveStar()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    QFETCH(int, starPoints);
    QFETCH(qreal, outer);
    QFETCH(qreal, inner);
    const qreal cell = std::max(120.0, outer * 2.5 * 30.0);
    setZones(makeStarZonesGrid(zoneCount, starPoints, outer, inner, cell, cell));
    setGridSize(30.0);

    measureFrames(15);
    const FrameStats s = measureFrames(60);
    printStats(QString("concaveStar/%1z %2pts r%3-%4")
                   .arg(zoneCount).arg(starPoints).arg(int(outer)).arg(int(inner)),
               s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstZoneRenderPerf::extremeCombo_data()
{
    QTest::addColumn<QString>("scenario");
    QTest::newRow("100 huge convex 60v") << "100huge60";
    QTest::newRow("50 huge star 16-pt")  << "50huge_star16";
    QTest::newRow("200 medium 40v")      << "200med40";
    QTest::newRow("1000 tiny 8v")        << "1000tiny";
}

void TstZoneRenderPerf::extremeCombo()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(QString, scenario);
    QVariantList zones;
    if (scenario == "100huge60") {
        zones = makeZonesGrid(100, 60, 12.0, 400.0, 400.0);
    } else if (scenario == "50huge_star16") {
        zones = makeStarZonesGrid(50, 16, 10.0, 3.0, 600.0, 600.0);
    } else if (scenario == "200med40") {
        zones = makeZonesGrid(200, 40, 4.0, 250.0, 250.0);
    } else { // 1000tiny
        zones = makeZonesGrid(1000, 8, 1.5, 90.0, 90.0);
    }
    setZones(zones);
    setGridSize(30.0);

    measureFrames(15);
    const FrameStats s = measureFrames(60);
    printStats(QString("extremeCombo/%1").arg(scenario), s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

// Custom main pour désactiver le vsync — sinon les mesures snappent sur les
// paliers du vsync (6.94 ms à 144 Hz, 13.88, 20.83…) et masquent les gains
// d'optimisation qui restent dans un palier.
int main(int argc, char *argv[])
{
    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setSwapInterval(0);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    app.setAttribute(Qt::AA_Use96Dpi, true);
    TstZoneRenderPerf t;
    return QTest::qExec(&t, argc, argv);
}
#include "tst_zone_render_perf.moc"
