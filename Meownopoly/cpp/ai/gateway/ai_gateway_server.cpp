#include "ai_gateway_server.h"

#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonArray>
#include <QRandomGenerator>
#include <QDateTime>
#include <QDebug>

// Accès à la scène QML pour la traduction des tools vers les hooks (C3). Ces
// en-têtes sont compilés quel que soit MEOW_HAS_HTTP_SERVER (le dispatch de tool
// est indépendant du transport HTTP) ; Qt6::Quick/Gui sont déjà liés à la cible.
#include <QGuiApplication>
#include <QWindow>
#include <QQuickWindow>
#include <QQuickItem>
#include <QMetaObject>
#include <QMetaMethod>
#include <QMetaEnum>
#include <QJSValue>
#include <QImage>
#include <QBuffer>

// C4 : énumération des enums exposés (state.enum) via QMetaEnum — recopie
// directe du Q_ENUM, aucune dérive. Les dossiers cpp/game/{case,map,item_snapable}
// sont dans les include dirs de la cible (CMakeLists.txt).
#include "Case.h"
#include "ItemSnapable.h"
#include "playerprofile.h"
#include "npcparameter.h"

// S-5 : module_config (D41) — état des modules gameplay lu directement sur le
// singleton C++ (source de vérité, GUI thread). Généralise l'ancien hook QML
// `setStatsModuleEnabled` à tout module, et alimente `snapshot.modules` du banc.
#include "game/modules/gameplay_module_manager.h"

// D4 : branchement du canal sur le journal métier (events_poll + résumé injecté).
#include "game/events/gameplay_event_bus.h"
// A9 : dry-run local via le banc d'essai (pool + P0 statique).
#include "ai/bench/bench_pool.h"
#include "ai/bench/bench_protocol.h"
#include "ai/bench/bench_supervisor.h"   // MEOW_BENCH_TIMEOUT_MS
#include "ai/sandbox/static_validator.h"
#include "ai/proposal/proposal_gateway.h"
#include "ai/proposal/proposal_lifecycle.h"
#include "game/memory/memory_store.h"
#include "game/rules/rules_engine.h"
#include "game/save/game_save.h"
#include <QCryptographicHash>
#include <QUuid>
#include <QEventLoop>
#include <QTimer>

#if MEOW_HAS_HTTP_SERVER
#  include <QHttpServer>
#  include <QHttpServerRequest>
#  include <QHttpServerResponse>
#  include <QHttpHeaders>
#  include <QTcpServer>
#endif

// ============================================================================
// Quotas (C2) — plafonds compile-time affinables (doc 02 §7, patron #define D22).
// ============================================================================

// Taille max du corps d'une requête HTTP. Un artefact QML est plafonné à 20 KB
// (doc 04/13), l'enveloppe + le lot ajoutent de la marge ; 64 KB couvre le pire
// cas sans laisser passer un dump abusif.
#ifndef MEOW_AI_GATEWAY_MAX_REQUEST_BYTES
#  define MEOW_AI_GATEWAY_MAX_REQUEST_BYTES 65536
#endif
// Rate-limit fenêtre glissante par token : au plus N requêtes par fenêtre.
#ifndef MEOW_AI_GATEWAY_RATE_LIMIT_REQUESTS
#  define MEOW_AI_GATEWAY_RATE_LIMIT_REQUESTS 120
#endif
#ifndef MEOW_AI_GATEWAY_RATE_LIMIT_WINDOW_MS
#  define MEOW_AI_GATEWAY_RATE_LIMIT_WINDOW_MS 60000
#endif
// Entropie du token éphémère (octets bruts avant hexadécimal). 32 → 64 chars.
#ifndef MEOW_AI_GATEWAY_TOKEN_BYTES
#  define MEOW_AI_GATEWAY_TOKEN_BYTES 32
#endif
// Plafond de captures d'écran par session d'IA (D22, 2026-07-12). Défaut 5,
// affinable au build. Rétention éphémère hors périmètre de la passerelle : le
// budget est simplement remis à 0 à la rotation des tokens (nouvelle session).
#ifndef MEOW_AI_GATEWAY_SCREENSHOT_CAP
#  define MEOW_AI_GATEWAY_SCREENSHOT_CAP 5
#endif
// Quota de dry-run (artifact_dryrun, D42) par session d'IA. Déclaré au manifeste
// (quotas.perInvocation.artifact_dryrun, défaut 10). Comme le budget de captures
// (D22), il est porté par le token et remis à 0 à la rotation (nouvelle session).
#ifndef MEOW_BENCH_DRYRUN_QUOTA
#  define MEOW_BENCH_DRYRUN_QUOTA 10
#endif
// Activation permanente du canal IA (opt-out) : à 1, la passerelle MCP démarre
// même sans --ai-gateway-port / MEOW_AI_GATEWAY_PORT, sur le port par défaut
// ci-dessous (+ instance-1 en dual-instance, patron 7700/7701 de l'automation).
// Désactivation ponctuelle au runtime : --ai-gateway-port 0 (ou env =0).
#ifndef MEOW_AI_GATEWAY_ALWAYS_ON
#  define MEOW_AI_GATEWAY_ALWAYS_ON 1
#endif
#ifndef MEOW_AI_GATEWAY_DEFAULT_PORT
#  define MEOW_AI_GATEWAY_DEFAULT_PORT 7790
#endif

// ============================================================================
// Constantes du protocole
// ============================================================================

namespace {
// Version MCP annoncée par le serveur (échoée au client si compatible). Une
// seule version supportée au MVP — cf. doc/v3/02_CANAL_IA.md §2 bis.
constexpr auto kMcpProtocolVersion = "2025-06-18";
constexpr auto kServerName = "Meownopoly AI Gateway";
constexpr auto kServerVersion = "0.1.0";

// Codes d'erreur JSON-RPC 2.0 standard.
constexpr int kParseError = -32700;
constexpr int kInvalidRequest = -32600;
constexpr int kMethodNotFound = -32601;
constexpr int kInvalidParams = -32602;

// Codes d'erreur applicatifs stables (doc 02 §6) — placés dans error.data.code,
// à durée de vie plus longue que les codes JSON-RPC numériques (contrat IA).
constexpr auto kAppParseError = "parse_error";
constexpr auto kAppInvalidRequest = "invalid_request";
constexpr auto kAppMethodNotFound = "method_not_found";
constexpr auto kAppInvalidParams = "invalid_params";
constexpr auto kAppUnauthorized = "unauthorized";
constexpr auto kAppRateLimited = "rate_limited";
constexpr auto kAppPayloadTooLarge = "payload_too_large";
constexpr auto kAppUnknownTool = "unknown_tool";
// C3 — dispatch de tools.
constexpr auto kAppForbiddenRole = "forbidden_role";     // tool hors allow-list du rôle
constexpr auto kAppNotImplemented = "not_implemented";   // capacité hôte à venir (C4/S-*)
constexpr auto kAppSceneUnavailable = "scene_unavailable"; // éditeur non chargé
constexpr auto kAppToolFailed = "tool_failed";           // hook exécuté mais en échec
// C4 — capacités manquantes.
constexpr auto kAppUnknownEnum = "unknown_enum";         // state.enum : nom hors catalogue
constexpr auto kAppScreenshotQuota = "screenshot_quota"; // plafond D22 atteint
// A9 — dry-run local.
constexpr auto kAppDryrunQuota = "dryrun_quota";         // quota artifact_dryrun (D42) atteint
constexpr auto kAppBenchUnavailable = "bench_unavailable"; // banc n'a pas rendu de verdict
} // namespace

// ============================================================================
// Construction / cycle de vie
// ============================================================================

AiGatewayServer *AiGatewayServer::s_instance = nullptr;

AiGatewayServer *AiGatewayServer::instance()
{
    return s_instance;
}

