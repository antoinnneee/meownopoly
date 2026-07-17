// ============================================================================
// meow_game_api — implémentation de la façade `Meow.GameApi` (D34, tâche A6)
// ============================================================================
// Voir meow_game_api.h pour l'architecture. Rappel : `emit` (macro Qt) est
// #undef par le header — utiliser Q_EMIT ici si des signaux apparaissent.
// ============================================================================

#include "meow_game_api.h"

#include <QElapsedTimer>
#include <QDateTime>
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
    return m_owner->playerPosition();
}

// ─── MeowZoneApi ────────────────────────────────────────────────────────────

MeowZoneApi::MeowZoneApi(MeowGameApi *owner)
    : QObject(owner), m_owner(owner) {}

QVariantList MeowZoneApi::playersInside() const
{
    return m_owner->zonePlayersInside();
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

void MeowGameApi::setPlayerSnapshot(const QJsonObject &playerSnapshot)
{
    m_playerValues = playerSnapshot.toVariantMap();
}

void MeowGameApi::setZoneOccupants(const QJsonArray &occupants)
{
    m_zoneOccupants = occupants.toVariantList();
}

void MeowGameApi::setRuntimeBudgets(int handlerBudgetUs, int tickBudgetUs,
                                    int emitMaxPerSec)
{
    if (handlerBudgetUs > 0) m_handlerBudgetUs = handlerBudgetUs;
    if (tickBudgetUs > 0)    m_tickBudgetUs    = tickBudgetUs;
    if (emitMaxPerSec > 0)   m_emitMaxPerSec   = emitMaxPerSec;
}

QVariantMap MeowGameApi::playerPosition() const
{
    // Instantané injecté (job du banc / runtime). Défaut neutre {0,0} tant
    // qu'aucune présence n'est fournie — l'artefact charge et tourne quand même.
    if (m_playerValues.isEmpty())
        return { { QStringLiteral("x"), 0.0 }, { QStringLiteral("y"), 0.0 } };
    QVariantMap pos;
    pos.insert(QStringLiteral("x"),
               m_playerValues.value(QStringLiteral("x"), 0.0));
    pos.insert(QStringLiteral("y"),
               m_playerValues.value(QStringLiteral("y"), 0.0));
    return pos;
}

QVariantList MeowGameApi::zonePlayersInside() const
{
    return m_zoneOccupants;
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
    // Enforcement runtime (D34, ≤ 30 émissions/s) : fenêtre glissante d'1 s.
    // OFF au banc → aucune coupure, le harness observe le débit réel (P4).
    if (m_enforce) {
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        while (!m_emitTimestampsMs.isEmpty()
               && now - m_emitTimestampsMs.first() >= 1000)
            m_emitTimestampsMs.removeFirst();
        if (m_emitTimestampsMs.size() >= m_emitMaxPerSec) {
            m_runtimeViolations.append(
                { QStringLiteral("event_flood"),
                  QStringLiteral("events.emit(\"%1\") : > %2 émissions/s — émission droppée")
                      .arg(name)
                      .arg(m_emitMaxPerSec) });
            ++m_activity; // l'activité compte même l'émission refusée
            return;       // rejet à la source, pas de dispatch
        }
        m_emitTimestampsMs.append(now);
    }

    ++m_emitCount;
    ++m_activity;
    // L'artefact entend ses propres émissions (bus local). La propagation
    // autoritative (autres tuiles/pairs) est l'affaire du bus d'état (M6-B).
    dispatch(name, payload, m_handlerBudgetUs);
}

void MeowGameApi::recordCall(const QString &channel, const QString &method,
                             const QVariantList &args)
{
    // File drainable : le consommateur runtime (S-7 / étage 2) l'applique au
    // vrai jeu. La façade elle-même reste sans effet de bord côté jeu.
    m_recordedCalls.append(ApiCall{ channel, method, args });
    ++m_activity;
}

QVector<ApiCall> MeowGameApi::takeRecordedCalls()
{
    QVector<ApiCall> calls;
    calls.swap(m_recordedCalls);
    return calls;
}

QVector<ApiViolation> MeowGameApi::takeRuntimeViolations()
{
    QVector<ApiViolation> v;
    v.swap(m_runtimeViolations);
    return v;
}

QVariant MeowGameApi::sessionGet(const QString &key) const
{
    return m_sessionValues.value(key);
}

void MeowGameApi::dispatchEvent(const QString &name, const QVariant &payload)
{
    // Budget handler (2 ms) sous enforcement. La cadence « tick » passe par
    // dispatchTick (budget 0,5 ms) — mais le banc appelle dispatchEvent("tick")
    // et mesure le coût de tick de l'extérieur, donc le budget handler ici est
    // sans effet au banc (enforcement OFF).
    dispatch(name, payload, m_handlerBudgetUs);
}

void MeowGameApi::dispatchTick(const QVariant &payload)
{
    dispatch(QStringLiteral("tick"), payload, m_tickBudgetUs);
}

void MeowGameApi::dispatch(const QString &name, const QVariant &payload,
                           qint64 budgetUs)
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
        invokeHandler(QStringLiteral("on:%1").arg(name), cb, args, budgetUs);
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
        invokeHandler(QStringLiteral("memory:%1").arg(key), cb, args,
                      m_handlerBudgetUs);
    }
}

void MeowGameApi::invokeHandler(const QString &handlerId, QJSValue &callback,
                                const QJSValueList &args, qint64 budgetUs)
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
    // Budget CPU runtime (D34) : la façade ne peut PAS interrompre un handler
    // déjà rendu (D26), mais elle journalise le dépassement pour le kill-switch
    // runtime (S-7). Code aligné sur le banc : tick_budget pour la cadence,
    // event_budget sinon. OFF au banc (mesuré de l'extérieur).
    if (m_enforce && budgetUs > 0 && run.elapsedUs > budgetUs) {
        const bool isTick = (budgetUs == m_tickBudgetUs);
        m_runtimeViolations.append(
            { isTick ? QStringLiteral("tick_budget")
                     : QStringLiteral("event_budget"),
              QStringLiteral("%1 : %2 µs > budget %3 µs")
                  .arg(handlerId)
                  .arg(run.elapsedUs)
                  .arg(budgetUs) });
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
