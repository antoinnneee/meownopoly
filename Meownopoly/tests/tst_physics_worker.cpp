#include "physics_world.h"
#include "physics_worker.h"
#include "pattounx_types.h"

#include <QObject>
#include <QSignalSpy>
#include <QTest>
#include <QVector2D>

class TstPhysicsWorker : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        // Enregistre les types pour Qt::QueuedConnection
        PhysicsWorld::registerQml();
    }

    void startStop_clean()
    {
        PhysicsWorld w;
        QVERIFY(!w.isRunning());
        w.start();
        QVERIFY(w.isRunning());
        // Laisse quelques ticks tourner
        QTest::qWait(150);
        w.stop();
        QVERIFY(!w.isRunning());
    }

    void createBody_appearsInSnapshot()
    {
        PhysicsWorld w;
        w.setTickRate(120);
        w.start();

        w.createKinematicActor("p1", QVector2D(2.0f, 3.0f), 0.3,
                               QVariantMap { { "maxSpeed", 0.0 } });

        // Attend qu'un snapshot soit publié et propagé à la GUI thread
        QSignalSpy spy(&w, &PhysicsWorld::snapshotAvailable);
        QVERIFY(spy.wait(500));

        // Plusieurs frames pour s'assurer que le body est visible
        for (int i = 0; i < 5; ++i) {
            QTest::qWait(20);
            w.beginFrame();
        }

        QVariantMap state = w.bodyState("p1");
        QVERIFY(state.contains("id"));
        QCOMPARE(state.value("id").toString(), QStringLiteral("p1"));

        QVector2D pos = state.value("position").value<QVector2D>();
        QCOMPARE(pos, QVector2D(2.0f, 3.0f));

        w.stop();
    }

    void multipleBodies_listedInAllIds()
    {
        PhysicsWorld w;
        w.start();
        w.createKinematicActor("p1", QVector2D(0, 0), 0.2);
        w.createKinematicActor("p2", QVector2D(1, 0), 0.2);
        w.createKinematicActor("p3", QVector2D(2, 0), 0.2);

        QSignalSpy spy(&w, &PhysicsWorld::snapshotAvailable);
        QVERIFY(spy.wait(500));
        for (int i = 0; i < 5; ++i) {
            QTest::qWait(20);
            w.beginFrame();
        }

        QStringList ids = w.allBodyIds();
        ids.sort();
        QCOMPARE(ids, (QStringList { "p1", "p2", "p3" }));
        w.stop();
    }

    void zoneTrigger_emitsEnterEvent()
    {
        PhysicsWorld w;
        w.setTickRate(120);
        w.start();
        // Body au centre, zone 1x1 autour, immobile → doit "enter"
        w.createKinematicActor("p", QVector2D(0, 0), 0.1);

        QVariantList poly = {
            QVariant::fromValue(QVector2D(-1, -1)),
            QVariant::fromValue(QVector2D(1, -1)),
            QVariant::fromValue(QVector2D(1, 1)),
            QVariant::fromValue(QVector2D(-1, 1)),
        };
        w.upsertZone("z", poly,
                     QVariantMap { { "exclusion", false }, { "trigger", true } });

        QSignalSpy spy(&w, &PhysicsWorld::actorEnteredZone);
        QVERIFY2(spy.wait(500), "actorEnteredZone signal never received");

        QList<QVariant> args = spy.takeFirst();
        QCOMPARE(args.at(0).toString(), QStringLiteral("p"));
        QCOMPARE(args.at(1).toString(), QStringLiteral("z"));
        w.stop();
    }
};

QTEST_MAIN(TstPhysicsWorker)
#include "tst_physics_worker.moc"
