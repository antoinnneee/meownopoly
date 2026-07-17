#include "bench_phases.h"

#include "deadline_watchdog.h"
#include "rss_watchdog.h"

#include "ai/bench/bench_constants.h"
#include "ai/sandbox/restricted_context.h"

#include "game/map/map.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QJsonArray>
#include <QPointer>
#include <QQmlComponent>
#include <QQmlEngine>

#include <algorithm>

namespace {

// Ticks de "démarrage à vide" du moteur physique en P1 — juste assez pour
// prouver que le moteur tourne dans le process du banc. La vraie simulation
// à vide (idleTicks) appartient à P3.
constexpr int kP1WarmupTicks = 10;
constexpr qreal kTickDt = 1.0 / 60.0;

// Fréquence du poll object_quota pendant P3 (en ticks).
constexpr int kObjectPollTicks = 60;

double percentileUs(QVector<qint64> ns, double p)
{
    if (ns.isEmpty())
        return 0.0;
    std::sort(ns.begin(), ns.end());
    const int idx = qBound(0, int(p * (ns.size() - 1) + 0.5), ns.size() - 1);
    return ns.at(idx) / 1000.0;
}

// Un warning QML pendant l'instanciation est-il une erreur d'exécution ?
// (ReferenceError sur singleton masqué, TypeError, SyntaxError…). Politique
// fail-closed : tout warning contenant "Error" fait échouer P2.
bool isErrorWarning(const QString &warning)
{
    return warning.contains(QLatin1String("Error"));
}

} // namespace

BenchPhases::BenchPhases(const BenchJob &job)
    : m_job(job)
    , m_rng(job.seed)
{
}

BenchPhases::~BenchPhases()
{
    delete m_root;
    m_root = nullptr;
    delete m_component;
    m_component = nullptr;
    delete m_ctx;
    m_ctx = nullptr;
    delete m_map;
    m_map = nullptr;
}

BenchPhases::Budgets BenchPhases::effectiveBudgets() const
{
    const QJsonObject &b = m_job.budgets;
    Budgets out;
    out.maxHandlerMs = b.value(QStringLiteral("maxHandlerMs"))
                           .toDouble(MEOW_SANDBOX_MAX_HANDLER_MS);
    out.maxTickMs =
        b.value(QStringLiteral("maxTickMs")).toDouble(MEOW_SANDBOX_MAX_TICK_MS);
    out.maxMemMB =
        b.value(QStringLiteral("maxMemMB")).toDouble(MEOW_SANDBOX_MAX_MEM_MB);
    out.maxObjects =
        b.value(QStringLiteral("maxObjects")).toInt(MEOW_SANDBOX_MAX_OBJECTS);
    out.maxEmitPerS =
        b.value(QStringLiteral("maxEmitPerS")).toInt(MEOW_SANDBOX_MAX_EMIT_PER_S);
    out.memValueKb =
        b.value(QStringLiteral("memValueKB")).toInt(MEOW_SANDBOX_MEM_VALUE_KB);
    out.loadTimeoutMs = b.value(QStringLiteral("loadTimeoutMs"))
                            .toInt(MEOW_BENCH_LOAD_TIMEOUT_MS);
    out.idleTicks =
        b.value(QStringLiteral("idleTicks")).toInt(MEOW_BENCH_IDLE_TICKS);
    return out;
}

int BenchPhases::liveObjectCount() const
{
    // Choix documenté (A6) : POLL de l'arbre d'objets (racine + descendants
    // QObject, findChildren récursif) plutôt qu'un hook onCompleted — le poll
    // voit aussi les objets créés dynamiquement après l'instanciation, sans
    // instrumenter chaque type. Les objets purement JS (arrays…) ne sont pas
    // comptés : eux relèvent du watchdog RSS (runaway_alloc).
    if (!m_root)
        return 0;
    return 1 + int(m_root->findChildren<QObject *>(Qt::FindChildrenRecursively)
                       .size());
}

qint64 BenchPhases::runOneTick()
{
    QElapsedTimer timer;
    timer.start();
    m_engine.step(kTickDt);
    m_engine.takeEvents(); // drainé : aucun consommateur au banc
    // Événements Qt bornés (timers QML de l'artefact, deferred deletes…).
    QCoreApplication::processEvents(QEventLoop::AllEvents, 2 /*ms*/);
    return timer.nsecsElapsed();
}

