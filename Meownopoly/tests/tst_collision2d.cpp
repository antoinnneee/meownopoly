#include "collision2d.h"

#include <QObject>
#include <QTest>
#include <QVector2D>
#include <QVector>

namespace {

QVector2D V(qreal x, qreal y) { return QVector2D(static_cast<float>(x), static_cast<float>(y)); }

Polygon2D makePolygon(QVector<QVector2D> pts)
{
    Polygon2D p;
    p.points = std::move(pts);
    p.computeCache();
    return p;
}

bool fuzzy(qreal a, qreal b, qreal eps = 1e-3)
{
    return std::abs(a - b) <= eps;
}

} // namespace

class TstCollision2D : public QObject
{
    Q_OBJECT

private slots:
    // ----- pointToSegmentDistance -----
    void pointToSegment_atEnd()
    {
        SegmentResult r = Collision2D::pointToSegmentDistance(V(0, 0), V(1, 0), V(3, 0));
        QVERIFY(fuzzy(r.distance, 1.0));
        QVERIFY(fuzzy(r.t, 0.0));
        QCOMPARE(r.closestPoint, V(1, 0));
    }

    void pointToSegment_middle()
    {
        SegmentResult r = Collision2D::pointToSegmentDistance(V(2, 1), V(0, 0), V(4, 0));
        QVERIFY(fuzzy(r.distance, 1.0));
        QVERIFY(fuzzy(r.t, 0.5));
        QCOMPARE(r.closestPoint, V(2, 0));
    }

    void pointToSegment_outside()
    {
        SegmentResult r = Collision2D::pointToSegmentDistance(V(5, 1), V(0, 0), V(4, 0));
        QVERIFY(fuzzy(r.t, 1.0));
        QCOMPARE(r.closestPoint, V(4, 0));
    }

    // ----- pointInPolygon -----
    void pointInPolygon_concave()
    {
        // Polygone en L (concave)
        Polygon2D L = makePolygon({ V(0, 0), V(4, 0), V(4, 2), V(2, 2), V(2, 4), V(0, 4) });
        QVERIFY(Collision2D::pointInPolygon(V(1, 1), L));
        QVERIFY(Collision2D::pointInPolygon(V(3, 1), L));
        QVERIFY(!Collision2D::pointInPolygon(V(3, 3), L)); // dans le creux du L
        QVERIFY(!Collision2D::pointInPolygon(V(-1, 1), L));
    }

    void pointInPolygon_convex()
    {
        Polygon2D box = makePolygon({ V(-1, -1), V(1, -1), V(1, 1), V(-1, 1) });
        QVERIFY(Collision2D::pointInPolygon(V(0, 0), box));
        QVERIFY(!Collision2D::pointInPolygon(V(2, 0), box));
    }

    // ----- sweepCircleSegment -----
    void sweepCircleSegment_direct()
    {
        QVector2D closest, normal;
        qreal t = Collision2D::sweepCircleSegment(
            V(0, 0), V(0, 5), 1.0, V(-2, 3), V(2, 3), closest, normal);
        QVERIFY(t >= 0.0);
        QVERIFY(fuzzy(t, 2.0 / 5.0)); // collide à y=2 (3 - r) ; movement y va 0→5
    }

    void sweepCircleSegment_parallel()
    {
        // Mouvement parallèle au segment, sans intersection : doit échouer (-1)
        QVector2D closest, normal;
        qreal t = Collision2D::sweepCircleSegment(
            V(0, 0), V(5, 0), 0.1, V(0, 3), V(5, 3), closest, normal);
        QVERIFY(t < 0.0);
    }

    // ----- sweepCircleCircle -----
    void sweepCircleCircle_headOn()
    {
        // A à x=0 → x=4, B fixe à x=5
        QVector2D normal;
        qreal t = Collision2D::sweepCircleCircle(
            V(0, 0), V(4, 0), 1.0, V(5, 0), V(5, 0), 1.0, normal);
        QVERIFY(t >= 0.0);
        // collision quand |A - B| = 2 → A à x=3 → t = 3/4
        QVERIFY(fuzzy(t, 0.75));
        QVERIFY(fuzzy(normal.x(), -1.0));
        QVERIFY(fuzzy(normal.y(), 0.0));
    }

    void sweepCircleCircle_oblique()
    {
        QVector2D normal;
        qreal t = Collision2D::sweepCircleCircle(
            V(0, 0), V(10, 0), 1.0, V(0, 1.5), V(0, 1.5), 1.0, normal);
        QVERIFY(t >= 0.0);
        // distance perpendiculaire = 1.5, somme rayons = 2 → ils s'effleurent
    }

    void sweepCircleCircle_alreadyOverlap()
    {
        QVector2D normal;
        qreal t = Collision2D::sweepCircleCircle(
            V(0, 0), V(1, 0), 1.0, V(1, 0), V(2, 0), 1.0, normal);
        QVERIFY(t == 0.0); // déjà en pénétration au départ
    }

    void sweepCircleCircle_miss()
    {
        QVector2D normal;
        qreal t = Collision2D::sweepCircleCircle(
            V(0, 0), V(1, 0), 0.1, V(0, 5), V(1, 5), 0.1, normal);
        QVERIFY(t < 0.0);
    }

    // ----- applyBounce -----
    void applyBounce_zero()
    {
        QVector2D v(2, -3);
        QVector2D n(0, 1);
        QVector2D out = Collision2D::applyBounce(v, n, 0.0, 1.0);
        // bounce=0 : la composante normale est annulée
        QCOMPARE(out, V(2, 0));
    }

    void applyBounce_full()
    {
        QVector2D v(2, -3);
        QVector2D n(0, 1);
        QVector2D out = Collision2D::applyBounce(v, n, 1.0, 1.0);
        // bounce=1 : normale inversée, tangentielle conservée
        QCOMPARE(out, V(2, 3));
    }

    void applyBounce_noSlide()
    {
        QVector2D v(2, -3);
        QVector2D n(0, 1);
        QVector2D out = Collision2D::applyBounce(v, n, 0.0, 0.0);
        // bounce=0 + slide=0 : tout annulé
        QCOMPARE(out, V(0, 0));
    }

    void applyBounce_outwardVelocity()
    {
        QVector2D v(0, 2); // vélocité s'éloigne déjà du mur
        QVector2D n(0, 1);
        QVector2D out = Collision2D::applyBounce(v, n, 0.5, 1.0);
        QCOMPARE(out, v); // inchangée
    }
};

QTEST_GUILESS_MAIN(TstCollision2D)
#include "tst_collision2d.moc"
