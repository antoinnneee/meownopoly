#include "gameplay_event_bus.h"

#include <QDateTime>
#include <QJsonObject>
#include <QThread>
#include <QTimer>
#include <QUuid>
#include <QtQml>

#include "game/game.h"
#include "editor/ops/editor_op_bus.h"
#include "game/physics/item_snapable_events.h"
#include "game/physics/physics_session.h"
#include "game/item_snapable/ItemSnapable.h"

// ==================== event_types helpers ====================

namespace meow {

EventDurability durabilityOf(EventType type)
{
    switch (type) {
    // Éphémères : haute fréquence ou purement visuels, non archivés dans
    // le noyau d'audit (D2). Diffusés quand même sur eventPublished.
    case EventType::TileMoved:
    case EventType::ZoneParameterChanged:
    case EventType::CombatRequest:
        return EventDurability::Ephemeral;
    // Tout le reste est durable (structure de carte, cycle de vie, ops,
    // résolution de combat).
    default:
        return EventDurability::Durable;
    }
}

QString eventTypeName(EventType type)
{
    switch (type) {
    case EventType::GameStarted:          return QStringLiteral("GameStarted");
    case EventType::MapLoaded:            return QStringLiteral("MapLoaded");
    case EventType::MapCleared:           return QStringLiteral("MapCleared");
    case EventType::TileRemovedGame:      return QStringLiteral("TileRemovedGame");
    case EventType::MapRestored:          return QStringLiteral("MapRestored");
    case EventType::EditorOpLocal:        return QStringLiteral("EditorOpLocal");
    case EventType::EditorOpRemote:       return QStringLiteral("EditorOpRemote");
    case EventType::TileCreated:          return QStringLiteral("TileCreated");
    case EventType::TileDeleted:          return QStringLiteral("TileDeleted");
    case EventType::TileMoved:            return QStringLiteral("TileMoved");
    case EventType::ZoneParameterChanged: return QStringLiteral("ZoneParameterChanged");
    case EventType::CombatRequest:        return QStringLiteral("CombatRequest");
    case EventType::CombatResolved:       return QStringLiteral("CombatResolved");
    case EventType::Unknown:              break;
    }
    return QStringLiteral("Unknown");
}

QString eventSourceName(EventSource source)
{
    switch (source) {
    case EventSource::Game:      return QStringLiteral("Game");
    case EventSource::EditorOps: return QStringLiteral("EditorOps");
    case EventSource::Tiles:     return QStringLiteral("Tiles");
    case EventSource::Physics:   return QStringLiteral("Physics");
    case EventSource::System:    return QStringLiteral("System");
    case EventSource::Unknown:   break;
    }
    return QStringLiteral("Unknown");
}

QVariantMap GameplayEvent::toVariantMap() const
{
    QVariantMap m;
    m.insert(QStringLiteral("id"), id);
    m.insert(QStringLiteral("type"), static_cast<int>(type));
    m.insert(QStringLiteral("typeName"), eventTypeName(type));
    m.insert(QStringLiteral("source"), static_cast<int>(source));
    m.insert(QStringLiteral("sourceName"), eventSourceName(source));
    m.insert(QStringLiteral("author"), author);
    m.insert(QStringLiteral("logicalTs"), logicalTs);
    m.insert(QStringLiteral("causeId"), causeId);
    m.insert(QStringLiteral("version"), static_cast<int>(version));
    m.insert(QStringLiteral("durable"), durability == EventDurability::Durable);
    m.insert(QStringLiteral("wallTs"), wallTs);
    m.insert(QStringLiteral("payload"), payload);
    return m;
}

} // namespace meow

// ==================== GameplayEventBus ====================

GameplayEventBus *GameplayEventBus::m_instance = nullptr;

GameplayEventBus *GameplayEventBus::instance()
{
    if (!m_instance) m_instance = new GameplayEventBus();
    return m_instance;
}