void BenchPhases::recordHandlerCalls(const QVector<MeowHandlerCall> &calls)
{
    for (const MeowHandlerCall &call : calls) {
        m_handlerNs[call.name].append(call.elapsedNs);
        if (call.jsError && !call.interrupted)
            m_handlerErrors.append(call.name + QStringLiteral(" : ")
                                   + call.errorString);
    }
}

// ============================================================================
// P1 — Reconstruction
// ============================================================================

PhaseResult BenchPhases::runP1Reconstruction()
{
    QElapsedTimer timer;
    timer.start();

    const QJsonObject &mapJson = m_job.snapshotMap;
    if (!mapJson.value(QStringLiteral("mapInfo")).isObject())
        return PhaseResult::fail(
            QStringLiteral("snapshot_invalid"),
            QStringLiteral("snapshot.map sans objet 'mapInfo'"));
    if (!mapJson.value(QStringLiteral("snapableTiles")).isArray())
        return PhaseResult::fail(
            QStringLiteral("snapshot_invalid"),
            QStringLiteral("snapshot.map sans tableau 'snapableTiles'"));

    m_map = Map::loadMap(mapJson);
    if (!m_map || !m_map->getMapInfo())
        return PhaseResult::fail(
            QStringLiteral("snapshot_invalid"),
            QStringLiteral("échec de la reconstruction de la carte depuis le "
                           "snapshot (mapInfo non chargée)"));

    const int expectedTiles =
        mapJson.value(QStringLiteral("snapableTiles")).toArray().size();
    const int loadedTiles = m_map->tiles().size();
    if (loadedTiles < expectedTiles)
        return PhaseResult::fail(
            QStringLiteral("snapshot_invalid"),
            QStringLiteral("%1 tuile(s) sur %2 rejetée(s) au rechargement "
                           "(uniqueId/tileType manquants ou entrée invalide)")
                .arg(expectedTiles - loadedTiles)
                .arg(expectedTiles));

    for (int i = 0; i < kP1WarmupTicks; ++i)
        m_engine.step(kTickDt);
    m_engine.takeEvents();

    m_metrics.insert(QStringLiteral("snapshotMs"), double(timer.elapsed()));
    m_metrics.insert(QStringLiteral("tileCount"), loadedTiles);
    return PhaseResult::pass();
}

// ============================================================================
// P2 — Instanciation dans le contexte restreint (A6)
// ============================================================================

