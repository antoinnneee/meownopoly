#ifndef MEOW_GAME_API_H
#define MEOW_GAME_API_H

// ============================================================================
// meow_game_api — façade `Meow.GameApi` exposée aux artefacts QML/JS (D34)
// ============================================================================
//
// Spécification : doc/v3/04_QML_GENERATIF_SANDBOX.md §3.3,
//                 doc/v3/08_DECISIONS_ET_QUESTIONS.md D34,
//                 doc/v3/12_BANC_ESSAI_R1.md §5 (« même façade que le runtime »).
//
// C'est le **vocabulaire complet** qu'un artefact généré a le droit d'utiliser
// — l'équivalent, pour le QML génératif, de l'allow-list de commandes du canal.
// Surface D34 : `memory.get/set/onChanged`, `events.on/emit`, `session.get`,
// `player.position()`, `zone.playersInside()`, `stats.addModifier`,
// `dialogue.show`, `anim.play`, `fx.spawn`, `sound.play`.
//
// Livrable A6 (« façade minimale ») : la surface charge sans erreur de
// référence ; `memory`/`events` fonctionnels + enregistrement des appels.
//
// Livrable S-6 (« façade complète MVP », plan doc 15) — cette classe :
//   - budgets RUNTIME derrière #define (handler ≤ 2 ms, tick ≤ 0,5 ms,
//     ≤ 30 émissions/s) avec auto-police optionnelle (setRuntimeEnforcement) ;
//   - lecture réelle `player.position()` / `zone.playersInside()` / `session`
//     depuis les instantanés injectés (setPlayerSnapshot/setZoneOccupants) ;
//   - `stats.addModifier` + `dialogue/anim/fx/sound` enregistrés en file
//     DRAINABLE (takeRecordedCalls) que le consommateur runtime applique au
//     vrai jeu — la façade reste découplée des singletons (invariant Core+Qml).
// Le câblage du drain sur les vrais systèmes (UI dialogue, FX, stats, Pattounx)
// est l'intégration S-7 / étage 2, hors de ce fichier.
//
// **Code partagé banc/jeu** (doc 12 §5) : le banc d'essai hors-process est le
// premier consommateur (P2→P5) ; le runtime confiné (étage 2, D13) réutilisera
// la même classe. Instrumentation intégrée côté C++ (jamais exposée au QML) :
//   - write-set observé (comparé au write-set déclaré, D11 → writeset_violation)
//   - compteur d'émissions (event_flood) et d'activité (leak P5)
//   - chronométrage de chaque handler (event_budget)
//   - quotas mémoire par valeur (memory_quota, plafond D35 1 KB/valeur)
//
// Dépendances : Qt6::Core + Qt6::Qml (QJSValue) — aucun module réseau, aucun
// singleton du jeu. La façade est injectée en context property `GameApi` dans
// le contexte restreint (restricted_context.h), une instance PAR artefact
// (quotas et write-set individuels).
//
// ⚠️ `events.emit` : `emit` est un mot-clé macro Qt (vide) ; il est #undef
// plus bas pour permettre le nom de méthode exigé par D34. Tout .cpp qui
// inclut cet en-tête doit utiliser `Q_EMIT` (pas `emit`) pour ses signaux.
// ============================================================================

#include <QObject>
#include <QJSValue>
#include <QVariant>
#include <QVariantMap>
#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QHash>
#include <QVector>
#include <QList>

// D35 : plafond par valeur écrite dans l'espace mémoire (1 KB/valeur).
// Derrière #define (pattern D22) ; surchargeable par les budgets du job.
#ifndef MEOW_API_MEMORY_VALUE_MAX_BYTES
#define MEOW_API_MEMORY_VALUE_MAX_BYTES 1024
#endif

// D34 — budgets RUNTIME (étage 2, en partie). Derrière #define (pattern D22),
// alignés sur les seuils du banc (bench_runner.h) : au banc, ces budgets sont
// mesurés DE L'EXTÉRIEUR (le harness observe les vraies durées/débits) et la
// façade reste passive ; en partie, il n'y a pas de harness — la façade
// s'auto-police quand `setRuntimeEnforcement(true)` est armé (voir plus bas).
#ifndef MEOW_API_HANDLER_BUDGET_US
#define MEOW_API_HANDLER_BUDGET_US 2000   // ≤ 2 ms / événement (D34)
#endif
#ifndef MEOW_API_TICK_BUDGET_US
#define MEOW_API_TICK_BUDGET_US 500       // ≤ 0,5 ms / tick (D34)
#endif
#ifndef MEOW_API_EMIT_MAX_PER_SEC
#define MEOW_API_EMIT_MAX_PER_SEC 30      // ≤ 30 émissions / s (D34)
#endif

