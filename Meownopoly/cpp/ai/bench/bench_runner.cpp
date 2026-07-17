// ============================================================================
// bench_runner — implémentation du pipeline P1→P5 (tâche A5, doc v3 12 §3)
// ============================================================================
// NOTE : meow_game_api.h #undef `emit` (D34 impose `events.emit`) — utiliser
// Q_EMIT dans ce fichier si des signaux Qt apparaissent.
// ============================================================================

#include "bench_runner.h"

#include "ai/sandbox/restricted_context.h"
#include "ai/sandbox/meow_game_api.h"

#include "game/map/map.h"
#include "game/physics/pattounx_engine_v2.h"

#include <QQmlEngine>
#include <QQmlComponent>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QPointer>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QScopedPointer>
#include <QHash>
#include <QVector>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <utility>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <random>
#include <thread>

#ifdef _WIN32
// PSAPI_VERSION 2 : GetProcessMemoryInfo est servi par kernel32
// (K32GetProcessMemoryInfo) — aucune dépendance de link supplémentaire.
#define PSAPI_VERSION 2
#include <windows.h>
#include <psapi.h>
#else
#include <unistd.h>
#endif

namespace meow::bench {

namespace {

// ─── RSS courant du process (doc 12 §5 : auto-surveillance) ─────────────────
qint64 currentRssBytes()
{
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc)))
        return static_cast<qint64>(pmc.WorkingSetSize);
    return 0;
#else
    // /proc/self/statm : "size resident ..." en pages (M13 Linux).
    std::FILE *f = std::fopen("/proc/self/statm", "r");
    if (!f)
        return 0;
    long size = 0, resident = 0;
    const int n = std::fscanf(f, "%ld %ld", &size, &resident);
    std::fclose(f);
    if (n < 2)
        return 0;
    return static_cast<qint64>(resident) * sysconf(_SC_PAGESIZE);
#endif
}

// ─── Watchdog : thread de surveillance RSS + hang de phase ──────────────────
// In-process, une boucle JS (create P2, handler P4) ne rend jamais la main au
// thread principal : seul un thread séparé peut flusher un verdict et
// terminer le process (le superviseur A3 reste le filet ultime à 30 s).
class BenchWatchdog
{
public:
    BenchWatchdog(const QString &jobId, int maxRssMB, const QElapsedTimer *wall)
        : m_jobId(jobId), m_maxRssBytes(qint64(maxRssMB) * 1024 * 1024), m_wall(wall)
    {
        m_thread = std::thread([this] { threadMain(); });
    }

    ~BenchWatchdog()
    {
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_quit = true;
        }
        m_cv.notify_all();
        if (m_thread.joinable())
            m_thread.join();
    }

    // Arme un garde-fou de phase : si `disarm()` n'est pas appelé dans les
    // `timeoutMs`, le watchdog flushe un verdict `code` et _exit(0).
    void arm(const char *code, const char *phase, int timeoutMs, const QString &details)
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_armed = true;
        m_code = code;
        m_phase = phase;
        m_details = details;
        m_deadline = std::chrono::steady_clock::now()
                     + std::chrono::milliseconds(timeoutMs);
    }

    void disarm()
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_armed = false;
    }

    qint64 peakRssBytes() const { return m_peakRss.load(); }