AiGatewayServer::AiGatewayServer(quint16 port, QObject *parent)
    : QObject(parent)
{
    s_instance = this;

    // Tokens éphémères de session (D20) — générés quel que soit l'état de l'add-on
    // HTTP, pour que proposerToken()/arbiterToken() soient exploitables au spawn.
    initSessionTokens();

#if MEOW_HAS_HTTP_SERVER
    m_httpServer = new QHttpServer(this);

    // Endpoint MCP unique : POST /mcp, corps JSON-RPC 2.0.
    m_httpServer->route(
        QStringLiteral("/mcp"), QHttpServerRequest::Method::Post,
        [this](const QHttpServerRequest &request) -> QHttpServerResponse {
            // SÉCURITÉ (double garde) : chaque requête re-vérifie que la source
            // est la loopback, même si le QTcpServer n'écoute que sur 127.0.0.1.
            const QHostAddress peer = request.remoteAddress();
            if (peer != QHostAddress(QHostAddress::LocalHost)
                && peer != QHostAddress(QHostAddress::LocalHostIPv6)) {
                qWarning() << "[AiGateway] Requête non-loopback rejetée :" << peer;
                return QHttpServerResponse(QHttpServerResponse::StatusCode::Forbidden);
            }

            // Fabrique de réponse d'erreur transport (corps JSON-RPC + statut HTTP).
            const auto errorResponse =
                [](const QJsonObject &body, QHttpServerResponse::StatusCode status) {
                    return QHttpServerResponse(
                        QByteArrayLiteral("application/json"),
                        QJsonDocument(body).toJson(QJsonDocument::Compact), status);
                };

            // QUOTA (taille) : rejette avant toute allocation JSON un corps abusif.
            if (request.body().size() > MEOW_AI_GATEWAY_MAX_REQUEST_BYTES) {
                return errorResponse(
                    makeAppError(QJsonValue(), kInvalidRequest, kAppPayloadTooLarge,
                                 QStringLiteral("Request body exceeds %1 bytes")
                                     .arg(MEOW_AI_GATEWAY_MAX_REQUEST_BYTES),
                                 /*retryable=*/false),
                    QHttpServerResponse::StatusCode::PayloadTooLarge);
            }

            // AUTH : chaque requête doit porter un Bearer token de session valide
            // (D20). Le token, injecté à l'agent au spawn, protège l'endpoint
            // loopback des autres process de la machine (R3) et porte le rôle.
            const QByteArray authRaw =
                request.headers()
                    .value(QHttpHeaders::WellKnownHeader::Authorization)
                    .toByteArray();
            const QString token = extractBearer(QString::fromLatin1(authRaw));
            Role role = Role::Proposer;
            if (token.isEmpty() || !validateToken(token, role)) {
                return errorResponse(
                    makeAppError(QJsonValue(), kInvalidRequest, kAppUnauthorized,
                                 QStringLiteral("Missing or invalid bearer token"),
                                 /*retryable=*/false),
                    QHttpServerResponse::StatusCode::Unauthorized);
            }

            // Token de la requête en cours : exploité par les tools à budget
            // par token (screenshot D22). GUI thread mono-fil, requête
            // synchrone → pas de réentrance à craindre.
            m_currentToken = token;

            // QUOTA (débit) : rate-limit fenêtre glissante par token.
            if (!consumeRateBudget(token)) {
                return errorResponse(
                    makeAppError(QJsonValue(), kInvalidRequest, kAppRateLimited,
                                 QStringLiteral("Rate limit exceeded (%1 req / %2 ms)")
                                     .arg(MEOW_AI_GATEWAY_RATE_LIMIT_REQUESTS)
                                     .arg(MEOW_AI_GATEWAY_RATE_LIMIT_WINDOW_MS),
                                 /*retryable=*/true),
                    QHttpServerResponse::StatusCode::TooManyRequests);
            }

            QJsonParseError perr;
            const QJsonDocument doc = QJsonDocument::fromJson(request.body(), &perr);
            if (perr.error != QJsonParseError::NoError) {
                return errorResponse(
                    makeAppError(QJsonValue(), kParseError, kAppParseError,
                                 QStringLiteral("Parse error: %1").arg(perr.errorString()),
                                 /*retryable=*/false),
                    QHttpServerResponse::StatusCode::Ok);
            }

            // JSON-RPC accepte une requête unique (objet) ou un lot (tableau).
            if (doc.isArray()) {
                QJsonArray responses;
                const QJsonArray batch = doc.array();
                for (const QJsonValue &item : batch) {
                    if (!item.isObject())
                        continue;
                    const QJsonObject resp = handleRpc(item.toObject(), role);
                    if (!resp.isEmpty()) // objet vide = notification, pas de réponse
                        responses.append(resp);
                }
                if (responses.isEmpty()) // lot 100 % notifications
                    return QHttpServerResponse(QHttpServerResponse::StatusCode::Accepted);
                return QHttpServerResponse(
                    QByteArrayLiteral("application/json"),
                    QJsonDocument(responses).toJson(QJsonDocument::Compact));
            }

            if (!doc.isObject()) {
                return errorResponse(
                    makeAppError(QJsonValue(), kInvalidRequest, kAppInvalidRequest,
                                 QStringLiteral("Invalid Request: expected a JSON object or array"),
                                 /*retryable=*/false),
                    QHttpServerResponse::StatusCode::Ok);
            }

            const QJsonObject resp = handleRpc(doc.object(), role);
            if (resp.isEmpty()) // notification : rien à renvoyer
                return QHttpServerResponse(QHttpServerResponse::StatusCode::Accepted);
            return QHttpServerResponse(
                QByteArrayLiteral("application/json"),
                QJsonDocument(resp).toJson(QJsonDocument::Compact));
        });

    // SÉCURITÉ : bind STRICTEMENT sur la loopback (127.0.0.1). Jamais 0.0.0.0 —
    // le canal expose le catalogue gameplay et sera protégé par token (C2).
    m_tcpServer = new QTcpServer(this);
    if (!m_tcpServer->listen(QHostAddress::LocalHost, port)
        || !m_httpServer->bind(m_tcpServer)) {
        qWarning() << "[AiGateway] Échec de l'écoute sur le port" << port
                   << ":" << m_tcpServer->errorString();
        m_tcpServer->deleteLater();
        m_tcpServer = nullptr;
    } else {
        m_port = m_tcpServer->serverPort();
        qInfo() << "[AiGateway] Passerelle MCP à l'écoute sur http://127.0.0.1:"
                << m_port << "/mcp";
    }
#else
    Q_UNUSED(port);
    qWarning() << "[AiGateway] Add-on QtHttpServer absent (P0-1) — passerelle MCP "
                  "inerte. Repli documenté : pont stdio (automation_mcp/).";
#endif
}

AiGatewayServer::~AiGatewayServer()
{
    if (s_instance == this)
        s_instance = nullptr;
}

bool AiGatewayServer::isListening() const
{
#if MEOW_HAS_HTTP_SERVER
    return m_tcpServer && m_tcpServer->isListening();
#else
    return false;
#endif
}

bool AiGatewayServer::httpServerAvailable()
{
#if MEOW_HAS_HTTP_SERVER
    return true;
#else
    return false;
#endif
}

// ============================================================================
// Résolution du port (CLI / env) et fabrique conditionnelle
// ============================================================================

quint16 AiGatewayServer::resolvePort(const QStringList &args)
{
    // Priorité au flag CLI explicite. La valeur 0 est un opt-out explicite
    // (désactive la passerelle même avec MEOW_AI_GATEWAY_ALWAYS_ON).
    const int idx = args.indexOf(QStringLiteral("--ai-gateway-port"));
    if (idx != -1 && idx + 1 < args.size()) {
        bool conv = false;
        const uint v = args.at(idx + 1).toUInt(&conv);
        if (conv && v <= 65535)
            return static_cast<quint16>(v);
        qWarning() << "[AiGateway] --ai-gateway-port avec valeur invalide :"
                   << args.value(idx + 1);
    }

    // Sinon, variable d'environnement (0 = opt-out explicite, comme le CLI).
    const QByteArray env = qgetenv("MEOW_AI_GATEWAY_PORT");
    if (!env.isEmpty()) {
        bool conv = false;
        const uint v = QString::fromUtf8(env).toUInt(&conv);
        if (conv && v <= 65535)
            return static_cast<quint16>(v);
        qWarning() << "[AiGateway] MEOW_AI_GATEWAY_PORT invalide :" << env;
    }

#if MEOW_AI_GATEWAY_ALWAYS_ON
    // Activation permanente : port par défaut, décalé par instance pour le
    // dual-instance (7790 / 7791, patron des ports d'automation 7700/7701).
    quint16 port = MEOW_AI_GATEWAY_DEFAULT_PORT;
    const int instIdx = args.indexOf(QStringLiteral("--instance"));
    if (instIdx != -1 && instIdx + 1 < args.size()) {
        bool conv = false;
        const uint inst = args.at(instIdx + 1).toUInt(&conv);
        if (conv && inst >= 1)
            port = static_cast<quint16>(port + inst - 1);
    }
    return port;
#else
    return 0; // aucun port demandé → pas de serveur
#endif
}

AiGatewayServer *AiGatewayServer::maybeCreate(const QStringList &args, QObject *parent)
{
    const quint16 port = resolvePort(args);
    if (port == 0)
        return nullptr;
    return new AiGatewayServer(port, parent);
}

// ============================================================================
// Dispatch JSON-RPC 2.0 (sous-ensemble MCP)
// ============================================================================

QJsonObject AiGatewayServer::handleRpc(const QJsonObject &request, Role role)
{
    // Une notification JSON-RPC n'a pas de champ "id" → aucune réponse renvoyée.
    const bool isNotification = !request.contains(QStringLiteral("id"));
    const QJsonValue id = request.value(QStringLiteral("id"));
    const QString method = request.value(QStringLiteral("method")).toString();
    const QJsonObject params = request.value(QStringLiteral("params")).toObject();

    if (method.isEmpty()) {
        if (isNotification)
            return {};
        return makeAppError(id, kInvalidRequest, kAppInvalidRequest,
                            QStringLiteral("Invalid Request: missing 'method'"),
                            /*retryable=*/false);
    }

    // Notifications MCP (ex. notifications/initialized) : traitées comme des
    // no-op côté serveur, sans réponse.
    if (method.startsWith(QStringLiteral("notifications/")))
        return {};

    if (method == QLatin1String("initialize"))
        return handleInitialize(id, params);
    if (method == QLatin1String("ping"))
        return makeResult(id, QJsonObject{});
    if (method == QLatin1String("tools/list"))
        return handleToolsList(id, params, role);
    if (method == QLatin1String("tools/call"))
        return handleToolsCall(id, params, role);

    if (isNotification)
        return {};
    return makeAppError(id, kMethodNotFound, kAppMethodNotFound,
                        QStringLiteral("Method not found: %1").arg(method),
                        /*retryable=*/false);
}

QJsonObject AiGatewayServer::handleInitialize(const QJsonValue &id, const QJsonObject &params)
{
    // Le client propose sa version ; on répond avec celle qu'on utilisera. Au
    // MVP une seule version est supportée : on l'annonce quelle que soit la
    // demande (un client incompatible négociera de son côté).
    Q_UNUSED(params);

    QJsonObject serverInfo;
    serverInfo[QStringLiteral("name")] = QString::fromLatin1(kServerName);
    serverInfo[QStringLiteral("version")] = QString::fromLatin1(kServerVersion);

    // Capacités : seuls les tools sont exposés au MVP (pas de resources/prompts).
    QJsonObject toolsCap;
    toolsCap[QStringLiteral("listChanged")] = false;
    QJsonObject capabilities;
    capabilities[QStringLiteral("tools")] = toolsCap;

    QJsonObject result;
    result[QStringLiteral("protocolVersion")] = QString::fromLatin1(kMcpProtocolVersion);
    result[QStringLiteral("capabilities")] = capabilities;
    result[QStringLiteral("serverInfo")] = serverInfo;

    return makeResult(id, result);
}

QJsonObject AiGatewayServer::handleToolsList(const QJsonValue &id, const QJsonObject &params,
                                             Role role)
{
    // Catalogue des tools MVP (manifeste P0-4, doc 02 §5), FILTRÉ par l'allow-list
    // du rôle authentifié (D20) : le proposant ne voit pas `arbiter_verdict`,
    // l'arbitre ne voit pas les tools de pose/édition. Format MCP : { tools: [...] }.
    Q_UNUSED(params);
    QJsonArray tools;
    for (const ToolDef &def : toolTable()) {
        if (!toolAllowedForRole(QString::fromLatin1(def.name), role))
            continue;
        tools.append(toolDescriptor(QString::fromLatin1(def.name)));
    }
    QJsonObject result;
    result[QStringLiteral("tools")] = tools;
    return makeResult(id, result);
}