PhaseResult BenchPhases::runP2Instantiation()
{
    m_budgets = effectiveBudgets();
    DeadlineWatchdog::init(m_job.jobId);

    const QString source =
        m_job.artifact.value(QStringLiteral("source")).toString();
    const QString targetUuid =
        m_job.artifact.value(QStringLiteral("targetUuid")).toString();

    RestrictedContext::Options options;
    options.targetUuid = targetUuid;
    options.memorySnapshot = m_job.snapshotMemory;
    options.maxEmitPerSecond = m_budgets.maxEmitPerS;
    options.memValueKb = m_budgets.memValueKb;
    m_ctx = new RestrictedContext(options);

    QElapsedTimer loadTimer;
    loadTimer.start();

    // Toute la fenêtre de chargement (compilation + création, dont les
    // Component.onCompleted) est couverte par le watchdog d'échéance : une
    // boucle au chargement bloque le thread → interruption JS à l'échéance,
    // _Exit en filet ultime.
    DeadlineWatchdog::arm("P2", "load_timeout",
                          QStringLiteral("chargement > %1 ms")
                              .arg(m_budgets.loadTimeoutMs),
                          m_budgets.loadTimeoutMs, m_ctx->engine(),
                          MEOW_BENCH_INTERRUPT_GRACE_MS);

    m_component = new QQmlComponent(m_ctx->engine());
    // Base URL sous qrc:/ (inexistante mais LOCALE) : l'import implicite du
    // « répertoire du fichier » se résout en synchrone. Un schéma custom
    // (meow://) part, lui, sur la voie réseau du type loader → composant
    // coincé en Loading.
    m_component->setData(source.toUtf8(),
                         QUrl(QStringLiteral("qrc:/meow-artifact/artifact.qml")));
    // Si des dépendances restent asynchrones, pomper la boucle d'événements
    // jusqu'à résolution — borné par le timeout de chargement.
    while (m_component->status() == QQmlComponent::Loading
           && loadTimer.elapsed() < m_budgets.loadTimeoutMs) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
    }
    if (m_component->status() == QQmlComponent::Loading) {
        DeadlineWatchdog::disarm();
        return PhaseResult::fail(
            QStringLiteral("load_timeout"),
            QStringLiteral("compilation toujours en cours après %1 ms")
                .arg(m_budgets.loadTimeoutMs));
    }

    qint64 compileMs = loadTimer.elapsed();
    QObject *created = nullptr;
    if (!m_component->isError()) {
        // beginCreate/completeCreate séparés : mesure de la part "création
        // d'objets" vs "handlers d'initialisation" (onCompleted tourne dans
        // completeCreate — c'est là que boucle_infinie_onload bloque).
        created = m_component->beginCreate(m_ctx->context());
        if (created)
            m_component->completeCreate();
    }
    const bool timedOut = DeadlineWatchdog::disarm();
    const qint64 loadMs = loadTimer.elapsed();
    m_root = created;

    // Drain : les warnings QML peuvent être postés en différé.
    QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
    const QStringList warnings = m_ctx->takeWarnings();

    m_metrics.insert(QStringLiteral("loadMs"), double(loadMs));
    m_metrics.insert(QStringLiteral("compileMs"), double(compileMs));

    if (timedOut)
        return PhaseResult::fail(
            QStringLiteral("load_timeout"),
            QStringLiteral("l'instanciation ne rend pas la main après %1 ms "
                           "(boucle au chargement ?) — moteur JS interrompu")
                .arg(m_budgets.loadTimeoutMs));

    if (m_component->isError() || !m_root) {
        QStringList errors;
        const auto componentErrors = m_component->errors();
        for (const QQmlError &e : componentErrors)
            errors.append(e.toString());
        errors.append(warnings);
        if (errors.isEmpty())
            errors.append(QStringLiteral("status=%1 errorString='%2'")
                              .arg(int(m_component->status()))
                              .arg(m_component->errorString()));
        return PhaseResult::fail(
            QStringLiteral("load_failed"),
            QStringLiteral("échec de création de l'artefact : %1")
                .arg(errors.join(QStringLiteral(" | "))));
    }

    // Erreur JS pendant l'instanciation (ReferenceError sur un singleton du
    // jeu masqué par le contexte restreint, TypeError…) : load_failed —
    // c'est la preuve du masquage attendue par acces_singleton.qml (R1 n°4).
    QStringList errorWarnings;
    for (const QString &w : warnings) {
        if (isErrorWarning(w))
            errorWarnings.append(w);
    }
    if (!errorWarnings.isEmpty())
        return PhaseResult::fail(
            QStringLiteral("load_failed"),
            QStringLiteral("erreur JS à l'instanciation : %1")
                .arg(errorWarnings.join(QStringLiteral(" | "))));

    const int objects = liveObjectCount();
    m_metrics.insert(QStringLiteral("objectCount"), objects);
    if (objects > m_budgets.maxObjects)
        return PhaseResult::fail(
            QStringLiteral("object_quota"),
            QStringLiteral("%1 objets QML instanciés > plafond %2 (D34)")
                .arg(objects)
                .arg(m_budgets.maxObjects));

    m_metrics.insert(QStringLiteral("listensTo"),
                     QJsonArray::fromStringList(
                         m_ctx->eventsApi()->registeredTypes()));
    return PhaseResult::pass();
}

// ============================================================================
// P3 — Simulation à vide (ticks accélérés, pas de sleep)
// ============================================================================

