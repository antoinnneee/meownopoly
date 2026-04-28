#include "pattounx_engine_v2.h"
#include "pattounx_types.h"

#include <QObject>
#include <QTest>

using namespace pattounx;

namespace {

QVector2D V(qreal x, qreal y) { return QVector2D(static_cast<float>(x), static_cast<float>(y)); }

bool fuzzy(qreal a, qreal b, qreal eps = 1e-3)
{
    return std::abs(a - b) <= eps;
}

BodySpec kinematicAt(const QString &id, QVector2D pos, qreal radius = 0.2)
{
    BodySpec s;
    s.id = id;
    s.type = BodyType::Kinematic;
    s.shape.type = ShapeType::Circle;
    s.shape.radius = radius;
    s.position = pos;
    s.acceleration = 30.0;
    s.maxSpeed = 5.0;
    return s;
}

BodySpec dynamicAt(const QString &id, QVector2D pos, qreal radius = 0.5, qreal mass = 1.0)
{
    BodySpec s;
    s.id = id;
    s.type = BodyType::Dynamic;
    s.shape.type = ShapeType::Circle;
    s.shape.radius = radius;
    s.position = pos;
    s.mass = mass;
    s.acceleration = 0.0;
    s.maxSpeed = 100.0;
    s.linearDamping = 0.05;
    s.restitution = 0.5;
    return s;
}

ZoneSpec wallBox(const QString &id, qreal x, qreal y, qreal w, qreal h)
{
    ZoneSpec z;
    z.id = id;
    z.exclusion = true;
    z.polygon = { V(x, y), V(x + w, y), V(x + w, y + h), V(x, y + h) };
    return z;
}

} // namespace

class TstPattounxEngine : public QObject
{
    Q_OBJECT

private slots:
    // ----- Smoke tests -----

    void emptyEngine_stepIsNoop()
    {
        PattounX_engine eng;
        eng.step(1.0 / 60.0);
        QCOMPARE(eng.bodyCount(), 0);
        QCOMPARE(eng.zoneCount(), 0);
    }

    void createAndQueryBody()
    {
        PattounX_engine eng;
        eng.upsertBody(kinematicAt("p1", V(1, 2)));
        QCOMPARE(eng.bodyCount(), 1);
        QVERIFY(eng.hasBody("p1"));

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        QVERIFY(snap.bodies.contains("p1"));
        QCOMPARE(snap.bodies["p1"].position, V(1, 2));
    }

    void removeBody()
    {
        PattounX_engine eng;
        eng.upsertBody(kinematicAt("p1", V(0, 0)));
        eng.removeBody("p1");
        QCOMPARE(eng.bodyCount(), 0);
        QVERIFY(!eng.hasBody("p1"));
    }

    void inputDrivesKinematic()
    {
        PattounX_engine eng;
        eng.upsertBody(kinematicAt("p1", V(0, 0)));
        eng.setBodyInput("p1", V(1, 0)); // vers +x

        const qreal dt = 1.0 / 60.0;
        for (int i = 0; i < 30; ++i) eng.step(dt); // 0.5s

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        QVERIFY(snap.bodies["p1"].position.x() > 0.5f);
        QVERIFY(fuzzy(snap.bodies["p1"].position.y(), 0.0));
    }

    // ----- Zones d'exclusion (collision body-zone) -----

    void bodyStopsAtWall()
    {
        PattounX_engine eng;
        // Body part de (0,0), vise +x avec mur d'exclusion à x>=2
        BodySpec s = kinematicAt("p1", V(0, 0), 0.3);
        s.maxSpeed = 10.0;
        s.acceleration = 100.0;
        eng.upsertBody(s);
        eng.upsertZone(wallBox("wall", 2.0, -5.0, 5.0, 10.0));
        eng.setBodyInput("p1", V(1, 0));

        const qreal dt = 1.0 / 60.0;
        for (int i = 0; i < 120; ++i) eng.step(dt); // 2s : large

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        // Doit être bloqué avant x=2 - radius (0.3), avec un peu de tolérance pour le buffer
        QVERIFY2(snap.bodies["p1"].position.x() < 2.0,
                 qPrintable(QString("position.x = %1, expected < 2.0")
                                .arg(snap.bodies["p1"].position.x())));
        QVERIFY(snap.bodies["p1"].position.x() > 1.0); // a quand même avancé
    }

    // ----- Body-body cercle-cercle -----

    void bodyBody_dynamicHitDynamic_pushed()
    {
        PattounX_engine eng;
        // A à (0,0) avec velocity initiale +x ; B à (1.5,0) immobile.
        // Avec radius=0.5 chacun, le contact est attendu à dx=1.0.
        BodySpec a = dynamicAt("A", V(0, 0));
        a.linearDamping = 0.0; // pas de friction pour le test
        BodySpec b = dynamicAt("B", V(1.5, 0));
        b.linearDamping = 0.0;
        eng.upsertBody(a);
        eng.upsertBody(b);

        // Donner une impulsion à A pour qu'il aille vers B
        eng.applyImpulse("A", V(5, 0));

        const qreal dt = 1.0 / 60.0;
        for (int i = 0; i < 120; ++i) eng.step(dt);

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        // B doit avoir été poussé vers +x
        QVERIFY2(snap.bodies["B"].position.x() > 1.55f,
                 qPrintable(QString("B.x = %1").arg(snap.bodies["B"].position.x())));
    }

