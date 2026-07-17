#include "gameplay_event_bus.h"

#include <QDebug>
#include <QJsonArray>

#include <algorithm>

GameplayEventBus *GameplayEventBus::m_instance = nullptr;

GameplayEventBus *GameplayEventBus::instance()
{
    if (!m_instance) m_instance = new GameplayEventBus();
    return m_instance;
}

QObject *GameplayEventBus::qmlInstance(QQmlEngine *, QJSEngine *)
{
    GameplayEventBus *inst = GameplayEventBus::instance();
    // Même piège que les autres singletons partagés C++/QML : sans
    // CppOwnership, l'engine détruirait le bus avec lui alors que
    // l'ingestion C++ le référence encore (cf. item_snapable_events.cpp).
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void GameplayEventBus::registerQml()
{
    // Metatype nécessaire aux connexions queued (consommateurs hors GUI thread).
    qRegisterMetaType<GameplayEvent>("GameplayEvent");
    qmlRegisterSingletonType<GameplayEventBus>(
        "GameplayEventBus", 1, 0, "GameplayEventBus",
        &GameplayEventBus::qmlInstance);
}

GameplayEventBus::GameplayEventBus(QObject *parent)
    : QObject(parent)
{
}

void GameplayEventBus::setLamportProvider(std::function<qint64()> provider)
{
    QMutexLocker lock(&m_mutex);
    m_lamportProvider = std::move(provider);
}

quint64 GameplayEventBus::append(GameplayEvent ev)
{
    // Garde de réentrance (protection D12 minimale) : la profondeur est
    // thread-local — une cascade est par définition synchrone sur le thread
    // de l'append initial (slot connecté en direct qui ré-appende).
    static thread_local int s_appendDepth = 0;
    if (s_appendDepth >= MEOW_EVENTBUS_MAX_CASCADE) {
        quint64 dropped;
        {
            QMutexLocker lock(&m_mutex);
            dropped = ++m_droppedCascade;
        }
        qWarning() << "[GameplayEventBus] cascade d'appends >"
                   << MEOW_EVENTBUS_MAX_CASCADE
                   << "— événement droppé (type =" << ev.type
                   << ", total drops =" << dropped << ")";
        return 0;
    }
    struct DepthGuard {
        int &d;
        explicit DepthGuard(int &depth) : d(depth) { ++d; }
        ~DepthGuard() { --d; }
    } guard(s_appendDepth);

    {
        QMutexLocker lock(&m_mutex);

        ev.seq = m_nextSeq++;
        if (ev.id.isNull())
            ev.id = QUuid::createUuid();
        // Lamport : monotone locale garantie même si l'horloge externe
        // stagne ; rattrape l'horloge externe (Game) si elle est en avance.
        const qint64 external = m_lamportProvider ? m_lamportProvider() : 0;
        m_lamport = std::max(external, m_lamport + 1);
        ev.lamportTs = m_lamport;
        if (ev.wallTs == 0)
            ev.wallTs = QDateTime::currentMSecsSinceEpoch();

        m_ring.push_back(ev);
        if (m_ring.size() > static_cast<size_t>(MEOW_EVENTBUS_CAPACITY)) {
            m_ringDroppedUpTo = m_ring.front().seq;
            m_ring.pop_front();
        }

        if (ev.durable) {
            m_audit.push_back(ev);
            if (m_audit.size() > static_cast<size_t>(MEOW_EVENTBUS_AUDIT_MAX)) {
                if (!m_auditOverflowWarned) {
                    m_auditOverflowWarned = true;
                    qWarning() << "[GameplayEventBus] liste d'audit >"
                               << MEOW_EVENTBUS_AUDIT_MAX
                               << "— éviction des plus anciens événements"
                               << "durables (noyau D19 : envisager la"
                               << "persistance disque avant d'élargir)";
                }
                m_auditDroppedUpTo = m_audit.front().seq;
                m_audit.pop_front();
            }
        }
    }

    // Hors mutex : un slot en connexion directe peut ré-appender sans
    // deadlock (la cascade est bornée par la garde ci-dessus).
    emit eventAppended(ev);
    return ev.seq;
}

QJsonObject GameplayEventBus::eventsSince(quint64 cursor, int maxCount,
                                          bool durableOnly) const
{
    QMutexLocker lock(&m_mutex);

    const std::deque<GameplayEvent> &store = durableOnly ? m_audit : m_ring;
    const quint64 droppedUpTo = durableOnly ? m_auditDroppedUpTo
                                            : m_ringDroppedUpTo;

    if (maxCount <= 0) maxCount = 256;

    // truncated ⇔ des événements de ce store, de seq > cursor, ont été
    // évincés : le client ne peut pas reconstituer le flot par relecture,
    // il doit repartir d'un snapshot (Q-E06).
    const bool truncated = cursor < droppedUpTo;
    const quint64 oldest = store.empty() ? 0 : store.front().seq;

    // Les seq sont strictement croissantes dans le store → lower_bound.
    auto it = std::lower_bound(
        store.begin(), store.end(), cursor,
        [](const GameplayEvent &ev, quint64 c) { return ev.seq <= c; });

    QJsonArray events;
    quint64 nextCursor = cursor;
    for (; it != store.end() && events.size() < maxCount; ++it) {
        events.append(it->toJson());
        nextCursor = it->seq;
    }

    QJsonObject out;
    out[QStringLiteral("events")]     = events;
    out[QStringLiteral("truncated")]  = truncated;
    out[QStringLiteral("oldestSeq")]  = static_cast<double>(oldest);
    out[QStringLiteral("nextCursor")] = static_cast<double>(nextCursor);
    return out;
}

quint64 GameplayEventBus::lastSeq() const
{
    QMutexLocker lock(&m_mutex);
    return m_nextSeq - 1;
}

quint64 GameplayEventBus::droppedCascadeCount() const
{
    QMutexLocker lock(&m_mutex);
    return m_droppedCascade;
}

void GameplayEventBus::clear()
{
    QMutexLocker lock(&m_mutex);
    m_ring.clear();
    m_audit.clear();
    m_nextSeq            = 1;
    m_lamport            = 0;
    m_ringDroppedUpTo    = 0;
    m_auditDroppedUpTo   = 0;
    m_droppedCascade     = 0;
    m_auditOverflowWarned = false;
}