QJsonObject AiGatewayServer::handleToolsCall(const QJsonValue &id, const QJsonObject &params,
                                             Role role)
{
    const QString name = params.value(QStringLiteral("name")).toString();
    if (name.isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("tools/call: champ 'name' requis"),
                            /*retryable=*/false);

    // Tool inconnu du manifeste.
    if (!toolExists(name))
        return makeAppError(id, kInvalidParams, kAppUnknownTool,
                            QStringLiteral("Unknown tool: %1").arg(name),
                            /*retryable=*/false);

    // Rôle : le tool existe mais n'est pas dans l'allow-list du token (D20).
    // Erreur distincte d'« unknown » pour ne pas révéler la surface d'un autre
    // rôle tout en restant actionnable (contrat d'erreur doc 02 §6).
    if (!toolAllowedForRole(name, role))
        return makeAppError(id, kInvalidParams, kAppForbiddenRole,
                            QStringLiteral("Tool '%1' non autorisé pour ce rôle").arg(name),
                            /*retryable=*/false);

    // MCP transporte les paramètres du tool dans `params.arguments`.
    const QJsonObject arguments = params.value(QStringLiteral("arguments")).toObject();
    return dispatchTool(id, name, arguments, role);
}

// ============================================================================
// Catalogue de tools (C3) — table dérivée du manifeste channel_manifest.json
// ============================================================================

const QVector<AiGatewayServer::ToolDef> &AiGatewayServer::toolTable()
{
    // Source de vérité : channel_manifest.json (P0-4, D43/D44). Ordre et
    // allow-lists par rôle recopiés de roles.<role>.toolAllowList. À régénérer
    // depuis le manifeste au build en M12 (C8).
    static const QVector<ToolDef> table = {
        //             name              proposer  arbiter
        { "help",             true,  true  },
        { "state_query",      true,  true  },
        { "editor_place",     true,  false },
        { "editor_edit",      true,  false },
        { "memory_set",       true,  false },
        { "roster_edit",      true,  false },
        { "module_config",    true,  false },
        { "artifact_submit",  true,  false },
        { "artifact_dryrun",  true,  false },
        { "events_poll",      true,  true  },
        { "screenshot",       true,  true  },
        { "arbiter_verdict",  false, true  },
    };
    return table;
}

bool AiGatewayServer::toolExists(const QString &name)
{
    for (const ToolDef &def : toolTable())
        if (name == QLatin1String(def.name))
            return true;
    return false;
}

bool AiGatewayServer::toolAllowedForRole(const QString &name, Role role)
{
    for (const ToolDef &def : toolTable()) {
        if (name != QLatin1String(def.name))
            continue;
        return role == Role::Proposer ? def.proposer : def.arbiter;
    }
    return false;
}

QJsonObject AiGatewayServer::toolDescriptor(const QString &name)
{
    // Fabrique un schéma d'entrée JSON-Schema { type, properties, required }.
    const auto schema = [](const QJsonObject &properties, const QStringList &required) {
        QJsonObject s;
        s[QStringLiteral("type")] = QStringLiteral("object");
        s[QStringLiteral("properties")] = properties;
        if (!required.isEmpty()) {
            QJsonArray req;
            for (const QString &r : required)
                req.append(r);
            s[QStringLiteral("required")] = req;
        }
        return s;
    };
    const auto prop = [](const QString &type, const QString &doc,
                         const QJsonArray &enumValues = {}) {
        QJsonObject p;
        if (!type.isEmpty()) // type vide = « any » (JSON Schema : pas de contrainte)
            p[QStringLiteral("type")] = type;
        if (!doc.isEmpty())
            p[QStringLiteral("description")] = doc;
        if (!enumValues.isEmpty())
            p[QStringLiteral("enum")] = enumValues;
        return p;
    };

    QJsonObject descriptor;
    descriptor[QStringLiteral("name")] = name;

    if (name == QLatin1String("help")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Divulgation progressive de la doc détaillée d'une "
                           "famille de commandes (doc 02 §3).");
        QJsonObject props;
        props[QStringLiteral("topic")] =
            prop(QStringLiteral("string"), QStringLiteral("famille ou concept ; vide = sommaire"));
        descriptor[QStringLiteral("inputSchema")] = schema(props, {});
    } else if (name == QLatin1String("state_query")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Lecture d'état structurée, résultats compacts et paginés.");
        QJsonObject props;
        props[QStringLiteral("what")] = prop(
            QStringLiteral("string"), QStringLiteral("nature de la lecture"),
            QJsonArray{ "tiles", "tile", "enums", "roster", "players", "rules",
                        "memory", "proposals" });
        props[QStringLiteral("filter")] =
            prop(QStringLiteral("object"), QStringLiteral("ex. { uuid } ou { type } ; pagination { limit, offset }"));
        props[QStringLiteral("cursor")] =
            prop(QStringLiteral("string"), QStringLiteral("pagination de listes longues"));
        descriptor[QStringLiteral("inputSchema")] = schema(props, { QStringLiteral("what") });
    } else if (name == QLatin1String("editor_place")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Pose d'un élément posable via le chemin UI exact "
                           "(compatible collab/undo).");
        QJsonObject props;
        props[QStringLiteral("kind")] = prop(
            QStringLiteral("string"), QStringLiteral("type d'élément à poser"),
            QJsonArray{ "asset", "case", "zone", "npc", "enemy", "crate" });
        props[QStringLiteral("params")] =
            prop(QStringLiteral("object"), QStringLiteral("params spécifiques au kind (position grille, type, dimensions…)"));
        descriptor[QStringLiteral("inputSchema")] =
            schema(props, { QStringLiteral("kind"), QStringLiteral("params") });
    } else if (name == QLatin1String("editor_edit")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Édition d'un existant identifié par uuid.");
        QJsonObject props;
        props[QStringLiteral("uuid")] = prop(QStringLiteral("string"), QStringLiteral("uuid de la tuile"));
        props[QStringLiteral("op")] = prop(
            QStringLiteral("string"), QStringLiteral("opération d'édition"),
            QJsonArray{ "move", "resize", "delete", "link", "unlink", "set_param",
                        "set_trigger", "set_dialogue" });
        props[QStringLiteral("params")] =
            prop(QStringLiteral("object"), QStringLiteral("params spécifiques à l'op"));
        descriptor[QStringLiteral("inputSchema")] =
            schema(props, { QStringLiteral("uuid"), QStringLiteral("op") });
    } else if (name == QLatin1String("memory_set")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Écriture dans l'espace mémoire 'config' (pipeline "
                           "édition, doc 05 / D15).");
        QJsonObject props;
        props[QStringLiteral("scope")] = prop(
            QStringLiteral("string"), QStringLiteral("portée"),
            QJsonArray{ "tile", "session", "player" });
        props[QStringLiteral("uuid")] =
            prop(QStringLiteral("string"), QStringLiteral("requis si scope=tile (ou id joueur si scope=player)"));
        props[QStringLiteral("key")] =
            prop(QStringLiteral("string"), QStringLiteral("clé namespacée, ex. 'config/damage'"));
        props[QStringLiteral("value")] = prop(QString(), QStringLiteral("valeur à écrire"));
        descriptor[QStringLiteral("inputSchema")] =
            schema(props, { QStringLiteral("scope"), QStringLiteral("key"), QStringLiteral("value") });
    } else if (name == QLatin1String("roster_edit")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Profils joueurs et limites min/max de la map (ops collab 12-16).");
        QJsonObject props;
        props[QStringLiteral("op")] = prop(
            QStringLiteral("string"), QStringLiteral("opération roster"),
            QJsonArray{ "add_profile", "remove_profile", "update_profile",
                        "reorder_profile", "set_limits" });
        props[QStringLiteral("params")] = prop(QStringLiteral("object"), QString());
        descriptor[QStringLiteral("inputSchema")] =
            schema(props, { QStringLiteral("op"), QStringLiteral("params") });
    } else if (name == QLatin1String("module_config")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Activation/config d'un module gameplay (D41).");
        QJsonObject props;
        props[QStringLiteral("id")] = prop(QStringLiteral("string"), QStringLiteral("ex. 'stats'"));
        props[QStringLiteral("enabled")] = prop(QStringLiteral("boolean"), QString());
        props[QStringLiteral("params")] = prop(QStringLiteral("object"), QString());
        descriptor[QStringLiteral("inputSchema")] =
            schema(props, { QStringLiteral("id"), QStringLiteral("enabled") });
    } else if (name == QLatin1String("artifact_submit")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Soumission d'un artefact QML/JS → enveloppe de "
                           "proposition (D11). Bloquant jusqu'au verdict.");
        QJsonObject props;
        props[QStringLiteral("source")] = prop(QStringLiteral("string"), QStringLiteral("QML/JS inline, ≤ 20 KB"));
        props[QStringLiteral("target")] = prop(QStringLiteral("string"), QStringLiteral("uuid de la tuile porteuse"));
        props[QStringLiteral("meta")] = prop(QStringLiteral("object"), QStringLiteral("aiSummary, requiresModules, declaredWriteSet…"));
        descriptor[QStringLiteral("inputSchema")] = schema(props, { QStringLiteral("source") });
    } else if (name == QLatin1String("artifact_dryrun")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Itération pré-soumission sur le banc d'essai local "
                           "(D42). Pass local ≠ acceptation.");
        QJsonObject props;
        props[QStringLiteral("source")] = prop(QStringLiteral("string"), QString());
        props[QStringLiteral("targetUuid")] = prop(QStringLiteral("string"), QString());
        descriptor[QStringLiteral("inputSchema")] = schema(props, { QStringLiteral("source") });
    } else if (name == QLatin1String("events_poll")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Resynchronisation en cours de tâche sur le journal "
                           "métier (Q-E06).");
        QJsonObject props;
        props[QStringLiteral("cursor")] =
            prop(QStringLiteral("integer"), QStringLiteral("seq du journal métier hôte (D19)"));
        descriptor[QStringLiteral("inputSchema")] = schema(props, { QStringLiteral("cursor") });
    } else if (name == QLatin1String("screenshot")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Capture de l'écran de jeu à la demande (D22). "
                           "Plafond par requête via #define.");
        QJsonObject props;
        props[QStringLiteral("view")] =
            prop(QStringLiteral("string"), QStringLiteral("vue ciblée (défaut : écran de jeu)"));
        descriptor[QStringLiteral("inputSchema")] = schema(props, {});
    } else if (name == QLatin1String("arbiter_verdict")) {
        descriptor[QStringLiteral("description")] =
            QStringLiteral("Rendu du verdict d'une proposition. TOKEN ARBITRE "
                           "UNIQUEMENT.");
        QJsonObject props;
        props[QStringLiteral("proposalId")] = prop(QStringLiteral("string"), QString());
        props[QStringLiteral("verdict")] = prop(
            QStringLiteral("string"), QString(),
            QJsonArray{ "accepted", "rejected", "amended" });
        props[QStringLiteral("reasons")] =
            prop(QStringLiteral("array"), QStringLiteral("entrées { audience, code?, text, retryable? }"));
        props[QStringLiteral("amendment")] =
            prop(QStringLiteral("object"), QStringLiteral("patch ; un amendement de code repasse au banc (D32)"));
        descriptor[QStringLiteral("inputSchema")] = schema(
            props, { QStringLiteral("proposalId"), QStringLiteral("verdict"), QStringLiteral("reasons") });
    } else {
        // Sécurité : un tool listé sans descripteur reste au moins déclaré.
        descriptor[QStringLiteral("description")] = QStringLiteral("(sans description)");
        descriptor[QStringLiteral("inputSchema")] = schema({}, {});
    }
    return descriptor;
}

