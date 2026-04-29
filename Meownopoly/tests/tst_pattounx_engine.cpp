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

    // ----- Damping & friction (spec → engine) -----

    // Helper : pousse un Kinematic avec une impulsion d'input pendant
    // `pushFrames`, puis lâche l'input et simule `coastFrames` frames de
    // décélération. Retourne la vitesse finale.
    static qreal coastSpeed(qreal damping, int pushFrames, int coastFrames)
    {
        PattounX_engine eng;
        BodySpec s = kinematicAt("p", V(0, 0));
        s.maxSpeed = 50.0;
        s.acceleration = 200.0;
        s.linearDamping = damping;
        eng.upsertBody(s);

        const qreal dt = 1.0 / 60.0;
        eng.setBodyInput("p", V(1, 0));
        for (int i = 0; i < pushFrames; ++i) eng.step(dt);
        eng.setBodyInput("p", V(0, 0));
        for (int i = 0; i < coastFrames; ++i) eng.step(dt);

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        return snap.bodies["p"].velocity.length();
    }

    // Régression : avant le fix de pattounx_engine_v2.cpp:157,
    // applyGroundFrictionAndZones initialisait `currentDamping` à
    // DEFAULT_GROUND_DAMPING (0.05) en ignorant body.spec.linearDamping.
    // Avec ce bug, damping=0.0 et damping=0.5 produisaient le même
    // comportement (les deux étaient écrasés par 0.05). On vérifie que la
    // vitesse de coast diffère significativement.
    void linearDamping_isAppliedFromSpec()
    {
        const qreal vNoDamp   = coastSpeed(0.0,  30, 30); // 0.5s push, 0.5s coast
        const qreal vMidDamp  = coastSpeed(0.1,  30, 30);
        const qreal vHighDamp = coastSpeed(0.5,  30, 30);

        // Plus le damping est fort, plus la velocity coastante est faible.
        QVERIFY2(vNoDamp > vMidDamp + 0.5,
                 qPrintable(QString("damping=0 et damping=0.1 trop proches : "
                                    "%1 vs %2").arg(vNoDamp).arg(vMidDamp)));
        QVERIFY2(vMidDamp > vHighDamp + 0.5,
                 qPrintable(QString("damping=0.1 et damping=0.5 trop proches : "
                                    "%1 vs %2").arg(vMidDamp).arg(vHighDamp)));
        // damping=0 doit conserver presque toute la vitesse (proche de
        // maxSpeed=50). damping=0.5 doit avoir presque tout amorti après 30
        // frames (~0.5s) car (1-0.5)^30 ≈ 1e-9.
        QVERIFY2(vNoDamp > 40.0,
                 qPrintable(QString("damping=0 freine trop : %1").arg(vNoDamp)));
        QVERIFY2(vHighDamp < 1.0,
                 qPrintable(QString("damping=0.5 ne freine pas : %1").arg(vHighDamp)));
    }

    // Régression complémentaire : un Kinematic isolé hors zone doit voir
    // son damping spec respecté (et non DEFAULT_GROUND_DAMPING=0.05).
    // On compare un body damping=0.05 (égal au défaut) à un body
    // damping=0.30 ; la diff doit être nette.
    void linearDamping_overridesDefaultGroundDamping()
    {
        const qreal vAtDefault = coastSpeed(0.05, 30, 60);
        const qreal vAtSix     = coastSpeed(0.30, 30, 60);
        QVERIFY2(vAtDefault > vAtSix + 1.0,
                 qPrintable(QString("0.05 et 0.30 indiscernables : %1 vs %2")
                                .arg(vAtDefault).arg(vAtSix)));
    }

    // Body-body : la friction tangentielle (Coulomb) doit réduire la
    // velocity tangentielle d'A glissant contre B. On lance A avec une
    // velocity oblique vers B, et on compare la velocity tangentielle
    // finale entre dynamicFriction faible et élevée.
    static qreal tangentialAfterContact(qreal dynFric)
    {
        PattounX_engine eng;
        BodySpec a = dynamicAt("A", V(-0.5, 0.0), 0.5);
        a.linearDamping = 0.0;       // isoler l'effet du friction de contact
        a.staticFriction = 0.0;      // pas de stiction (test friction dynamique)
        a.dynamicFriction = dynFric;
        a.restitution = 0.0;         // pas de rebond pour clarté
        BodySpec b = dynamicAt("B", V(0.6, 0.0), 0.5, 100.0); // très lourd → quasi statique
        b.linearDamping = 0.0;
        b.staticFriction = 0.0;
        b.dynamicFriction = dynFric;
        b.restitution = 0.0;
        eng.upsertBody(a);
        eng.upsertBody(b);

        // Velocity oblique : composante tangentielle (y) + normale (x)
        eng.applyImpulse("A", V(5.0, 3.0));

        const qreal dt = 1.0 / 60.0;
        for (int i = 0; i < 30; ++i) eng.step(dt);

        WorldSnapshot snap;
        eng.writeSnapshot(snap, 0, 0);
        return std::abs(snap.bodies["A"].velocity.y());
    }

    void dynamicFriction_reducesTangentialVelocity()
    {
        const qreal vyNoFric  = tangentialAfterContact(0.0);
        const qreal vyHighFric = tangentialAfterContact(1.0);
        QVERIFY2(vyHighFric < vyNoFric - 0.1,
                 qPrintable(QString("friction=0 et friction=1 indiscernables : "
                                    "vyNoFric=%1 vyHigh=%2")
                                .arg(vyNoFric).arg(vyHighFric)));
    }

    // staticFriction : seuil au-dessus duquel l'impulsion tangentielle
    // n'est PAS appliquée. Avec staticFriction=0, l'impulsion tangentielle
    // de Coulomb passe en dynamic (jt = -mu*jn). Avec staticFriction très
    // élevée, jt est plafonné à mu_s*jn ce qui peut littéralement annuler
    // une glissade lente. On vérifie qu'avec staticFriction=10 (au-dessus
    // de mu*jn nécessaire), la velocity tangentielle est plus préservée
    // (stiction) qu'avec staticFriction=0 + dynamicFriction=1.
    void staticFriction_thresholdAffectsTangential()
    {
        // muS très élevé → jt complet appliqué (max friction utilisée),
        // dynamique nulle. C'est la branche "static" du code.
        const qreal vyStatic = [&]() {
            PattounX_engine eng;
            BodySpec a = dynamicAt("A", V(-0.5, 0.0), 0.5);
            a.linearDamping = 0.0;
            a.staticFriction = 10.0;     // très élevé → branche stiction prise
            a.dynamicFriction = 0.0;
            a.restitution = 0.0;
            BodySpec b = dynamicAt("B", V(0.6, 0.0), 0.5, 100.0);
            b.linearDamping = 0.0;
            b.staticFriction = 10.0;
            b.dynamicFriction = 0.0;
            b.restitution = 0.0;
            eng.upsertBody(a);
            eng.upsertBody(b);
            eng.applyImpulse("A", V(5.0, 3.0));
            const qreal dt = 1.0 / 60.0;
            for (int i = 0; i < 30; ++i) eng.step(dt);
            WorldSnapshot snap;
            eng.writeSnapshot(snap, 0, 0);
            return std::abs(snap.bodies["A"].velocity.y());
        }();

        // muS=0 + muD=0 → aucune friction tangentielle, vy préservée.
        const qreal vyFreeSlip = tangentialAfterContact(0.0);

        QVERIFY2(vyStatic < vyFreeSlip - 0.1,
                 qPrintable(QString("staticFriction=10 vs sans friction : "
                                    "%1 vs %2 (devrait être plus faible)")
                                .arg(vyStatic).arg(vyFreeSlip)));
    }

    // Zone friction : un body qui coast dans une zone à frictionStrength
    // élevé doit décélérer plus vite que dans l'air libre. La zone doit
    // englober la trajectoire complète du coast (sinon le body en sort et
    // retombe sur le linearDamping spec).
    void zoneFrictionStrength_slowsBody()
    {
        auto coastInZone = [](qreal zoneFriction) -> qreal {
            PattounX_engine eng;
            BodySpec s = kinematicAt("p", V(0, 0));
            s.maxSpeed = 50.0;
            s.acceleration = 200.0;
            s.linearDamping = 0.05;
            eng.upsertBody(s);

            ZoneSpec z;
            z.id = "slowZone";
            z.exclusion = false;
            z.trigger = false;
            z.frictionStrength = zoneFriction;
            // Polygone large pour que le body reste dedans tout le coast.
            z.polygon = { V(-5, -5), V(200, -5), V(200, 5), V(-5, 5) };
            eng.upsertZone(z);

            const qreal dt = 1.0 / 60.0;
            // Push court : 5 frames suffisent pour atteindre maxSpeed
            // (acceleration=200, blend cap=1 dès la 1re frame).
            eng.setBodyInput("p", V(1, 0));
            for (int i = 0; i < 5; ++i) eng.step(dt);
            eng.setBodyInput("p", V(0, 0));
            for (int i = 0; i < 60; ++i) eng.step(dt);

            WorldSnapshot snap;
            eng.writeSnapshot(snap, 0, 0);
            return snap.bodies["p"].velocity.length();
        };

        const qreal vNoFric  = coastInZone(0.0);
        const qreal vHiFric  = coastInZone(0.4);
        QVERIFY2(vNoFric > vHiFric + 1.0,
                 qPrintable(QString("zone friction inactive : %1 vs %2")
                                .arg(vNoFric).arg(vHiFric)));
    }
};

QTEST_GUILESS_MAIN(TstPattounxEngine)
#include "tst_pattounx_engine.moc"
