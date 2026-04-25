#include "physics_world.h"
#include "physics_worker.h"
#include "pattounx_types.h"

#include <QElapsedTimer>
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

    // Régression : le triple buffer GUI ne doit JAMAIS faire reculer le
    // tick observé, même quand le rendu tire plus vite que la publication
    // worker (ex : moniteur 144 Hz vs tick 60 Hz). Cf. fix peek+swap dans
    // PhysicsWorld::tryAdvanceGuiBuffer.
    //
    // Avant la fix, deux exchanges successifs sans publication entre les
    // deux récupéraient le buffer que la GUI venait de déposer = un tick
    // antérieur. Visible côté QML : `currentGuiTick` qui oscille
    // (ex 2663 → 2662 → 2664 → 2662…).
    void guiTickMonotonic_atHighReadCadence()
    {
        PhysicsWorld w;
        w.setTickRate(60);              // worker normal 60 Hz
        w.start();
        w.createKinematicActor("p", QVector2D(0, 0), 0.2,
                               QVariantMap { { "maxSpeed", 0.0 } });

        QSignalSpy spy(&w, &PhysicsWorld::snapshotAvailable);
        QVERIFY2(spy.wait(500), "no snapshot published in 500ms");

        // Lecture GUI en busy-loop pendant 500ms : aussi vite que possible,
        // bien plus que la publication worker 60 Hz. C'est le scénario qui
        // exposait le bug. Pas de QTest::qSleep — la résolution timer
        // Windows par défaut (~15.6 ms) finit par caler la lecture sur le
        // rythme du worker et masquerait le problème.
        quint64 lastTick = 0;
        int regressions = 0;
        int sameTick = 0;
        int advances = 0;
        QElapsedTimer clock;
        clock.start();
        while (clock.elapsed() < 500) {
            w.beginFrame();
            const quint64 tick = w.currentGuiTick();
            if (lastTick != 0) {
                if (tick < lastTick) ++regressions;
                else if (tick == lastTick) ++sameTick;
                else ++advances;
            }
            lastTick = tick;
            QThread::yieldCurrentThread();   // laisse le worker progresser
        }

        // Invariant principal : pas de régression de tick côté GUI.
        // Avant la fix peek+swap, ce compteur était >>0 sur cette boucle.
        QCOMPARE(regressions, 0);
        // Sanité : le worker a bien publié plusieurs ticks pendant le test,
        // sinon la boucle pourrait passer trivialement.
        QVERIFY2(advances >= 5,
                 qPrintable(QString("expected ≥5 tick advances, got %1")
                                .arg(advances)));
        // Sanité : on a effectivement lu plus vite que le worker. Si la
        // résolution timer Windows colle la boucle à 60 Hz, sameTick reste
        // bas et on rate le scénario qu'on veut tester.
        QVERIFY2(sameTick > advances,
                 qPrintable(QString("expected sameTick (%1) > advances (%2) "
                                    "— GUI read loop too slow to expose bug")
                                .arg(sameTick).arg(advances)));

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
