#include "restricted_context.h"

#include <QDir>
#include <QQmlAbstractUrlInterceptor>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>

#if defined(QT_NETWORK_LIB)
// Compilé uniquement là où QtNetwork est lié (le jeu). Le banc, lui, ne lie
// pas QtNetwork du tout — garantie plus forte que n'importe quelle factory
// (doc 12 §5) ; ce bloc y est absent par construction.
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlNetworkAccessManagerFactory>
#endif

namespace {

// ----------------------------------------------------------------------------
// Intercepteur d'URL : refuse tout ce qui n'est pas nécessaire au chargement
// de l'artefact lui-même. Autorisé :
//   - qrc:/ (ressources embarquées, immuables) ;
//   - meow:/ (URL synthétique de la source fournie en mémoire via setData) ;
//   - les fichiers locaux SOUS un chemin d'import QML du moteur (obligatoire
//     pour résoudre `import QtQuick` & co depuis l'installation Qt).
// Tout le reste (http/https/ws/ftp/file hors imports…) est redirigé vers
// qrc:/meow-blocked, une ressource inexistante → échec de chargement propre.
// ----------------------------------------------------------------------------
class RestrictedUrlInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    explicit RestrictedUrlInterceptor(const QStringList &importPaths)
    {
        for (const QString &path : importPaths) {
            const QString clean = QDir::cleanPath(path);
            if (!clean.isEmpty())
                m_allowedPrefixes.append(normalize(clean));
        }
    }

    QUrl intercept(const QUrl &url, DataType type) override
    {
        Q_UNUSED(type);
        const QString scheme = url.scheme();
        if (scheme == QLatin1String("qrc") || scheme == QLatin1String("meow")
            || scheme.isEmpty()) // relatif → résolu contre une base déjà filtrée
            return url;
        if (url.isLocalFile()) {
            const QString local = normalize(QDir::cleanPath(url.toLocalFile()));
            for (const QString &prefix : std::as_const(m_allowedPrefixes)) {
                if (local.startsWith(prefix))
                    return url;
            }
        }
        return QUrl(QStringLiteral("qrc:/meow-blocked"));
    }

private:
    static QString normalize(const QString &path)
    {
#ifdef Q_OS_WIN
        return path.toLower(); // système de fichiers insensible à la casse
#else
        return path;
#endif
    }

    QStringList m_allowedPrefixes;
};

#if defined(QT_NETWORK_LIB)
// QNAM qui refuse toutes les requêtes : l'URL est remplacée par un schéma
// inconnu avant d'atteindre la pile réseau → QNetworkReply::ProtocolUnknownError
// immédiat, aucun socket ouvert.
class BlockingNetworkAccessManager : public QNetworkAccessManager
{
public:
    using QNetworkAccessManager::QNetworkAccessManager;

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                                 QIODevice *outgoingData) override
    {
        Q_UNUSED(op);
        Q_UNUSED(outgoingData);
        QNetworkRequest blocked(request);
        blocked.setUrl(QUrl(QStringLiteral("meow-blocked://denied")));
        return QNetworkAccessManager::createRequest(
            QNetworkAccessManager::GetOperation, blocked, nullptr);
    }
};

class BlockingNamFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override
    {
        return new BlockingNetworkAccessManager(parent);
    }
};

Q_GLOBAL_STATIC(BlockingNamFactory, g_blockingNamFactory)
#endif // QT_NETWORK_LIB

} // namespace

RestrictedContext::RestrictedContext(const Options &options, QObject *parent)
    : QObject(parent)
{
    // Rend `import Meow.GameApi` licite (module déclaré, AUCUN type — la
    // façade passe par les context properties ci-dessous). Idempotent.
    // TODO(S-6) : vrai module QML installé avec types.
    qmlRegisterModule("Meow.GameApi", 1, 0);

    // --- Niveau 1 : moteur DÉDIÉ (aucun singleton/context property du jeu) ---
    m_engine = new QQmlEngine; // détruit explicitement dans le dtor
    m_engine->setOutputWarningsToStandardError(false);
    connect(m_engine, &QQmlEngine::warnings, this,
            [this](const QList<QQmlError> &warnings) {
                for (const QQmlError &w : warnings)
                    m_warnings.append(w.toString());
            });

    // --- Neutralisation des accès réseau/fichier via le moteur QML ---
    m_interceptor = new RestrictedUrlInterceptor(m_engine->importPathList());
    m_engine->addUrlInterceptor(m_interceptor);
#if defined(QT_NETWORK_LIB)
    m_engine->setNetworkAccessManagerFactory(g_blockingNamFactory());
#endif

    // --- Façade (enfants de this : CppOwnership garanti côté JS) ---
    m_memory = new MeowMemoryApi(this);
    m_memory->setup(m_engine, options.targetUuid, options.memorySnapshot,
                    options.memValueKb);
    m_events = new MeowEventsApi(this);
    m_events->setup(m_engine, options.maxEmitPerSecond);
    m_stats = new MeowStatsApi(this);

    // `events.emit` : `emit` est un mot-macro Qt côté C++ — l'API réelle est
    // MeowEventsApi::emitEvent, exposée sous le nom `emit` via un wrapper JS
    // figé construit dans le moteur de l'artefact.
    const QJSValue factory = m_engine->evaluate(QStringLiteral(
        "(function (memoryApi, eventsImpl, statsApi, targetUuid) {"
        "  'use strict';"
        "  var events = Object.freeze({"
        "    on: function (t, cb) { eventsImpl.on(t, cb); },"
        "    emit: function (t, p) { return eventsImpl.emitEvent(t, p); }"
        "  });"
        "  return Object.freeze({"
        "    memory: memoryApi,"
        "    events: events,"
        "    stats: statsApi,"
        "    targetUuid: targetUuid"
        "  });"
        "})"));
    const QJSValue meow = QJSValue(factory).call(
        {m_engine->newQObject(m_memory), m_engine->newQObject(m_events),
         m_engine->newQObject(m_stats), QJSValue(options.targetUuid)});

    // --- Niveau 2 : contexte enfant, façade UNIQUEMENT ---
    m_context = new QQmlContext(m_engine->rootContext(), m_engine);
    m_context->setContextProperty(QStringLiteral("Meow"),
                                  QVariant::fromValue(meow));
    m_context->setContextProperty(QStringLiteral("memory"), m_memory);
    m_context->setContextProperty(
        QStringLiteral("events"),
        QVariant::fromValue(meow.property(QStringLiteral("events"))));
    m_context->setContextProperty(QStringLiteral("stats"), m_stats);
}

RestrictedContext::~RestrictedContext()
{
    // Ordre : moteur d'abord (le contexte est son enfant QObject), puis
    // l'intercepteur (le moteur peut encore l'appeler pendant sa destruction).
    delete m_engine;
    m_engine = nullptr;
    delete m_interceptor;
    m_interceptor = nullptr;
}

QStringList RestrictedContext::takeWarnings()
{
    QStringList warnings;
    warnings.swap(m_warnings);
    return warnings;
}
