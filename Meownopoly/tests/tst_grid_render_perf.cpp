// Benchmark de rendu pour la grille de l'éditeur (GridManager).
// Compare deux modes :
//   - Repeater (legacy)  : 1202 Rectangle pour 600 croisillons.
//   - GridCanvasPainter  : 1 item GPU + viewport culling.
//
// Toggle via env var MEOW_GRID_RENDERER=repeater|canvas (défaut canvas).
//
// Scénarios :
//   - staticIdle        : grille statique, mesure le coût steady-state.
//   - zoomBurst         : 30 changements de mmSize (~ scroll-zoom user).
//   - panBurst          : 30 changements de gridX/gridY (~ drag/pan).
//   - resizeCroisillons : 5 changements de croisillons (rare mais coûteux
//                         pour le Repeater = ré-instanciation massive).
//
// Compile uniquement si MEOW_HAS_CANVAS_PAINTER est défini (Qt 6.11+).
//
// Usage : ./tst_grid_render_perf -v2

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QGuiApplication>
#include <QObject>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QSignalSpy>
#include <QSurfaceFormat>
#include <QtTest/QtTest>
#include <QString>
#include <QByteArray>
#include <algorithm>
#include <cmath>
#include <numeric>

#ifdef MEOW_HAS_CANVAS_PAINTER
#include "editor/painter/grid_canvas_painter.h"
#include "editor/painter/grid_canvas_painter_renderer.h"
#endif

namespace {

struct FrameStats {
    double meanMs = 0;
    double p50Ms = 0;
    double p95Ms = 0;
    double p99Ms = 0;
    double maxMs = 0;
    int frames = 0;
    double cpuMsPerFrame = 0.0;
    int paintCalls = 0;
    double syncMsPerFrame = 0.0;
    int syncCalls = 0;
    qint64 linesEmitted = 0;
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

void printStats(const QString &label, const FrameStats &s, const char *mode)
{
    qInfo().noquote() << QString::asprintf(
        "[%s/%s] n=%d  mean=%.2f ms  p50=%.2f  p95=%.2f  p99=%.2f  max=%.2f  (~%.1f FPS)  paint=%.2f ms/fr (%d)  sync=%.2f ms/fr (%d)  lines=%lld",
        qPrintable(label), mode, s.frames, s.meanMs, s.p50Ms, s.p95Ms, s.p99Ms, s.maxMs,
        s.meanMs > 0.0 ? 1000.0 / s.meanMs : 0.0,
        s.cpuMsPerFrame, s.paintCalls,
        s.syncMsPerFrame, s.syncCalls,
        static_cast<long long>(s.linesEmitted));
}

const char *currentMode()
{
    const QByteArray raw = qgetenv("MEOW_GRID_RENDERER").toLower();
    if (raw == "repeater") return "repeater";
    return "canvas";
}

} // namespace

class TstGridRenderPerf : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();

    void staticIdle_data();
    void staticIdle();

    void zoomBurst_data();
    void zoomBurst();

    void panBurst_data();
    void panBurst();

    void resizeCroisillons();

private:
    void loadScene();
    void setProp(const char *name, const QVariant &v);
    FrameStats measureIdle(int frameCount);
    FrameStats measureBurst(int iterations,
                            std::function<void(int)> mutate);

    QQuickView *m_view = nullptr;
    int m_tick = 0;
};

void TstGridRenderPerf::initTestCase()
{
#ifndef MEOW_HAS_CANVAS_PAINTER
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#else
    qmlRegisterType<GridCanvasPainter>("MeowPainter", 1, 0, "GridCanvasPainter");

    m_view = new QQuickView;
    m_view->setResizeMode(QQuickView::SizeRootObjectToView);
    m_view->resize(1280, 720);

    // Poser le context property avant le load — GridManager.qml le lit dès
    // sa création pour décider Repeater vs Canvas.
    const QByteArray raw = qgetenv("MEOW_GRID_RENDERER").toLower();
    bool useCanvas = (raw != "repeater"); // défaut canvas
    m_view->rootContext()->setContextProperty(
        "_gridRendererUseCanvas", QVariant(useCanvas));

    qInfo().noquote() << QString("Mode actif : %1").arg(useCanvas ? "canvas" : "repeater");

    loadScene();
    m_view->show();

    QSignalSpy frameSpy(m_view, &QQuickWindow::frameSwapped);
    QVERIFY(frameSpy.wait(2000));
#endif
}