// `emit` (macro Qt vide) doit céder la place à la méthode QML `events.emit`
// (nom figé par D34). Utiliser Q_EMIT dans les unités qui incluent ce header.
#ifdef emit
#undef emit
#endif

class QJSEngine;

namespace meow::sandbox {

class MeowGameApi;

// ─── Instrumentation (C++ uniquement, invisible du QML) ─────────────────────

// Un handler JS invoqué (événement, changement mémoire) : durée et erreur.
struct ApiHandlerRun {
    QString handlerId;   // ex. "onZoneEntered" ou "memory:score"
    qint64  elapsedUs = 0;
    bool    errored = false;
    QString error;
};

// Violation de quota détectée par la façade elle-même (ex. memory_quota).
struct ApiViolation {
    QString code;        // aligné sur les codes du banc (bench_protocol)
    QString details;
};

// Un appel de présentation ou de stats émis par l'artefact (dialogue/anim/fx/
// sound/stats). En partie (étage 2), le consommateur runtime draine cette file
// (takeRecordedCalls) et l'applique au vrai jeu — UI de dialogue, animations,
// particules, sons, stats réelles (S-7). La façade elle-même reste découplée
// des singletons du jeu (invariant : Qt6::Core + Qt6::Qml seulement).
struct ApiCall {
    QString channel;     // "dialogue" | "anim" | "fx" | "sound" | "stats"
    QString method;      // "show" | "play" | "spawn" | "addModifier"
    QVariantList args;   // arguments dans l'ordre de la surface D34
};

// ─── Sous-objets de la façade ───────────────────────────────────────────────

// `GameApi.memory` — espace mémoire de la tuile porteuse (doc 05).
// MVP banc : dictionnaire local initialisé depuis snapshot.memory ; le
// branchement sur le vrai MemoryStore (S-4) remplacera le backing sans
// changer la surface QML.
class MeowMemoryApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowMemoryApi(MeowGameApi *owner);

    Q_INVOKABLE QVariant get(const QString &key) const;
    Q_INVOKABLE bool set(const QString &key, const QVariant &value);
    Q_INVOKABLE void onChanged(const QString &key, const QJSValue &callback);

private:
    MeowGameApi *m_owner;
};

// `GameApi.events` — bus d'événements de jeu vu par l'artefact.
class MeowEventsApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowEventsApi(MeowGameApi *owner);

    Q_INVOKABLE void on(const QString &name, const QJSValue &callback);
    // Nom figé par D34 (macro Qt `emit` #undef en tête de fichier).
    Q_INVOKABLE void emit(const QString &name, const QVariant &payload = QVariant());

private:
    MeowGameApi *m_owner;
};

// `GameApi.stats` — modificateurs de statistiques. Enregistrés en file
// drainable (takeRecordedCalls) ; l'application aux vraies stats est S-7.
class MeowStatsApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowStatsApi(MeowGameApi *owner);
    Q_INVOKABLE void addModifier(const QString &target, const QString &stat,
                                 const QVariant &value);
private:
    MeowGameApi *m_owner;
};

// `GameApi.session` — lecture seule de l'état de session (S-6).
class MeowSessionApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowSessionApi(MeowGameApi *owner);
    Q_INVOKABLE QVariant get(const QString &key) const;
private:
    MeowGameApi *m_owner;
};

// `GameApi.player` — infos joueur ; position lue de l'instantané injecté.
class MeowPlayerApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowPlayerApi(MeowGameApi *owner);
    Q_INVOKABLE QVariantMap position() const;
private:
    MeowGameApi *m_owner;
};

// `GameApi.zone` — requêtes de zone ; occupants lus de l'instantané injecté.
class MeowZoneApi : public QObject
{
    Q_OBJECT
public:
    explicit MeowZoneApi(MeowGameApi *owner);
    Q_INVOKABLE QVariantList playersInside() const;
private:
    MeowGameApi *m_owner;
};

// `GameApi.dialogue` / `.anim` / `.fx` / `.sound` — canaux de présentation.
// Chaque appel est enregistré en file drainable (takeRecordedCalls) + compté
// pour l'activité P5 ; le rendu réel (UI dialogue, animations, particules,
// sons) est appliqué par le consommateur runtime (S-7). Une classe unique pour
// les quatre canaux — le nom du canal discrimine à l'enregistrement.
class MeowPresentationApi : public QObject
{
    Q_OBJECT
public:
    MeowPresentationApi(MeowGameApi *owner, const QString &channel);

    Q_INVOKABLE void show(const QVariant &content,
                          const QVariant &options = QVariant());   // dialogue.show
    Q_INVOKABLE void play(const QString &name,
                          const QVariant &options = QVariant());   // anim.play / sound.play
    Q_INVOKABLE void spawn(const QString &name,
                           const QVariant &options = QVariant());  // fx.spawn

private:
    MeowGameApi *m_owner;
    QString m_channel;
};