    void bodyBody_kinematicPushesDynamic()
    {
        PattounX_engine eng;
        // Joueur kinematic pousse une caisse dynamic
        BodySpec p = kinematicAt("player", V(0, 0), 0.3);
        p.maxSpeed = 5.0;
        p.acceleration = 50.0;
        BodySpec crate = dynamicAt("crate", V(2, 0), 0.4);
        eng.upsertBody(p);
        eng.upsertBody(crate);

        eng.setBodyInput("player", V(1, 0));

        const qreal dt = 1.0 / 60.0;
        for (int i = 0; i < 60; ++i) eng.step(dt); // 1s

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        // La caisse doit avoir bougé (le player la pousse via les positions
        // de contact en CCD)
        QVERIFY2(snap.bodies["crate"].position.x() > 2.05f,
                 qPrintable(QString("crate.x = %1").arg(snap.bodies["crate"].position.x())));
    }

    void bodyBody_kinematicPush_massAffectsResponse()
    {
        // Régression : avant le fix, Kinematic avait `invMass() = 0`, ce qui
        // annulait la masse de la caisse dans le calcul d'impulsion (les
        // caisses lourdes étaient poussées comme les légères). Avec la
        // masse inertielle correcte, une caisse 5× plus lourde se déplace
        // significativement moins qu'une caisse de masse 1.
        auto runScenario = [](qreal crateMass) -> qreal {
            PattounX_engine eng;
            BodySpec p = kinematicAt("player", V(0, 0), 0.3);
            p.maxSpeed = 5.0;
            p.acceleration = 50.0;
            p.mass = 1.0;
            BodySpec crate = dynamicAt("crate", V(2, 0), 0.4, crateMass);
            crate.linearDamping = 0.2;   // friction modérée pour limiter l'inertie
            eng.upsertBody(p);
            eng.upsertBody(crate);
            eng.setBodyInput("player", V(1, 0));

            const qreal dt = 1.0 / 60.0;
            for (int i = 0; i < 60; ++i) eng.step(dt); // 1s

            WorldSnapshot snap;
            eng.writeSnapshot(snap, 0, 0);
            return snap.bodies["crate"].position.x() - 2.0;
        };

        const qreal lightDx = runScenario(1.0);
        const qreal heavyDx = runScenario(5.0);

        QVERIFY2(lightDx > 0.05,
                 qPrintable(QString("light crate didn't move: dx=%1").arg(lightDx)));
        QVERIFY2(heavyDx > 0.0,
                 qPrintable(QString("heavy crate didn't move at all: dx=%1").arg(heavyDx)));
        // La caisse lourde doit clairement bouger moins. Marge volontairement
        // large (1.4×) pour absorber les variations dues au damping et au
        // re-contact répété frame par frame.
        QVERIFY2(lightDx > heavyDx * 1.4,
                 qPrintable(QString("mass had no significant effect: light=%1, heavy=%2")
                                .arg(lightDx).arg(heavyDx)));
    }

    void bodyBody_noOverlap_noEvent()
    {
        PattounX_engine eng;
        eng.upsertBody(dynamicAt("A", V(0, 0)));
        eng.upsertBody(dynamicAt("B", V(10, 10)));

        eng.step(1.0 / 60.0);

        auto ev = eng.takeEvents();
        QCOMPARE(ev.collisions.size(), 0);
    }

    // ----- Sleep system -----

    void sleepActivatesAfterIdleFrames()
    {
        PattounX_engine eng;
        eng.upsertBody(kinematicAt("p", V(0, 0)));
        // pas d'input → le body est immédiatement au repos
        const qreal dt = 1.0 / 60.0;
        // > SLEEP_FRAMES_REQUIRED (30)
        for (int i = 0; i < 60; ++i) eng.step(dt);

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        QVERIFY(snap.bodies["p"].isSleeping);
    }

    // ----- Zones triggers (trigger-only) -----

    void enterExitZone_emitsEvents()
    {
        PattounX_engine eng;
        eng.upsertBody(kinematicAt("p", V(0, 0), 0.1));

        ZoneSpec trig;
        trig.id = "trig";
        trig.exclusion = false;
        trig.trigger = true;
        // zone 2x2 centrée en (5,0)
        trig.polygon = { V(4, -1), V(6, -1), V(6, 1), V(4, 1) };
        eng.upsertZone(trig);

        BodySpec moveSpec = kinematicAt("p", V(0, 0), 0.1);
        moveSpec.maxSpeed = 30.0;
        moveSpec.acceleration = 100.0;
        eng.upsertBody(moveSpec);
        eng.setBodyInput("p", V(1, 0));

        const qreal dt = 1.0 / 60.0;
        bool gotEnter = false;
        bool gotExit = false;
        for (int i = 0; i < 120 && !(gotEnter && gotExit); ++i) {
            eng.step(dt);
            auto ev = eng.takeEvents();
            for (const auto &e : ev.entered)
                if (e.first == "p" && e.second == "trig") gotEnter = true;
            for (const auto &e : ev.exited)
                if (e.first == "p" && e.second == "trig") gotExit = true;
        }
        QVERIFY(gotEnter);
        QVERIFY(gotExit);
    }

    // ----- Robustesse spec -----

    void invalidPolygon_isIgnored()
    {
        PattounX_engine eng;
        ZoneSpec degenerate;
        degenerate.id = "z";
        degenerate.polygon = { V(0, 0), V(1, 0) }; // 2 points → invalide
        eng.upsertZone(degenerate);
        QCOMPARE(eng.zoneCount(), 0);
    }

    void teleportResetsSweep()
    {
        PattounX_engine eng;
        eng.upsertBody(kinematicAt("p", V(0, 0)));
        eng.setBodyPosition("p", V(50, 50));
        eng.step(1.0 / 60.0);

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        QVERIFY(fuzzy(snap.bodies["p"].position.x(), 50.0));
        QVERIFY(fuzzy(snap.bodies["p"].position.y(), 50.0));
    }
};

QTEST_GUILESS_MAIN(TstPattounxEngine)
#include "tst_pattounx_engine.moc"