void TstGridRenderPerf::cleanupTestCase()
{
    delete m_view;
    m_view = nullptr;
}

void TstGridRenderPerf::loadScene()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    const QString qmlPath = QFINDTESTDATA("grid_render_scene.qml");
    QVERIFY(!qmlPath.isEmpty());
    m_view->setSource(QUrl::fromLocalFile(qmlPath));
    QStringList errs;
    for (const QQmlError &e : m_view->errors())
        errs << e.toString();
    QVERIFY2(m_view->status() == QQuickView::Ready, qPrintable(errs.join('\n')));
#endif
}

void TstGridRenderPerf::setProp(const char *name, const QVariant &v)
{
    if (m_view && m_view->rootObject())
        m_view->rootObject()->setProperty(name, v);
}

FrameStats TstGridRenderPerf::measureIdle(int frameCount)
{
    QList<qint64> times;
    times.reserve(frameCount);

#ifdef MEOW_HAS_CANVAS_PAINTER
    GridCanvasPainterRenderer::resetStats();
#endif

    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer timer;
    timer.start();
    qint64 lastNs = 0;
    int captured = 0;
    while (captured < frameCount) {
        // Pour forcer un re-render à chaque tick (sinon avec vsync OFF Qt
        // n'émet plus de frameSwapped si rien ne change), on touche une
        // valeur strictement croissante côté QML.
        ++m_tick;
        m_view->rootObject()->setProperty("gridX", 0.001 * m_tick);
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
    s.paintCalls = GridCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) {
        const std::int64_t totalNs = GridCanvasPainterRenderer::s_totalPaintNs.load(
            std::memory_order_relaxed);
        s.cpuMsPerFrame = (totalNs / 1.0e6) / s.frames;
        const std::int64_t syncNs = GridCanvasPainterRenderer::s_totalSyncNs.load(
            std::memory_order_relaxed);
        s.syncCalls = GridCanvasPainterRenderer::s_syncCalls.load(
            std::memory_order_relaxed);
        s.syncMsPerFrame = (syncNs / 1.0e6) / s.frames;
    }
    s.linesEmitted = GridCanvasPainterRenderer::s_totalLinesEmitted.load(
        std::memory_order_relaxed);
#endif
    return s;
}

FrameStats TstGridRenderPerf::measureBurst(int iterations,
                                           std::function<void(int)> mutate)
{
    QList<qint64> times;
    times.reserve(iterations);

#ifdef MEOW_HAS_CANVAS_PAINTER
    GridCanvasPainterRenderer::resetStats();
#endif

    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer timer;
    timer.start();
    qint64 lastNs = 0;
    for (int i = 0; i < iterations; ++i) {
        mutate(i);
        m_view->update();
        spy.clear();
        if (!spy.wait(2000)) break;
        const qint64 nowNs = timer.nsecsElapsed();
        if (lastNs > 0) times.append(nowNs - lastNs);
        lastNs = nowNs;
    }
    FrameStats s = computeStats(times);
#ifdef MEOW_HAS_CANVAS_PAINTER
    s.paintCalls = GridCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) {
        const std::int64_t totalNs = GridCanvasPainterRenderer::s_totalPaintNs.load(
            std::memory_order_relaxed);
        s.cpuMsPerFrame = (totalNs / 1.0e6) / s.frames;
        const std::int64_t syncNs = GridCanvasPainterRenderer::s_totalSyncNs.load(
            std::memory_order_relaxed);
        s.syncCalls = GridCanvasPainterRenderer::s_syncCalls.load(
            std::memory_order_relaxed);
        s.syncMsPerFrame = (syncNs / 1.0e6) / s.frames;
    }
    s.linesEmitted = GridCanvasPainterRenderer::s_totalLinesEmitted.load(
        std::memory_order_relaxed);
#endif
    return s;
}