// ============================================================================
// Dispatch d'un appel de tool vers les hooks éditeur (C3)
// ============================================================================

QJsonObject AiGatewayServer::dispatchTool(const QJsonValue &id, const QString &name,
                                          const QJsonObject &arguments, Role role)
{
    if (name == QLatin1String("help"))
        return toolHelp(id, arguments);
    if (name == QLatin1String("editor_place"))
        return toolEditorPlace(id, arguments);
    if (name == QLatin1String("editor_edit"))
        return toolEditorEdit(id, arguments);
    if (name == QLatin1String("module_config"))
        return toolModuleConfig(id, arguments);
    // C4 — capacités manquantes (doc 02 §5.2).
    if (name == QLatin1String("state_query"))
        return toolStateQuery(id, arguments);
    if (name == QLatin1String("roster_edit"))
        return toolRosterEdit(id, arguments);
    if (name == QLatin1String("screenshot"))
        return toolScreenshot(id, arguments);
    // D4 — branchement du canal sur le journal métier (Q-E06). Le rôle du token
    // fixe l'audience (proposant = public ; arbitre = public + réservé, D20).
    if (name == QLatin1String("events_poll"))
        return toolEventsPoll(id, arguments, role);
    // A9 — dry-run local sur le banc d'essai (D42). Verdict + métriques complets ;
    // pass local ≠ acceptation ; non journalisé au journal partagé (D44).
    if (name == QLatin1String("artifact_dryrun"))
        return toolArtifactDryrun(id, arguments);

    // Pivot de proposition (S-1/S-2) et espace mémoire (S-3/S-4). Le contrôle
    // de rôle est déjà fait par toolAllowedForRole (arbiter_verdict = arbitre).
    if (name == QLatin1String("memory_set"))
        return toolMemorySet(id, arguments);
    if (name == QLatin1String("artifact_submit"))
        return toolArtifactSubmit(id, arguments);
    if (name == QLatin1String("arbiter_verdict"))
        return toolArbiterVerdict(id, arguments);

    // Ne devrait pas arriver : toolExists a filtré en amont.
    return makeAppError(id, kInvalidParams, kAppUnknownTool,
                        QStringLiteral("Unknown tool: %1").arg(name),
                        /*retryable=*/false);
}

QJsonObject AiGatewayServer::toolHelp(const QJsonValue &id, const QJsonObject &arguments)
{
    // Divulgation progressive (doc 02 §3) : sommaire par défaut, doc d'un tool si
    // `topic` nomme un tool du catalogue. Source = descripteurs du manifeste.
    const QString topic = arguments.value(QStringLiteral("topic")).toString().trimmed();
    if (topic.isEmpty()) {
        QString text = QStringLiteral(
            "Canal IA Meownopoly — tools disponibles (manifeste v1). "
            "Appelle help(topic:\"<tool>\") pour le détail d'un tool.\n");
        for (const ToolDef &def : toolTable()) {
            const QJsonObject d = toolDescriptor(QString::fromLatin1(def.name));
            text += QStringLiteral("- %1 : %2\n")
                        .arg(QString::fromLatin1(def.name),
                             d.value(QStringLiteral("description")).toString());
        }
        return makeToolTextResult(id, text);
    }

    if (!toolExists(topic))
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("help: topic inconnu '%1'").arg(topic),
                            /*retryable=*/false);

    const QJsonObject d = toolDescriptor(topic);
    QString text = QStringLiteral("%1 — %2\n\nSchéma d'entrée :\n%3")
                       .arg(topic, d.value(QStringLiteral("description")).toString(),
                            QString::fromUtf8(QJsonDocument(
                                d.value(QStringLiteral("inputSchema")).toObject())
                                    .toJson(QJsonDocument::Indented)));
    return makeToolTextResult(id, text);
}

QJsonObject AiGatewayServer::toolEditorPlace(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString kind = arguments.value(QStringLiteral("kind")).toString();
    const QJsonObject p = arguments.value(QStringLiteral("params")).toObject();

    QString hook;
    QVariantList args;
    if (kind == QLatin1String("asset")) {
        hook = QStringLiteral("placeAsset");
        args = { p.value(QStringLiteral("assetId")).toVariant(),
                 p.value(QStringLiteral("category")).toVariant(),
                 p.value(QStringLiteral("type")).toVariant(),
                 p.value(QStringLiteral("gridX")).toVariant(),
                 p.value(QStringLiteral("gridY")).toVariant() };
    } else if (kind == QLatin1String("case")) {
        hook = QStringLiteral("placeCase");
        args = { p.value(QStringLiteral("caseType")).toVariant(),
                 p.value(QStringLiteral("gridX")).toVariant(),
                 p.value(QStringLiteral("gridY")).toVariant() };
    } else if (kind == QLatin1String("zone")) {
        hook = QStringLiteral("placeZone");
        args = { p.value(QStringLiteral("points")).toVariant(),
                 p.value(QStringLiteral("options")).toVariant() };
    } else if (kind == QLatin1String("npc")) {
        hook = QStringLiteral("placeNPC");
        args = { p.value(QStringLiteral("visualKind")).toVariant(),
                 p.value(QStringLiteral("ref")).toVariant(),
                 p.value(QStringLiteral("gridX")).toVariant(),
                 p.value(QStringLiteral("gridY")).toVariant(),
                 p.value(QStringLiteral("options")).toVariant() };
    } else if (kind == QLatin1String("enemy")) {
        hook = QStringLiteral("placeEnemy");
        args = { p.value(QStringLiteral("modelName")).toVariant(),
                 p.value(QStringLiteral("gridX")).toVariant(),
                 p.value(QStringLiteral("gridY")).toVariant(),
                 p.value(QStringLiteral("options")).toVariant() };
    } else if (kind == QLatin1String("crate")) {
        hook = QStringLiteral("placeCrate");
        args = { p.value(QStringLiteral("gridX")).toVariant(),
                 p.value(QStringLiteral("gridY")).toVariant(),
                 p.value(QStringLiteral("options")).toVariant() };
    } else {
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("editor_place: kind invalide '%1'").arg(kind),
                            /*retryable=*/false);
    }

    bool ok = false;
    QString err;
    const QJsonObject res = invokeHook(hook, args, ok, err);
    if (!ok)
        return makeAppError(id, kInvalidParams, kAppSceneUnavailable, err,
                            /*retryable=*/true);
    return makeToolResult(id, res);
}

QJsonObject AiGatewayServer::toolEditorEdit(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString uuid = arguments.value(QStringLiteral("uuid")).toString();
    const QString op = arguments.value(QStringLiteral("op")).toString();
    const QJsonObject p = arguments.value(QStringLiteral("params")).toObject();
    if (uuid.isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("editor_edit: 'uuid' requis"),
                            /*retryable=*/false);

    QString hook;
    QVariantList args;
    if (op == QLatin1String("set_trigger")) {
        hook = QStringLiteral("setZoneTrigger");
        args = { uuid, p.toVariantMap() };
    } else if (op == QLatin1String("set_dialogue")) {
        hook = QStringLiteral("setNpcDialogue");
        args = { uuid, p.value(QStringLiteral("lines")).toVariant() };
    } else if (op == QLatin1String("move")) {
        // C4 : déplacement par uuid (coords grille absolues).
        hook = QStringLiteral("moveTile");
        args = { uuid, p.value(QStringLiteral("gridX")).toVariant(),
                 p.value(QStringLiteral("gridY")).toVariant() };
    } else if (op == QLatin1String("resize")) {
        hook = QStringLiteral("resizeTile");
        args = { uuid, p.value(QStringLiteral("w")).toVariant(),
                 p.value(QStringLiteral("h")).toVariant() };
    } else if (op == QLatin1String("delete")) {
        hook = QStringLiteral("deleteTile");
        args = { uuid };
    } else if (op == QLatin1String("link")) {
        // uuid = source ; params.target = cible ; params.kind = next|previous.
        hook = QStringLiteral("linkTiles");
        args = { uuid, p.value(QStringLiteral("target")).toVariant(),
                 p.value(QStringLiteral("kind")).toVariant() };
    } else if (op == QLatin1String("unlink")) {
        hook = QStringLiteral("unlinkTiles");
        args = { uuid, p.value(QStringLiteral("target")).toVariant(),
                 p.value(QStringLiteral("kind")).toVariant() };
    } else {
        // set_param : le paramétrage typé par sous-objet (case/npc/enemy/zone…)
        // passe déjà par set_trigger/set_dialogue ou par des ops dédiées ;
        // la voie générique par uuid reste à cadrer (S-3/S-5). Non câblé.
        return toolNotImplemented(
            id, QStringLiteral("editor_edit(%1)").arg(op),
            QStringLiteral("S-3/S-5 (set_param générique par uuid)"));
    }

    bool ok = false;
    QString err;
    const QJsonObject res = invokeHook(hook, args, ok, err);
    if (!ok)
        return makeAppError(id, kInvalidParams, kAppSceneUnavailable, err,
                            /*retryable=*/true);
    return makeToolResult(id, res);
}