private:
    void threadMain()
    {
        std::unique_lock<std::mutex> lock(m_mutex);
        while (!m_quit) {
            // Poll 100 ms (doc 12 §5).
            m_cv.wait_for(lock, std::chrono::milliseconds(100));
            if (m_quit)
                return;

            const qint64 rss = currentRssBytes();
            qint64 prev = m_peakRss.load();
            while (rss > prev && !m_peakRss.compare_exchange_weak(prev, rss)) {}

            if (rss > m_maxRssBytes) {
                fireAndExit(failure::kRunawayAlloc, m_armed ? m_phase : QString(),
                            QStringLiteral("RSS du banc %1 Mo > plafond %2 Mo — artefact tué (auto-surveillance)")
                                .arg(rss / (1024 * 1024))
                                .arg(m_maxRssBytes / (1024 * 1024)));
            }
            if (m_armed && std::chrono::steady_clock::now() > m_deadline)
                fireAndExit(m_code, m_phase, m_details);
        }
    }

    [[noreturn]] void fireAndExit(const QString &code, const QString &phase,
                                  const QString &details)
    {
        BenchFailure f;
        f.code = code;
        f.phase = phase;
        f.details = details;
        f.retryable = false;
        BenchVerdict v = BenchVerdict::fail(m_jobId, f);
        if (m_wall)
            v.durationMs = m_wall->elapsed();
        const QByteArray line = formatVerdictLine(v.toJson());
        std::fwrite(line.constData(), 1, size_t(line.size()), stdout);
        std::fputc('\n', stdout);
        std::fflush(stdout);
        // Pas de teardown Qt : le process est jetable, le verdict est rendu
        // (exit 0 = « verdict rendu quel qu'il soit », doc 12 §2.2).
        std::_Exit(0);
    }

    QString m_jobId;
    qint64 m_maxRssBytes;
    const QElapsedTimer *m_wall;

    std::thread m_thread;
    std::mutex m_mutex;
    std::condition_variable m_cv;
    bool m_quit = false;

    bool m_armed = false;
    QString m_code;
    QString m_phase;
    QString m_details;
    std::chrono::steady_clock::time_point m_deadline;

    std::atomic<qint64> m_peakRss { 0 };
};

// ─── Budgets effectifs (job.budgets ▷ défauts D34 §9) ──────────────────────
struct Budgets {
    int loadTimeoutMs       = MEOW_BENCH_LOAD_TIMEOUT_MS;
    int idleTicks           = MEOW_BENCH_IDLE_TICKS;
    int tickBudgetUs        = MEOW_BENCH_TICK_BUDGET_US;
    int handlerBudgetUs     = MEOW_BENCH_HANDLER_BUDGET_US;
    int emitMaxPerSec       = MEOW_BENCH_EMIT_MAX_PER_SEC;
    int objectMaxCount      = MEOW_BENCH_OBJECT_MAX;
    int artifactMemMaxMB    = MEOW_BENCH_ARTIFACT_MEM_MB;
    int memoryValueMaxBytes = MEOW_BENCH_MEMORY_VALUE_MAX_BYTES;
    int maxRssMB            = MEOW_BENCH_MAX_RSS_MB;

    static Budgets fromJson(const QJsonObject &o)
    {
        Budgets b;
        auto read = [&o](const char *key, int fallback) {
            const int v = o.value(QLatin1String(key)).toInt(0);
            return v > 0 ? v : fallback;
        };
        b.loadTimeoutMs       = read("loadTimeoutMs", b.loadTimeoutMs);
        b.idleTicks           = read("idleTicks", b.idleTicks);
        b.tickBudgetUs        = read("tickBudgetUs", b.tickBudgetUs);
        b.handlerBudgetUs     = read("handlerBudgetUs", b.handlerBudgetUs);
        b.emitMaxPerSec       = read("emitMaxPerSec", b.emitMaxPerSec);
        b.objectMaxCount      = read("objectMaxCount", b.objectMaxCount);
        b.artifactMemMaxMB    = read("artifactMemMaxMB", b.artifactMemMaxMB);
        b.memoryValueMaxBytes = read("memoryValueMaxBytes", b.memoryValueMaxBytes);
        b.maxRssMB            = read("maxRssMB", b.maxRssMB);
        return b;
    }
};

// ─── Helpers de mesure ──────────────────────────────────────────────────────
qint64 percentile(QVector<qint64> sorted, double p)
{
    if (sorted.isEmpty())
        return 0;
    std::sort(sorted.begin(), sorted.end());
    const int idx = qBound(0, int(std::ceil(p * sorted.size())) - 1,
                           int(sorted.size()) - 1);
    return sorted.at(idx);
}

int countObjects(QObject *root)
{
    return root ? 1 + root->findChildren<QObject *>().size() : 0;
}

// Un tick de banc accéléré : physique + event loop (Timers QML) + handlers
// `tick` de l'artefact. Retourne la durée en µs.
qint64 benchTick(pattounx::PattounX_engine &phys, meow::sandbox::MeowGameApi *api,
                 quint64 tickIndex)
{
    QElapsedTimer t;
    t.start();
    phys.step(1.0 / 60.0);
    if (api)
        api->dispatchEvent(QStringLiteral("tick"),
                           QVariantMap { { QStringLiteral("tick"),
                                           double(tickIndex) } });
    QCoreApplication::processEvents();
    return t.nsecsElapsed() / 1000;
}

} // namespace

