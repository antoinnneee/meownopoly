// Benchmark combiné : grille (GridCanvasPainter ou Repeater) + zones
// d'exclusion (ZoneCanvasPainter) dans la même scène, à partir d'une
// map JSON réaliste (test_map.json — ~22 zones polygonales aux tailles
// et positions variées).
//
// Sert à mesurer le coût total éditeur en conditions réelles (vs les
// scénarios synthétiques de tst_zone_render_perf et tst_grid_render_perf).
//
// Toggles :
//   - MEOW_GRID_RENDERER=repeater|canvas (défaut canvas)
//   - MEOW_ZONE_PARALLEL_MODE=baseline|...|precompute-async (défaut async)
//
// Compile uniquement si MEOW_HAS_CANVAS_PAINTER est défini (Qt 6.11+).

#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickView>
#include <QSignalSpy>
#include <QSurfaceFormat>
#include <QtTest/QtTest>
#include <QString>
#include <QFile>
#include <QVariantList>
#include <QVariantMap>
#include <algorithm>
#include <cmath>
#include <numeric>

#ifdef MEOW_HAS_CANVAS_PAINTER
#include "editor/painter/grid_canvas_painter.h"
#include "editor/painter/grid_canvas_painter_renderer.h"
#include "editor/painter/zone_canvas_painter.h"
#include "editor/painter/zone_canvas_painter_renderer.h"
#endif

namespace {

struct FrameStats {
    double meanMs = 0;
    double p50Ms = 0;
    double p95Ms = 0;
    double p99Ms = 0;
    double maxMs = 0;
    int frames = 0;
    double zonePaintMsPerFrame = 0.0;
    int zonePaintCalls = 0;
    double gridPaintMsPerFrame = 0.0;
    int gridPaintCalls = 0;
    qint64 gridLines = 0;
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

const char *currentGridMode()
{
    const QByteArray raw = qgetenv("MEOW_GRID_RENDERER").toLower();
    if (raw == "repeater") return "repeater";
    return "canvas";
}

void printStats(const QString &label, const FrameStats &s)
{
    qInfo().noquote() << QString::asprintf(
        "[%s/%s] n=%d  mean=%.2f ms  p50=%.2f  p95=%.2f  p99=%.2f  max=%.2f  (~%.1f FPS)  zone=%.2f ms/fr (%d)  grid=%.2f ms/fr (%d, %lld lines)",
        qPrintable(label), currentGridMode(),
        s.frames, s.meanMs, s.p50Ms, s.p95Ms, s.p99Ms, s.maxMs,
        s.meanMs > 0.0 ? 1000.0 / s.meanMs : 0.0,
        s.zonePaintMsPerFrame, s.zonePaintCalls,
        s.gridPaintMsPerFrame, s.gridPaintCalls,
        static_cast<long long>(s.gridLines));
}

// Parse test_map.json → liste de zones { posX, posY, w, h, points, color }
// avec posX/posY/w/h en pixels (= gridRelativePosition * gridSize).
QVariantList parseMap(const QString &jsonPath, int gridSize)
{
    QFile f(jsonPath);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "Cannot open map JSON:" << jsonPath;
        return {};
    }
    const QByteArray data = f.readAll();
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError) {
        qWarning() << "JSON parse error:" << perr.errorString();
        return {};
    }
    const QJsonArray tiles = doc.object().value("snapableTiles").toArray();
    QVariantList zones;
    zones.reserve(tiles.size());
    for (const QJsonValue &tv : tiles) {
        const QJsonObject tile = tv.toObject();
        // tileType 2 = ExclusionZone (cf. cpp/game/map/maptypes.h)
        if (tile.value("tileType").toInt() != 2) continue;
        const QJsonObject zp = tile.value("zoneParameter").toObject();
        const QJsonObject dp = tile.value("displayParameter").toObject();
        if (zp.isEmpty()) continue;

        QVariantList points;
        for (const QJsonValue &pv : zp.value("polygonPoints").toArray()) {
            const QJsonObject po = pv.toObject();
            QVariantMap m;
            m.insert(QStringLiteral("x"), po.value("x").toDouble());
            m.insert(QStringLiteral("y"), po.value("y").toDouble());
            points.append(m);
        }
        if (points.size() < 3) continue;

        QVariantMap z;
        z.insert(QStringLiteral("posX"), dp.value("gridRelativePositionX").toDouble() * gridSize);
        z.insert(QStringLiteral("posY"), dp.value("gridRelativePositionY").toDouble() * gridSize);
        z.insert(QStringLiteral("w"),    dp.value("unitSizeWidth").toDouble() * gridSize);
        z.insert(QStringLiteral("h"),    dp.value("unitSizeHeight").toDouble() * gridSize);
        z.insert(QStringLiteral("points"), points);
        z.insert(QStringLiteral("color"),
                 QColor(zp.value("zoneColor").toString("#FF5722")));
        zones.append(z);
    }
    return zones;
}

} // namespace

