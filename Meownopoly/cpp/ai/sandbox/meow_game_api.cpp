#include "meow_game_api.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QQmlEngine>

namespace {

// Clé canonique du write-set : "<uuid>/<clé>". La clé porte déjà son
// namespace (ex: "state/armed", doc 05).
QString canonicalKey(const QString &uuid, const QString &key)
{
    return uuid + QLatin1Char('/') + key;
}

// Chronomètre un appel de callback JS et capture erreur/interruption.
MeowHandlerCall timedCall(QQmlEngine *engine,
                          const QString &name,
                          QJSValue callback,
                          const QJSValueList &args)
{
    MeowHandlerCall call;
    call.name = name;
    QElapsedTimer timer;
    timer.start();
    const QJSValue result = callback.call(args);
    call.elapsedNs = timer.nsecsElapsed();
    if (result.isError()) {
        call.jsError = true;
        call.errorString = result.toString();
    }
    if (engine && engine->isInterrupted())
        call.interrupted = true;
    return call;
}

} // namespace

// ============================================================================
// MeowMemoryApi
// ============================================================================

MeowMemoryApi::MeowMemoryApi(QObject *parent)
    : QObject(parent)
{
}

void MeowMemoryApi::setup(QQmlEngine *engine,
                          const QString &targetUuid,
                          const QJsonObject &memorySnapshot,
                          int maxValueKb)
{
    m_engine = engine;
    m_targetUuid = targetUuid;
    m_maxValueBytes = maxValueKb * 1024;

    // Snapshot doc 05 : { "<uuid>": { "<clé>": <valeur>, ... }, ... }
    for (auto it = memorySnapshot.constBegin(); it != memorySnapshot.constEnd();
         ++it) {
        if (it.value().isObject())
            m_store.insert(it.key(), it.value().toObject().toVariantMap());
    }
}

QJSValue MeowMemoryApi::get(const QString &keyOrUuid, const QString &key)
{
    const QString uuid = key.isEmpty() ? m_targetUuid : keyOrUuid;
    const QString realKey = key.isEmpty() ? keyOrUuid : key;

    const auto it = m_store.constFind(uuid);
    if (it == m_store.constEnd() || !it->contains(realKey))
        return QJSValue(QJSValue::UndefinedValue);
    if (!m_engine)
        return QJSValue(QJSValue::UndefinedValue);
    return m_engine->toScriptValue(it->value(realKey));
}

bool MeowMemoryApi::set(const QString &keyOrUuid,
                        const QJSValue &valueOrKey,
                        const QJSValue &value)
{
    QString uuid;
    QString key;
    QJSValue jsValue;
    if (value.isUndefined()) {
        // Forme set(key, value) sur la tuile porteuse.
        uuid = m_targetUuid;
        key = keyOrUuid;
        jsValue = valueOrKey;
    } else {
        uuid = keyOrUuid;
        key = valueOrKey.toString();
        jsValue = value;
    }
    return storeValue(uuid, key, jsValue);
}

bool MeowMemoryApi::storeValue(const QString &uuid, const QString &key,
                               const QJSValue &value)
{
    const QString canonical = canonicalKey(uuid, key);

    // Toute TENTATIVE d'écriture par l'artefact entre dans le write-set
    // observé — y compris une écriture ensuite refusée pour quota (c'est
    // l'intention qui est comparée au write-set déclaré, D11).
    if (!m_observedWrites.contains(canonical))
        m_observedWrites.append(canonical);

    const QVariant variant = value.toVariant();

    // Quota de taille (MEOW_SANDBOX_MEM_VALUE_KB, D15/D34) : taille de la
    // valeur sérialisée en JSON compact (même métrique que la synchro).
    const QJsonValue json = QJsonValue::fromVariant(variant);
    QJsonObject probe;
    probe.insert(QStringLiteral("v"), json);
    const int bytes =
        QJsonDocument(probe).toJson(QJsonDocument::Compact).size() - 8;
    if (bytes > m_maxValueBytes) {
        m_quotaViolations.append(
            QStringLiteral("%1 : %2 octets > quota %3 octets")
                .arg(canonical)
                .arg(bytes)
                .arg(m_maxValueBytes));
        return false; // écriture refusée
    }

    m_store[uuid].insert(key, variant);
    notifyWatchers(uuid, key, variant); // mesures agrégées côté banc via P4
    return true;
}

void MeowMemoryApi::onChanged(const QString &keyOrUuid,
                              const QJSValue &keyOrCallback,
                              const QJSValue &callback)
{
    Watcher w;
    if (keyOrCallback.isCallable()) {
        // Forme onChanged(key, cb) sur la tuile porteuse.
        w.uuid = m_targetUuid;
        w.key = keyOrUuid;
        w.callback = keyOrCallback;
    } else if (callback.isCallable()) {
        w.uuid = keyOrUuid;
        w.key = keyOrCallback.toString();
        w.callback = callback;
    } else {
        return; // pas de callback : enregistrement ignoré (fail-soft)
    }
    m_watchers.append(w);
}

