/*
 *      Tests unitaires — GameplayEventBus (V3 piste D, D1/D2)
 *
 * Compile le bus SEUL (gameplay_event_bus.cpp, aucune dépendance jeu/réseau)
 * avec des bornes réduites via -D pour rendre la troncature testable :
 *   MEOW_EVENTBUS_CAPACITY=16, MEOW_EVENTBUS_AUDIT_MAX=32,
 *   MEOW_EVENTBUS_MAX_CASCADE=4 (cf. tests/CMakeLists.txt).
 */
#include <QJsonArray>
#include <QSignalSpy>
#include <QtTest>

#include "game/events/gameplay_event_bus.h"

static_assert(MEOW_EVENTBUS_CAPACITY == 16,
              "test calibré pour une capacité ring de 16 (voir CMakeLists)");
static_assert(MEOW_EVENTBUS_AUDIT_MAX == 32,
              "test calibré pour une borne audit de 32 (voir CMakeLists)");
static_assert(MEOW_EVENTBUS_MAX_CASCADE == 4,
              "test calibré pour une cascade max de 4 (voir CMakeLists)");

namespace {

GameplayEvent makeEvent(const QString &type, bool durable = false)
{
    GameplayEvent ev;
    ev.type    = type;
    ev.source  = GameplayEventSource::System;
    ev.durable = durable;
    return ev;
}

} // namespace

class TstGameplayEventBus : public QObject
{
    Q_OBJECT

private slots:
    void init()
    {
        GameplayEventBus::instance()->clear();
        GameplayEventBus::instance()->setLamportProvider(nullptr);
    }

    // Séquence monotone attribuée par le bus, id auto, Lamport croissant.
    void appendAssignsSeqAndClocks()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        QSignalSpy spy(bus, &GameplayEventBus::eventAppended);

        QCOMPARE(bus->append(makeEvent("a")), quint64(1));
        QCOMPARE(bus->append(makeEvent("b")), quint64(2));
        QCOMPARE(bus->lastSeq(), quint64(2));
        QCOMPARE(spy.count(), 2);