PhaseResult BenchPhases::runP3IdleSimulation()
{
    const int ticks = m_budgets.idleTicks;
    QVector<qint64> tickNs;
    tickNs.reserve(ticks);

    // Filet anti-gel de la phase entière (un Timer QML de l'artefact peut
    // exécuter du JS pendant processEvents) : cap large, code tick_budget.
    DeadlineWatchdog::arm("P3", "tick_budget",
                          QStringLiteral("simulation à vide bloquée (> 10 s "
                                         "pour %1 ticks)")
                              .arg(ticks),
                          10000, m_ctx ? m_ctx->engine() : nullptr,
                          MEOW_BENCH_INTERRUPT_GRACE_MS);

    for (int i = 0; i < ticks; ++i) {
        tickNs.append(runOneTick());
        if ((i + 1) % kObjectPollTicks == 0) {
            const int objects = liveObjectCount();
            if (objects > m_budgets.maxObjects) {
                DeadlineWatchdog::disarm();
                return PhaseResult::fail(
                    QStringLiteral("object_quota"),
                    QStringLiteral("%1 objets QML au tick %2 > plafond %3")
                        .arg(objects)
                        .arg(i + 1)
                        .arg(m_budgets.maxObjects));
            }
        }
    }
    const bool blocked = DeadlineWatchdog::disarm();

    const double p50 = percentileUs(tickNs, 0.50);
    const double p95 = percentileUs(tickNs, 0.95);
    const double maxUs = percentileUs(tickNs, 1.0);
    m_metrics.insert(QStringLiteral("idleTicks"), ticks);
    m_metrics.insert(QStringLiteral("tickUsP50"), p50);
    m_metrics.insert(QStringLiteral("tickUsP95"), p95);
    m_metrics.insert(QStringLiteral("tickUsMax"), maxUs);

    if (blocked)
        return PhaseResult::fail(
            QStringLiteral("tick_budget"),
            QStringLiteral("simulation à vide interrompue : un tick ne rendait "
                           "plus la main"));
    if (p95 / 1000.0 > m_budgets.maxTickMs)
        return PhaseResult::fail(
            QStringLiteral("tick_budget"),
            QStringLiteral("tick p95 %1 µs > budget %2 ms soutenu sur %3 ticks")
                .arg(p95, 0, 'f', 1)
                .arg(m_budgets.maxTickMs)
                .arg(ticks));
    return PhaseResult::pass();
}

// ============================================================================
// P4 — Stimulation (injection directe des callbacks, reco doc 12 §11)
// ============================================================================

