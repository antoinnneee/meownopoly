#ifndef AI_GATEWAY_SERVER_H
#define AI_GATEWAY_SERVER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonValue>
#include <QJsonArray>
#include <QHash>
#include <QList>
#include <QVector>
#include <QVariant>
#include <QVariantList>

// Forward-declarations : les types QtHttpServer/QTcpServer ne sont utilisés
// (et le module lié) que lorsque MEOW_HAS_HTTP_SERVER vaut 1. La déclaration
// anticipée suffit au header — aucune inclusion du module ici.
class QHttpServer;
class QTcpServer;
class QQuickWindow;
namespace meow::bench { class BenchPool; }

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
 * Périmètre C3 (cette tâche) : **catalogue de tools + traduction vers les hooks**
 * (manifeste `channel_manifest.json`, P0-4 ratifié D43/D44). Les 12 tools MVP du
 * manifeste sont exposés par `tools/list` (filtrés par l'allow-list du rôle du
 * token, D20), et `tools/call` traduit chaque appel vers les hooks QML existants
 * `editorAutomationHooks` (Editor.qml, chemin UI exact `placeSelectedAsset` +
 * `Game.updateMap` → compatible collab/undo). Les tools dont la capacité
 * sous-jacente n'existe pas encore côté hooks (state_query, memory_set,
 * roster_edit, artifact_*, events_poll, screenshot, arbiter_verdict, et les op
 * move/resize/delete/link de editor_edit) renvoient une erreur structurée
 * `not_implemented` pointant sur la tâche de suite (C4/S-*). Les tools réellement
 * câblés au MVP : `editor_place` (asset/case/zone/npc/enemy/crate), `editor_edit`
 * (set_trigger/set_dialogue), `module_config` (stats), `help`.
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
    /// quota associé (dont les budgets de captures et de dry-run). Les anciens
    /// tokens deviennent immédiatement invalides.
    void rotateSessionTokens();

    /// D4 — Bloc résumé injecté au pré-prompt d'un tour d'IA (Q-E06
    /// injectedBlock, plafonné 250 lignes/D44). Le rôle du token fixe l'audience
    /// (D20) ; `cursor` = dernière seq du journal vue par l'agent. Délègue à
    /// GameplayEventBus::canalSummary. Consommé par l'orchestration de tour
    /// (C5/C7) au spawn / début d'invocation (le transport MCP n'injecte pas
    /// lui-même le pré-prompt).
    QString injectedEventSummary(Role role, quint64 cursor) const;

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

    // — Catalogue de tools (C3) —
    // Table statique dérivée du manifeste versionné (channel_manifest.json,
    // P0-4/D43). Chaque entrée porte son nom et son autorisation par rôle. M12
    // (C8) régénérera cette table depuis la source de vérité au build ; au MVP
    // elle est recopiée à la main et co-versionnée avec le manifeste (D17).
    struct ToolDef {
        const char *name;
        bool proposer; // exposé au token proposer ?
        bool arbiter;  // exposé au token arbiter ?
    };
    static const QVector<ToolDef> &toolTable();
    static bool toolExists(const QString &name);
    static bool toolAllowedForRole(const QString &name, Role role);
    /// Descripteur MCP { name, description, inputSchema } d'un tool du manifeste.
    static QJsonObject toolDescriptor(const QString &name);

    // — Dispatch d'un appel de tool vers les hooks éditeur (C3) —
    // `arguments` = objet MCP `params.arguments`. Renvoie une réponse JSON-RPC
    // complète (result MCP avec content/structuredContent, ou erreur structurée).
    QJsonObject dispatchTool(const QJsonValue &id, const QString &name,
                             const QJsonObject &arguments, Role role);
    QJsonObject toolHelp(const QJsonValue &id, const QJsonObject &arguments);
    QJsonObject toolEditorPlace(const QJsonValue &id, const QJsonObject &arguments);
    QJsonObject toolEditorEdit(const QJsonValue &id, const QJsonObject &arguments);
    QJsonObject toolModuleConfig(const QJsonValue &id, const QJsonObject &arguments);
    // — C4 : capacités manquantes (doc 02 §5.2) —
    /// state_query(what, filter) : lecture d'état structurée et compacte.
    /// tiles/tile/roster/players → hooks scène ; enums → QMetaEnum (C++).
    QJsonObject toolStateQuery(const QJsonValue &id, const QJsonObject &arguments);
    /// roster_edit(op, params) : profils joueurs + limites map (ops collab 12-16).
    QJsonObject toolRosterEdit(const QJsonValue &id, const QJsonObject &arguments);
    /// screenshot() : capture de l'écran de jeu (D22), plafond par token via
    /// MEOW_AI_GATEWAY_SCREENSHOT_CAP. Résultat MCP image (base64 PNG).
    QJsonObject toolScreenshot(const QJsonValue &id, const QJsonObject &arguments);
    /// Table des enums exposés (state.enum) : { name, values:{clé:valeur} }.
    /// `known` = false si l'enum n'est pas au catalogue. Source : QMetaEnum
    /// (pas de dérive : recopie du Q_ENUM du type).
    static QJsonObject enumValues(const QString &enumName, bool &known);
    /// Tool présent au manifeste mais dont la capacité hôte arrive en C4/S-* :
    /// erreur structurée `not_implemented` non-retryable pointant la suite.
    QJsonObject toolNotImplemented(const QJsonValue &id, const QString &name,
                                   const QString &followUp);
    // — D4 : events_poll (journal métier, Q-E06) —
    /// events_poll(cursor) : différentiel du journal projeté au schéma canal,
    /// filtré par l'audience du rôle (D20). Délègue à GameplayEventBus::canalPoll.
    QJsonObject toolEventsPoll(const QJsonValue &id, const QJsonObject &arguments, Role role);
    // — A9 : artifact_dryrun (banc d'essai local, D42) —
    /// artifact_dryrun(source, targetUuid?) : P0 statique puis exécution one-shot
    /// du banc via le pool. Verdict + métriques complets ; quota par session ;
    /// non journalisé au journal partagé (D44).
    QJsonObject toolArtifactDryrun(const QJsonValue &id, const QJsonObject &arguments);
    /// Projette un verdict de banc (ou de P0) au schéma retourné à l'IA, avec le
    /// stage ("P0"|"bench") et le rappel « pass local ≠ acceptation » (D42).
    QJsonObject makeDryrunResult(const QJsonValue &id, const QJsonObject &verdict,
                                 const QString &stage);
    /// Pool de dry-run partagé, créé à la première demande (lazy).
    meow::bench::BenchPool *ensureBenchPool();

    // — Fabriques de résultats de tool (MCP) —
    /// Enveloppe un résultat de hook `{ ok, ... }` en résultat MCP :
    /// content[texte JSON] + structuredContent + isError (= !ok).
    static QJsonObject makeToolResult(const QJsonValue &id, const QJsonObject &hookResult);
    static QJsonObject makeToolTextResult(const QJsonValue &id, const QString &text);

    // — Accès à la scène QML (GUI thread) pour invoquer les hooks —
    /// Localise l'Item passif `objectName: "editorAutomationHooks"` (nullptr si
    /// l'éditeur n'est pas chargé).
    QObject *findEditorHooks() const;
    static QObject *findByObjectName(QObject *root, const QString &name);
    /// Première fenêtre QQuickWindow visible (cible de la capture D22).
    QQuickWindow *primaryQuickWindow() const;
    /**
     * Invoque une fonction JS d'`editorAutomationHooks` (params + retour QVariant,
     * voie identique à AutomationServer::cmdInvoke). Renvoie l'objet JSON résultat
     * du hook (`{ ok, ... }`). `ok`=false si la scène/fonction est absente ou si
     * l'invocation échoue (`error` renseigné).
     */
    QJsonObject invokeHook(const QString &fn, const QVariantList &args,
                           bool &ok, QString &error);
    static QJsonValue variantToJson(const QVariant &v);
    static QVariant jsonToVariant(const QJsonValue &v);

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
    /// Consomme une unité du budget de captures (D22) pour `token`. Faux si le
    /// plafond MEOW_AI_GATEWAY_SCREENSHOT_CAP est atteint. Réinitialisé à la
    /// rotation des tokens (nouvelle session IA).
    bool consumeScreenshotBudget(const QString &token);
    /// Consomme une unité du budget de dry-run (D42) pour `token`. Faux si le
    /// plafond MEOW_BENCH_DRYRUN_QUOTA est atteint. Réinitialisé à la rotation.
    bool consumeDryrunBudget(const QString &token);
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
        int screenshotsTaken = 0;       // budget captures D22, remis à 0 à la rotation
        int dryrunsUsed = 0;            // budget dry-run D42, remis à 0 à la rotation
    };
    QHash<QString, TokenState> m_tokens;
    QString m_proposerToken;
    QString m_arbiterToken;

    // Token de la requête en cours (transitoire, GUI thread mono-fil). Posé par
    // le lambda de route avant handleRpc, utilisé par les tools à budget par
    // token (ex. screenshot D22) sans threader le token dans chaque signature.
    QString m_currentToken;

    // A9 — pool de dry-run (banc d'essai local), créé à la première demande.
    // Partagé par les deux identités ; sérialise les jobs (un slot au MVP).
    meow::bench::BenchPool *m_benchPool = nullptr;

#if MEOW_HAS_HTTP_SERVER
    QHttpServer *m_httpServer = nullptr;
    QTcpServer *m_tcpServer = nullptr;
#endif
};

#endif // AI_GATEWAY_SERVER_H
