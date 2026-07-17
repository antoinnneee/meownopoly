// ============================================================================
// restricted_context — implémentation (tâche A6, doc v3 04 §3.2 / 12 §5)
// ============================================================================

#include "restricted_context.h"
#include "meow_game_api.h"

#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlComponent>
#include <QQmlError>
#include <QElapsedTimer>
#include <QVariant>

namespace meow::sandbox {

RestrictedContext::RestrictedContext(QQmlEngine *engine, MeowGameApi *api,
                                     QObject *parent)
    : QObject(parent), m_engine(engine)
{
    // Contexte enfant du root context : il hérite des context properties
    // globales… qu'on écrase immédiatement (masquage ci-dessous). L'héritage
    // est voulu : c'est lui qui permet au MÊME code de tourner au banc (root
    // quasi vide) et dans le jeu (root chargé, d'où le masquage).
    m_context = new QQmlContext(engine->rootContext(), this);

    // Masquage par nom : chaque nom global connu est ré-exposé comme QVariant
    // invalide → `undefined` côté JS. Une nouvelle context property globale
    // ajoutée dans qmlapp.cpp doit être ajoutée à maskedGlobalNames() (revue
    // de code) — les singletons de module restent couverts par P0 + non-liaison.
    const QStringList masked = maskedGlobalNames();
    for (const QString &name : masked)
        m_context->setContextProperty(name, QVariant());

    // La façade — seul vocabulaire autorisé (D34).
    api->setJsEngine(engine);
    m_context->setContextProperty(QStringLiteral("GameApi"), api);
}

RestrictedContext::~RestrictedContext() = default;

void RestrictedContext::registerQmlModule()
{
    static bool registered = false;
    if (registered)
        return;
    registered = true;
    // Module volontairement vide : rend `import Meow.GameApi 1.0` valide
    // (l'import est dans l'allow-list D34) sans exposer de type créable ni
    // de singleton process-global. L'objet `GameApi` est injecté par contexte.
    qmlRegisterModule("Meow.GameApi", 1, 0);
}

QStringList RestrictedContext::maskedGlobalNames()
{
    // Source : qmlapp.cpp:84-115 (registrations) + context properties posées
    // dans QmlApp. Liste EXHAUSTIVE volontairement, y compris les types que le
    // banc ne lie pas (l'étage 2 en jeu les a tous). Défense en profondeur :
    // ces noms résolvent normalement via import (bloqué en P0) — le masquage
    // couvre le cas d'un module custom du manifeste qui ré-exporterait un nom.
    return {
        // Singletons / types enregistrés (qmlapp.cpp:84-115)
        QStringLiteral("UiStyle"),
        QStringLiteral("Game"),
        QStringLiteral("MeowStyle"),
        QStringLiteral("ItemSnapable"),
        QStringLiteral("FolderCompressor"),
        QStringLiteral("LauncherManager"),
        QStringLiteral("AssetManager"),
        QStringLiteral("MapFileManager"),
        QStringLiteral("TemplateFileManager"),
        QStringLiteral("MapInfo"),
        QStringLiteral("PlayerProfile"),
        QStringLiteral("ScreenEffect"),
        QStringLiteral("EditorEnum"),
        QStringLiteral("ItemSnapableFactory"),
        QStringLiteral("Logger"),
        QStringLiteral("CursorManager"),
        QStringLiteral("TestManager"),
        QStringLiteral("PhysicsWorld"),
        QStringLiteral("PhysicsSession"),
        QStringLiteral("ItemSnapableEvents"),
        QStringLiteral("ChatClient"),
        QStringLiteral("ChatSlashCommands"),
        QStringLiteral("ChatSessionManager"),
        QStringLiteral("AccountManager"),
        QStringLiteral("Catway"),
        QStringLiteral("PlayerNetwork"),
        QStringLiteral("GameSession"),
        QStringLiteral("MinigameSync"),
        QStringLiteral("EditorSession"),
        QStringLiteral("EditorOpBus"),
        QStringLiteral("GameplayModuleManager"),
        QStringLiteral("MapTypes"),
        QStringLiteral("EditDelta"),
        // Context properties globales (QmlApp + qmlapp.cpp toggles)
        QStringLiteral("folderCompressor"),
        QStringLiteral("pattounxWorld"),
        QStringLiteral("_gridRendererUseCanvas"),
        QStringLiteral("_useZonesOverlay"),
    };
}

RestrictedContext::InstantiationResult
RestrictedContext::instantiate(const QString &source, const QUrl &url,
                               QObject *parentObject)
{
    InstantiationResult res;
    QElapsedTimer t;
    t.start();

    QQmlComponent component(m_engine);
    component.setData(source.toUtf8(), url);

    if (component.isError()) {
        const QList<QQmlError> errors = component.errors();
        for (const QQmlError &e : errors)
            res.errors.append(e.toString());
        res.elapsedMs = t.elapsed();
        return res;
    }
    if (component.status() != QQmlComponent::Ready) {
        // Un scheme d'URL non-local (http, scheme custom) fait basculer la
        // compilation en asynchrone — l'appelant doit fournir une URL qrc:/
        // ou file:/ pour rester synchrone et déterministe.
        res.errors.append(QStringLiteral("compilation non synchrone (status=%1) — URL source « %2 » à scheme non local ?")
                              .arg(int(component.status()))
                              .arg(url.toString()));
        res.elapsedMs = t.elapsed();
        return res;
    }

    // Synchrone — cf. avertissement du header (watchdog côté appelant).
    QObject *object = component.create(m_context);

    if (!object || component.isError()) {
        const QList<QQmlError> errors = component.errors();
        for (const QQmlError &e : errors)
            res.errors.append(e.toString());
        if (res.errors.isEmpty())
            res.errors.append(QStringLiteral("création de l'artefact échouée sans message QML"));
        delete object;
        res.elapsedMs = t.elapsed();
        return res;
    }

    // Ownership C++ explicite : le teardown (P5 au banc, kill-switch en jeu)
    // est déterministe, jamais laissé au GC JS.
    QQmlEngine::setObjectOwnership(object, QQmlEngine::CppOwnership);
    object->setParent(parentObject);

    res.object = object;
    res.elapsedMs = t.elapsed();
    return res;
}

} // namespace meow::sandbox
