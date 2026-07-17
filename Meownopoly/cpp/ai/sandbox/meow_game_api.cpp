// ============================================================================
// meow_game_api — implémentation de la façade `Meow.GameApi` (D34, tâche A6)
// ============================================================================
// Voir meow_game_api.h pour l'architecture. Rappel : `emit` (macro Qt) est
// #undef par le header — utiliser Q_EMIT ici si des signaux apparaissent.
// ============================================================================

#include "meow_game_api.h"

#include <QElapsedTimer>
#include <QJSEngine>
#include <QJsonDocument>
#include <QJsonValue>
#include <QJsonArray>

namespace meow::sandbox {

// ─── MeowMemoryApi ──────────────────────────────────────────────────────────

MeowMemoryApi::MeowMemoryApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

QVariant MeowMemoryApi::get(const QString &key) const
{
    return m_owner->memoryGet(key);
}

bool MeowMemoryApi::set(const QString &key, const QVariant &value)
{
    return m_owner->memorySet(key, value, /*external=*/false);
}

void MeowMemoryApi::onChanged(const QString &key, const QJSValue &callback)
{
    m_owner->memoryWatch(key, callback);
}

// ─── MeowEventsApi ──────────────────────────────────────────────────────────

MeowEventsApi::MeowEventsApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

void MeowEventsApi::on(const QString &name, const QJSValue &callback)
{
    m_owner->eventsOn(name, callback);
}

void MeowEventsApi::emit(const QString &name, const QVariant &payload)
{
    m_owner->eventsEmit(name, payload);
}

// ─── MeowStatsApi ───────────────────────────────────────────────────────────

MeowStatsApi::MeowStatsApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

void MeowStatsApi::addModifier(const QString &target, const QString &stat,
                               const QVariant &value)
{
    // S-6 : branchement sur les vraies stats. MVP : enregistrement seul.
    m_owner->recordCall(QStringLiteral("stats"), QStringLiteral("addModifier"),
                        { target, stat, value });
}

// ─── MeowSessionApi ─────────────────────────────────────────────────────────

MeowSessionApi::MeowSessionApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

QVariant MeowSessionApi::get(const QString &key) const
{
    return m_owner->sessionGet(key);
}

// ─── MeowPlayerApi ──────────────────────────────────────────────────────────

MeowPlayerApi::MeowPlayerApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

QVariantMap MeowPlayerApi::position() const
{
    // S-6 : position réelle du joueur (Pattounx). MVP : origine neutre —
    // suffisant pour que l'artefact charge et que ses handlers s'exécutent.
    return { { QStringLiteral("x"), 0.0 }, { QStringLiteral("y"), 0.0 } };
}

// ─── MeowZoneApi ────────────────────────────────────────────────────────────

MeowZoneApi::MeowZoneApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

QVariantList MeowZoneApi::playersInside() const
{
    // S-6 : lecture réelle des occupants de zone. MVP : liste vide.
    return {};
}

// ─── MeowPresentationApi ────────────────────────────────────────────────────

MeowPresentationApi::MeowPresentationApi(MeowGameApi *owner, const QString &channel)
    : QObject(owner), m_owner(owner), m_channel(channel) {}

void MeowPresentationApi::show(const QVariant &content, const QVariant &options)
{
    m_owner->recordCall(m_channel, QStringLiteral("show"), { content, options });
}

void MeowPresentationApi::play(const QString &name, const QVariant &options)
{
    m_owner->recordCall(m_channel, QStringLiteral("play"), { name, options });
}

void MeowPresentationApi::spawn(const QString &name, const QVariant &options)
{
    m_owner->recordCall(m_channel, QStringLiteral("spawn"), { name, options });
}

// ─── MeowGameApi ────────────────────────────────────────────────────────────

MeowGameApi::MeowGameApi(QObject *parent)
    : QObject(parent)
{
    m_memory   = new MeowMemoryApi(this);
    m_events   = new MeowEventsApi(this);
    m_stats    = new MeowStatsApi(this);
    m_session  = new MeowSessionApi(this);
    m_player   = new MeowPlayerApi(this);
    m_zone     = new MeowZoneApi(this);
    m_dialogue = new MeowPresentationApi(this, QStringLiteral("dialogue"));
    m_anim     = new MeowPresentationApi(this, QStringLiteral("anim"));
    m_fx       = new MeowPresentationApi(this, QStringLiteral("fx"));
    m_sound    = new MeowPresentationApi(this, QStringLiteral("sound"));
}

void MeowGameApi::configure(const QString &targetUuid,
                            const QJsonObject &memorySnapshot,
                            const QJsonObject &sessionSnapshot,
                            int memoryValueMaxBytes)
{
    m_targetUuid = targetUuid;
    m_memoryValues = memorySnapshot.toVariantMap();
    m_sessionValues = sessionSnapshot.toVariantMap();
    m_memoryValueMaxBytes = memoryValueMaxBytes > 0
                                ? memoryValueMaxBytes
                                : MEOW_API_MEMORY_VALUE_MAX_BYTES;
}

QString MeowGameApi::writeSetKey(const QString &key) const
{
    // Format doc 12 §4 : "<uuid>/state/<clé>" — namespace `state` (doc 05),
    // le namespace `config` ne s'écrit que par ops d'édition, pas par la façade.
    const QString uuid = m_targetUuid.isEmpty() ? QStringLiteral("session")
                                                : m_targetUuid;
    return uuid + QStringLiteral("/state/") + key;
}

QVariant MeowGameApi::memoryGet(const QString &key) const
{
    return m_memoryValues.value(key);
}

bool MeowGameApi::memorySet(const QString &key, const QVariant &value, bool external)
{
    if (!external) {
        // Quota par valeur (D35 : 1 KB/valeur) — mesuré en JSON compact,
        // même métrique que le transport réseau futur.
        const QByteArray serialized =
            QJsonDocument(QJsonArray{ QJsonValue::fromVariant(value) })
                .toJson(QJsonDocument::Compact);
        if (serialized.size() > m_memoryValueMaxBytes + 2) { // +2 : crochets
            m_violations.append({ QStringLiteral("memory_quota"),
                                  QStringLiteral("memory.set(\"%1\") : valeur de %2 octets > plafond %3 octets par valeur")
                                      .arg(key)
                                      .arg(serialized.size() - 2)
                                      .arg(m_memoryValueMaxBytes) });
            ++m_activity;
            return false; // rejet à la source, jamais de troncature (D35)
        }
        const QString wsKey = writeSetKey(key);
        if (!m_writeSet.contains(wsKey))
            m_writeSet.append(wsKey);
        ++m_activity;
    }
    m_memoryValues.insert(key, value);
    notifyMemoryWatchers(key, value);
    return true;
}

void MeowGameApi::memoryWatch(const QString &key, const QJSValue &callback)
{
    if (!callback.isCallable())
        return;
    m_memoryWatchers[key].append(callback);
}

void MeowGameApi::eventsOn(const QString &name, const QJSValue &callback)
{
    if (!callback.isCallable())
        return;
    m_eventHandlers[name].append(callback);
}

void MeowGameApi::eventsEmit(const QString &name, const QVariant &payload)
{
    ++m_emitCount;
    ++m_activity;
    // L'artefact entend ses propres émissions (bus local). La propagation
    // autoritative (autres tuiles/pairs) est l'affaire du bus d'état (M6-B).
    dispatchEvent(name, payload);
}

void MeowGameApi::recordCall(const QString &channel, const QString &method,
                             const QVariantList &args)
{
    Q_UNUSED(args)
    Q_UNUSED(channel)
    Q_UNUSED(method)
    ++m_activity;
}

QVariant MeowGameApi::sessionGet(const QString &key) const
{
    return m_sessionValues.value(key);
}

void MeowGameApi::dispatchEvent(const QString &name, const QVariant &payload)
{
    auto it = m_eventHandlers.find(name);
    if (it == m_eventHandlers.end())
        return;
    // Copie : un handler peut se ré-abonner pendant l'itération.
    QList<QJSValue> handlers = it.value();
    for (int i = 0; i < handlers.size(); ++i) {
        QJSValue cb = handlers.at(i);
        QJSValueList args;
        if (m_jsEngine)
            args << m_jsEngine->toScriptValue(payload);
        invokeHandler(QStringLiteral("on:%1").arg(name), cb, args);
    }
}

void MeowGameApi::touchMemory(const QString &key, const QVariant &value)
{
    memorySet(key, value, /*external=*/true);
}

void MeowGameApi::notifyMemoryWatchers(const QString &key, const QVariant &value)
{
    auto it = m_memoryWatchers.find(key);
    if (it == m_memoryWatchers.end())
        return;
    QList<QJSValue> watchers = it.value();
    for (int i = 0; i < watchers.size(); ++i) {
        QJSValue cb = watchers.at(i);
        QJSValueList args;
        if (m_jsEngine) {
            args << m_jsEngine->toScriptValue(QVariant(key))
                 << m_jsEngine->toScriptValue(value);
        }
        invokeHandler(QStringLiteral("memory:%1").arg(key), cb, args);
    }
}

void MeowGameApi::invokeHandler(const QString &handlerId, QJSValue &callback,
                                const QJSValueList &args)
{
    ApiHandlerRun run;
    run.handlerId = handlerId;

    QElapsedTimer t;
    t.start();
    const QJSValue result = callback.call(args);
    run.elapsedUs = t.nsecsElapsed() / 1000;

    if (result.isError()) {
        run.errored = true;
        run.error = result.toString();
    }
    ++m_activity;
    m_handlerRuns.append(run);
}

QStringList MeowGameApi::registeredEventNames() const
{
    QStringList names = m_eventHandlers.keys();
    names.sort(); // ordre déterministe (reproductibilité, critère R1)
    return names;
}

QStringList MeowGameApi::watchedMemoryKeys() const
{
    QStringList keys = m_memoryWatchers.keys();
    keys.sort();
    return keys;
}

QVector<ApiHandlerRun> MeowGameApi::takeHandlerRuns()
{
    QVector<ApiHandlerRun> runs;
    runs.swap(m_handlerRuns);
    return runs;
}

} // namespace meow::sandbox