QObject *GameplayEventBus::qmlInstance(QQmlEngine *, QJSEngine *)
{
    GameplayEventBus *inst = GameplayEventBus::instance();
    // Le singleton est aussi consommé côté C++ (ingestion, futur canal IA) →
    // garder l'ownership C++ pour éviter la destruction avec l'engine.
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void GameplayEventBus::registerQml()
{
    qRegisterMetaType<meow::GameplayEvent>();
    qmlRegisterSingletonType<GameplayEventBus>(
        "MeowEvents", 1, 0, "GameplayEventBus",
        &GameplayEventBus::qmlInstance);
}

GameplayEventBus::GameplayEventBus(QObject *parent)
    : QObject(parent)
{
    m_journal.reserve(256);
}

// ---- Horloge de Lamport dédiée aux événements -----------------------------
//
// On NE réutilise PAS Game::tickLamport() : cette horloge-là pilote le zOrder
// des tuiles (game_lamport.cpp) et progresse par pose de tuile ; la cadencer
// au rythme des événements métier (jusqu'à 30 Hz côté physique) la ferait
// dériver et empièterait sur les zLayers. On garde donc un compteur logique
// dédié, mais de MÊME principe (monotone, +1 par event local, sync au max sur
// réception d'un ts distant).

qint64 GameplayEventBus::tickLamport()
{
    return ++m_logicalClock;
}

void GameplayEventBus::syncLogicalClock(qint64 remoteTs)
{
    if (remoteTs > m_logicalClock) {
        m_logicalClock = remoteTs;
        emit eventCountChanged(); // rafraîchit la Q_PROPERTY logicalClock
    }
}

// ---- Publication / ingestion ----------------------------------------------

QString GameplayEventBus::publish(int type, int source, const QString &author,
                                  const QVariantMap &payload, const QString &causeId)
{
    meow::GameplayEvent ev;
    ev.id         = QUuid::createUuid().toString(QUuid::WithoutBraces);
    ev.type       = static_cast<meow::EventType>(type);
    ev.source     = static_cast<meow::EventSource>(source);
    ev.author     = author.isEmpty() ? QStringLiteral("local") : author;
    ev.causeId    = causeId;
    ev.durability = meow::durabilityOf(ev.type);
    ev.version    = meow::kGameplayEventSchemaVersion;
    ev.wallTs     = QDateTime::currentMSecsSinceEpoch();
    // logicalTs est attribué dans ingest(), sur le thread du bus, pour que le
    // compteur ne soit muté que là (pas de course).
    dispatchIngest(ev);
    return ev.id;
}

void GameplayEventBus::dispatchIngest(const meow::GameplayEvent &ev)
{
    if (QThread::currentThread() == thread()) {
        ingest(ev);
    } else {
        // Appel hors thread (ex. un futur émetteur côté worker physique) :
        // ré-ordonnancer sur le thread du bus.
        QMetaObject::invokeMethod(this,
            [this, ev]() { ingest(ev); },
            Qt::QueuedConnection);
    }
}

void GameplayEventBus::ingest(meow::GameplayEvent ev)
{
    ev.logicalTs = tickLamport();

    m_journal.append(ev);
    if (m_journal.size() > k_journalCap)
        m_journal.remove(0, m_journal.size() - k_journalCap);

    ++m_eventCount;
    emit eventCountChanged();
    emit eventPublished(ev.toVariantMap());
}

QVariantList GameplayEventBus::recentEvents(int max) const
{
    QVariantList out;
    if (max <= 0) return out;
    const int n     = m_journal.size();
    const int start = (n > max) ? (n - max) : 0;
    out.reserve(n - start);
    for (int i = start; i < n; ++i)
        out.append(m_journal.at(i).toVariantMap());
    return out;
}

// ---- Ingestion : câblage des sources --------------------------------------

void GameplayEventBus::connectSources()
{
    if (m_sourcesConnected) return;
    m_sourcesConnected = true;
    connectGame();
    connectEditorOps();
    connectTiles();
    connectPhysics();
}

void GameplayEventBus::connectGame()
{
    Game *g = Game::instance();
    if (!g) return;

    connect(g, &Game::gameStarted, this, [this]() {
        publish(static_cast<int>(meow::EventType::GameStarted),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("system"));
    });
    connect(g, &Game::clearCurrentMap, this, [this]() {
        publish(static_cast<int>(meow::EventType::MapCleared),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("system"));
    });
    connect(g, &Game::mapLoaded, this, [this](Map *) {
        publish(static_cast<int>(meow::EventType::MapLoaded),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("system"));
    });
    connect(g, &Game::tileRemoved, this, [this](QUuid tileId) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"),
                 tileId.toString(QUuid::WithoutBraces));
        publish(static_cast<int>(meow::EventType::TileRemovedGame),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("local"), p);
    });
    connect(g, &Game::afterRestoration, this, [this](const QList<QUuid> &ids) {
        QVariantMap p;
        p.insert(QStringLiteral("count"), ids.size());
        publish(static_cast<int>(meow::EventType::MapRestored),
                static_cast<int>(meow::EventSource::Game),
                QStringLiteral("local"), p);
    });
}