// ─── Pipeline ───────────────────────────────────────────────────────────────
BenchVerdict runBenchJob(QQmlEngine &engine, const BenchJob &job)
{
    namespace ms = meow::sandbox;

    QElapsedTimer wall;
    wall.start();

    const Budgets budgets = Budgets::fromJson(job.budgets);

    BenchVerdict verdict;
    verdict.jobId = job.jobId;
    QJsonObject metrics;

    BenchWatchdog dog(job.jobId, budgets.maxRssMB, &wall);

    auto failNow = [&verdict, &metrics](const char *code, const char *phase,
                                        const QString &details,
                                        bool retryable = false) {
        BenchFailure f;
        f.code = QLatin1String(code);
        f.phase = QLatin1String(phase);
        f.details = details;
        f.retryable = retryable;
        verdict.failures.append(f);
        verdict.metrics = metrics;
        verdict.pass = false;
        return verdict;
    };

    // Aléa seedé (doc 12 §2.3 : un job rejoué produit le même verdict).
    std::mt19937 rng(quint32(job.seed));

    // ════ P1 — Reconstruction ═══════════════════════════════════════════════
    // Carte : même chemin que le full-sync collab (Map + ItemSnapableFactory,
    // doc 12 §10) — pas de singleton Game (non lié au banc, cf. A1).
    QScopedPointer<Map> map;
    const QJsonObject mapObj = job.snapshot.value(QStringLiteral("map")).toObject();
    if (mapObj.isEmpty()) {
        map.reset(new Map()); // job sans carte : artefact testé sur map vide
    } else {
        if (!mapObj.contains(QStringLiteral("snapableTiles"))
            || !mapObj.value(QStringLiteral("snapableTiles")).isArray()) {
            return failNow(failure::kSnapshotInvalid, "P1",
                           QStringLiteral("snapshot.map sans tableau 'snapableTiles' — snapshot corrompu (bug interne, pas la faute de l'artefact)"));
        }
        map.reset(Map::loadMap(mapObj));
        if (!map)
            return failNow(failure::kSnapshotInvalid, "P1",
                           QStringLiteral("Map::loadMap a échoué sur snapshot.map"));
    }
    metrics.insert(QStringLiteral("tileCount"), map->tiles().size());

    // Moteur physique : cœur Qt-free tické en direct (pas de worker thread ni
    // PhysicsSession). Les événements de zone de P4 sont injectés directement
    // (reco doc 12 §11) — la physique ne sert qu'au réalisme du coût de tick.
    pattounx::PattounX_engine phys;

    // Warm-up : charge les plugins QML de l'allow-list D34 AVANT la baseline
    // mémoire/CPU — sinon le premier artefact paierait le chargement de
    // QtQuick/Controls (dizaines de Mo) sur SON budget de 8 Mo (faux positif
    // `runaway_alloc`, bloquant critère R1 n°5).
    {
        QQmlComponent warmup(&engine);
        warmup.setData(QByteArrayLiteral(
                           "import QtQuick\n"
                           "import QtQuick.Shapes\n"
                           "import QtQuick.Layouts\n"
                           "import QtQuick.Controls\n"
                           "Item {}"),
                       // Scheme qrc: obligatoire — un scheme inconnu (meow://)
                       // fait passer QQmlComponent en compilation ASYNCHRONE
                       // (status Loading, « Component is not ready » au create).
                       QUrl(QStringLiteral("qrc:/meow/bench/warmup.qml")));
        QScopedPointer<QObject> obj(warmup.create());
        if (!obj) {
            // Environnement du banc cassé (plugins QML introuvables) : bug
            // interne, pas la faute de l'artefact.
            QStringList errs;
            const auto errors = warmup.errors();
            for (const auto &e : errors)
                errs << e.toString();
            return failNow(failure::kSnapshotInvalid, "P1",
                           QStringLiteral("warm-up QML impossible (plugins QtQuick absents ?) : %1")
                               .arg(errs.join(QStringLiteral(" | "))),
                           /*retryable=*/true);
        }
        QCoreApplication::processEvents();
    }

    // Baseline CPU : coût d'un tick à vide SANS artefact — soustrait des
    // mesures P3 pour que la carte du snapshot n'émarge pas au budget de
    // l'artefact.
    QVector<qint64> baselineSamples;
    baselineSamples.reserve(MEOW_BENCH_BASELINE_TICKS);
    for (int i = 0; i < MEOW_BENCH_BASELINE_TICKS; ++i)
        baselineSamples.append(benchTick(phys, nullptr, quint64(i)));
    const qint64 baselineP50 = percentile(baselineSamples, 0.50);

    // Baseline mémoire : le delta artefact se mesure à partir d'ici.
    const qint64 rssBaseline = currentRssBytes();

    // ════ P2 — Instanciation dans le contexte restreint ═════════════════════
    const QString source = job.artifact.value(QStringLiteral("source")).toString();
    if (source.isEmpty())
        return failNow(failure::kLoadFailed, "P2",
                       QStringLiteral("artifact.source vide — rien à instancier"));

    const QString targetUuid =
        job.artifact.value(QStringLiteral("targetUuid")).toString();
    const QString contentHash =
        job.artifact.value(QStringLiteral("contentHash")).toString();

    // Une façade PAR artefact (quotas et write-set individuels). Détruite en
    // fin de run, APRÈS l'artefact (P5).
    QScopedPointer<ms::MeowGameApi> api(new ms::MeowGameApi());
    api->configure(targetUuid,
                   job.snapshot.value(QStringLiteral("memory")).toObject(),
                   QJsonObject(), budgets.memoryValueMaxBytes);

    ms::RestrictedContext::registerQmlModule();
    ms::RestrictedContext restricted(&engine, api.data());

    QObject holder; // parent C++ des artefacts — teardown déterministe

    // Capture des erreurs JS runtime pendant la fenêtre de chargement : un
    // TypeError/ReferenceError au Component.onCompleted (ex. tentative
    // d'accès à un singleton masqué, corpus `acces_singleton.qml`) ne fait
    // pas échouer QQmlComponent::create — il remonte par le canal warnings.
    QStringList loadRuntimeErrors;
    const QMetaObject::Connection warnConn = QObject::connect(
        &engine, &QQmlEngine::warnings, &holder,
        [&loadRuntimeErrors](const QList<QQmlError> &warnings) {
            for (const QQmlError &e : warnings)
                loadRuntimeErrors.append(e.toString());
        });

    dog.arm(failure::kLoadTimeout, "P2", budgets.loadTimeoutMs,
            QStringLiteral("chargement > %1 ms : boucle au chargement (Component.onCompleted ?) — process tué, le jeu n'a jamais gelé")
                .arg(budgets.loadTimeoutMs));
    const auto inst = restricted.instantiate(
        source,
        // qrc: pour rester en compilation synchrone (cf. warm-up ci-dessus).
        QUrl(QStringLiteral("qrc:/meow/artifact/%1.qml")
                 .arg(contentHash.isEmpty() ? job.jobId : contentHash)),
        &holder);
    dog.disarm();

    metrics.insert(QStringLiteral("loadMs"), double(inst.elapsedMs));
    if (!inst.ok()) {
        return failNow(failure::kLoadFailed, "P2",
                       QStringLiteral("erreur QML au chargement : %1")
                           .arg(inst.errors.join(QStringLiteral(" | "))),
                       /*retryable=*/true);
    }
    QCoreApplication::processEvents(); // Component.onCompleted différés
    QObject::disconnect(warnConn);

    if (!loadRuntimeErrors.isEmpty()) {
        // Erreur de référence/type au chargement — c'est aussi la preuve du
        // masquage (critère R1 n°4 : `Game.` ⇒ TypeError, jamais l'objet réel).
        return failNow(failure::kLoadFailed, "P2",
                       QStringLiteral("erreur JS au chargement : %1")
                           .arg(loadRuntimeErrors.join(QStringLiteral(" | "))),
                       /*retryable=*/true);
    }

    // Chargement trop lent mais fini : hors budget quand même (D34 ≤ 5 s).
    if (inst.elapsedMs > budgets.loadTimeoutMs)
        failNow(failure::kLoadTimeout, "P2",
                QStringLiteral("chargement %1 ms > budget %2 ms")
                    .arg(inst.elapsedMs)
                    .arg(budgets.loadTimeoutMs));

    // Les handlers du chargement (Component.onCompleted → events.on) ne sont
    // pas des mesures : purge avant P3.
    api->takeHandlerRuns();

    // ════ P3 — Simulation à vide (ticks accélérés, le banc ne dort pas) ═════
    const qint64 emitWindowStartNs = wall.nsecsElapsed();
    int maxObjectCount = countObjects(inst.object);

    dog.arm(failure::kTickBudget, "P3",
            qMax(MEOW_BENCH_P3_HARD_TIMEOUT_MS, budgets.idleTicks * 100),
            QStringLiteral("P3 suspendue > garde-fou : tick pathologique (boucle dans un Timer/handler tick ?)"));
    QVector<qint64> tickSamples;
    tickSamples.reserve(budgets.idleTicks);
    for (int i = 0; i < budgets.idleTicks; ++i) {
        tickSamples.append(benchTick(phys, api.data(), quint64(i)));
        if ((i & 63) == 0)
            maxObjectCount = qMax(maxObjectCount, countObjects(inst.object));
    }
    dog.disarm();
    api->takeHandlerRuns(); // comptés dans le coût de tick, pas en event_budget

    // Mesures par tick, baseline soustraite (part de l'artefact).
    QVector<qint64> adjusted;
    adjusted.reserve(tickSamples.size());
    for (qint64 s : std::as_const(tickSamples))
        adjusted.append(qMax<qint64>(0, s - baselineP50));
    const qint64 tickP50 = percentile(adjusted, 0.50);
    const qint64 tickP95 = percentile(adjusted, 0.95);
    const qint64 tickMax = *std::max_element(adjusted.cbegin(), adjusted.cend());
    metrics.insert(QStringLiteral("tickUsP50"), double(tickP50));
    metrics.insert(QStringLiteral("tickUsP95"), double(tickP95));
    metrics.insert(QStringLiteral("tickUsMax"), double(tickMax));

    if (tickP95 > budgets.tickBudgetUs)
        failNow(failure::kTickBudget, "P3",
                QStringLiteral("coût par tick soutenu : p95 %1 µs > budget %2 µs")
                    .arg(tickP95)
                    .arg(budgets.tickBudgetUs));

    // ════ P4 — Stimulation ══════════════════════════════════════════════════
    // 1) Stimuli explicites du job (générés côté jeu selon les hooks écoutés).
    // 2) Scénarios génériques MVP dérivés des abonnements réellement observés
    //    en P2/P3 (doc 12 §3 : ghost actor, clé mémoire changée deux fois,
    //    10 ticks) — le banc reste utile même si le jeu n'a rien généré.
    quint64 tickIndex = quint64(budgets.idleTicks);
    auto runTicks = [&](int count) {
        for (int i = 0; i < count; ++i)
            benchTick(phys, api.data(), tickIndex++);
    };
    auto dispatchGuarded = [&](const QString &name, const QVariant &payload) {
        dog.arm(failure::kEventBudget, "P4", MEOW_BENCH_P4_HANG_TIMEOUT_MS,
                QStringLiteral("handler de « %1 » ne rend pas la main (> %2 ms) : boucle dans un handler — process tué")
                    .arg(name)
                    .arg(int(MEOW_BENCH_P4_HANG_TIMEOUT_MS)));
        api->dispatchEvent(name, payload);
        dog.disarm();
    };
    auto touchGuarded = [&](const QString &key, const QVariant &value) {
        dog.arm(failure::kEventBudget, "P4", MEOW_BENCH_P4_HANG_TIMEOUT_MS,
                QStringLiteral("watcher mémoire de « %1 » ne rend pas la main — process tué")
                    .arg(key));
        api->touchMemory(key, value);
        dog.disarm();
    };

    const QJsonArray stimuli = job.stimuli;
    for (const QJsonValue &sv : stimuli) {
        const QJsonObject s = sv.toObject();
        const QString type = s.value(QStringLiteral("type")).toString();
        const int count = qMax(1, s.value(QStringLiteral("count")).toInt(1));
        if (type == QLatin1String("event")) {
            const QString name = s.value(QStringLiteral("name")).toString();
            const QVariant payload = s.value(QStringLiteral("payload")).toVariant();
            for (int i = 0; i < count; ++i)
                dispatchGuarded(name, payload);
        } else if (type == QLatin1String("memory")) {
            const QString key = s.value(QStringLiteral("key")).toString();
            const QVariant value = s.value(QStringLiteral("value")).toVariant();
            for (int i = 0; i < count; ++i)
                touchGuarded(key, value.isValid() ? value
                                                  : QVariant(int(rng() % 1000)));
        } else if (type == QLatin1String("ticks")) {
            runTicks(count);
        } // type inconnu : ignoré (tolérance MVP — le vocabulaire vit côté jeu)
    }

    // Scénarios génériques : un acteur fantôme par événement écouté…
    const QStringList eventNames = api->registeredEventNames();
    for (const QString &name : eventNames) {
        if (name == QLatin1String("tick"))
            continue; // déjà couvert par P3
        for (int i = 0; i < 2; ++i) {
            dispatchGuarded(name,
                            QVariantMap {
                                { QStringLiteral("ghost"), true },
                                { QStringLiteral("actorId"),
                                  QStringLiteral("bench_ghost") },
                                { QStringLiteral("n"), i },
                            });
        }
        runTicks(2);
    }
    // …et chaque clé mémoire écoutée change deux fois.
    const QStringList watchedKeys = api->watchedMemoryKeys();
    for (const QString &key : watchedKeys) {
        touchGuarded(key, int(rng() % 1000));
        runTicks(1);
        touchGuarded(key, int(rng() % 1000));
    }
    runTicks(10);

    // Fenêtre d'observation TEMPS RÉEL (event_flood) : les ticks P3/P4 sont
    // accélérés (le banc ne dort pas) — un `Timer { interval: 1 }` n'y tire
    // presque pas. On laisse l'event loop tourner en temps réel pour mesurer
    // le débit soutenu réel (corpus `timer_spam.qml`).
    const int floodEmitsBefore = api->emitCount();
    QElapsedTimer floodWindow;
    floodWindow.start();
    dog.arm(failure::kEventBudget, "P4",
            MEOW_BENCH_P4_HANG_TIMEOUT_MS + MEOW_BENCH_FLOOD_WINDOW_MS,
            QStringLiteral("fenêtre d'observation temps réel suspendue — handler pathologique"));
    while (floodWindow.elapsed() < MEOW_BENCH_FLOOD_WINDOW_MS)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
    dog.disarm();
    const double floodSec = qMax(0.05, double(floodWindow.elapsed()) / 1000.0);
    const int floodEmits = api->emitCount() - floodEmitsBefore;
    const double floodRate = double(floodEmits) / floodSec;
    if (floodRate > budgets.emitMaxPerSec
        && floodEmits >= qMax(1, budgets.emitMaxPerSec / 2))
        failNow(failure::kEventFlood, "P4",
                QStringLiteral("%1 émissions en %2 s de temps réel (%3/s) > plafond %4/s")
                    .arg(floodEmits)
                    .arg(floodSec, 0, 'f', 2)
                    .arg(floodRate, 0, 'f', 1)
                    .arg(budgets.emitMaxPerSec));

    // ── Budgets P4 ──
    // CPU par handler (p50/p95/max par handler, doc 12 §3).
    QHash<QString, QVector<qint64>> byHandler;
    const auto runs = api->takeHandlerRuns();
    for (const auto &r : runs)
        byHandler[r.handlerId].append(r.elapsedUs);
    QJsonObject handlerP95;
    for (auto it = byHandler.cbegin(); it != byHandler.cend(); ++it) {
        const qint64 p95 = percentile(it.value(), 0.95);
        handlerP95.insert(it.key(), double(p95));
        if (p95 > budgets.handlerBudgetUs)
            failNow(failure::kEventBudget, "P4",
                    QStringLiteral("handler %1 : p95 %2 µs > budget %3 µs")
                        .arg(it.key())
                        .arg(p95)
                        .arg(budgets.handlerBudgetUs));
    }
    metrics.insert(QStringLiteral("handlerUsP95"), handlerP95);

    // Débit d'émissions (event_flood). Soutenu : on exige à la fois un volume
    // minimal ET un débit hors budget — deux emits dans une fenêtre courte ne
    // sont pas un flood (critère R1 n°5 : pas de faux positif sur le sain).
    const double emitWindowSec =
        qMax(0.05, double(wall.nsecsElapsed() - emitWindowStartNs) / 1e9);
    const double emitRate = double(api->emitCount()) / emitWindowSec;
    metrics.insert(QStringLiteral("emitRate"),
                   double(qRound(emitRate * 10.0)) / 10.0);
    if (api->emitCount() > budgets.emitMaxPerSec && emitRate > budgets.emitMaxPerSec)
        failNow(failure::kEventFlood, "P4",
                QStringLiteral("%1 émissions en %2 s (%3/s) > plafond %4/s")
                    .arg(api->emitCount())
                    .arg(emitWindowSec, 0, 'f', 2)
                    .arg(emitRate, 0, 'f', 1)
                    .arg(budgets.emitMaxPerSec));

    // Quotas mémoire détectés par la façade (D15/D35).
    const auto violations = api->violations();
    for (const auto &viol : violations)
        failNow(failure::kMemoryQuota, "P4", viol.details);

    // Write-set observé vs déclaré (D11). Champ `writeSet` de l'artefact
    // (doc 13) ; absent ⇒ pas de déclaration à confronter (check sauté).
    const QStringList observed = api->observedWriteSet();
    metrics.insert(QStringLiteral("writeSet"),
                   QJsonArray::fromStringList(observed));
    if (job.artifact.contains(QStringLiteral("writeSet"))) {
        QStringList declared;
        const QJsonArray declaredArr =
            job.artifact.value(QStringLiteral("writeSet")).toArray();
        for (const QJsonValue &v : declaredArr)
            declared << v.toString();
        for (const QString &key : observed) {
            if (!declared.contains(key))
                failNow(failure::kWritesetViolation, "P4",
                        QStringLiteral("écriture observée hors write-set déclaré : %1")
                            .arg(key),
                        /*retryable=*/true);
        }
    }

    // Nombre d'objets instanciés (≤ 200, D34).
    maxObjectCount = qMax(maxObjectCount, countObjects(inst.object));
    metrics.insert(QStringLiteral("objectCount"), maxObjectCount);
    if (maxObjectCount > budgets.objectMaxCount)
        failNow(failure::kObjectQuota, "P4",
                QStringLiteral("%1 objets QML instanciés > plafond %2")
                    .arg(maxObjectCount)
                    .arg(budgets.objectMaxCount));

    // Pic mémoire attribuable à l'artefact (delta RSS depuis la baseline P1).
    const qint64 peakDelta =
        qMax<qint64>(0, qMax(dog.peakRssBytes(), currentRssBytes()) - rssBaseline);
    const double peakMemMB = double(peakDelta) / (1024.0 * 1024.0);
    metrics.insert(QStringLiteral("peakMemMB"),
                   double(qRound(peakMemMB * 10.0)) / 10.0);
    if (peakMemMB > double(budgets.artifactMemMaxMB))
        failNow(failure::kRunawayAlloc, "P4",
                QStringLiteral("pic mémoire %1 Mo > budget %2 Mo (delta RSS depuis P1)")
                    .arg(peakMemMB, 0, 'f', 1)
                    .arg(budgets.artifactMemMaxMB));

    // ════ P5 — Teardown ═════════════════════════════════════════════════════
    QPointer<QObject> guard(inst.object);
    const qint64 activityBefore = api->activityCounter();

    inst.object->deleteLater();
    QCoreApplication::processEvents();
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QCoreApplication::processEvents();

    // Fenêtre d'observation : un Timer/handler survivant se manifeste par de
    // l'activité façade après destruction (émission, écriture, callback).
    dog.arm(failure::kLeak, "P5", MEOW_BENCH_P3_HARD_TIMEOUT_MS,
            QStringLiteral("teardown suspendu — objet survivant pathologique"));
    for (int i = 0; i < MEOW_BENCH_POST_TEARDOWN_TICKS; ++i)
        benchTick(phys, nullptr, tickIndex++);
    dog.disarm();

    if (guard)
        failNow(failure::kLeak, "P5",
                QStringLiteral("objet racine de l'artefact encore vivant après destruction"));
    const qint64 residualActivity = api->activityCounter() - activityBefore;
    const auto residualRuns = api->takeHandlerRuns();
    if (residualActivity > 0 || !residualRuns.isEmpty())
        failNow(failure::kLeak, "P5",
                QStringLiteral("%1 appel(s) à la façade après teardown : objets/timers/connexions survivants")
                    .arg(qMax<qint64>(residualActivity, residualRuns.size())));

    // ════ Verdict ═══════════════════════════════════════════════════════════
    verdict.metrics = metrics;
    verdict.pass = verdict.failures.isEmpty();
    return verdict;
}

} // namespace meow::bench