PhaseResult BenchPhases::runP4Stimulation()
{
    if (!m_ctx)
        return PhaseResult::pass(); // pas d'artefact instancié (impossible ici)

    MeowEventsApi *events = m_ctx->eventsApi();
    MeowMemoryApi *memory = m_ctx->memoryApi();
    const QString targetUuid = memory->targetUuid();

    // --- 1. Un stimulus générique par hook RÉELLEMENT abonné en P2 (source
    // de vérité : l'enregistrement events.on, confirmé du listensTo P0).
    // L'acteur fantôme traverse la zone : deux injections (entrée puis
    // sortie/répétition) par type écouté. ---
    const QStringList types = events->registeredTypes();
    for (const QString &type : types) {
        for (int pass = 0; pass < 2; ++pass) {
            QVariantMap payload;
            payload.insert(QStringLiteral("playerId"),
                           QStringLiteral("ghost-%1")
                               .arg(m_rng.bounded(100000)));
            payload.insert(QStringLiteral("zoneUuid"), targetUuid);
            payload.insert(QStringLiteral("type"), type);
            payload.insert(QStringLiteral("phase"),
                           pass == 0 ? QStringLiteral("enter")
                                     : QStringLiteral("exit"));

            DeadlineWatchdog::arm(
                "P4", "event_budget",
                QStringLiteral("handler on(%1) ne rend pas la main").arg(type),
                MEOW_BENCH_HANDLER_HARD_CAP_MS, m_ctx->engine(),
                MEOW_BENCH_INTERRUPT_GRACE_MS);
            const QVector<MeowHandlerCall> calls =
                events->dispatch(type, payload);
            const bool interrupted = DeadlineWatchdog::disarm();
            recordHandlerCalls(calls);

            if (interrupted)
                return PhaseResult::fail(
                    QStringLiteral("event_budget"),
                    QStringLiteral("handler on(%1) interrompu après %2 ms "
                                   "(boucle dans le handler ?) — budget %3 ms")
                        .arg(type)
                        .arg(MEOW_BENCH_HANDLER_HARD_CAP_MS)
                        .arg(m_budgets.maxHandlerMs));
        }
    }

    // --- 2. Double écriture externe de chaque clé mémoire écoutée
    // (memory.onChanged) — doc 12 §3. ---
    const QStringList watched = memory->watchedKeys();
    for (const QString &canonical : watched) {
        const int slash = int(canonical.indexOf(QLatin1Char('/')));
        const QString uuid = canonical.left(slash);
        const QString key = canonical.mid(slash + 1);
        for (int pass = 0; pass < 2; ++pass) {
            DeadlineWatchdog::arm(
                "P4", "event_budget",
                QStringLiteral("watcher memory(%1) ne rend pas la main")
                    .arg(key),
                MEOW_BENCH_HANDLER_HARD_CAP_MS, m_ctx->engine(),
                MEOW_BENCH_INTERRUPT_GRACE_MS);
            const QVector<MeowHandlerCall> calls = memory->simulateExternalWrite(
                uuid, key, QVariant(int(m_rng.bounded(1000))));
            const bool interrupted = DeadlineWatchdog::disarm();
            recordHandlerCalls(calls);
            if (interrupted)
                return PhaseResult::fail(
                    QStringLiteral("event_budget"),
                    QStringLiteral("watcher memory(%1) interrompu après %2 ms")
                        .arg(key)
                        .arg(MEOW_BENCH_HANDLER_HARD_CAP_MS));
        }
    }

    // --- 3. Dix ticks post-stimuli (les effets différés se déclenchent). ---
    for (int i = 0; i < 10; ++i)
        runOneTick();

    // --- Verdicts P4 ---
    // Métriques handlers (p95 par hook).
    QJsonObject handlerUsP95;
    double worstP95Ms = 0.0;
    QString worstName;
    for (auto it = m_handlerNs.constBegin(); it != m_handlerNs.constEnd();
         ++it) {
        const double p95 = percentileUs(it.value(), 0.95);
        handlerUsP95.insert(it.key(), p95);
        if (p95 / 1000.0 > worstP95Ms) {
            worstP95Ms = p95 / 1000.0;
            worstName = it.key();
        }
    }
    m_metrics.insert(QStringLiteral("handlerUsP95"), handlerUsP95);
    m_metrics.insert(QStringLiteral("emitCount"), events->totalEmits());
    // emitRate = pire fenêtre glissante d'1 s (émissions/s). Le taux moyen
    // sur temps réel serait trompeur : le banc accélère les ticks (10 s
    // simulées en quelques ms réelles).
    m_metrics.insert(QStringLiteral("emitRate"), events->maxEmitsPerWindow());
    m_metrics.insert(QStringLiteral("writeSet"),
                     QJsonArray::fromStringList(memory->observedWriteSet()));
    if (!m_handlerErrors.isEmpty())
        m_metrics.insert(QStringLiteral("handlerErrors"),
                         QJsonArray::fromStringList(m_handlerErrors));
    m_metrics.insert(QStringLiteral("objectCount"), liveObjectCount());

    if (worstP95Ms > m_budgets.maxHandlerMs)
        return PhaseResult::fail(
            QStringLiteral("event_budget"),
            QStringLiteral("handler %1 : p95 %2 ms > budget %3 ms")
                .arg(worstName)
                .arg(worstP95Ms, 0, 'f', 2)
                .arg(m_budgets.maxHandlerMs));

    if (events->floodDetected())
        return PhaseResult::fail(
            QStringLiteral("event_flood"),
            QStringLiteral("%1 émissions dans une fenêtre d'1 s > plafond "
                           "%2/s (D34)")
                .arg(events->maxEmitsPerWindow())
                .arg(m_budgets.maxEmitPerS));

    const QStringList quota = memory->quotaViolations();
    if (!quota.isEmpty())
        return PhaseResult::fail(
            QStringLiteral("memory_quota"),
            QStringLiteral("écriture(s) mémoire hors quota : %1")
                .arg(quota.join(QStringLiteral(" | "))));

    // Write-set observé vs déclaré (D11). Entrées déclarées acceptées sous
    // deux formes : "state/clé" (implicitement la tuile porteuse) ou
    // "<uuid>/state/clé" (explicite).
    QStringList declared;
    const QJsonArray declaredArray =
        m_job.artifact.value(QStringLiteral("declaredWriteSet")).toArray();
    for (const QJsonValue &v : declaredArray)
        declared.append(v.toString());
    QStringList violations;
    const QStringList observed = memory->observedWriteSet();
    for (const QString &entry : observed) {
        if (declared.contains(entry))
            continue;
        const QString prefix = targetUuid + QLatin1Char('/');
        if (entry.startsWith(prefix) && declared.contains(entry.mid(prefix.size())))
            continue;
        violations.append(entry);
    }
    if (!violations.isEmpty())
        return PhaseResult::fail(
            QStringLiteral("writeset_violation"),
            QStringLiteral("écriture(s) hors write-set déclaré (D11) : %1 — "
                           "déclaré : [%2]")
                .arg(violations.join(QStringLiteral(", ")),
                     declared.join(QStringLiteral(", "))));

    const int objects = liveObjectCount();
    if (objects > m_budgets.maxObjects)
        return PhaseResult::fail(
            QStringLiteral("object_quota"),
            QStringLiteral("%1 objets QML après stimulation > plafond %2")
                .arg(objects)
                .arg(m_budgets.maxObjects));

    return PhaseResult::pass();
}

