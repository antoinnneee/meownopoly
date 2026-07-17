#include "ai_gateway_server.h"

#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonArray>
#include <QRandomGenerator>
#include <QDateTime>
#include <QDebug>

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
    // Catalogue VIDE (C1). Les tools MVP (manifeste P0-4, doc 02 §5) sont
    // enregistrés en C3, traduits vers les hooks existants (editorAutomationHooks
    // → Game.updateMap → EditorOpBus). Le format de retour MCP est { "tools": [...] }.
    //
    // C2 fournit le rôle authentifié : en C3, filtrer ce catalogue par
    // l'allow-list du rôle (le proposant ne voit pas `arbiter_verdict`, l'arbitre
    // ne voit pas les tools de pose — manifeste roles.<role>.toolAllowList).
    Q_UNUSED(params);
    Q_UNUSED(role);
    QJsonObject result;
    result[QStringLiteral("tools")] = QJsonArray{};
    return makeResult(id, result);
}

QJsonObject AiGatewayServer::handleToolsCall(const QJsonValue &id, const QJsonObject &params,
                                             Role role)
{
    Q_UNUSED(role);
    const QString name = params.value(QStringLiteral("name")).toString();
    if (name.isEmpty())
        return makeAppError(id, kInvalidParams, kAppInvalidParams,
                            QStringLiteral("tools/call: champ 'name' requis"),
                            /*retryable=*/false);

    // Catalogue vide → tout nom est inconnu. En C3, avant le dispatch : rejeter
    // avec un code `forbidden_role` si le tool existe mais n'est pas dans
    // l'allow-list de `role` (manifeste P0-4). L'auth/quotas (C2) est déjà appliquée
    // en amont dans la route ; ici on reste sur l'erreur structurée « tool inconnu ».
    return makeAppError(id, kInvalidParams, kAppUnknownTool,
                        QStringLiteral("Unknown tool: %1").arg(name),
                        /*retryable=*/false);
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
