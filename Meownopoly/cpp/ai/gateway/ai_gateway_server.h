#ifndef AI_GATEWAY_SERVER_H
#define AI_GATEWAY_SERVER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonValue>

// Forward-declarations : les types QtHttpServer/QTcpServer ne sont utilisés
// (et le module lié) que lorsque MEOW_HAS_HTTP_SERVER vaut 1. La déclaration
// anticipée suffit au header — aucune inclusion du module ici.
class QHttpServer;
class QTcpServer;

/**
 * AiGatewayServer — passerelle MCP (Model Context Protocol) locale du canal IA.
 *
 * C'est **le canal IA ↔ jeu** (D2/D20/D21), distinct et durci par rapport à
 * l'`AutomationServer` (qui reste strictement réservé au test/debug interne et
 * n'est PAS modifié). Le serveur expose le catalogue curé du jeu sous forme de
 * **serveur MCP local streamable HTTP** embarqué dans le process du jeu :
 *
 *   - transport : HTTP POST loopback, corps JSON-RPC 2.0 (SSE optionnel, non
 *     requis au MVP — réponses `application/json`) ;
 *   - méthodes MVP : `initialize`, `tools/list`, `tools/call` (+ `ping` et les
 *     `notifications/*` sans réponse). Cf. doc/v3/02_CANAL_IA.md §2 bis.
 *
 * SÉCURITÉ (patron `AutomationServer`) : écoute STRICTEMENT sur la loopback
 * (127.0.0.1), opt-in via `--ai-gateway-port <N>` ou `MEOW_AI_GATEWAY_PORT`.
 * Chaque requête HTTP re-vérifie l'adresse source (double garde). Tout tourne
 * sur le GUI thread (les tools manipuleront la scène QML — C3).
 *
 * Périmètre C1 (cette tâche) : **le transport et le squelette JSON-RPC** only.
 *   - `initialize`  → capacités + serverInfo ;
 *   - `tools/list`  → catalogue (VIDE en C1, peuplé en C3 depuis le manifeste) ;
 *   - `tools/call`  → erreur « tool inconnu » tant que le catalogue est vide.
 * L'auth par token/rôles/quotas est C2 ; les tools MVP sont C3.
 *
 * Prérequis kit (P0-1, D21) : add-on **QtHttpServer** (absent du kit Qt 6.11.0
 * par défaut). Quand MEOW_HAS_HTTP_SERVER vaut 0, la classe compile en no-op
 * (le serveur n'écoute jamais) et le repli documenté est un pont stdio
 * `@modelcontextprotocol/sdk` (patron `automation_mcp/`).
 */
class AiGatewayServer : public QObject
{
    Q_OBJECT

public:
    explicit AiGatewayServer(quint16 port, QObject *parent = nullptr);
    ~AiGatewayServer() override;

    /// Port effectivement écouté (0 si l'écoute a échoué ou HTTP indisponible).
    quint16 port() const { return m_port; }
    bool isListening() const;

    /// true si l'add-on QtHttpServer était présent à la compilation (P0-1).
    static bool httpServerAvailable();

    /**
     * Résout le port de la passerelle depuis les arguments CLI et l'environnement.
     * Priorité : `--ai-gateway-port <N>` > `MEOW_AI_GATEWAY_PORT`.
     * Retourne 0 si aucun port n'est demandé (→ pas de serveur).
     */
    static quint16 resolvePort(const QStringList &args);

    /**
     * Crée le serveur si un port est demandé, sinon retourne nullptr.
     * `parent` prend ownership de l'instance créée.
     */
    static AiGatewayServer *maybeCreate(const QStringList &args, QObject *parent);

private:
    // — Dispatch JSON-RPC 2.0 (sous-ensemble MCP) —
    // Indépendant du transport HTTP : prend l'objet de requête, renvoie l'objet
    // de réponse. Un objet VIDE signale une notification (pas de réponse à
    // renvoyer côté transport).
    QJsonObject handleRpc(const QJsonObject &request);
    QJsonObject handleInitialize(const QJsonValue &id, const QJsonObject &params);
    QJsonObject handleToolsList(const QJsonValue &id, const QJsonObject &params);
    QJsonObject handleToolsCall(const QJsonValue &id, const QJsonObject &params);

    // — Fabriques de messages JSON-RPC —
    static QJsonObject makeResult(const QJsonValue &id, const QJsonValue &result);
    static QJsonObject makeError(const QJsonValue &id, int code, const QString &message,
                                 const QJsonValue &data = QJsonValue());

    quint16 m_port = 0;

#if MEOW_HAS_HTTP_SERVER
    QHttpServer *m_httpServer = nullptr;
    QTcpServer *m_tcpServer = nullptr;
#endif
};

#endif // AI_GATEWAY_SERVER_H