// ============================================================================
// P5 — Teardown
// ============================================================================

PhaseResult BenchPhases::runP5Teardown()
{
    QStringList leaks;

    if (m_root) {
        // --- Timers encore actifs AU teardown (fuite type doc 12 §8) ---
        // Le Timer QML est un QQmlTimer (pas un QTimer) : détection par nom
        // de classe + heuristique de propriétés (interval/running/repeat).
        QList<QObject *> all;
        all.append(m_root);
        all.append(m_root->findChildren<QObject *>(Qt::FindChildrenRecursively));
        for (QObject *obj : std::as_const(all)) {
            const QString className =
                QString::fromLatin1(obj->metaObject()->className());
            const bool looksLikeTimer =
                className.contains(QLatin1String("Timer"))
                || (obj->property("interval").isValid()
                    && obj->property("repeat").isValid()
                    && obj->property("triggeredOnStart").isValid());
            if (looksLikeTimer && obj->property("running").toBool())
                leaks.append(QStringLiteral("timer actif au teardown (%1, "
                                            "interval %2 ms, objectName '%3')")
                                 .arg(className)
                                 .arg(obj->property("interval").toInt())
                                 .arg(obj->objectName()));
        }

        // --- Objets survivants après destruction ---
        QVector<QPointer<QObject>> tracked;
        tracked.reserve(all.size());
        for (QObject *obj : std::as_const(all))
            tracked.append(QPointer<QObject>(obj));

        delete m_root;
        m_root = nullptr;
        for (int i = 0; i < 3; ++i) {
            QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
            QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
        }

        int survivors = 0;
        for (const QPointer<QObject> &p : std::as_const(tracked)) {
            if (!p.isNull())
                ++survivors;
        }
        if (survivors > 0)
            leaks.append(QStringLiteral("%1 objet(s) QML survivant(s) à la "
                                        "destruction de l'artefact")
                             .arg(survivors));
        m_metrics.insert(QStringLiteral("teardownSurvivors"), survivors);
    }

    // Libération du reste de l'environnement (composant, contexte restreint
    // avec son moteur dédié, carte) — hors périmètre du verdict leak :
    // c'est l'infrastructure du banc, pas l'artefact.
    delete m_component;
    m_component = nullptr;
    delete m_ctx;
    m_ctx = nullptr;
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QCoreApplication::processEvents(QEventLoop::AllEvents, 5);
    delete m_map;
    m_map = nullptr;

    if (!leaks.isEmpty())
        return PhaseResult::fail(
            QStringLiteral("leak"),
            QStringLiteral("fuite(s) au teardown : %1")
                .arg(leaks.join(QStringLiteral(" | "))));
    return PhaseResult::pass();
}