QVector<MeowHandlerCall> MeowMemoryApi::notifyWatchers(const QString &uuid,
                                                       const QString &key,
                                                       const QVariant &value)
{
    QVector<MeowHandlerCall> calls;
    if (m_notifyDepth >= 8)
        return calls; // garde anti-récursion set → watcher → set
    ++m_notifyDepth;
    for (const Watcher &w : std::as_const(m_watchers)) {
        if (w.uuid != uuid || w.key != key)
            continue;
        QJSValueList args;
        if (m_engine)
            args.append(m_engine->toScriptValue(value));
        calls.append(timedCall(m_engine,
                               QStringLiteral("memory(%1)").arg(key),
                               w.callback, args));
        if (m_engine && m_engine->isInterrupted())
            break;
    }
    --m_notifyDepth;
    return calls;
}

QVector<MeowHandlerCall> MeowMemoryApi::simulateExternalWrite(
    const QString &uuid, const QString &key, const QVariant &value)
{
    // Écriture du BANC (acteur externe) : pas d'entrée dans le write-set
    // observé de l'artefact, pas de quota — seul le dispatch des watchers
    // nous intéresse (mesure event/handler).
    m_store[uuid].insert(key, value);
    return notifyWatchers(uuid, key, value);
}

QStringList MeowMemoryApi::watchedKeys() const
{
    QStringList keys;
    for (const Watcher &w : m_watchers) {
        const QString canonical = canonicalKey(w.uuid, w.key);
        if (!keys.contains(canonical))
            keys.append(canonical);
    }
    return keys;
}

// ============================================================================
// MeowEventsApi
// ============================================================================

MeowEventsApi::MeowEventsApi(QObject *parent)
    : QObject(parent)
{
}

void MeowEventsApi::setup(QQmlEngine *engine, int maxEmitPerSecond)
{
    m_engine = engine;
    m_maxEmitPerSecond = maxEmitPerSecond;
    m_clock.start();
    m_windowStartMs = 0;
}

void MeowEventsApi::on(const QString &type, const QJSValue &callback)
{
    if (type.isEmpty() || !callback.isCallable())
        return; // fail-soft : abonnement invalide ignoré
    m_handlers.append({type, callback});
}

bool MeowEventsApi::emitEvent(const QString &type, const QJSValue &payload)
{
    Q_UNUSED(payload); // no-op au banc : compté, jamais redistribué
    Q_UNUSED(type);

    ++m_totalEmits;
    const qint64 nowMs = m_clock.elapsed();
    if (nowMs - m_windowStartMs >= 1000) {
        m_windowStartMs = nowMs;
        m_emitsInWindow = 0;
    }
    ++m_emitsInWindow;
    if (m_emitsInWindow > m_maxEmitsPerWindow)
        m_maxEmitsPerWindow = m_emitsInWindow;
    return true;
}

QStringList MeowEventsApi::registeredTypes() const
{
    QStringList types;
    for (const Handler &h : m_handlers) {
        if (!types.contains(h.type))
            types.append(h.type);
    }
    return types;
}

QVector<MeowHandlerCall> MeowEventsApi::dispatch(const QString &type,
                                                 const QVariantMap &payload)
{
    QVector<MeowHandlerCall> calls;
    for (const Handler &h : std::as_const(m_handlers)) {
        if (h.type != type)
            continue;
        QJSValueList args;
        if (m_engine)
            args.append(m_engine->toScriptValue(payload));
        calls.append(timedCall(m_engine,
                               QStringLiteral("on(%1)").arg(type),
                               h.callback, args));
        if (m_engine && m_engine->isInterrupted())
            break; // moteur interrompu : inutile d'appeler les suivants
    }
    return calls;
}

double MeowEventsApi::emitRatePerSecond() const
{
    const double seconds = qMax<qint64>(m_clock.elapsed(), 1) / 1000.0;
    return m_totalEmits / seconds;
}

// ============================================================================
// MeowStatsApi
// ============================================================================

MeowStatsApi::MeowStatsApi(QObject *parent)
    : QObject(parent)
{
}

bool MeowStatsApi::addModifier(const QString &playerId,
                               const QString &stat,
                               double value,
                               const QJSValue &durationMs)
{
    m_journal.append(QStringLiteral("addModifier(%1, %2, %3, %4)")
                         .arg(playerId, stat)
                         .arg(value)
                         .arg(durationMs.isNumber()
                                  ? QString::number(durationMs.toNumber())
                                  : QStringLiteral("-")));
    return true;
}
