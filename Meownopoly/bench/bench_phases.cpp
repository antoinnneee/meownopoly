#include "bench_phases.h"

#include "ai/bench/bench_constants.h"

#include "game/map/map.h"

#include <QElapsedTimer>
#include <QJsonArray>

namespace {

// Ticks de "démarrage à vide" du moteur physique en P1 — juste assez pour
// prouver que le moteur tourne dans le process du banc. Les
// MEOW_BENCH_IDLE_TICKS de la vraie simulation à vide appartiennent à P3 (A5).
constexpr int kP1WarmupTicks = 10;
constexpr qreal kTickDt = 1.0 / 60.0;

} // namespace

BenchPhases::BenchPhases(const BenchJob &job)
    : m_job(job)
    , m_rng(job.seed)
{
}

BenchPhases::~BenchPhases()
{
    delete m_map;
    m_map = nullptr;
}

PhaseResult BenchPhases::runP1Reconstruction()
{
    QElapsedTimer timer;
    timer.start();

    // --- Validation structurelle du snapshot map ---
    // Format = sérialisation de sauvegarde existante : { mapInfo: {...},
    // snapableTiles: [...] } (même chemin que le full-sync collab).
    const QJsonObject &mapJson = m_job.snapshotMap;
    if (!mapJson.value(QStringLiteral("mapInfo")).isObject())
        return PhaseResult::fail(
            QStringLiteral("snapshot_invalid"),
            QStringLiteral("snapshot.map sans objet 'mapInfo'"));
    if (!mapJson.value(QStringLiteral("snapableTiles")).isArray())
        return PhaseResult::fail(
            QStringLiteral("snapshot_invalid"),
            QStringLiteral("snapshot.map sans tableau 'snapableTiles'"));

    // --- Reconstruction ---
    // Map::loadMap(QJsonObject) reconstruit MapInfo + toutes les tuiles via
    // le constructeur ItemSnapable(QJsonObject) — le même chemin que
    // ItemSnapableFactory::createItemSnapableFromJson (la factory est un
    // wrapper de ce constructeur), avec en plus le recâblage des liens
    // next/prev et l'ownership C++ (parent = Map, libérée en P5).
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

    // --- Démarrage du moteur physique à vide (doc 12 §10 : le banc tick en
    // direct, sans PhysicsWorker ni PhysicsSession) ---
    for (int i = 0; i < kP1WarmupTicks; ++i)
        m_engine.step(kTickDt);
    m_engine.takeEvents(); // draine les événements accumulés (aucun attendu)

    m_metrics.insert(QStringLiteral("loadMs"), double(timer.elapsed()));
    m_metrics.insert(QStringLiteral("tileCount"), loadedTiles);
    return PhaseResult::pass();
}

PhaseResult BenchPhases::runP2Instantiation()
{
    // STUB (A5/A6) : l'instanciation de l'artefact exige le contexte
    // restreint partagé (cpp/ai/sandbox/, chantier M9) — non câblé au
    // squelette. L'artefact a été validé présent au parsing du job.
    return PhaseResult::pass();
}

PhaseResult BenchPhases::runP3IdleSimulation()
{
    // STUB (A5) : la vraie P3 = MEOW_BENCH_IDLE_TICKS ticks accélérés avec
    // mesure CPU/tick (p50/p95/max) et budget tick_budget (> 0,5 ms soutenu).
    m_metrics.insert(QStringLiteral("idleTicks"), 0);
    return PhaseResult::pass();
}

PhaseResult BenchPhases::runP4Stimulation()
{
    // STUB (A5) : rejouera m_job.stimuli — injection directe des événements
    // de zone (reco doc 12 §11), event_budget/event_flood/memory_quota/
    // writeset_violation.
    return PhaseResult::pass();
}

PhaseResult BenchPhases::runP5Teardown()
{
    // Au squelette : libère la carte (les tuiles sont des QObject-children de
    // la Map). La vraie P5 vérifiera la libération de l'artefact (objets,
    // connexions, timers survivants → leak).
    delete m_map;
    m_map = nullptr;
    return PhaseResult::pass();
}