QJsonObject AiGatewayServer::toolModuleConfig(const QJsonValue &id, const QJsonObject &arguments)
{
    // S-5 (D41) — module_config généralisé à TOUT module gameplay. Le module est
    // adressé sur le singleton C++ `GameplayModuleManager` (source de vérité,
    // GUI thread), pas via un hook d'éditeur : l'activation d'un module n'est pas
    // une mutation de tuile et doit fonctionner hors scène d'édition (banc, partie).
    const QString moduleId = arguments.value(QStringLiteral("id")).toString();
    if (moduleId.trimmed().isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("module_config: 'id' (moduleId) requis"),
                            /*retryable=*/false);

    GameplayModuleManager *mgr = GameplayModuleManager::instance();
    GameplayModule *mod = mgr->moduleById(moduleId);
    if (!mod)
        return makeAppError(
            id, kInvalidParams, kAppInvalidParams,
            QStringLiteral("module_config: module inconnu '%1'").arg(moduleId),
            /*retryable=*/false);

    const bool enabled = arguments.value(QStringLiteral("enabled")).toBool();
    mgr->setModuleEnabled(moduleId, enabled);

    // Résultat porté au schéma d'une **opération `structure`** (D41) : intégrable
    // au lot atomique de l'enveloppe (D14) — l'IA active un module et pose dans la
    // même proposition l'artefact qui en dépend, jugé d'un bloc par l'arbitre.
    QJsonObject res;
    res[QStringLiteral("ok")] = true;
    res[QStringLiteral("requestType")] = QStringLiteral("structure");
    res[QStringLiteral("id")] = moduleId;
    res[QStringLiteral("enabled")] = mod->enabled();
    res[QStringLiteral("effectiveEnabled")] = mod->effectiveEnabled();

    // `params` (D41, optionnel) : aucun mécanisme générique de paramétrage de
    // module n'existe au MVP — seule l'activation est appliquée. On le signale
    // sans échouer (l'IA voit paramsApplied=false et peut passer par les tools
    // dédiés, ex. stats.addModifier).
    const QJsonObject params = arguments.value(QStringLiteral("params")).toObject();
    if (!params.isEmpty()) {
        res[QStringLiteral("paramsApplied")] = false;
        res[QStringLiteral("note")] = QStringLiteral(
            "params ignoré au MVP : pas de paramétrage générique de module "
            "(seule l'activation est appliquée).");
    }

    // État courant de tous les modules (satisfait la vérification requiresModules
    // du même lot côté P0 / static_validator, D41).
    res[QStringLiteral("modules")] = mgr->moduleStateJson();
    return makeToolResult(id, res);
}

// ============================================================================
// C4 — Introspection d'état, roster, énumérations, capture (doc 02 §5.2)
// ============================================================================

QJsonObject AiGatewayServer::enumValues(const QString &enumName, bool &known)
{
    known = true;
    const auto fromMeta = [&](const QString &name, const QMetaEnum &me) {
        QJsonObject values;
        for (int i = 0; i < me.keyCount(); ++i)
            values[QString::fromLatin1(me.key(i))] = me.value(i);
        QJsonObject o;
        o[QStringLiteral("name")] = name;
        o[QStringLiteral("values")] = values;
        return o;
    };

    if (enumName == QLatin1String("CaseType"))
        return fromMeta(enumName, QMetaEnum::fromType<Case::CaseType>());
    if (enumName == QLatin1String("TileType"))
        return fromMeta(enumName, QMetaEnum::fromType<ItemSnapable::TileType>());
    if (enumName == QLatin1String("PickMode"))
        return fromMeta(enumName, QMetaEnum::fromType<PlayerProfile::PickMode>());
    // TriggerMode : par défaut celui des PNJ (Q_ENUM Proximity/Click/Always).
    if (enumName == QLatin1String("TriggerMode")
        || enumName == QLatin1String("NpcTriggerMode"))
        return fromMeta(QStringLiteral("TriggerMode"),
                        QMetaEnum::fromType<NPCParameter::TriggerMode>());
    // Déclenchement de zone : entier libre (pas de Q_ENUM), table figée.
    if (enumName == QLatin1String("ZoneTriggerMode")) {
        QJsonObject values;
        values[QStringLiteral("None")] = 0;
        values[QStringLiteral("PressurePlate")] = 1;
        QJsonObject o;
        o[QStringLiteral("name")] = enumName;
        o[QStringLiteral("values")] = values;
        return o;
    }

    known = false;
    return {};
}

QJsonObject AiGatewayServer::toolStateQuery(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString what = arguments.value(QStringLiteral("what")).toString();
    const QJsonObject filter = arguments.value(QStringLiteral("filter")).toObject();

    if (what.isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("state_query: champ 'what' requis"),
                            /*retryable=*/false);

    // Énumérations : résolues en C++ (QMetaEnum), sans la scène QML.
    if (what == QLatin1String("enums")) {
        const QString enumName = filter.value(QStringLiteral("name")).toString();
        if (enumName.isEmpty())
            return makeAppError(id, kInvalidParams, kAppInvalidParams,
                                QStringLiteral("state_query(enums): filter.name requis "
                                               "(ex. CaseType, TileType, PickMode, TriggerMode)"),
                                /*retryable=*/false);
        bool known = false;
        const QJsonObject e = enumValues(enumName, known);
        if (!known) {
            QJsonObject details;
            details[QStringLiteral("requested")] = enumName;
            details[QStringLiteral("known")] = QJsonArray{
                QStringLiteral("CaseType"), QStringLiteral("TileType"),
                QStringLiteral("PickMode"), QStringLiteral("TriggerMode"),
                QStringLiteral("ZoneTriggerMode") };
            return makeAppError(id, kInvalidParams, kAppUnknownEnum,
                                QStringLiteral("Enum inconnu au catalogue: %1").arg(enumName),
                                /*retryable=*/false, details);
        }
        QJsonObject res = e;
        res[QStringLiteral("ok")] = true;
        return makeToolResult(id, res);
    }

    // Règlement courant (T4-4) : lu sur le singleton C++, sans la scène QML.
    if (what == QLatin1String("rules")) {
        RulesEngine *engine = RulesEngine::instance();
        QJsonObject res = engine->toJson();
        res[QStringLiteral("hostAuthority")] = engine->hostAuthority();
        res[QStringLiteral("ok")] = true;
        return makeToolResult(id, res);
    }

    // Espace mémoire (S-3/S-4) : blob session+joueurs, secrets D20 retirés
    // (même liste conservatrice que la persistance GameSave).
    if (what == QLatin1String("memory")) {
        QJsonObject res;
        res[QStringLiteral("memory")] =
            GameSave::sanitizeSecrets(MemoryStore::instance()->toJson());
        res[QStringLiteral("ok")] = true;
        return makeToolResult(id, res);
    }

    // Propositions (S-1) : projections du cycle de vie, du + ancien au + récent.
    if (what == QLatin1String("proposals")) {
        ProposalLifecycle *lifecycle = ProposalLifecycle::instance();
        QJsonObject res;
        res[QStringLiteral("proposals")] =
            QJsonArray::fromVariantList(lifecycle->proposals());
        res[QStringLiteral("queued")] =
            QJsonArray::fromVariantList(lifecycle->queuedIds());
        res[QStringLiteral("ok")] = true;
        return makeToolResult(id, res);
    }

    // Le reste s'appuie sur les hooks de la scène (éditeur chargé requis).
    QString hook;
    QVariantList args;
    if (what == QLatin1String("tiles")) {
        hook = QStringLiteral("listTiles");
        args = { filter.toVariantMap() };
    } else if (what == QLatin1String("tile")) {
        const QString uuid = filter.value(QStringLiteral("uuid")).toString();
        if (uuid.isEmpty())
            return makeAppError(id, kInvalidParams, kAppInvalidParams,
                                QStringLiteral("state_query(tile): filter.uuid requis"),
                                /*retryable=*/false);
        hook = QStringLiteral("getTile");
        args = { uuid };
    } else if (what == QLatin1String("roster") || what == QLatin1String("players")) {
        hook = QStringLiteral("listRoster");
        args = {};
    } else {
        return makeAppError(
            id, kInvalidParams, kAppInvalidParams,
            QStringLiteral("state_query: 'what' inconnu '%1' (tiles|tile|enums|"
                           "roster|players|rules|memory|proposals)").arg(what),
            /*retryable=*/false);
    }

    bool ok = false;
    QString err;
    const QJsonObject res = invokeHook(hook, args, ok, err);
    if (!ok)
        return makeAppError(id, kInvalidParams, kAppSceneUnavailable, err,
                            /*retryable=*/true);
    return makeToolResult(id, res);
}

QJsonObject AiGatewayServer::toolRosterEdit(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString op = arguments.value(QStringLiteral("op")).toString();
    const QJsonObject p = arguments.value(QStringLiteral("params")).toObject();

    QString hook;
    QVariantList args;
    if (op == QLatin1String("add_profile")) {
        hook = QStringLiteral("addPlayerProfile");
        // params.profile facultatif : objet de champs ({} = profil par défaut).
        args = { p.value(QStringLiteral("profile")).toObject().toVariantMap() };
    } else if (op == QLatin1String("remove_profile")) {
        hook = QStringLiteral("removePlayerProfile");
        args = { p.value(QStringLiteral("id")).toVariant() };
    } else if (op == QLatin1String("update_profile")) {
        hook = QStringLiteral("updatePlayerProfile");
        args = { p.value(QStringLiteral("id")).toVariant(),
                 p.value(QStringLiteral("fields")).toObject().toVariantMap() };
    } else if (op == QLatin1String("reorder_profile")) {
        hook = QStringLiteral("reorderPlayerProfile");
        args = { p.value(QStringLiteral("id")).toVariant(),
                 p.value(QStringLiteral("newIndex")).toVariant() };
    } else if (op == QLatin1String("set_limits")) {
        hook = QStringLiteral("setMapPlayerLimits");
        args = { p.toVariantMap() };
    } else {
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("roster_edit: op invalide '%1'").arg(op),
                            /*retryable=*/false);
    }

    bool ok = false;
    QString err;
    const QJsonObject res = invokeHook(hook, args, ok, err);
    if (!ok)
        return makeAppError(id, kInvalidParams, kAppSceneUnavailable, err,
                            /*retryable=*/true);
    return makeToolResult(id, res);
}