// ─── Façade racine ──────────────────────────────────────────────────────────
class MeowGameApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *memory   READ memoryApi   CONSTANT)
    Q_PROPERTY(QObject *events   READ eventsApi   CONSTANT)
    Q_PROPERTY(QObject *stats    READ statsApi    CONSTANT)
    Q_PROPERTY(QObject *session  READ sessionApi  CONSTANT)
    Q_PROPERTY(QObject *player   READ playerApi   CONSTANT)
    Q_PROPERTY(QObject *zone     READ zoneApi     CONSTANT)
    Q_PROPERTY(QObject *dialogue READ dialogueApi CONSTANT)
    Q_PROPERTY(QObject *anim     READ animApi     CONSTANT)
    Q_PROPERTY(QObject *fx       READ fxApi       CONSTANT)
    Q_PROPERTY(QObject *sound    READ soundApi    CONSTANT)

public:
    explicit MeowGameApi(QObject *parent = nullptr);

    // Configuration (avant instanciation de l'artefact) :
    //   targetUuid      : tuile porteuse (préfixe des clés du write-set)
    //   memorySnapshot  : snapshot.memory du job (doc 12 §2.3)
    //   sessionSnapshot : valeurs `session.get` (MVP : celles du job, sinon vide)
    //   memoryValueMaxBytes : plafond par valeur (D35), ≤ 0 → défaut #define
    void configure(const QString &targetUuid,
                   const QJsonObject &memorySnapshot,
                   const QJsonObject &sessionSnapshot = QJsonObject(),
                   int memoryValueMaxBytes = 0);

    // Instantané de présence injecté par l'appelant (job du banc, ou runtime).
    // `player.position()` lit x/y de ce snapshot ; `zone.playersInside()` lit
    // la liste d'occupants. Découple la façade de Pattounx (invariant Core+Qml).
    void setPlayerSnapshot(const QJsonObject &playerSnapshot);
    void setZoneOccupants(const QJsonArray &occupants);

    // Auto-police des budgets runtime (D34). OFF par défaut : au banc, les
    // budgets sont mesurés de l'extérieur et la façade ne doit rien altérer
    // (émissions non droppées, débit vrai observé). En partie (étage 2), le
    // runtime l'arme → la façade drope les émissions au-delà du plafond et
    // journalise les dépassements handler/tick dans `runtimeViolations`.
    // Seuils surchargeables (≤ 0 → défaut #define).
    void setRuntimeEnforcement(bool on) { m_enforce = on; }
    bool runtimeEnforcement() const { return m_enforce; }
    void setRuntimeBudgets(int handlerBudgetUs, int tickBudgetUs,
                           int emitMaxPerSec);

    // Moteur JS utilisé pour convertir les payloads QVariant → QJSValue lors
    // de l'invocation des callbacks (QJSValue::engine() n'existe plus en Qt6).
    // Renseigné par RestrictedContext à la création du contexte.
    void setJsEngine(QJSEngine *engine) { m_jsEngine = engine; }

    // ── Consommé par le banc (P4 stimuli) et le runtime (étage 2) ──
    // Invoque tous les handlers `events.on(name)` ; chaque run est chronométré
    // et journalisé (takeHandlerRuns).
    void dispatchEvent(const QString &name, const QVariant &payload);
    // Cadence de simulation (`events.on("tick")`) : même dispatch, mais sous
    // enforcement runtime le dépassement est jugé au budget TICK (0,5 ms), pas
    // au budget handler (2 ms). Le banc, lui, passe par dispatchEvent("tick")
    // et mesure le coût de tick de l'extérieur (P3) — inchangé.
    void dispatchTick(const QVariant &payload);
    // Change une clé mémoire « de l'extérieur » (stimulus, écriture distante) :
    // met à jour le backing et invoque les watchers `memory.onChanged(key)`.
    void touchMemory(const QString &key, const QVariant &value);

    // ── Instrumentation (lue par le banc) ──
    QStringList observedWriteSet() const { return m_writeSet; }
    QStringList registeredEventNames() const;
    QStringList watchedMemoryKeys() const;
    int emitCount() const { return m_emitCount; }
    // Compteur monotone de TOUTE activité issue de l'artefact (écritures,
    // émissions, appels stats/présentation, handlers invoqués). Un delta > 0
    // après teardown ⇒ `leak` (P5).
    qint64 activityCounter() const { return m_activity; }
    QVector<ApiHandlerRun> takeHandlerRuns();
    QVector<ApiViolation> violations() const { return m_violations; }
    // File des appels stats/présentation, dans l'ordre d'émission. Drainée par
    // le consommateur runtime (S-7 / étage 2) qui les applique au vrai jeu.
    QVector<ApiCall> takeRecordedCalls();
    int recordedCallCount() const { return m_recordedCalls.size(); }
    // Dépassements de budget runtime détectés SOUS enforcement (event_budget,
    // tick_budget, event_flood). Distincts de `violations()` (memory_quota) —
    // ne jamais fusionner : le banc lit `violations()` et les code toutes en
    // memory_quota. Codes alignés sur bench_protocol.
    QVector<ApiViolation> runtimeViolations() const { return m_runtimeViolations; }
    QVector<ApiViolation> takeRuntimeViolations();

    // ── Accès internes (sous-objets) ──
    QVariant memoryGet(const QString &key) const;
    bool memorySet(const QString &key, const QVariant &value, bool external);
    void memoryWatch(const QString &key, const QJSValue &callback);
    void eventsOn(const QString &name, const QJSValue &callback);
    void eventsEmit(const QString &name, const QVariant &payload);
    void recordCall(const QString &channel, const QString &method,
                    const QVariantList &args);
    QVariant sessionGet(const QString &key) const;
    QVariantMap playerPosition() const;
    QVariantList zonePlayersInside() const;

    QObject *memoryApi() const   { return m_memory; }
    QObject *eventsApi() const   { return m_events; }
    QObject *statsApi() const    { return m_stats; }
    QObject *sessionApi() const  { return m_session; }
    QObject *playerApi() const   { return m_player; }
    QObject *zoneApi() const     { return m_zone; }
    QObject *dialogueApi() const { return m_dialogue; }
    QObject *animApi() const     { return m_anim; }
    QObject *fxApi() const       { return m_fx; }
    QObject *soundApi() const    { return m_sound; }

