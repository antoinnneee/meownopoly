// ============================================================================
// meow_testbench — Banc d'essai hors-process (étage 1 du sandbox, D26)
// ============================================================================
//
// Spécification : doc/v3/12_BANC_ESSAI_R1.md.
//
// Ce fichier est le POINT D'ENTRÉE de l'exécutable jetable `meow_testbench`.
// Il constitue le livrable de la tâche A1 (« cible CMake headless ») : un
// process Qt **offscreen**, sans aucun module réseau lié (pas de Catway, pas
// de chat, pas de PhysicsSession), qui réutilise l'arbre source du jeu pour la
// sérialisation de map, `ItemSnapableFactory` et le cœur physique Pattounx v2.
//
// Périmètre A1 : amener la cible à un build vert avec l'enregistrement des
// types QML nécessaires prouvé (le moteur QML se crée sans réseau). Le
// protocole job/verdict (A2), le superviseur (A3) et les phases P1→P5 (A5)
// sont branchés dans les tâches suivantes — ici, un verdict de substitution
// (`bench_not_implemented`) est émis sur la ligne `MEOWBENCH:` afin de figer
// dès maintenant le contrat de sortie décrit au §2.2 / §4.
//
// Entrée  : chemin d'un fichier de job JSON en argument (§2.3), optionnel à ce
//           stade.
// Sortie  : une ligne unique `MEOWBENCH:{…}` sur stdout ; code de sortie 0 =
//           verdict rendu, ≠ 0 = crash du banc lui-même.
// ============================================================================

#include <QGuiApplication>
#include <QQmlEngine>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <QByteArray>

#include <cstdio>

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

namespace {

constexpr int kBenchVersion = 1;

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
    const QByteArray line =
        "MEOWBENCH:" + QJsonDocument(verdict).toJson(QJsonDocument::Compact);
    std::fwrite(line.constData(), 1, static_cast<size_t>(line.size()), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}

} // namespace

int main(int argc, char *argv[])
{
    // Headless : forcer la plateforme offscreen si le superviseur ne l'a pas
    // déjà imposée via `-platform offscreen` (§2.1). Le rendu n'est jamais
    // évalué — on valide le comportement, pas les pixels.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "offscreen");

    QGuiApplication app(argc, argv);

    // Le moteur QML du banc est distinct de celui du jeu (process jetable).
    QQmlEngine engine;
    registerBenchQmlTypes();

    // Chemin du fichier de job (§2.3) — parsé à partir de A2.
    QString jobPath;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        if (!args.at(i).startsWith('-')) {
            jobPath = args.at(i);
            break;
        }
    }

    // Verdict de substitution : le pipeline P1→P5 arrive avec A2/A5. On rend
    // dès maintenant un verdict bien formé pour que le superviseur (A3) puisse
    // se brancher sur le contrat de sortie sans attendre l'implémentation.
    QJsonObject verdict;
    verdict.insert(QStringLiteral("benchVersion"), kBenchVersion);
    verdict.insert(QStringLiteral("verdict"), QStringLiteral("fail"));
    QJsonObject failure;
    failure.insert(QStringLiteral("code"), QStringLiteral("bench_not_implemented"));
    failure.insert(QStringLiteral("details"),
                   jobPath.isEmpty()
                       ? QStringLiteral("A1: cible headless prête, protocole job/verdict non implémenté (A2)")
                       : QStringLiteral("A1: job reçu mais pipeline P1->P5 non implémenté (A2/A5)"));
    failure.insert(QStringLiteral("retryable"), false);
    verdict.insert(QStringLiteral("failures"), QJsonArray{failure});
    emitVerdict(verdict);

    return 0;
}