QJsonObject AiGatewayServer::toolScreenshot(const QJsonValue &id, const QJsonObject &arguments)
{
    Q_UNUSED(arguments);

    // Plafond par session d'IA (D22) : consomme une unité du budget du token.
    if (!consumeScreenshotBudget(m_currentToken))
        return makeAppError(
            id, kInvalidParams, kAppScreenshotQuota,
            QStringLiteral("Plafond de captures atteint (%1 / session, D22).")
                .arg(MEOW_AI_GATEWAY_SCREENSHOT_CAP),
            /*retryable=*/false);

    QQuickWindow *win = primaryQuickWindow();
    if (!win)
        return makeAppError(id, kInvalidParams, kAppSceneUnavailable,
                            QStringLiteral("Aucune fenêtre de jeu à capturer"),
                            /*retryable=*/true);

    // grabWindow() est synchrone sur le GUI thread (où tourne la passerelle).
    const QImage img = win->grabWindow();
    if (img.isNull())
        return makeAppError(id, kInvalidParams, kAppToolFailed,
                            QStringLiteral("grabWindow() a renvoyé une image vide"),
                            /*retryable=*/true);

    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    if (!img.save(&buffer, "PNG")) {
        buffer.close();
        return makeAppError(id, kInvalidParams, kAppToolFailed,
                            QStringLiteral("Échec de l'encodage PNG de la capture"),
                            /*retryable=*/true);
    }
    buffer.close();

    // Résultat MCP image (content type "image", data base64, mimeType).
    QJsonObject imageItem;
    imageItem[QStringLiteral("type")] = QStringLiteral("image");
    imageItem[QStringLiteral("data")] = QString::fromLatin1(png.toBase64());
    imageItem[QStringLiteral("mimeType")] = QStringLiteral("image/png");
    QJsonObject result;
    result[QStringLiteral("content")] = QJsonArray{ imageItem };
    result[QStringLiteral("isError")] = false;
    return makeResult(id, result);
}

QJsonObject AiGatewayServer::toolNotImplemented(const QJsonValue &id, const QString &name,
                                                const QString &followUp)
{
    QJsonObject details;
    details[QStringLiteral("tool")] = name;
    details[QStringLiteral("followUp")] = followUp;
    return makeAppError(id, kInvalidParams, kAppNotImplemented,
                        QStringLiteral("Tool '%1' déclaré au manifeste mais pas "
                                       "encore câblé (voir %2).").arg(name, followUp),
                        /*retryable=*/false, details);
}

// ============================================================================
// D4 — events_poll : branchement du canal sur le journal métier (Q-E06)
// ============================================================================

QJsonObject AiGatewayServer::toolEventsPoll(const QJsonValue &id, const QJsonObject &arguments,
                                            Role role)
{
    // `cursor` : entier requis = seq du journal métier hôte (D19). En JSON, tout
    // nombre est un double ; on refuse un cursor absent ou non numérique.
    const QJsonValue cv = arguments.value(QStringLiteral("cursor"));
    if (!cv.isDouble())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("events_poll: 'cursor' (entier) requis"),
                            /*retryable=*/false);
    const double cd = cv.toDouble();
    const quint64 cursor = cd > 0.0 ? static_cast<quint64>(cd) : 0;

    // Filtrage par rôle appliqué CÔTÉ SERVEUR (D20) : le token porte le rôle,
    // l'agent ne choisit pas son audience.
    const int audience = (role == Role::Arbiter)
                             ? GameplayEventBus::AudienceArbiter
                             : GameplayEventBus::AudienceProposer;

    // Projection au schéma canal (curée, D44) : { entries, nextCursor, truncated,
    // oldestSeq, count }. Les verdicts de dry-run n'y figurent pas (non ingérés).
    const QVariantMap poll =
        GameplayEventBus::instance()->canalPoll(cursor, audience);

    QJsonObject out = QJsonObject::fromVariantMap(poll);
    out[QStringLiteral("ok")] = true;
    return makeToolResult(id, out);
}

QString AiGatewayServer::injectedEventSummary(Role role, quint64 cursor) const
{
    // Bloc compact du résumé injecté au pré-prompt d'un tour d'IA (Q-E06
    // injectedBlock, plafonné à 250 lignes, D44). Le rôle fixe l'audience (D20).
    // Consommé par l'orchestration de tour (C5/C7) au spawn / début d'invocation.
    const int audience = (role == Role::Arbiter)
                             ? GameplayEventBus::AudienceArbiter
                             : GameplayEventBus::AudienceProposer;
    const QVariantMap summary =
        GameplayEventBus::instance()->canalSummary(cursor, audience);
    return summary.value(QStringLiteral("text")).toString();
}

// ============================================================================
// A9 — artifact_dryrun : dry-run local sur le banc d'essai (D42)
// ============================================================================

meow::bench::BenchPool *AiGatewayServer::ensureBenchPool()
{
    // Instancié à la première demande (aucun coût si l'IA ne fait pas de dry-run).
    // Un seul pool partagé : au MVP la file transactionnelle sérialise déjà les
    // propositions (le pool sérialise les jobs de dry-run des deux identités).
    if (!m_benchPool)
        m_benchPool = new meow::bench::BenchPool(this);
    return m_benchPool;
}

QJsonObject AiGatewayServer::makeDryrunResult(const QJsonValue &id, const QJsonObject &verdict,
                                              const QString &stage)
{
    // Schéma retourné à l'IA (manifeste : { verdict, metrics }), enrichi du stage
    // (P0 ou banc) et du rappel D42. `ok=true` : le dry-run s'est EXÉCUTÉ — un
    // échec de banc n'est pas une erreur de tool, c'est un résultat exploitable.
    QJsonObject out;
    const QString v = verdict.value(QStringLiteral("verdict")).toString();
    out[QStringLiteral("verdict")] = v.isEmpty() ? QStringLiteral("fail") : v;
    out[QStringLiteral("pass")] = (v == QLatin1String("pass"));
    out[QStringLiteral("stage")] = stage;
    out[QStringLiteral("failures")] = verdict.value(QStringLiteral("failures"));
    out[QStringLiteral("metrics")] = verdict.value(QStringLiteral("metrics"));
    if (verdict.contains(QStringLiteral("durationMs")))
        out[QStringLiteral("durationMs")] = verdict.value(QStringLiteral("durationMs"));
    // Rappel D42 : le dry-run est une aide d'itération, pas une garantie.
    out[QStringLiteral("note")] = QStringLiteral(
        "Dry-run local (D42) : un pass local ne vaut PAS acceptation. À la "
        "soumission, la proposition repasse au P0 de l'hôte, au banc, puis à "
        "l'arbitre. Ce dry-run n'est pas inscrit au journal partagé.");
    out[QStringLiteral("ok")] = true;
    return makeToolResult(id, out);
}

QJsonObject AiGatewayServer::toolArtifactDryrun(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString source = arguments.value(QStringLiteral("source")).toString();
    if (source.trimmed().isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("artifact_dryrun: 'source' requis"),
                            /*retryable=*/false);

    // Quota par session (D42). Comme le budget de captures, porté par le token et
    // remis à 0 à la rotation. Consommé AVANT tout travail (P0 + spawn).
    if (!consumeDryrunBudget(m_currentToken))
        return makeAppError(
            id, kInvalidParams, kAppDryrunQuota,
            QStringLiteral("Quota de dry-run atteint (%1 / session, D42).")
                .arg(MEOW_BENCH_DRYRUN_QUOTA),
            /*retryable=*/false);

    const QString targetUuid = arguments.value(QStringLiteral("targetUuid")).toString();

    // Préfiltre P0 statique d'abord — même ORDRE que le pipeline réel (doc 12 §3 :
    // « inutile de payer un process pour un import interdit »). Un échec P0 rend un
    // verdict immédiat, sans spawner le banc.
    meow::sandbox::StaticValidationInput sin;
    sin.source = source;
    const meow::sandbox::StaticValidationResult p0 =
        meow::sandbox::StaticValidator::validate(sin);
    if (!p0.passed()) {
        QJsonObject verdict;
        verdict[QStringLiteral("verdict")] = QStringLiteral("fail");
        QJsonArray fs;
        for (const meow::sandbox::StaticFinding &f : p0.findings)
            fs.append(f.toJson());
        verdict[QStringLiteral("failures")] = fs;
        QJsonObject metrics;
        metrics[QStringLiteral("imports")] = QJsonArray::fromStringList(p0.imports);
        verdict[QStringLiteral("metrics")] = metrics;
        return makeDryrunResult(id, verdict, QStringLiteral("P0"));
    }

    // Job du banc (contrat bench_protocol). Snapshot MINIMAL au MVP : la
    // reconstruction sur la carte courante réelle passera par le pipeline de
    // proposition (Phase 2) ; ici on valide le comportement de l'artefact à vide.
    const QString jobId =
        QStringLiteral("dryrun_") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QJsonObject artifact;
    artifact[QStringLiteral("source")] = source;
    if (!targetUuid.isEmpty())
        artifact[QStringLiteral("targetUuid")] = targetUuid;
    // contentHash : sert aussi de clé de cache de verdicts (A8) → un dry-run
    // répété d'une source identique est servi sans re-spawn.
    artifact[QStringLiteral("contentHash")] = QString::fromLatin1(
        QCryptographicHash::hash(source.toUtf8(), QCryptographicHash::Sha256).toHex());

    QJsonObject snapshot;
    snapshot[QStringLiteral("map")] = QJsonObject{};
    snapshot[QStringLiteral("memory")] = QJsonObject{};
    // S-5 (D41) : le snapshot du banc porte l'état des modules gameplay pour
    // tester l'artefact dans les conditions réelles (doc 12 §2.3). La map/mémoire
    // restent minimales au MVP (dry-run à vide) mais l'état des modules, lui, est
    // global au jeu et disponible ici sans reconstruction.
    snapshot[QStringLiteral("modules")] =
        GameplayModuleManager::instance()->moduleStateJson();

    QJsonObject job;
    job[QStringLiteral("jobId")] = jobId;
    job[QStringLiteral("benchVersion")] = meow::bench::kBenchVersion;
    job[QStringLiteral("snapshot")] = snapshot;
    job[QStringLiteral("artifact")] = artifact;
    job[QStringLiteral("budgets")] = QJsonObject{};   // le banc applique ses défauts
    job[QStringLiteral("stimuli")] = QJsonArray{};
    job[QStringLiteral("seed")] = 0;

    // Exécution one-shot via le pool (A8). Le pool est 100 % asynchrone
    // (verdictReady) ; le tool MCP est synchrone → on attend le verdict dans un
    // event loop imbriqué. Le GUI reste vivant (l'event loop continue de traiter
    // les événements — invariant doc 12 §1, comme l'attente bloquante de
    // artifact_submit). Filet de sécurité si le pool ne répond jamais.
    meow::bench::BenchPool *pool = ensureBenchPool();

    QJsonObject verdict;
    bool got = false;
    QEventLoop loop;
    const QMetaObject::Connection conn = connect(
        pool, &meow::bench::BenchPool::verdictReady, &loop,
        [&](const QString &vid, const QJsonObject &v) {
            if (vid != jobId)
                return;   // verdict d'un autre job (dry-run concurrent) : ignorer
            verdict = v;
            got = true;
            loop.quit();
        });

    QTimer safety;
    safety.setSingleShot(true);
    connect(&safety, &QTimer::timeout, &loop, &QEventLoop::quit);
    // Le superviseur a son propre timeout dur (MEOW_BENCH_TIMEOUT_MS) et rend un
    // verdict synthétique ; ce filet ne couvre qu'un blocage du pool lui-même.
    safety.start(MEOW_BENCH_TIMEOUT_MS + 5000);

    pool->submit(job);
    if (!got)
        loop.exec();
    disconnect(conn);

    if (!got)
        return makeAppError(id, kInvalidParams, kAppBenchUnavailable,
                            QStringLiteral("Le banc n'a pas rendu de verdict de "
                                           "dry-run dans le délai imparti"),
                            /*retryable=*/true);

    return makeDryrunResult(id, verdict, QStringLiteral("bench"));
}

