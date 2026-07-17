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
//     proprement sur job illisible/invalide, et échoit sur `bench_not_implemented`
//     tant que le pipeline P1→P5 (A5) n'est pas branché.
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

#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/itemsnapablefactory.h"
#include "game/map/mapfilemanager.h"
#include "game/map/mapinfo.h"
#include "assetManager/asset_manager.h"

// ─── Constantes du banc (§9, toutes derrière #define, pattern D22) ───────────
// La source de vérité reste le jeu (les budgets voyagent sérialisés dans le
// job, §2.3). Ces valeurs par défaut servent l'auto-surveillance du banc et
// le pilotage local ; elles sont consommées à partir de A3/A5.
#ifndef MEOW_BENCH_LOAD_TIMEOUT_MS
#define MEOW_BENCH_LOAD_TIMEOUT_MS 5000
#endif
#ifndef MEOW_BENCH_IDLE_TICKS
#define MEOW_BENCH_IDLE_TICKS 600
#endif
#ifndef MEOW_BENCH_MAX_RSS_MB
#define MEOW_BENCH_MAX_RSS_MB 512
#endif

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

    // Verdict de substitution : le pipeline P1→P5 arrive avec A5. On rend dès
    // maintenant un verdict bien formé — job échoué, code `bench_not_implemented`
    // — en échoant `jobId`, `benchVersion` et `durationMs` pour que le
    // superviseur (A3) valide le contrat de sortie de bout en bout.
    mb::BenchFailure f;
    f.code = QString::fromLatin1(mb::failure::kNotImplemented);
    f.details = QStringLiteral("A2 : job « %1 » lu et validé ; pipeline P1→P5 non implémenté (A5)")
                    .arg(job.jobId);
    f.retryable = false;
    mb::BenchVerdict v = mb::BenchVerdict::fail(job.jobId, f);
    v.durationMs = wall.elapsed();
    emitVerdict(v.toJson());

    return 0;
}
