#ifndef MEOW_GAME_API_H
#define MEOW_GAME_API_H

// ============================================================================
// Façade `Meow.GameApi` MINIMALE exposée aux artefacts QML/JS générés
// (tâche A6 du plan doc/v3/15_PLAN_IMPLEMENTATION.md, décision D34,
//  doc/v3/04_QML_GENERATIF_SANDBOX.md §3.3).
//
// Périmètre MVP (besoins du fil rouge doc 11 + corpus doc 12 §8) :
//   - memory : get / set (borné MEOW_SANDBOX_MEM_VALUE_KB) / onChanged —
//     backée par une QVariantMap en mémoire initialisée du snapshot du job.
//     Le write-set OBSERVÉ est enregistré (verdict writeset_violation, P4).
//   - events : on (instrumentation des stimuli P4) / emit (compté pour
//     event_flood). `emit` est un mot-macro Qt : l'implémentation C++
//     s'appelle emitEvent, et le contexte restreint expose aux artefacts un
//     wrapper JS figé `{ on, emit }` (voir restricted_context.cpp).
//   - stats : addModifier → no-op JOURNALISÉ au banc.
//
// TODO(S-6) : promouvoir en vrai module QML installé (`import Meow.GameApi`
// avec types) et compléter la liste D34 (session.get, player.position,
// zone.playersInside, dialogue.show, anim.play, fx.spawn, sound.play).
// Au banc, `import Meow.GameApi` est rendu licite par qmlRegisterModule
// (module vide) et la façade passe par des context properties.
//
// Code PARTAGÉ banc/jeu (doc 12 §5) : QtCore + QtQml uniquement.
// ============================================================================

#include <QElapsedTimer>
#include <QHash>
#include <QJSValue>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QVector>

class QQmlEngine;

// Résultat de l'invocation instrumentée d'un handler (stimuli P4).
struct MeowHandlerCall
{
    QString name;        // "on(<type>)" ou "memory(<clé>)"
    qint64 elapsedNs = 0;
    bool jsError = false;    // le handler a levé une exception JS
    bool interrupted = false; // le moteur a été interrompu pendant l'appel
    QString errorString;
};

// ----------------------------------------------------------------------------
// memory — espace mémoire de la tuile (doc 05), backé QVariantMap au banc.
// Formes d'appel côté artefact (arité, cf. D34) :
//   memory.get("state/armed")              → clé sur la tuile porteuse
//   memory.get(uuid, "state/armed")        → clé d'une autre tuile
//   memory.set("state/armed", true)        / memory.set(uuid, key, value)
//   memory.onChanged("state/armed", cb)    / memory.onChanged(uuid, key, cb)
// ----------------------------------------------------------------------------
class MeowMemoryApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowMemoryApi(QObject *parent = nullptr);

    void setup(QQmlEngine *engine,
               const QString &targetUuid,
               const QJsonObject &memorySnapshot,
               int maxValueKb);

    Q_INVOKABLE QJSValue get(const QString &keyOrUuid,
                             const QString &key = QString());
    Q_INVOKABLE bool set(const QString &keyOrUuid,
                         const QJSValue &valueOrKey,
                         const QJSValue &value = QJSValue(QJSValue::UndefinedValue));
    Q_INVOKABLE void onChanged(const QString &keyOrUuid,
                               const QJSValue &keyOrCallback,
                               const QJSValue &callback = QJSValue(QJSValue::UndefinedValue));

    // --- Instrumentation banc ---
    // Écriture EXTERNE (stimulus P4 « une clé écoutée change ») : mute la
    // valeur et déclenche les watchers, SANS compter dans le write-set
    // observé (ce n'est pas l'artefact qui écrit).
    QVector<MeowHandlerCall> simulateExternalWrite(const QString &uuid,
                                                   const QString &key,
                                                   const QVariant &value);

    // Clés observées par onChanged : paires "uuid/key".
    QStringList watchedKeys() const;
    // Write-set observé, entrées "uuid/key" (uuid réel, jamais raccourci).
    QStringList observedWriteSet() const { return m_observedWrites; }
    // Violations de quota de taille de valeur (memory_quota).
    QStringList quotaViolations() const { return m_quotaViolations; }
    QString targetUuid() const { return m_targetUuid; }

private:
    struct Watcher
    {
        QString uuid;
        QString key;
        QJSValue callback;
    };

    bool storeValue(const QString &uuid, const QString &key,
                    const QJSValue &value);
    QVector<MeowHandlerCall> notifyWatchers(const QString &uuid,
                                            const QString &key,
                                            const QVariant &value);

    QQmlEngine *m_engine = nullptr;
    QString m_targetUuid;
    int m_maxValueBytes = 1024;
    QHash<QString, QVariantMap> m_store; // uuid → (clé → valeur)
    QVector<Watcher> m_watchers;
    QStringList m_observedWrites;
    QStringList m_quotaViolations;
    int m_notifyDepth = 0; // garde anti-récursion set→watcher→set
};

// ----------------------------------------------------------------------------
// events — abonnements et émissions d'événements de jeu. Au banc, emitEvent
// est un no-op compté (pas de dispatch vers les propres handlers de
// l'artefact : dans le jeu, c'est le bus autoritatif qui redistribue).
// ----------------------------------------------------------------------------
class MeowEventsApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowEventsApi(QObject *parent = nullptr);

    void setup(QQmlEngine *engine, int maxEmitPerSecond);

    Q_INVOKABLE void on(const QString &type, const QJSValue &callback);
    Q_INVOKABLE bool emitEvent(const QString &type,
                               const QJSValue &payload = QJSValue(QJSValue::UndefinedValue));

    // --- Instrumentation banc ---
    // Types réellement abonnés en P2 (source de vérité des stimuli P4 :
    // « confirmés en P2 à l'enregistrement », doc 12 §3).
    QStringList registeredTypes() const;
    int handlerCount() const { return m_handlers.size(); }

    // Injection directe d'un stimulus (reco doc 12 §11 : pas de physique
    // réelle) : appelle chaque handler abonné à `type`, chronométré.
    QVector<MeowHandlerCall> dispatch(const QString &type,
                                      const QVariantMap &payload);

    int totalEmits() const { return m_totalEmits; }
    int maxEmitsPerWindow() const { return m_maxEmitsPerWindow; }
    bool floodDetected() const { return m_maxEmitsPerWindow > m_maxEmitPerSecond; }
    // Émissions/s moyennées sur le temps réel écoulé depuis setup(). NB : le
    // banc accélère les ticks, ce taux réel est donc PESSIMISTE (majore le
    // taux en partie) — c'est le sens sûr.
    double emitRatePerSecond() const;

private:
    struct Handler
    {
        QString type;
        QJSValue callback;
    };

    QQmlEngine *m_engine = nullptr;
    int m_maxEmitPerSecond = 30;
    QVector<Handler> m_handlers;
    QElapsedTimer m_clock;
    int m_totalEmits = 0;
    qint64 m_windowStartMs = 0;
    int m_emitsInWindow = 0;
    int m_maxEmitsPerWindow = 0;
};

// ----------------------------------------------------------------------------
// stats — module gameplay « stats » (D41). No-op journalisé au banc.
// ----------------------------------------------------------------------------
class MeowStatsApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowStatsApi(QObject *parent = nullptr);

    Q_INVOKABLE bool addModifier(const QString &playerId,
                                 const QString &stat,
                                 double value,
                                 const QJSValue &durationMs = QJSValue(QJSValue::UndefinedValue));

    QStringList journal() const { return m_journal; }

private:
    QStringList m_journal;
};

#endif // MEOW_GAME_API_H
