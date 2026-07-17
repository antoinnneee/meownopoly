#ifndef RESTRICTED_CONTEXT_H
#define RESTRICTED_CONTEXT_H

// ============================================================================
// RestrictedContext — environnement d'instanciation confiné d'un artefact
// QML/JS généré (tâche A6, doc/v3/12_BANC_ESSAI_R1.md §5, doc 04 §3.3-3.5).
// Code PARTAGÉ banc/jeu : premier consommateur = meow_testbench (étage 1) ;
// le confinement runtime in-process (D13, étage 2) réutilisera cette classe.
//
// LA FRONTIÈRE D'ISOLATION (deux niveaux, à documenter et maintenir) :
//
// 1. Moteur QML DÉDIÉ à l'artefact — jamais celui du jeu. Les context
//    properties du jeu (`pattounxWorld`, …) vivent dans le rootContext du
//    moteur du jeu : un moteur neuf ne les voit pas. Les qmlRegisterType/
//    Singleton (Catway, Game, MapFileManager, EditorOpBus… ~30 singletons de
//    qmlapp.cpp) sont enregistrés PAR PROCESS, mais un singleton n'est
//    résoluble que si son MODULE est importé : l'import des modules du jeu
//    est bloqué par P0 (allow-list D34) ET, dans le banc, ces modules ne sont
//    même pas enregistrés (le banc ne lie pas qmlapp.cpp). Ceinture (P0) et
//    bretelles (non-enregistrement).
//
// 2. Contexte QML enfant portant UNIQUEMENT la façade : `Meow` (objet
//    complet) + raccourcis `memory` / `events` / `stats` (formes non
//    qualifiées utilisées par le corpus et le fil rouge doc 11).
//
// CE QUI RESTE ACCESSIBLE depuis un moteur neuf (résiduel assumé, mesuré
// pour le go/no-go R1) :
//   - le global JS ECMAScript : Math, Date, JSON, Promise, RegExp… ;
//   - l'objet `Qt` (Qt.rgba, Qt.point, Qt.md5, Qt.platform.os,
//     Qt.application.name/arguments, Qt.locale, Qt.quit()/Qt.exit() — quit
//     n'est PAS connecté au banc : warning sans effet) ;
//   - `console.*` (log local uniquement) ;
//   - Qt.createQmlObject / Qt.createComponent / eval / Function /
//     XMLHttpRequest existent dans le moteur mais sont REJETÉS PAR P0
//     (js_forbidden) — défense statique, pas dynamique au MVP ;
//   - les types des modules de l'allow-list D34 (QtQuick, Shapes, Layouts,
//     Controls), dont Timer (plancher 100 ms vérifié par P0 sur littéraux).
//
// ACCÈS RÉSEAU/FICHIER via le moteur QML : neutralisés.
//   - urlInterceptor : refuse toute URL hors qrc:/ (dont l'URL synthétique
//     qrc:/meow-artifact/… de la source fournie en mémoire via setData),
//     meow:/ (réservé) et chemins d'import Qt locaux (nécessaires pour
//     charger QtQuick lui-même) — un `Image { source: "file:///…" }` ou une
//     URL http est redirigée vers qrc:/meow-blocked (inexistante).
//   - network access manager factory : dans le JEU (QtNetwork lié), tout
//     QNAM créé pour ce moteur refuse toutes les requêtes. Dans le BANC,
//     QtNetwork n'est pas lié du tout par la cible (garantie plus forte,
//     doc 12 §5) — la factory est compilée seulement si QT_NETWORK_LIB.
// ============================================================================

#include "meow_game_api.h"

#include <QJsonObject>
#include <QObject>
#include <QStringList>

class QQmlAbstractUrlInterceptor;
class QQmlContext;
class QQmlEngine;

class RestrictedContext : public QObject
{
    Q_OBJECT
public:
    struct Options
    {
        QString targetUuid;        // tuile porteuse (memory par défaut)
        QJsonObject memorySnapshot; // snapshot.memory du job (doc 05)
        int maxEmitPerSecond = 30; // MEOW_SANDBOX_MAX_EMIT_PER_S
        int memValueKb = 1;        // MEOW_SANDBOX_MEM_VALUE_KB
    };

    explicit RestrictedContext(const Options &options,
                               QObject *parent = nullptr);
    ~RestrictedContext() override;

    QQmlEngine *engine() const { return m_engine; }
    // Contexte enfant à passer à QQmlComponent::beginCreate — porte la façade.
    QQmlContext *context() const { return m_context; }

    MeowMemoryApi *memoryApi() const { return m_memory; }
    MeowEventsApi *eventsApi() const { return m_events; }
    MeowStatsApi *statsApi() const { return m_stats; }

    // Warnings QML collectés depuis le dernier appel (le moteur est muet sur
    // stderr : setOutputWarningsToStandardError(false)). Une erreur JS à
    // l'instanciation (ReferenceError sur un singleton masqué…) arrive ici.
    QStringList takeWarnings();

private:
    QQmlEngine *m_engine = nullptr;
    QQmlAbstractUrlInterceptor *m_interceptor = nullptr;
    QQmlContext *m_context = nullptr;
    MeowMemoryApi *m_memory = nullptr;
    MeowEventsApi *m_events = nullptr;
    MeowStatsApi *m_stats = nullptr;
    QStringList m_warnings;
};

#endif // RESTRICTED_CONTEXT_H
