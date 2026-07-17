#ifndef MEOW_RESTRICTED_CONTEXT_H
#define MEOW_RESTRICTED_CONTEXT_H

// ============================================================================
// restricted_context — contexte d'exécution restreint des artefacts QML (D13)
// ============================================================================
//
// Spécification : doc/v3/04_QML_GENERATIF_SANDBOX.md §3.2 / §3.3,
//                 doc/v3/12_BANC_ESSAI_R1.md §5 (« même masquage que le
//                 runtime : le code du contexte restreint est partagé entre
//                 banc et jeu, pas dupliqué »).
//
// Rôle : instancier un artefact QML/JS candidat dans un **QQmlContext dédié**
// qui n'expose QUE la façade `Meow.GameApi` (meow_game_api.h) — jamais les
// singletons du jeu ni les context properties globales.
//
// Défense en profondeur (l'ordre compte, doc 04 §3.2 : « un contexte enfant ne
// constitue pas, à lui seul, une frontière de sécurité ») :
//   1. P0 (static_validator) rejette les imports hors allow-list D34 — les
//      singletons QML du jeu (Game, Catway, EditorOpBus…) ne sont accessibles
//      QUE via leur import de module, donc déjà inatteignables.
//   2. Au banc (étage 1), les modules réseau ne sont PAS liés dans
//      l'exécutable : les types n'existent même pas (doc 12 §5).
//   3. Ce contexte MASQUE en plus, par nom, les ~30 singletons enregistrés
//      dans qmlapp.cpp:84-115 et les context properties globales
//      (pattounxWorld, folderCompressor…) : une référence non qualifiée
//      `Game.x` résout en `undefined.x` → TypeError chez l'artefact, jamais
//      l'objet réel. C'est la propriété mesurée par `acces_singleton.qml`
//      (corpus R1, doc 12 §8).
//
// **Code partagé banc/jeu** : le banc (bench_runner, P2) est le premier
// consommateur ; l'étage 2 (exécution en partie, D13) réutilisera cette même
// classe avec le moteur du jeu. Dépendances : Qt6::Qml uniquement.
//
// Livrable de la tâche A6 (plan doc 15).
// ============================================================================

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>

class QQmlEngine;
class QQmlContext;

namespace meow::sandbox {

class MeowGameApi;

class RestrictedContext : public QObject
{
    Q_OBJECT
public:
    // Crée le contexte restreint sur `engine` et y injecte `api` sous le nom
    // `GameApi`. `api` doit survivre au contexte (le banc le détruit en P5,
    // après l'artefact). Une instance de façade PAR artefact : quotas,
    // write-set et abonnements individuels.
    RestrictedContext(QQmlEngine *engine, MeowGameApi *api,
                      QObject *parent = nullptr);
    ~RestrictedContext() override;

    QQmlContext *context() const { return m_context; }

    // Enregistre (une fois par process) le module QML `Meow.GameApi 1.0` pour
    // que l'import figurant dans l'allow-list D34 résolve. Le module est
    // volontairement VIDE de types créables : l'objet `GameApi` n'arrive que
    // par context property — une instance par artefact, jamais un singleton
    // process-global.
    static void registerQmlModule();

    // Noms globaux masqués dans le contexte (singletons qmlapp.cpp:84-115 +
    // context properties). Exposé pour test (le corpus R1 vérifie le masquage).
    static QStringList maskedGlobalNames();

    // ── Instanciation d'un artefact dans ce contexte ──
    struct InstantiationResult {
        QObject *object = nullptr;   // nul si échec
        QStringList errors;          // erreurs QML (compilation + création)
        qint64 elapsedMs = 0;        // durée totale (métrique loadMs, doc 12 §4)

        bool ok() const { return object != nullptr; }
    };

    // Compile `source` (QQmlComponent::setData) et crée l'objet dans le
    // contexte restreint. `url` sert de source-id pour les messages d'erreur
    // (ex. meow://artifact/<hash>). L'objet créé est parenté à `parentObject`
    // (ownership C++ explicite — le teardown P5 est déterministe).
    // ⚠️ Synchrone : une boucle infinie dans Component.onCompleted ne rend
    // jamais la main — l'appelant doit poser un watchdog (au banc : thread de
    // surveillance + _exit ; en jeu : c'est précisément ce que l'étage 1 a
    // éliminé avant introduction).
    InstantiationResult instantiate(const QString &source, const QUrl &url,
                                    QObject *parentObject);

private:
    QQmlEngine *m_engine = nullptr;
    QQmlContext *m_context = nullptr;
};

} // namespace meow::sandbox

#endif // MEOW_RESTRICTED_CONTEXT_H
