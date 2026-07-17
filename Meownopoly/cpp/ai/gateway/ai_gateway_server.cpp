#include "ai_gateway_server.h"

#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>

#if MEOW_HAS_HTTP_SERVER
#  include <QHttpServer>
#  include <QHttpServerRequest>
#  include <QHttpServerResponse>
#  include <QTcpServer>
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
} // namespace

// ============================================================================
// Construction / cycle de vie
// ============================================================================

AiGatewayServer::AiGatewayServer(quint16 port, QObject *parent)
    : QObject(parent)
{
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

            QJsonParseError perr;
            const QJsonDocument doc = QJsonDocument::fromJson(request.body(), &perr);
            if (perr.error != QJsonParseError::NoError) {
                const QJsonObject err = makeError(
                    QJsonValue(), kParseError,
                    QStringLiteral("Parse error: %1").arg(perr.errorString()));
                return QHttpServerResponse(
                    QByteArrayLiteral("application/json"),
                    QJsonDocument(err).toJson(QJsonDocument::Compact));
            }

            // JSON-RPC accepte une requête unique (objet) ou un lot (tableau).
            if (doc.isArray()) {
                QJsonArray responses;
                const QJsonArray batch = doc.array();
                for (const QJsonValue &item : batch) {
                    if (!item.isObject())
                        continue;
                    const QJsonObject resp = handleRpc(item.toObject());
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
                const QJsonObject err = makeError(
                    QJsonValue(), kInvalidRequest,
                    QStringLiteral("Invalid Request: expected a JSON object or array"));
                return QHttpServerResponse(
                    QByteArrayLiteral("application/json"),
                    QJsonDocument(err).toJson(QJsonDocument::Compact));
            }

            const QJsonObject resp = handleRpc(doc.object());
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

QJsonObject AiGatewayServer::handleRpc(const QJsonObject &request)
{
    // Une notification JSON-RPC n'a pas de champ "id" → aucune réponse renvoyée.
    const bool isNotification = !request.contains(QStringLiteral("id"));
    const QJsonValue id = request.value(QStringLiteral("id"));
    const QString method = request.value(QStringLiteral("method")).toString();
    const QJsonObject params = request.value(QStringLiteral("params")).toObject();

    if (method.isEmpty()) {
        if (isNotification)
            return {};
        return makeError(id, kInvalidRequest,
                         QStringLiteral("Invalid Request: missing 'method'"));
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
        return handleToolsList(id, params);
    if (method == QLatin1String("tools/call"))
        return handleToolsCall(id, params);

    if (isNotification)
        return {};
    return makeError(id, kMethodNotFound,
                     QStringLiteral("Method not found: %1").arg(method));
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

QJsonObject AiGatewayServer::handleToolsList(const QJsonValue &id, const QJsonObject &params)
{
    // C1 : catalogue VIDE. Les tools MVP (manifeste P0-4, doc 02 §5) sont
    // enregistrés en C3, traduits vers les hooks existants (editorAutomationHooks
    // → Game.updateMap → EditorOpBus). Le format de retour MCP est { "tools": [...] }.
    Q_UNUSED(params);
    QJsonObject result;
    result[QStringLiteral("tools")] = QJsonArray{};
    return makeResult(id, result);
}

QJsonObject AiGatewayServer::handleToolsCall(const QJsonValue &id, const QJsonObject &params)
{
    const QString name = params.value(QStringLiteral("name")).toString();
    if (name.isEmpty())
        return makeError(id, kInvalidParams,
                         QStringLiteral("tools/call: champ 'name' requis"));

    // C1 : aucun tool enregistré → tout nom est inconnu. Les tools arrivent en
    // C3 ; l'auth/rôles/quotas et les erreurs { code, message, details, retryable }
    // arrivent en C2.
    return makeError(id, kInvalidParams,
                     QStringLiteral("Unknown tool: %1").arg(name));
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