class TstCombinedRenderPerf : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();

    void staticIdle();
    void zoomBurst();
    void panBurst();

private:
    void loadScene();
    void setProp(const char *name, const QVariant &v);
    FrameStats measureIdle(int frameCount);
    FrameStats measureBurst(int iterations,
                            std::function<void(int)> mutate);
    void fillCounters(FrameStats &s);

    QQuickView *m_view = nullptr;
    QVariantList m_zones;
    int m_tick = 0;
};

void TstCombinedRenderPerf::initTestCase()
{
#ifndef MEOW_HAS_CANVAS_PAINTER
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#else
    qmlRegisterType<GridCanvasPainter>("MeowPainter", 1, 0, "GridCanvasPainter");
    qmlRegisterType<ZoneCanvasPainter>("MeowPainter", 1, 0, "ZoneCanvasPainter");

    m_view = new QQuickView;
    m_view->setResizeMode(QQuickView::SizeRootObjectToView);
    m_view->resize(1280, 720);

    const QByteArray raw = qgetenv("MEOW_GRID_RENDERER").toLower();
    bool useCanvas = (raw != "repeater");
    m_view->rootContext()->setContextProperty(
        "_gridRendererUseCanvas", QVariant(useCanvas));
    qInfo().noquote() << QString("Grid mode actif : %1").arg(useCanvas ? "canvas" : "repeater");

    // Le QML est cherché via QFINDTESTDATA, donc relatif au tests/.
    // test_map.json est dans le même dossier — copié à côté du binaire
    // par le CMake POST_BUILD.
    const QString mapPath = QFINDTESTDATA("test_map.json");
    QVERIFY2(!mapPath.isEmpty(), "test_map.json introuvable");
    m_zones = parseMap(mapPath, /*gridSize*/12);
    QVERIFY2(!m_zones.isEmpty(), "Aucune zone parsée depuis test_map.json");
    qInfo().noquote() << QString("Zones chargées : %1").arg(m_zones.size());

    loadScene();
    setProp("zonesData", m_zones);
    m_view->show();

    QSignalSpy frameSpy(m_view, &QQuickWindow::frameSwapped);
    QVERIFY(frameSpy.wait(2000));
#endif
}

void TstCombinedRenderPerf::cleanupTestCase()
{
    delete m_view;
    m_view = nullptr;
}

void TstCombinedRenderPerf::loadScene()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    const QString qmlPath = QFINDTESTDATA("combined_render_scene.qml");
    QVERIFY(!qmlPath.isEmpty());
    m_view->setSource(QUrl::fromLocalFile(qmlPath));
    QStringList errs;
    for (const QQmlError &e : m_view->errors())
        errs << e.toString();
    QVERIFY2(m_view->status() == QQuickView::Ready, qPrintable(errs.join('\n')));
#endif
}

void TstCombinedRenderPerf::setProp(const char *name, const QVariant &v)
{
    if (m_view && m_view->rootObject())
        m_view->rootObject()->setProperty(name, v);
}

