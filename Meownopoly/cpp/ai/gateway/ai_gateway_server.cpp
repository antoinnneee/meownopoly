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
#include <QJSValue>

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
} // namespace

// ============================================================================
// Construction / cycle de vie
// ============================================================================

AiGatewayServer::AiGatewayServer(quint16 port, QObject *parent)
    : QObject(parent)
{
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

AiGatewayServer::~AiGatewayServer() = default;

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
    // Priorité au flag CLI explicite.
    const int idx = args.indexOf(QStringLiteral("--ai-gateway-port"));
    if (idx != -1 && idx + 1 < args.size()) {
        bool conv = false;
        const uint v = args.at(idx + 1).toUInt(&conv);
        if (conv && v > 0 && v <= 65535)
            return static_cast<quint16>(v);
        qWarning() << "[AiGateway] --ai-gateway-port avec valeur invalide :"
                   << args.value(idx + 1);
    }

    // Sinon, variable d'environnement.
    const QByteArray env = qgetenv("MEOW_AI_GATEWAY_PORT");
    if (!env.isEmpty()) {
        bool conv = false;
        const uint v = QString::fromUtf8(env).toUInt(&conv);
        if (conv && v > 0 && v <= 65535)
            return static_cast<quint16>(v);
        qWarning() << "[AiGateway] MEOW_AI_GATEWAY_PORT invalide :" << env;
    }

    return 0; // aucun port demandé → pas de serveur
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
    Q_UNUSED(role);

    if (name == QLatin1String("help"))
        return toolHelp(id, arguments);
    if (name == QLatin1String("editor_place"))
        return toolEditorPlace(id, arguments);
    if (name == QLatin1String("editor_edit"))
        return toolEditorEdit(id, arguments);
    if (name == QLatin1String("module_config"))
        return toolModuleConfig(id, arguments);

    // Tools du manifeste dont la capacité côté hôte n'est pas encore livrée.
    // Chaque renvoi cite la tâche du plan qui la câblera (traçabilité).
    if (name == QLatin1String("state_query"))
        return toolNotImplemented(id, name, QStringLiteral("C4 (state.listTiles/getTile/enum/roster)"));
    if (name == QLatin1String("memory_set"))
        return toolNotImplemented(id, name, QStringLiteral("S-3 (espace mémoire snapable, D15)"));
    if (name == QLatin1String("roster_edit"))
        return toolNotImplemented(id, name, QStringLiteral("C4 (hooks roster PlayerProfile/MapInfo)"));
    if (name == QLatin1String("artifact_submit"))
        return toolNotImplemented(id, name, QStringLiteral("S-1/S-2 (enveloppe de proposition, D11)"));
    if (name == QLatin1String("artifact_dryrun"))
        return toolNotImplemented(id, name, QStringLiteral("A9 (banc d'essai, D42)"));
    if (name == QLatin1String("events_poll"))
        return toolNotImplemented(id, name, QStringLiteral("D4 (journal d'événements, Q-E06)"));
    if (name == QLatin1String("screenshot"))
        return toolNotImplemented(id, name, QStringLiteral("C4 (capture D22, plafond #define)"));
    if (name == QLatin1String("arbiter_verdict"))
        return toolNotImplemented(id, name, QStringLiteral("S-2 (verdict 2 audiences, D32)"));

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
    } else {
        // move/resize/delete/link/unlink/set_param : hooks à ajouter en C4
        // (editor_edit par uuid via EditorOpBus). Non câblés au MVP.
        return toolNotImplemented(
            id, QStringLiteral("editor_edit(%1)").arg(op),
            QStringLiteral("C4 (move/resize/delete/link/unlink/set_param par uuid)"));
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
    const QString moduleId = arguments.value(QStringLiteral("id")).toString();
    const bool enabled = arguments.value(QStringLiteral("enabled")).toBool();

    if (moduleId == QLatin1String("stats")) {
        bool ok = false;
        QString err;
        const QJsonObject res =
            invokeHook(QStringLiteral("setStatsModuleEnabled"), { enabled }, ok, err);
        if (!ok)
            return makeAppError(id, kInvalidParams, kAppSceneUnavailable, err,
                                /*retryable=*/true);
        return makeToolResult(id, res);
    }

    // Généralisation du module_config à tout module gameplay : S-5 (op
    // 'structure', vérif requiresModules dans P0). Seul 'stats' est câblé au MVP.
    return toolNotImplemented(
        id, QStringLiteral("module_config(%1)").arg(moduleId),
        QStringLiteral("S-5 (généralisation module_config, D41)"));
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