bool AiGatewayServer::consumeDryrunBudget(const QString &token)
{
    const auto it = m_tokens.find(token);
    if (it == m_tokens.end())
        return false; // token inconnu = pas de budget (défense en profondeur)
    if (it->dryrunsUsed >= MEOW_BENCH_DRYRUN_QUOTA)
        return false;
    ++it->dryrunsUsed;
    return true;
}

// ============================================================================
// Fabriques de résultats de tool (MCP) et pont vers la scène QML
// ============================================================================

QJsonObject AiGatewayServer::makeToolResult(const QJsonValue &id, const QJsonObject &hookResult)
{
    // Les hooks renvoient `{ ok: bool, error?: string, ... }`. On expose :
    //  - content[texte] : JSON compact lisible par l'agent (MCP standard) ;
    //  - structuredContent : l'objet natif (MCP 2025-06-18) ;
    //  - isError : reflète l'échec applicatif du hook (ok=false).
    const bool okField = hookResult.value(QStringLiteral("ok")).toBool(true);
    QJsonObject textItem;
    textItem[QStringLiteral("type")] = QStringLiteral("text");
    textItem[QStringLiteral("text")] =
        QString::fromUtf8(QJsonDocument(hookResult).toJson(QJsonDocument::Compact));
    QJsonObject result;
    result[QStringLiteral("content")] = QJsonArray{ textItem };
    result[QStringLiteral("structuredContent")] = hookResult;
    result[QStringLiteral("isError")] = !okField;
    return makeResult(id, result);
}

QJsonObject AiGatewayServer::makeToolTextResult(const QJsonValue &id, const QString &text)
{
    QJsonObject textItem;
    textItem[QStringLiteral("type")] = QStringLiteral("text");
    textItem[QStringLiteral("text")] = text;
    QJsonObject result;
    result[QStringLiteral("content")] = QJsonArray{ textItem };
    result[QStringLiteral("isError")] = false;
    return makeResult(id, result);
}

QObject *AiGatewayServer::findByObjectName(QObject *root, const QString &name)
{
    if (!root)
        return nullptr;
    if (root->objectName() == name)
        return root;
    // Descente par l'arbre visuel quand possible (les hooks sont un Item).
    if (auto *item = qobject_cast<QQuickItem *>(root)) {
        const QList<QQuickItem *> kids = item->childItems();
        for (QQuickItem *c : kids)
            if (QObject *hit = findByObjectName(c, name))
                return hit;
    } else {
        const QObjectList kids = root->children();
        for (QObject *c : kids)
            if (QObject *hit = findByObjectName(c, name))
                return hit;
    }
    return nullptr;
}

QObject *AiGatewayServer::findEditorHooks() const
{
    const QList<QWindow *> tops = QGuiApplication::topLevelWindows();
    for (QWindow *w : tops) {
        auto *qw = qobject_cast<QQuickWindow *>(w);
        if (!qw || !qw->contentItem())
            continue;
        if (QObject *hit = findByObjectName(qw->contentItem(),
                                            QStringLiteral("editorAutomationHooks")))
            return hit;
    }
    return nullptr;
}

QQuickWindow *AiGatewayServer::primaryQuickWindow() const
{
    const QList<QWindow *> tops = QGuiApplication::topLevelWindows();
    // Priorité à une fenêtre visible ; à défaut, la première QQuickWindow.
    QQuickWindow *fallback = nullptr;
    for (QWindow *w : tops) {
        auto *qw = qobject_cast<QQuickWindow *>(w);
        if (!qw)
            continue;
        if (qw->isVisible())
            return qw;
        if (!fallback)
            fallback = qw;
    }
    return fallback;
}

QJsonObject AiGatewayServer::invokeHook(const QString &fn, const QVariantList &args,
                                        bool &ok, QString &error)
{
    ok = false;
    QObject *hooks = findEditorHooks();
    if (!hooks) {
        error = QStringLiteral("Éditeur non chargé (hooks 'editorAutomationHooks' introuvables)");
        return {};
    }
    if (args.size() > 10) {
        error = QStringLiteral("Hook '%1' : trop d'arguments (%2 > 10)").arg(fn).arg(args.size());
        return {};
    }

    // Les hooks sont des fonctions JS QML : le meta-object annonce des paramètres
    // et un retour de type QVariant. Voie identique à AutomationServer::cmdInvoke.
    const QMetaObject *mo = hooks->metaObject();
    QMetaMethod chosen;
    bool found = false;
    for (int i = 0; i < mo->methodCount(); ++i) {
        const QMetaMethod mm = mo->method(i);
        if (QString::fromLatin1(mm.name()) != fn)
            continue;
        if (mm.parameterCount() != args.size())
            continue;
        chosen = mm;
        found = true;
        break;
    }
    if (!found) {
        error = QStringLiteral("Hook '%1' (%2 arg) introuvable").arg(fn).arg(args.size());
        return {};
    }

    QVariantList vargs = args;
    QGenericArgument gen[10];
    for (int i = 0; i < vargs.size(); ++i)
        gen[i] = QGenericArgument("QVariant", &vargs[i]);

    QVariant retVal;
    QGenericReturnArgument ret("QVariant", &retVal);
    const bool invoked = chosen.invoke(hooks, Qt::DirectConnection, ret,
                                       gen[0], gen[1], gen[2], gen[3], gen[4],
                                       gen[5], gen[6], gen[7], gen[8], gen[9]);
    if (!invoked) {
        error = QStringLiteral("Échec de l'invocation du hook '%1'").arg(fn);
        return {};
    }
    ok = true;
    return variantToJson(retVal).toObject();
}

QJsonValue AiGatewayServer::variantToJson(const QVariant &v)
{
    // Une fonction JS QML retourne un QJSValue enveloppé dans le QVariant retour :
    // le déballer avant conversion, sinon QJsonValue::fromVariant produit `null`.
    if (v.metaType().id() == qMetaTypeId<QJSValue>())
        return QJsonValue::fromVariant(v.value<QJSValue>().toVariant());
    return QJsonValue::fromVariant(v);
}

QVariant AiGatewayServer::jsonToVariant(const QJsonValue &v)
{
    return v.toVariant();
}

// ============================================================================
// Fabriques de messages JSON-RPC 2.0
// ============================================================================

QJsonObject AiGatewayServer::makeResult(const QJsonValue &id, const QJsonValue &result)
{
    QJsonObject resp;
    resp[QStringLiteral("jsonrpc")] = QStringLiteral("2.0");
    resp[QStringLiteral("id")] = id;
    resp[QStringLiteral("result")] = result;
    return resp;
}

QJsonObject AiGatewayServer::makeError(const QJsonValue &id, int code,
                                       const QString &message, const QJsonValue &data)
{
    QJsonObject err;
    err[QStringLiteral("code")] = code;
    err[QStringLiteral("message")] = message;
    if (!data.isNull())
        err[QStringLiteral("data")] = data;

    QJsonObject resp;
    resp[QStringLiteral("jsonrpc")] = QStringLiteral("2.0");
    resp[QStringLiteral("id")] = id;
    resp[QStringLiteral("error")] = err;
    return resp;
}

QJsonObject AiGatewayServer::makeAppError(const QJsonValue &id, int rpcCode,
                                          const QString &appCode, const QString &message,
                                          bool retryable, const QJsonValue &details)
{
    // Contrat d'erreur IA (doc 02 §6) : le code JSON-RPC numérique reste standard,
    // et error.data porte le contrat exploitable { code stable, retryable, details? }.
    QJsonObject data;
    data[QStringLiteral("code")] = appCode;
    data[QStringLiteral("retryable")] = retryable;
    if (!details.isNull() && !details.isUndefined())
        data[QStringLiteral("details")] = details;
    return makeError(id, rpcCode, message, data);
}

// ============================================================================
// Authentification, tokens de session et quotas (C2)
// ============================================================================