private:
    // `budgetUs` : plafond runtime appliqué à CE run sous enforcement (budget
    // handler pour les événements, budget tick pour la cadence).
    void invokeHandler(const QString &handlerId, QJSValue &callback,
                       const QJSValueList &args, qint64 budgetUs);
    void dispatch(const QString &name, const QVariant &payload, qint64 budgetUs);
    void notifyMemoryWatchers(const QString &key, const QVariant &value);
    QString writeSetKey(const QString &key) const;

    // Sous-objets (enfants QObject → détruits avec la façade)
    MeowMemoryApi       *m_memory = nullptr;
    MeowEventsApi       *m_events = nullptr;
    MeowStatsApi        *m_stats = nullptr;
    MeowSessionApi      *m_session = nullptr;
    MeowPlayerApi       *m_player = nullptr;
    MeowZoneApi         *m_zone = nullptr;
    MeowPresentationApi *m_dialogue = nullptr;
    MeowPresentationApi *m_anim = nullptr;
    MeowPresentationApi *m_fx = nullptr;
    MeowPresentationApi *m_sound = nullptr;

    // Backing mémoire (MVP banc ; remplacé par MemoryStore en S-4)
    QJSEngine *m_jsEngine = nullptr;
    QString m_targetUuid;
    QVariantMap m_memoryValues;
    QVariantMap m_sessionValues;
    QVariantMap m_playerValues;      // instantané joueur (player.position)
    QVariantList m_zoneOccupants;    // occupants de zone (zone.playersInside)
    int m_memoryValueMaxBytes = MEOW_API_MEMORY_VALUE_MAX_BYTES;

    // Budgets runtime (D34) — auto-police OFF par défaut (banc = observation
    // externe). Voir setRuntimeEnforcement.
    bool  m_enforce = false;
    qint64 m_handlerBudgetUs = MEOW_API_HANDLER_BUDGET_US;
    qint64 m_tickBudgetUs    = MEOW_API_TICK_BUDGET_US;
    int    m_emitMaxPerSec   = MEOW_API_EMIT_MAX_PER_SEC;
    QVector<qint64> m_emitTimestampsMs;  // fenêtre glissante 1 s (event_flood)

    // Abonnements
    QHash<QString, QList<QJSValue>> m_eventHandlers;   // nom → callbacks
    QHash<QString, QList<QJSValue>> m_memoryWatchers;  // clé → callbacks

    // Instrumentation
    QStringList m_writeSet;
    int m_emitCount = 0;
    qint64 m_activity = 0;
    QVector<ApiHandlerRun> m_handlerRuns;
    QVector<ApiViolation> m_violations;         // memory_quota (lu par le banc)
    QVector<ApiViolation> m_runtimeViolations;  // budgets runtime (enforcement)
    QVector<ApiCall> m_recordedCalls;           // stats/présentation drainables
};

} // namespace meow::sandbox

#endif // MEOW_GAME_API_H
