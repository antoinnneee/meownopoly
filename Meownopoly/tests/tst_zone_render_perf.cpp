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
#include <QVariantList>
#include <QVariantMap>
#include <QtTest/QtTest>
#include <QString>
#include <algorithm>
#include <cmath>
#include <numeric>

#ifdef MEOW_HAS_CANVAS_PAINTER
#include "editor/painter/zone_canvas_painter.h"
#endif

namespace {

struct FrameStats {
    double meanMs;
    double p50Ms;
    double p95Ms;
    double p99Ms;
    double maxMs;
    int frames;
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
        "[%s] n=%d  mean=%.2f ms  p50=%.2f  p95=%.2f  p99=%.2f  max=%.2f  (~%.1f FPS)",
        qPrintable(label), s.frames, s.meanMs, s.p50Ms, s.p95Ms, s.p99Ms, s.maxMs,
        s.meanMs > 0.0 ? 1000.0 / s.meanMs : 0.0);
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
    return computeStats(times);
}

void TstZoneRenderPerf::renderScaling_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::newRow("10")  << 10;
    QTest::newRow("50")  << 50;
    QTest::newRow("100") << 100;
    QTest::newRow("200") << 200;
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
    QTest::newRow("100x8 verts")  << 100 << 8;
    QTest::newRow("100x20 verts") << 100 << 20;
    QTest::newRow("100x40 verts") << 100 << 40;
    QTest::newRow("50 grandes (radius=8, 20 verts)") << 50 << 20;
}

void TstZoneRenderPerf::hatchComplexity()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    QFETCH(int, vertices);
    // Pour la dernière ligne ("50 grandes"), on bump aussi le radius
    const qreal radius = (zoneCount == 50) ? 8.0 : 2.0;
    setZones(makeZonesGrid(zoneCount, vertices, radius, 200.0, 200.0));
    setGridSize(30.0);

    measureFrames(15);
    const FrameStats s = measureFrames(60);
    printStats(QString("hatchComplexity/%1x%2v").arg(zoneCount).arg(vertices), s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

void TstZoneRenderPerf::zoomBurst_data()
{
    QTest::addColumn<int>("zoneCount");
    QTest::newRow("50")  << 50;
    QTest::newRow("100") << 100;
    QTest::newRow("200") << 200;
}

void TstZoneRenderPerf::zoomBurst()
{
#ifdef MEOW_HAS_CANVAS_PAINTER
    QFETCH(int, zoneCount);
    setZones(makeZonesGrid(zoneCount, 12, 2.0, 120.0, 120.0));
    setGridSize(20.0);

    measureFrames(15); // warmup

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
    const FrameStats s = computeStats(deltas);
    printStats(QString("zoomBurst/%1").arg(zoneCount), s);
    QVERIFY(s.frames > 0);
#else
    QSKIP("MEOW_HAS_CANVAS_PAINTER non défini.");
#endif
}

QTEST_MAIN(TstZoneRenderPerf)
#include "tst_zone_render_perf.moc"
