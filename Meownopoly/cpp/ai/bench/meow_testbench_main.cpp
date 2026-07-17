// ============================================================================
// meow_testbench — Banc d'essai hors-process (étage 1 du sandbox, D26)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md.
//
// Ce fichier est le POINT D'ENTRÉE de l'exécutable jetable `meow_testbench`.
// Il constitue le livrable des tâches A1 (« cible CMake headless ») et A2
// (« protocole job/verdict ») : un process Qt **offscreen**, sans aucun module
// réseau lié (pas de Catway, pas de chat, pas de PhysicsSession), qui réutilise
// l'arbre source du jeu pour la sérialisation de map, `ItemSnapableFactory` et
// le cœur physique Pattounx v2.
//
// État actuel :
//   - A1 : cible headless verte, types QML nécessaires enregistrés.
//   - A2 : le fichier de job JSON (§2.3) est lu et validé via `bench_protocol` ;
//     le verdict (§4) est émis sur une ligne unique `MEOWBENCH:`, échoue
//     proprement sur job illisible/invalide.
//   - A5 : pipeline P1→P5 branché (bench_runner.{h,cpp}) — reconstruction du
//     snapshot, instanciation dans le contexte restreint (façade Meow.GameApi,
//     A6, code partagé banc/jeu dans cpp/ai/sandbox/), ticks à vide, stimuli,
//     teardown/leaks. Auto-surveillance RSS + watchdogs de phase intégrés au
//     runner (thread de surveillance → verdict flushé → _exit).
//
// Entrée  : chemin d'un fichier de job JSON en argument (§2.3).
// Sortie  : une ligne unique `MEOWBENCH:{…}` sur stdout ; code de sortie 0 =
//           verdict rendu, ≠ 0 = crash du banc lui-même.
// ============================================================================

#include <QGuiApplication>
#include <QQmlEngine>
#include <QElapsedTimer>
#include <QString>
#include <QStringList>
#include <QByteArray>
#include <QJsonObject>

#include <cstdio>

#include "bench_protocol.h"
#include "bench_runner.h"

#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/itemsnapablefactory.h"
#include "game/map/mapfilemanager.h"
#include "game/map/mapinfo.h"
#include "assetManager/asset_manager.h"

// Les constantes du banc (§9, pattern D22) vivent dans bench_runner.h — la
// source de vérité des budgets reste le jeu (sérialisés dans le job, §2.3).

namespace mb = meow::bench;

namespace {

// Enregistre les types QML strictement nécessaires à la reconstruction d'un
// snapshot de map (§11 : « ne lier que le nécessaire »). AUCUN type réseau.
//
// Note d'architecture : le singleton `Game` n'est volontairement PAS lié au
// banc. `Game` est couplé au réseau (game_loader.cpp → EditorOpBus →
// EditorSession → Catway) ; l'inclure aspirerait tout le module collab dans un
// exécutable qui doit rester sans surface réseau (doc 12 §5). La
// reconstruction de snapshot passe par `Map` + `ItemSnapableFactory`
// (chemin full-sync, doc 12 §10), qui ne dépendent pas de `Game`.
void registerBenchQmlTypes()
{
    ItemSnapable::registerQml();
    ItemSnapableFactory::registerQml();
    MapFileManager::registerQml();
    MapInfo::registerQml();
    AssetManager::registerQml();
}

// Émet le verdict sur une ligne unique préfixée, puis flush (§2.2).
void emitVerdict(const QJsonObject &verdict)
{
    const QByteArray line = mb::formatVerdictLine(verdict);
    std::fwrite(line.constData(), 1, static_cast<size_t>(line.size()), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}

} // namespace

int main(int argc, char *argv[])
{
    QElapsedTimer wall;
    wall.start();

    // Headless : forcer la plateforme offscreen si le superviseur ne l'a pas
    // déjà imposée via `-platform offscreen` (§2.1). Le rendu n'est jamais
    // évalué — on valide le comportement, pas les pixels.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "offscreen");

    QGuiApplication app(argc, argv);

    // Le moteur QML du banc est distinct de celui du jeu (process jetable).
    QQmlEngine engine;
    registerBenchQmlTypes();

    // Chemin du fichier de job (§2.3) : premier argument non-option.
    QString jobPath;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (!args.at(i).startsWith('-')) {
            jobPath = args.at(i);
            break;
        }
    }

    // A2 : lecture + validation du job. Sur échec structurel (illisible, JSON
    // cassé, champs manquants), on rend un verdict d'échec ciblé — le job n'a
    // même pas atteint le pipeline.
    const mb::BenchJob job = mb::parseJobFile(jobPath);
    if (!job.ok) {
        mb::BenchFailure f;
        f.code = job.errorCode;
        f.details = job.errorDetails;
        f.retryable = false;
        mb::BenchVerdict v = mb::BenchVerdict::fail(job.jobId, f);
        v.durationMs = wall.elapsed();
        emitVerdict(v.toJson());
        return 0;
    }

    // A5 : pipeline P1→P5. Rend toujours un verdict — sauf comportement
    // pathologique où le watchdog du runner flushe lui-même la ligne
    // MEOWBENCH: puis _exit(0) (load_timeout, runaway_alloc, hang P4).
    mb::BenchVerdict v = mb::runBenchJob(engine, job);
    v.durationMs = wall.elapsed();
    emitVerdict(v.toJson());

    return 0;
}