void AiGatewayServer::initSessionTokens()
{
    m_tokens.clear();
    m_proposerToken = generateToken();
    m_arbiterToken = generateToken();
    // Collision d'entropie 2×256 bits négligeable, mais on garantit la disjonction.
    while (m_arbiterToken == m_proposerToken)
        m_arbiterToken = generateToken();
    m_tokens.insert(m_proposerToken, TokenState{Role::Proposer, {}});
    m_tokens.insert(m_arbiterToken, TokenState{Role::Arbiter, {}});
}

void AiGatewayServer::rotateSessionTokens()
{
    initSessionTokens();
}

QString AiGatewayServer::generateToken()
{
    // Entropie cryptographique (QRandomGenerator::system), rendue en hexadécimal
    // pour un usage sûr en en-tête HTTP. MEOW_AI_GATEWAY_TOKEN_BYTES est multiple
    // de 4 → remplissage par mots de 32 bits.
    constexpr int kBytes = MEOW_AI_GATEWAY_TOKEN_BYTES;
    static_assert(kBytes % 4 == 0, "MEOW_AI_GATEWAY_TOKEN_BYTES doit être multiple de 4");
    QByteArray raw(kBytes, Qt::Uninitialized);
    QRandomGenerator::system()->fillRange(
        reinterpret_cast<quint32 *>(raw.data()), kBytes / 4);
    return QString::fromLatin1(raw.toHex());
}

bool AiGatewayServer::validateToken(const QString &token, Role &outRole) const
{
    const auto it = m_tokens.constFind(token);
    if (it == m_tokens.constEnd())
        return false;
    outRole = it->role;
    return true;
}

bool AiGatewayServer::consumeRateBudget(const QString &token)
{
    const auto it = m_tokens.find(token);
    if (it == m_tokens.end())
        return false; // token inconnu = pas de budget (défense en profondeur)

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 windowStart = now - MEOW_AI_GATEWAY_RATE_LIMIT_WINDOW_MS;

    QList<qint64> &stamps = it->recentRequestsMs;
    // Purge des horodatages hors fenêtre (liste triée croissante).
    int drop = 0;
    while (drop < stamps.size() && stamps.at(drop) < windowStart)
        ++drop;
    if (drop > 0)
        stamps.remove(0, drop);

    if (stamps.size() >= MEOW_AI_GATEWAY_RATE_LIMIT_REQUESTS)
        return false;
    stamps.append(now);
    return true;
}

bool AiGatewayServer::consumeScreenshotBudget(const QString &token)
{
    const auto it = m_tokens.find(token);
    if (it == m_tokens.end())
        return false; // token inconnu = pas de budget (défense en profondeur)
    if (it->screenshotsTaken >= MEOW_AI_GATEWAY_SCREENSHOT_CAP)
        return false;
    ++it->screenshotsTaken;
    return true;
}

// ============================================================================
// Pivot de proposition (S-1/S-2) et espace mémoire (S-3/S-4)
// ============================================================================

QJsonObject AiGatewayServer::toolMemorySet(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString scope = arguments.value(QStringLiteral("scope")).toString();
    const QString key = arguments.value(QStringLiteral("key")).toString();
    const QJsonValue value = arguments.value(QStringLiteral("value"));
    if (scope.isEmpty() || key.isEmpty() || value.isUndefined())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("memory_set: scope, key et value requis"),
                            /*retryable=*/false);
    // Le namespace `state` (runtime) ne s'écrit JAMAIS par ce tool : il passe
    // par le bus d'état (D35). Seul le pipeline édition (`config`) est ouvert.
    if (key.startsWith(QLatin1String("state/")))
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("memory_set: le namespace 'state' est en "
                                           "lecture seule ici (bus d'état, D35) — "
                                           "clé attendue sous 'config/'"),
                            /*retryable=*/false);

    const QString uuid = arguments.value(QStringLiteral("uuid")).toString();
    QJsonObject res;
    res[QStringLiteral("scope")] = scope;
    res[QStringLiteral("key")] = key;

    if (scope == QLatin1String("session")) {
        res[QStringLiteral("written")] =
            MemoryStore::instance()->setSessionValue(key, value.toVariant());
    } else if (scope == QLatin1String("player")) {
        if (uuid.isEmpty())
            return makeAppError(id, kInvalidParams, kAppInvalidParams,
                                QStringLiteral("memory_set(player): uuid (id joueur) requis"),
                                /*retryable=*/false);
        res[QStringLiteral("uuid")] = uuid;
        res[QStringLiteral("written")] =
            MemoryStore::instance()->setPlayerValue(uuid, key, value.toVariant());
    } else if (scope == QLatin1String("tile")) {
        if (uuid.isEmpty())
            return makeAppError(id, kInvalidParams, kAppInvalidParams,
                                QStringLiteral("memory_set(tile): uuid requis"),
                                /*retryable=*/false);
        bool ok = false;
        QString err;
        const QJsonObject hookRes = invokeHook(
            QStringLiteral("setTileMemory"), { uuid, key, value.toVariant() }, ok, err);
        if (!ok)
            return makeAppError(id, kInvalidParams, kAppSceneUnavailable, err,
                                /*retryable=*/true);
        if (!hookRes.value(QStringLiteral("ok")).toBool())
            return makeAppError(id, kInvalidParams, kAppToolFailed,
                                hookRes.value(QStringLiteral("error"))
                                    .toString(QStringLiteral("memory_set(tile): échec")),
                                /*retryable=*/false);
        res[QStringLiteral("uuid")] = uuid;
        res[QStringLiteral("written")] = true;
    } else {
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("memory_set: scope inconnu '%1' "
                                           "(tile|session|player)").arg(scope),
                            /*retryable=*/false);
    }

    res[QStringLiteral("ok")] = true;
    return makeToolResult(id, res);
}

QJsonObject AiGatewayServer::toolArtifactSubmit(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString source = arguments.value(QStringLiteral("source")).toString();
    if (source.isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("artifact_submit: source requis"),
                            /*retryable=*/false);
    const QString target = arguments.value(QStringLiteral("target")).toString();
    const QJsonObject meta = arguments.value(QStringLiteral("meta")).toObject();

    // Enveloppe de proposition (doc 13 §3) construite côté hôte : requestType
    // et writeSet sont de toute façon RECALCULÉS par le P0, jamais déclarés.
    QJsonObject author;
    author[QStringLiteral("playerId")] =
        meta.value(QStringLiteral("playerId")).toString(QStringLiteral("proposer"));
    author[QStringLiteral("role")] = QStringLiteral("proposer");

    QJsonObject intent;
    if (meta.contains(QStringLiteral("playerPrompt")))
        intent[QStringLiteral("playerPrompt")] = meta.value(QStringLiteral("playerPrompt"));
    intent[QStringLiteral("aiSummary")] =
        meta.value(QStringLiteral("aiSummary"))
            .toString(QStringLiteral("artifact_submit via passerelle MCP"));

    QJsonObject artifact;
    artifact[QStringLiteral("source")] = source;
    if (!target.isEmpty())
        artifact[QStringLiteral("targetUuid")] = target;
    for (const char *field : { "declaredWriteSet", "listensTo", "requiresModules",
                               "executionPolicy" }) {
        const QLatin1String f(field);
        if (meta.contains(f))
            artifact[f] = meta.value(f);
    }

    QJsonObject env;
    env[QStringLiteral("envelopeVersion")] = 1;
    env[QStringLiteral("channelVersion")] = QStringLiteral("1.0.0");
    env[QStringLiteral("author")] = author;
    env[QStringLiteral("intent")] = intent;
    env[QStringLiteral("operations")] = QJsonArray{};
    env[QStringLiteral("artifacts")] = QJsonArray{ artifact };

    // Bloquant jusqu'au verdict (ou rejet mécanique) dans la limite de
    // MEOW_PROPOSAL_TIMEOUT_MS ; au-delà : { status: "pending", proposalId } —
    // le verdict arrive alors par events_poll / state_query(proposals).
    const QVariantMap ret = ProposalGateway::instance()->artifactSubmit(env.toVariantMap());
    QJsonObject res = QJsonObject::fromVariantMap(ret);
    res[QStringLiteral("ok")] = true;
    return makeToolResult(id, res);
}

QJsonObject AiGatewayServer::toolArbiterVerdict(const QJsonValue &id, const QJsonObject &arguments)
{
    const QString proposalId = arguments.value(QStringLiteral("proposalId")).toString();
    const QString verdict = arguments.value(QStringLiteral("verdict")).toString();
    const QJsonValue reasons = arguments.value(QStringLiteral("reasons"));
    if (proposalId.isEmpty() || verdict.isEmpty() || !reasons.isArray())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("arbiter_verdict: proposalId, verdict et "
                                           "reasons[] requis"),
                            /*retryable=*/false);

    QJsonObject verdictDoc;
    verdictDoc[QStringLiteral("verdict")] = verdict;
    verdictDoc[QStringLiteral("reasons")] = reasons.toArray();
    if (arguments.contains(QStringLiteral("amendment")))
        verdictDoc[QStringLiteral("amendment")] =
            arguments.value(QStringLiteral("amendment"));

    const bool accepted = ProposalLifecycle::instance()->provideVerdictDoc(
        proposalId, verdictDoc.toVariantMap(), QStringLiteral("arbiter"));
    if (!accepted)
        return makeAppError(id, kInvalidParams, kAppToolFailed,
                            QStringLiteral("arbiter_verdict refusé : proposition "
                                           "inconnue, état ≠ arbitrating, ou document "
                                           "mal formé (verdict ∈ accepted|rejected|"
                                           "amended, reasons avec audience)"),
                            /*retryable=*/false);

    QJsonObject res;
    res[QStringLiteral("ok")] = true;
    res[QStringLiteral("proposalId")] = proposalId;
    res[QStringLiteral("verdict")] = verdict;
    res[QStringLiteral("note")] =
        QStringLiteral("Accusé : l'application des effets reste sous autorité hôte.");
    return makeToolResult(id, res);
}

QString AiGatewayServer::extractBearer(const QString &authHeaderValue)
{
    // En-tête attendu : « Bearer <token> » (schéma insensible à la casse).
    const QString trimmed = authHeaderValue.trimmed();
    const QString scheme = QStringLiteral("bearer ");
    if (trimmed.size() <= scheme.size()
        || trimmed.left(scheme.size()).compare(scheme, Qt::CaseInsensitive) != 0)
        return {};
    return trimmed.mid(scheme.size()).trimmed();
}
