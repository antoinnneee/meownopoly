#ifndef AI_GATEWAY_SERVER_H
#define AI_GATEWAY_SERVER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonValue>
#include <QHash>
#include <QList>

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
 * Périmètre C1 : **le transport et le squelette JSON-RPC**.
 *   - `initialize`  → capacités + serverInfo ;
 *   - `tools/list`  → catalogue (VIDE, peuplé en C3 depuis le manifeste) ;
 *   - `tools/call`  → erreur « tool inconnu » tant que le catalogue est vide.
 *
 * Périmètre C2 (cette tâche) : **authentification, rôles et quotas** (doc 02 §7,
 * D20). Chaque requête HTTP doit porter un `Authorization: Bearer <token>` valide :
 *   - **Token éphémère par session** généré par le jeu (`proposerToken()` /
 *     `arbiterToken()`), destiné à être injecté à l'agent au spawn (env/config,
 *     C5). Deux identités locales distinctes (proposante / arbitre), tokens et
 *     rôles séparés — l'arbitre ne voit pas les tools de la proposante et vice
 *     versa (gating par rôle branché sur le catalogue en C3).
 *   - **Quotas** : taille max de requête (`MEOW_AI_GATEWAY_MAX_REQUEST_BYTES`) et
 *     rate-limit fenêtre glissante par token (`MEOW_AI_GATEWAY_RATE_LIMIT_*`).
 *   - **Erreurs structurées** exploitables par une IA (doc 02 §6) : le champ
 *     `error.data` porte `{ code (stable), retryable, details? }`.
 * Les tools MVP et l'allow-list par rôle (manifeste P0-4) restent C3.
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
    /**
     * Rôle (identité locale) porté par un token (D20). Les deux rôles ont des
     * capacités disjointes : la proposante pose/soumet, l'arbitre rend des
     * verdicts. L'allow-list de tools par rôle est appliquée en C3 (catalogue).
     */
    enum class Role { Proposer, Arbiter };

    explicit AiGatewayServer(quint16 port, QObject *parent = nullptr);
    ~AiGatewayServer() override;

    /// Port effectivement écouté (0 si l'écoute a échoué ou HTTP indisponible).
    quint16 port() const { return m_port; }
    bool isListening() const;

    // — Tokens éphémères de session (D20) —
    // Générés à la construction, à injecter aux agents au spawn (env/config, C5).
    // Chaque rôle a un token distinct. Ne jamais logger ces valeurs.
    QString proposerToken() const { return m_proposerToken; }
    QString arbiterToken() const { return m_arbiterToken; }

    /// Régénère les tokens de session (nouvelle session IA) et purge l'état de
    /// quota associé. Les anciens tokens deviennent immédiatement invalides.
    void rotateSessionTokens();

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
    // Indépendant du transport HTTP : prend l'objet de requête + le rôle du
    // token authentifié, renvoie l'objet de réponse. Un objet VIDE signale une
    // notification (pas de réponse à renvoyer côté transport).
    QJsonObject handleRpc(const QJsonObject &request, Role role);
    QJsonObject handleInitialize(const QJsonValue &id, const QJsonObject &params);
    QJsonObject handleToolsList(const QJsonValue &id, const QJsonObject &params, Role role);
    QJsonObject handleToolsCall(const QJsonValue &id, const QJsonObject &params, Role role);

    // — Authentification & quotas (C2) —
    // Toute la logique auth/quota est indépendante du transport (compilée même
    // quand QtHttpServer est absent) : seules l'extraction d'en-tête et la
    // construction des réponses HTTP vivent dans le bloc MEOW_HAS_HTTP_SERVER.
    void initSessionTokens();
    static QString generateToken();
    /// Vrai si `token` est connu ; renseigne `outRole` avec son rôle.
    bool validateToken(const QString &token, Role &outRole) const;
    /// Consomme une unité de budget rate-limit pour `token`. Faux si dépassé.
    bool consumeRateBudget(const QString &token);
    /// Extrait le token d'un en-tête « Bearer <token> » (vide si mal formé).
    static QString extractBearer(const QString &authHeaderValue);

    // — Fabriques de messages JSON-RPC —
    static QJsonObject makeResult(const QJsonValue &id, const QJsonValue &result);
    static QJsonObject makeError(const QJsonValue &id, int code, const QString &message,
                                 const QJsonValue &data = QJsonValue());
    /// Erreur enrichie exploitable par une IA (doc 02 §6) : error.data porte
    /// `{ code (stable), retryable, details? }`.
    static QJsonObject makeAppError(const QJsonValue &id, int rpcCode,
                                    const QString &appCode, const QString &message,
                                    bool retryable, const QJsonValue &details = QJsonValue());

    quint16 m_port = 0;

    // État d'un token de session : rôle + horodatages récents (fenêtre glissante
    // du rate-limit). Sur le GUI thread uniquement → pas de verrou.
    struct TokenState {
        Role role = Role::Proposer;
        QList<qint64> recentRequestsMs; // ms depuis epoch, purgés hors fenêtre
    };
    QHash<QString, TokenState> m_tokens;
    QString m_proposerToken;
    QString m_arbiterToken;

#if MEOW_HAS_HTTP_SERVER
    QHttpServer *m_httpServer = nullptr;
    QTcpServer *m_tcpServer = nullptr;
#endif
};

#endif // AI_GATEWAY_SERVER_H