void GameplayEventBus::connectEditorOps()
{
    EditorOpBus *bus = EditorOpBus::instance();
    if (!bus) return;

    connect(bus, &EditorOpBus::opRecorded, this, [this](const QJsonObject &op) {
        QVariantMap p;
        p.insert(QStringLiteral("op"), op.toVariantMap());
        publish(static_cast<int>(meow::EventType::EditorOpLocal),
                static_cast<int>(meow::EventSource::EditorOps),
                QStringLiteral("local"), p);
    });
    connect(bus, &EditorOpBus::remoteOpReceived, this, [this](const QJsonObject &op) {
        QVariantMap p;
        p.insert(QStringLiteral("op"), op.toVariantMap());
        publish(static_cast<int>(meow::EventType::EditorOpRemote),
                static_cast<int>(meow::EventSource::EditorOps),
                QStringLiteral("remote"), p);
    });
}

void GameplayEventBus::connectTiles()
{
    ItemSnapableEvents *evs = ItemSnapableEvents::instance();
    if (!evs) return;

    auto tileId = [](ItemSnapable *t) -> QString {
        return t ? t->uniqueId().toString(QUuid::WithoutBraces) : QString();
    };

    connect(evs, &ItemSnapableEvents::tileCreated, this, [this, tileId](ItemSnapable *t) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), tileId(t));
        publish(static_cast<int>(meow::EventType::TileCreated),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
    connect(evs, &ItemSnapableEvents::tileDeleted, this,
            [this](const QUuid &id, int tileType) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), id.toString(QUuid::WithoutBraces));
        p.insert(QStringLiteral("tileType"), tileType);
        publish(static_cast<int>(meow::EventType::TileDeleted),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
    connect(evs, &ItemSnapableEvents::tileMoved, this, [this, tileId](ItemSnapable *t) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), tileId(t));
        publish(static_cast<int>(meow::EventType::TileMoved),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
    connect(evs, &ItemSnapableEvents::zoneParameterChanged, this,
            [this, tileId](ItemSnapable *t) {
        QVariantMap p;
        p.insert(QStringLiteral("tileId"), tileId(t));
        publish(static_cast<int>(meow::EventType::ZoneParameterChanged),
                static_cast<int>(meow::EventSource::Tiles),
                QStringLiteral("local"), p);
    });
}

void GameplayEventBus::connectPhysics()
{
    PhysicsSession *ps = PhysicsSession::instance();
    if (!ps) return;

    // PhysicsSession vit sur le thread GUI (comme le bus), mais la simulation
    // Pattounx tourne dans un worker dédié. On câble en QueuedConnection par
    // prudence : si un jour un signal physique était réémis depuis le worker,
    // l'ingestion resterait sûre (marshalling sur le thread du bus).
    connect(ps, &PhysicsSession::combatRequestReceived, this,
            [this](const QString &senderId, const QVariantMap &payload) {
        publish(static_cast<int>(meow::EventType::CombatRequest),
                static_cast<int>(meow::EventSource::Physics),
                senderId.isEmpty() ? QStringLiteral("remote") : senderId,
                payload);
    }, Qt::QueuedConnection);
    connect(ps, &PhysicsSession::combatEventReceived, this,
            [this](const QVariantMap &payload) {
        publish(static_cast<int>(meow::EventType::CombatResolved),
                static_cast<int>(meow::EventSource::Physics),
                QStringLiteral("host"), payload);
    }, Qt::QueuedConnection);
}

// ==================== Bootstrap ====================
//
// D1 se limite strictement à cpp/game/events/. Pour que l'ingestion soit vive
// sans toucher qmlapp.cpp (hors périmètre de cette tâche — l'enregistrement
// formel du singleton y sera intégré en D4, au branchement du canal), le bus
// s'auto-amorce : on enregistre le type QML au démarrage de l'application, et
// on câble les sources une fois l'event loop lancée (les singletons Game /
// EditorOpBus / ItemSnapableEvents / PhysicsSession sont alors instanciés).

static void meowBootstrapGameplayEventBus()
{
    GameplayEventBus::registerQml();
    // Déféré à l'event loop : connectSources() crée au besoin les singletons
    // sources et pose les connexions à un moment sûr (après QmlApp).
    QTimer::singleShot(0, []() {
        GameplayEventBus::instance()->connectSources();
    });
}
Q_COREAPP_STARTUP_FUNCTION(meowBootstrapGameplayEventBus)