void TstCombinedRenderPerf::fillCounters(FrameStats &s)
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    if (s.frames <= 0) return;
    const std::int64_t zNs = ZoneCanvasPainterRenderer::s_totalPaintNs.load(
        std::memory_order_relaxed);
    s.zonePaintCalls = ZoneCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    s.zonePaintMsPerFrame = (zNs / 1.0e6) / s.frames;
    const std::int64_t gNs = GridCanvasPainterRenderer::s_totalPaintNs.load(
        std::memory_order_relaxed);
    s.gridPaintCalls = GridCanvasPainterRenderer::s_paintCalls.load(
        std::memory_order_relaxed);
    s.gridPaintMsPerFrame = (gNs / 1.0e6) / s.frames;
    s.gridLines = GridCanvasPainterRenderer::s_totalLinesEmitted.load(
        std::memory_order_relaxed);
#endif
}

FrameStats TstCombinedRenderPerf::measureIdle(int frameCount)
{
    QList<qint64> times;
    times.reserve(frameCount);

#ifdef MEOW_HAS_CANVAS_PAINTER
    ZoneCanvasPainterRenderer::resetPaintStats();
    GridCanvasPainterRenderer::resetStats();
#endif

    QSignalSpy spy(m_view, &QQuickWindow::frameSwapped);
    QElapsedTimer timer;
    timer.start();
    qint64 lastNs = 0;
    int captured = 0;
    while (captured < frameCount) {
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
    fillCounters(s);
    return s;
}

FrameStats TstCombinedRenderPerf::measureBurst(int iterations,
                                               std::function<void(int)> mutate)
{
    QList<qint64> times;
    times.reserve(iterations);

#ifdef MEOW_HAS_CANVAS_PAINTER
    ZoneCanvasPainterRenderer::resetPaintStats();
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
    fillCounters(s);
    return s;
}

void TstCombinedRenderPerf::staticIdle()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    setProp("croisillons", 600);
    setProp("mmSize", 12);
    // Centrer une partie de la map sur le viewport en partant du coin
    // (0,0) — la majorité des zones sont autour de gridPos (0..30, 0..20).
    setProp("gridX", 0.0);
    setProp("gridY", 0.0);

    measureIdle(15);
    const FrameStats s = measureIdle(60);
    printStats(QString("staticIdle/%1z").arg(m_zones.size()), s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstCombinedRenderPerf::zoomBurst()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    setProp("croisillons", 600);
    setProp("mmSize", 1.0);
    setProp("gridX", 0.0);
    setProp("gridY", 0.0);

    measureIdle(15);

    // Burst multiplicatif identique à tst_grid_render_perf : mmSize=1
    // → mmSize≈237 en 30 crans à ×1.2. Zoom recompute les zones (le
    // gridSize de chaque ZoneCanvasPainter change → invalide cache +
    // recompute hatch segments en async). Stresse le pipeline complet.
    const double startMmSize = 1.0;
    const double factor = 1.2;
    const FrameStats s = measureBurst(30, [this, startMmSize, factor](int i) {
        const double mm = startMmSize * std::pow(factor, i + 1);
        setProp("mmSize", QVariant(mm));
    });
    printStats(QString("zoomBurst/%1z").arg(m_zones.size()), s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstCombinedRenderPerf::panBurst()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    setProp("croisillons", 600);
    setProp("mmSize", 12);
    setProp("gridX", 0.0);
    setProp("gridY", 0.0);

    measureIdle(15);

    const FrameStats s = measureBurst(30, [this](int i) {
        // Pan diagonal pour traverser la zone qui contient les zones.
        setProp("gridX", QVariant(-30.0 * i));
        setProp("gridY", QVariant(-15.0 * i));
    });
    printStats(QString("panBurst/%1z").arg(m_zones.size()), s);
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
    TstCombinedRenderPerf t;
    return QTest::qExec(&t, argc, argv);
}
#include "tst_combined_render_perf.moc"