void TstGridRenderPerf::staticIdle_data()
{
    QTest::addColumn<int>("croisillons");
    QTest::newRow("100")  << 100;
    QTest::newRow("300")  << 300;
    QTest::newRow("600")  << 600;
    QTest::newRow("1000") << 1000;
}

void TstGridRenderPerf::staticIdle()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, croisillons);
    setProp("croisillons", croisillons);
    setProp("mmSize", 12);
    setProp("gridX", 0.0);
    setProp("gridY", 0.0);

    measureIdle(15); // warmup
    const FrameStats s = measureIdle(60);
    printStats(QString("staticIdle/%1c").arg(croisillons), s, currentMode());
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstGridRenderPerf::zoomBurst_data()
{
    QTest::addColumn<int>("croisillons");
    QTest::newRow("100")  << 100;
    QTest::newRow("300")  << 300;
    QTest::newRow("600")  << 600;
    QTest::newRow("1000") << 1000;
}

void TstGridRenderPerf::zoomBurst()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, croisillons);
    setProp("croisillons", croisillons);
    setProp("mmSize", 12);
    setProp("gridX", 0.0);
    setProp("gridY", 0.0);

    measureIdle(15); // warmup

    const FrameStats s = measureBurst(30, [this](int i) {
        // mmSize est int côté GridManager. Variation 6..36 (~scroll user).
        setProp("mmSize", QVariant(6 + i));
    });
    printStats(QString("zoomBurst/%1c").arg(croisillons), s, currentMode());
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstGridRenderPerf::panBurst_data()
{
    QTest::addColumn<int>("croisillons");
    QTest::newRow("100")  << 100;
    QTest::newRow("300")  << 300;
    QTest::newRow("600")  << 600;
    QTest::newRow("1000") << 1000;
}

void TstGridRenderPerf::panBurst()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, croisillons);
    setProp("croisillons", croisillons);
    setProp("mmSize", 12);
    setProp("gridX", 0.0);
    setProp("gridY", 0.0);

    measureIdle(15); // warmup

    const FrameStats s = measureBurst(30, [this](int i) {
        // Simule un drag : translation diagonale en continu.
        setProp("gridX", QVariant(-50.0 * i));
        setProp("gridY", QVariant(-30.0 * i));
    });
    printStats(QString("panBurst/%1c").arg(croisillons), s, currentMode());
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstGridRenderPerf::resizeCroisillons()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    setProp("croisillons", 600);
    setProp("mmSize", 12);
    measureIdle(15);

    // 5 changements consécutifs de croisillons : pour le Repeater c'est
    // la ré-instanciation de tous les Rectangle (très coûteux). Pour le
    // Canvas c'est juste une property set (no-op visuel si culling rejette
    // toutes les nouvelles lignes hors viewport).
    const QList<int> values = {300, 1000, 200, 1500, 600};
    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer t;
    QList<qint64> deltas;
    qint64 lastNs = 0;
#ifdef MEOW_HAS_CANVAS_PAINTER
    GridCanvasPainterRenderer::resetStats();
#endif
    t.start();
    for (int v : values) {
        setProp("croisillons", v);
        m_view->update();
        spy.clear();
        if (!spy.wait(5000)) break;
        const qint64 nowNs = t.nsecsElapsed();
        if (lastNs > 0) deltas.append(nowNs - lastNs);
        lastNs = nowNs;
    }
    FrameStats s = computeStats(deltas);
#ifdef MEOW_HAS_CANVAS_PAINTER
    s.paintCalls = GridCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    if (s.frames > 0) {
        const std::int64_t totalNs = GridCanvasPainterRenderer::s_totalPaintNs.load(
            std::memory_order_relaxed);
        s.cpuMsPerFrame = (totalNs / 1.0e6) / s.frames;
    }
    s.linesEmitted = GridCanvasPainterRenderer::s_totalLinesEmitted.load(
        std::memory_order_relaxed);
#endif
    printStats(QString("resizeCroisillons"), s, currentMode());
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

int main(int argc, char *argv[])
{
    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setSwapInterval(0);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    app.setAttribute(Qt::AA_Use96Dpi, true);
    TstGridRenderPerf t;
    return QTest::qExec(&t, argc, argv);
}
#include "tst_grid_render_perf.moc"