        const auto ev1 = spy.at(0).at(0).value<GameplayEvent>();
        const auto ev2 = spy.at(1).at(0).value<GameplayEvent>();
        QVERIFY(!ev1.id.isNull());
        QVERIFY(ev2.lamportTs > ev1.lamportTs);
        QVERIFY(ev1.wallTs > 0);
    }

    // Le provider externe est rattrapé, la monotonie locale est préservée
    // même si l'horloge externe stagne.
    void lamportProviderIsMonotone()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        bus->setLamportProvider([]() { return qint64(100); });
        QSignalSpy spy(bus, &GameplayEventBus::eventAppended);

        bus->append(makeEvent("a"));
        bus->append(makeEvent("b"));
        QCOMPARE(spy.at(0).at(0).value<GameplayEvent>().lamportTs, qint64(100));
        QCOMPARE(spy.at(1).at(0).value<GameplayEvent>().lamportTs, qint64(101));
    }

    // Relecture par curseur : borne max, nextCursor, idempotence.
    void eventsSinceCursor()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        for (int i = 0; i < 5; ++i)
            bus->append(makeEvent(QStringLiteral("e%1").arg(i)));

        QJsonObject r = bus->eventsSince(2);
        QCOMPARE(r["events"].toArray().size(), 3);
        QCOMPARE(r["truncated"].toBool(), false);
        QCOMPARE(quint64(r["nextCursor"].toDouble()), quint64(5));
        QCOMPARE(quint64(r["events"].toArray().first().toObject()["seq"].toDouble()),
                 quint64(3));

        // Idempotent : relire au même curseur redonne exactement pareil.
        QCOMPARE(bus->eventsSince(2), r);

        // maxCount respecté + reprise au nextCursor.
        r = bus->eventsSince(0, 2);
        QCOMPARE(r["events"].toArray().size(), 2);
        QCOMPARE(quint64(r["nextCursor"].toDouble()), quint64(2));

        // Curseur au bout : vide, non tronqué.
        r = bus->eventsSince(5);
        QCOMPARE(r["events"].toArray().size(), 0);
        QCOMPARE(r["truncated"].toBool(), false);
    }

    // Recyclage du ring : curseur trop vieux → truncated + oldestSeq (Q-E06).
    void ringTruncation()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        for (int i = 0; i < 40; ++i)
            bus->append(makeEvent("e"));

        QJsonObject r = bus->eventsSince(0);
        QCOMPARE(r["truncated"].toBool(), true);
        QCOMPARE(quint64(r["oldestSeq"].toDouble()), quint64(25)); // 40-16+1
        QCOMPARE(r["events"].toArray().size(), 16);

        // Curseur au-delà de la zone recyclée : plus de troncature.
        r = bus->eventsSince(24);
        QCOMPARE(r["truncated"].toBool(), false);
        QCOMPARE(r["events"].toArray().size(), 16);
    }

    // Noyau d'audit D19 : les durables survivent au recyclage du ring.
    void durableAuditSurvivesRing()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        // 1 durable (seq 1) puis 39 éphémères → le ring a perdu seq 1.
        bus->append(makeEvent("audit", /*durable=*/true));
        for (int i = 0; i < 39; ++i)
            bus->append(makeEvent("e"));

        QJsonObject r = bus->eventsSince(0, 256, /*durableOnly=*/true);
        QCOMPARE(r["truncated"].toBool(), false);
        QCOMPARE(r["events"].toArray().size(), 1);
        QCOMPARE(quint64(r["events"].toArray().first().toObject()["seq"].toDouble()),
                 quint64(1));
        QVERIFY(r["events"].toArray().first().toObject()["durable"].toBool());
    }

    // Débordement de la liste d'audit : éviction + truncated côté durable.
    void auditOverflow()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        for (int i = 0; i < 40; ++i)
            bus->append(makeEvent("audit", /*durable=*/true));

        QJsonObject r = bus->eventsSince(0, 256, /*durableOnly=*/true);
        QCOMPARE(r["truncated"].toBool(), true);
        QCOMPARE(r["events"].toArray().size(), 32);
        QCOMPARE(quint64(r["oldestSeq"].toDouble()), quint64(9)); // 40-32+1
    }

    // Garde de réentrance D12 : un slot direct qui ré-appende est coupé
    // à MEOW_EVENTBUS_MAX_CASCADE, avec drop tracé.
    void cascadeGuard()
    {
        GameplayEventBus *bus = GameplayEventBus::instance();
        QCOMPARE(bus->droppedCascadeCount(), quint64(0));

        QMetaObject::Connection c = connect(
            bus, &GameplayEventBus::eventAppended, bus,
            [bus](const GameplayEvent &) { bus->append(makeEvent("cascade")); },
            Qt::DirectConnection);

        bus->append(makeEvent("seed"));
        disconnect(c);

        // Profondeur max 4 → 4 événements stockés, le 5e est droppé
        // (le slot du 4e a tenté un append à profondeur 4).
        QCOMPARE(bus->lastSeq(), quint64(4));
        QVERIFY(bus->droppedCascadeCount() >= 1);
        // Le bus reste fonctionnel après la coupure.
        QCOMPARE(bus->append(makeEvent("after")), quint64(5));
    }

    // Round-trip JSON de GameplayEvent.
    void jsonRoundTrip()
    {
        GameplayEvent ev;
        ev.seq       = 42;
        ev.id        = QUuid::createUuid();
        ev.type      = QStringLiteral("tile.created");
        ev.author    = QStringLiteral("player-1");
        ev.source    = GameplayEventSource::Editor;
        ev.lamportTs = 7;
        ev.wallTs    = 1234567890123LL;
        ev.payload   = QJsonObject{{QStringLiteral("uuid"), QStringLiteral("x")}};
        ev.durable   = true;

        const GameplayEvent back = GameplayEvent::fromJson(ev.toJson());
        QCOMPARE(back.seq, ev.seq);
        QCOMPARE(back.id, ev.id);
        QCOMPARE(back.type, ev.type);
        QCOMPARE(back.author, ev.author);
        QCOMPARE(back.source, ev.source);
        QCOMPARE(back.lamportTs, ev.lamportTs);
        QCOMPARE(back.wallTs, ev.wallTs);
        QCOMPARE(back.payload, ev.payload);
        QCOMPARE(back.durable, ev.durable);
    }
};

QTEST_GUILESS_MAIN(TstGameplayEventBus)
#include "tst_gameplay_event_bus.moc"
