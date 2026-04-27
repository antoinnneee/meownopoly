/*
 * tst_snapshot_codec — round-trip serializeSnapshot / applyRemoteSnapshot
 * (cf. PHYSICS_REFACTOR_PLAN.md §5.5 + §7).
 *
 * Approche : démarrer 2 instances PhysicsWorld dans le même processus —
 * "host" tourne sa simu, "client" en mode useRemoteBuffer reçoit les
 * payloads que produit le host. Pas de Catway dans cette suite : on
 * manipule directement les QByteArray pour isoler le codec.
 */
#include "physics_world.h"
#include "physics_worker.h"
#include "pattounx_types.h"

#include <QObject>
#include <QSignalSpy>
#include <QTest>
#include <QVector2D>

class TstSnapshotCodec : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase() { PhysicsWorld::registerQml(); }

    // Cas nominal : host crée 2 bodies, sérialise, le client applique
    // BodiesAnnounce + Snapshot → bodyState côté client matche celui du host
    // à la précision de quantification (1/1000).
    void roundTrip_twoBodies()
    {
        PhysicsWorld host;
        host.setTickRate(120);
        host.start();
        host.createKinematicActor("p1", QVector2D(2.0f, 3.0f), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });
        host.createKinematicActor("p2", QVector2D(-1.5f, 4.25f), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });

        // Attendre que les bodies soient visibles dans le snapshot GUI.
        QSignalSpy hostSpy(&host, &PhysicsWorld::snapshotAvailable);
        QVERIFY(hostSpy.wait(500));
        for (int i = 0; i < 5; ++i) {
            QTest::qWait(20);
            host.beginFrame();
        }

        const QByteArray payload = host.serializeSnapshot();
        QVERIFY(!payload.isEmpty());

        const QVariantMap delta = host.takePendingAnnouncements();
        const QVariantMap added = delta.value(QStringLiteral("added")).toMap();
        QCOMPARE(added.size(), 2);

        // Côté client : sim off + buffer remote on, puis applique table + snapshot.
        PhysicsWorld client;
        client.setSimulationEnabled(false);
        client.setUseRemoteBuffer(true);

        client.applyBodiesAnnounce(added, /*removed=*/{});
        client.applyRemoteSnapshot(payload);

        const QVariantMap s1 = client.bodyState("p1");
        const QVariantMap s2 = client.bodyState("p2");
        QVERIFY(s1.contains("id"));
        QVERIFY(s2.contains("id"));

        const QVector2D p1 = s1.value("position").value<QVector2D>();
        const QVector2D p2 = s2.value("position").value<QVector2D>();
        // ±0.001 = précision de la quantification int32 × 1000.
        QVERIFY(std::abs(p1.x() - 2.0f)  < 1e-3f);
        QVERIFY(std::abs(p1.y() - 3.0f)  < 1e-3f);
        QVERIFY(std::abs(p2.x() + 1.5f)  < 1e-3f);
        QVERIFY(std::abs(p2.y() - 4.25f) < 1e-3f);

        host.stop();
    }

    // Si BodiesAnnounce n'a pas été appliqué côté client, tous les bodies
    // doivent être droppés silencieusement (idIndex inconnu) — pas de crash,
    // bodyState retourne map vide.
    void applyRemoteSnapshot_unknownIdIndex_dropsBodies()
    {
        PhysicsWorld host;
        host.setTickRate(120);
        host.start();
        host.createKinematicActor("p1", QVector2D(1, 1), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });

        QSignalSpy spy(&host, &PhysicsWorld::snapshotAvailable);
        QVERIFY(spy.wait(500));
        for (int i = 0; i < 3; ++i) { QTest::qWait(20); host.beginFrame(); }

        const QByteArray payload = host.serializeSnapshot();
        host.takePendingAnnouncements(); // on jette volontairement la table

        // Client vierge — pas d'applyBodiesAnnounce.
        PhysicsWorld client;
        client.setSimulationEnabled(false);
        client.setUseRemoteBuffer(true);
        client.applyRemoteSnapshot(payload);

        QCOMPARE(client.allBodyIds(), QStringList{});
        QVERIFY(client.bodyState("p1").isEmpty());

        host.stop();
    }

    // Suppression d'un body côté host → après serialize + takePending,
    // m_pendingAnnouncements.removed contient l'actorId. Côté client,
    // applyBodiesAnnounce({}, [id]) purge l'entrée et retire le body du
    // remote buffer. Vérifie le contrat round-trip pour le retrait.
    void bodiesAnnounce_removesActorOnClient()
    {
        PhysicsWorld host;
        host.setTickRate(120);
        host.start();
        host.createKinematicActor("p1", QVector2D(0, 0), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });
        host.createKinematicActor("p2", QVector2D(1, 0), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });

        QSignalSpy spy(&host, &PhysicsWorld::snapshotAvailable);
        QVERIFY(spy.wait(500));
        for (int i = 0; i < 3; ++i) { QTest::qWait(20); host.beginFrame(); }

        // 1er serialize → table de 2 entries.
        QByteArray payload = host.serializeSnapshot();
        QVariantMap delta = host.takePendingAnnouncements();
        QVariantMap added = delta.value("added").toMap();
        QCOMPARE(added.size(), 2);

        PhysicsWorld client;
        client.setSimulationEnabled(false);
        client.setUseRemoteBuffer(true);
        client.applyBodiesAnnounce(added, {});
        client.applyRemoteSnapshot(payload);
        QCOMPARE(client.allBodyIds().size(), 2);

        // Retire p1 → après serialize + takePending, removed contient "p1".
        host.removeBody("p1");
        spy.clear();
        QVERIFY(spy.wait(500));
        for (int i = 0; i < 3; ++i) { QTest::qWait(20); host.beginFrame(); }

        payload = host.serializeSnapshot();
        delta = host.takePendingAnnouncements();
        const QStringList removed = delta.value("removed").toStringList();
        QVERIFY(removed.contains("p1"));

        client.applyBodiesAnnounce({}, removed);
        client.applyRemoteSnapshot(payload);
        const QStringList ids = client.allBodyIds();
        QVERIFY(!ids.contains("p1"));
        QVERIFY(ids.contains("p2"));

        host.stop();
    }

    // Robustesse : payload vide / tronqué → pas de crash, pas de body créé.
    void applyRemoteSnapshot_emptyOrCorrupt_noCrash()
    {
        PhysicsWorld client;
        client.setSimulationEnabled(false);
        client.setUseRemoteBuffer(true);

        client.applyRemoteSnapshot(QByteArray{});
        QCOMPARE(client.allBodyIds(), QStringList{});

        // Header tronqué (juste le tick u32, pas de timestamp/count).
        QByteArray truncated;
        truncated.append('\x00').append('\x00').append('\x00').append('\x01');
        client.applyRemoteSnapshot(truncated);
        QCOMPARE(client.allBodyIds(), QStringList{});

        // Octets aléatoires.
        client.applyRemoteSnapshot(QByteArray("garbage payload qui ne décode pas"));
        QCOMPARE(client.allBodyIds(), QStringList{});
    }

    // applyBodiesAnnounce idempotent : appeler 2 fois avec la même table
    // ne corrompt pas l'index, et un snapshot reste interprétable.
    void applyBodiesAnnounce_isIdempotent()
    {
        PhysicsWorld host;
        host.setTickRate(120);
        host.start();
        host.createKinematicActor("p1", QVector2D(5, 7), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });
        QSignalSpy spy(&host, &PhysicsWorld::snapshotAvailable);
        QVERIFY(spy.wait(500));
        for (int i = 0; i < 3; ++i) { QTest::qWait(20); host.beginFrame(); }

        const QByteArray payload = host.serializeSnapshot();
        const QVariantMap added = host.takePendingAnnouncements()
                                      .value("added").toMap();

        PhysicsWorld client;
        client.setSimulationEnabled(false);
        client.setUseRemoteBuffer(true);
        client.applyBodiesAnnounce(added, {});
        client.applyBodiesAnnounce(added, {});  // 2e appel — idempotent
        client.applyRemoteSnapshot(payload);

        const QVariantMap s = client.bodyState("p1");
        QVERIFY(s.contains("id"));
        const QVector2D p = s.value("position").value<QVector2D>();
        QVERIFY(std::abs(p.x() - 5.0f) < 1e-3f);
        QVERIFY(std::abs(p.y() - 7.0f) < 1e-3f);

        host.stop();
    }

    // resetNetworkState() purge la table idIndex côté hôte → la prochaine
    // sérialisation réémet TOUS les bodies dans pendingAnnouncements.added.
    void resetNetworkState_reAnnouncesEverything()
    {
        PhysicsWorld host;
        host.setTickRate(120);
        host.start();
        host.createKinematicActor("p1", QVector2D(0, 0), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });
        host.createKinematicActor("p2", QVector2D(1, 0), 0.2,
                                  QVariantMap { { "maxSpeed", 0.0 } });

        QSignalSpy spy(&host, &PhysicsWorld::snapshotAvailable);
        QVERIFY(spy.wait(500));
        for (int i = 0; i < 3; ++i) { QTest::qWait(20); host.beginFrame(); }

        host.serializeSnapshot();
        QCOMPARE(host.takePendingAnnouncements().value("added").toMap().size(), 2);

        // Après reset, le prochain serialize doit ré-annoncer les 2 bodies.
        host.resetNetworkState();
        host.serializeSnapshot();
        const QVariantMap added2 = host.takePendingAnnouncements()
                                       .value("added").toMap();
        QCOMPARE(added2.size(), 2);

        host.stop();
    }
};

QTEST_MAIN(TstSnapshotCodec)
#include "tst_snapshot_codec.moc"
