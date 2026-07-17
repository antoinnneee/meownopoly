#ifndef AI_PROCESS_SUPERVISOR_H
#define AI_PROCESS_SUPERVISOR_H

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QByteArray>
#include <QHash>
#include <QVariantMap>

class QProcess;
class QTimer;
class QQmlEngine;
class QJSEngine;

/**
 * AiProcessSupervisor — superviseur du cycle de vie des processus d'agents IA
 * (M2, doc/v3/14_ADAPTATEUR_AGENTS.md §2.1).
 *
 * C'est le composant par lequel le jeu **lance, surveille et arrête** les CLIs
 * d'agents (`claude -p`, Codex non-interactif) qui exécutent les rôles
 * `proposer` et `arbiter` — sans que le joueur ne touche jamais un terminal
 * (D10 : le CLI est le mécanisme sous-jacent, invisible). Il ne parle PAS MCP
 * (c'est la passerelle `AiGatewayServer`, C1-C4) et ne juge rien (c'est
 * l'arbitre) : il fournit l'**environnement d'exécution** des agents et l'état
 * de leur cycle de vie exposé à QML.
 *
 * Périmètre C5 (cette tâche) :
 *   - `QProcess` (chantier neuf — aucun `QProcess` ailleurs dans le code) ;
 *   - **adaptateurs séparés** par CLI (`claude -p` vs Codex), arguments
 *     configurables (jamais codés en dur dans l'UI, doc 14 §2.2) ;
 *   - cycle de vie complet : démarrage/arrêt **gracieux**, kill, **timeout**,
 *     détection de **crash**, **redémarrage** avec backoff borné ;
 *   - capture **bornée** de stdout/stderr (anneau, plafond `#define`) ;
 *   - **secrets par env/fichier uniquement**, jamais sur la ligne de commande
 *     (token de rôle éphémère D20 injecté via un fichier MCP à permissions
 *     restreintes, jamais journalisé) ;
 *   - **aucun orphelin à la fermeture** : la destruction du superviseur — et la
 *     fin de l'application (`aboutToQuit`) — tue tous les process enfants
 *     (critère M2). Sous Windows, un **Job Object** `KILL_ON_JOB_CLOSE`
 *     garantit la mort de tout l'arbre de process (y compris les petits-enfants
 *     Node du CLI) même si le jeu se ferme brutalement.
 *   - États exposés à QML : `Stopped/Starting/Ready/Failed/Restarting` (M2),
 *     mappés sur l'indicateur lobby à 4 états de D31
 *     (`Absent`/`Test en cours`/`Prêt`/`Erreur`).
 *
 * Chez l'hôte, **deux processus/sessions isolés** (proposante + arbitre,
 * D6/D10) : jamais une session unique qui change de rôle. Chaque rôle a au plus
 * un process actif à la fois ; les deux sont pilotables indépendamment.
 *
 * Le handshake/challenge de rôle (D24/D31) et le tchat ingame (une invocation =
 * un tour) sont branchés PAR-DESSUS ce socle en C6/C7 : le superviseur expose la
 * machinerie générique (spawn one-shot ou persistant, `sendInput`,
 * `invocationCompleted`) sur laquelle ils s'appuient. Le passage à l'état
 * `Ready` sur `started()` est une base ; C6 pourra le conditionner au succès du
 * handshake via `notifyHandshake(role, ok)`.
 */
class AiProcessSupervisor : public QObject
{
    Q_OBJECT

    // États des deux agents, exposés séparément pour un binding direct dans le
    // lobby. Voir aussi lobbyState(role) pour l'indicateur 4-états D31.
    Q_PROPERTY(int proposerState READ proposerState NOTIFY proposerStateChanged)
    Q_PROPERTY(int arbiterState READ arbiterState NOTIFY arbiterStateChanged)

public:
    /// Rôle (identité locale) de l'agent supervisé (D6/D10). Valeurs stables
    /// (exposées à QML) : ne pas réordonner.
    enum Role { Proposer = 0, Arbiter = 1 };
    Q_ENUM(Role)

    /// Machine à états du cycle de vie d'un agent (M2, doc 14 §2.1).
    ///  - Stopped    : aucun process (état initial, arrêt gracieux terminé).
    ///  - Starting   : process lancé, pas encore prêt (fenêtre de timeout).
    ///  - Ready      : process démarré et opérationnel.
    ///  - Failed     : échec définitif (crash sans redémarrage restant, timeout,
    ///                 impossible à lancer, handshake refusé).
    ///  - Restarting : redémarrage automatique en cours (backoff), après un
    ///                 crash avec des tentatives restantes.
    enum State { Stopped = 0, Starting = 1, Ready = 2, Failed = 3, Restarting = 4 };
    Q_ENUM(State)

    /// Indicateur lobby à 4 états (D31), projection de State pour l'UI.
    /// Noms ASCII et distincts de State (mêmes enumerators interdits dans la
    /// portée de classe partagée par les enums non-scopés).
    enum LobbyState { Absent = 0, Testing = 1, Prete = 2, Erreur = 3 };
    Q_ENUM(LobbyState)

    /// CLI sous-jacent. Chaque valeur a un adaptateur séparé (argv + env).
    enum Adapter { ClaudeCli = 0, Codex = 1 };
    Q_ENUM(Adapter)

    static void registerQml();
    static AiProcessSupervisor *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    ~AiProcessSupervisor() override;

    // — Propriétés d'état —
    int proposerState() const { return stateOf(Proposer); }
    int arbiterState() const { return stateOf(Arbiter); }

    /// État courant d'un rôle (valeur de State ; Stopped si aucun agent).
    Q_INVOKABLE int stateOf(int role) const;
    /// Projection lobby 4-états (D31) de l'état courant d'un rôle.
    Q_INVOKABLE int lobbyState(int role) const;
    /// Vrai si un process est actuellement vivant pour ce rôle.
    Q_INVOKABLE bool isRunning(int role) const;
    /// Dernier motif d'échec lisible (vide si aucun).
    Q_INVOKABLE QString lastError(int role) const;
    /// Queue bornée de sortie (stdout+stderr entremêlés, plafonnée) pour
    /// diagnostic UI. Ne contient jamais de secret (injectés par env/fichier).
    Q_INVOKABLE QString recentOutput(int role) const;

    /**
     * Lance l'agent d'un rôle. `opts` (tout optionnel sauf indiqué) :
     *   - `adapter`      : int Adapter (défaut ClaudeCli) ;
     *   - `program`      : chemin/nom de l'exécutable CLI (défaut selon adapter,
     *                      configurable — jamais codé en dur dans l'UI) ;
     *   - `gatewayUrl`   : endpoint MCP loopback (défaut dérivé de
     *                      MEOW_AI_GATEWAY_PORT : http://127.0.0.1:<port>/mcp) ;
     *   - `token`        : token éphémère de rôle (D20) — **secret**, injecté
     *                      via fichier de config MCP à permissions restreintes,
     *                      jamais sur la ligne de commande ni journalisé ;
     *   - `skillPath`    : chemin du pré-prompt SKILL.md (D17) ;
     *   - `prompt`       : instruction initiale (poussée sur stdin) ;
     *   - `workingDir`   : répertoire de travail du process ;
     *   - `extraArgs`    : QStringList d'arguments additionnels (configurable) ;
     *   - `oneShot`      : true = invocation attendue de terminer (exit) ;
     *                      false = process persistant (défaut) ;
     *   - `startupTimeoutMs` / `invocationTimeoutMs` : bornes de temps.
     * Retourne false si le rôle est déjà en cours (utiliser restart) ou si le
     * lancement est impossible.
     */
    Q_INVOKABLE bool startAgent(int role, const QVariantMap &opts = QVariantMap());

    /// Arrêt **gracieux** (terminate → kill après grâce). Marque l'arrêt comme
    /// volontaire : aucun redémarrage automatique n'est déclenché.
    Q_INVOKABLE void stopAgent(int role);
    /// Kill immédiat (SIGKILL / TerminateProcess). Volontaire, pas de restart.
    Q_INVOKABLE void killAgent(int role);
    /// Redémarre l'agent avec la même configuration que le dernier `startAgent`.
    Q_INVOKABLE void restartAgent(int role);
    /// Arrête gracieusement TOUS les agents (idempotent). Appelé sur aboutToQuit.
    Q_INVOKABLE void stopAll();

    /// Pousse du texte sur le stdin de l'agent (un tour de tchat, C7).
    Q_INVOKABLE void sendInput(int role, const QString &text);

    /// Hook C6 : confirme (ok=true) ou invalide (ok=false, → Failed) l'état
    /// `Ready` après le handshake/challenge de rôle. No-op si l'agent n'est pas
    /// dans un état où cela a du sens.
    Q_INVOKABLE void notifyHandshake(int role, bool ok, const QString &reason = QString());

signals:
    void proposerStateChanged();
    void arbiterStateChanged();
    /// Émis à chaque transition d'état (role = valeur Role, state = valeur State).
    void stateChanged(int role, int state);
    void agentReady(int role);
    void agentFailed(int role, const QString &reason);
    /// Un agent one-shot a terminé normalement : `output` = sortie standard
    /// capturée (bornée), `exitCode` = code de sortie.
    void invocationCompleted(int role, int exitCode, const QString &output);
    /// Fragment de sortie temps réel (borné) : `isError` distingue stderr.
    void outputReceived(int role, const QString &chunk, bool isError);
    /// Journalisation (à connecter au Logger comme les autres managers).
    void logMessage(const QString &message);

private:
    explicit AiProcessSupervisor(QObject *parent = nullptr);
    static AiProcessSupervisor *m_instance;

    // Runtime interne d'un agent. Non-QObject : les signaux QProcess sont
    // connectés par lambda capturant le rôle. Un seul par rôle à la fois.
    struct Agent {
        Role role = Proposer;
        QProcess *process = nullptr;
        State state = Stopped;
        int restartCount = 0;
        bool intentionalStop = false; // arrêt volontaire → pas de redémarrage
        bool oneShot = false;
        bool reachedReady = false;
        int invocationTimeoutMs = 0;
        QTimer *startupTimer = nullptr;   // Starting → Failed si non prêt à temps
        QTimer *invocationTimer = nullptr; // borne d'exécution d'une invocation
        QByteArray outputBuf;             // stdout+stderr entremêlés, borné
        QString lastError;
        QString mcpConfigPath;            // fichier temporaire (token) à purger
        QVariantMap lastOpts;             // pour redémarrer à l'identique
    };

    Agent *agentFor(int role, bool create);
    const Agent *agentFor(int role) const;

    // — Machine à états —
    void setState(Agent *a, State s, const QString &reason = QString());
    void emitStateFor(Role role);

    // — Cycle de vie process —
    bool launch(Agent *a, const QVariantMap &opts);
    void gracefulStop(Agent *a);
    void forceKill(Agent *a);
    void scheduleRestart(Agent *a);
    void cleanupProcess(Agent *a);     // ferme timers + process + fichier MCP temp
    void cleanupMcpFileOnly(Agent *a); // supprime seulement le fichier MCP (token)

    // — Handlers QProcess —
    void onStarted(Agent *a);
    void onFinished(Agent *a, int exitCode, int exitStatus);
    void onErrorOccurred(Agent *a, int processError);
    void onReadyReadOut(Agent *a);
    void onReadyReadErr(Agent *a);
    void appendOutput(Agent *a, const QByteArray &data, bool isError);

    // — Adaptateurs CLI (séparés) : programme + arguments —
    // Aucun secret dans l'argv (journalisable). Le token voyage par fichier MCP.
    static QString defaultProgram(Adapter adapter);
    static QStringList claudeArgs(const QVariantMap &opts, const QString &mcpConfigPath);
    static QStringList codexArgs(const QVariantMap &opts, const QString &mcpConfigPath);

    // — Injection (env + fichier MCP à permissions restreintes) —
    // Écrit un fichier de config MCP loopback portant l'en-tête Authorization
    // (token de rôle). Retourne son chemin (vide si pas de token). Permissions
    // réduites au propriétaire. C'est le seul vecteur du secret — jamais l'argv.
    QString writeMcpConfigFile(Role role, const QVariantMap &opts);
    static QString gatewayUrlFromOpts(const QVariantMap &opts);

    // — Anti-orphelin (Windows Job Object) —
    void ensureJobObject();          // crée le job KILL_ON_JOB_CLOSE (une fois)
    void assignToJob(QProcess *p);   // rattache un enfant lancé au job

    QHash<int, Agent *> m_agents; // clé = valeur Role

    // Handle du Job Object Windows (void* pour éviter <windows.h> dans le header).
    void *m_jobHandle = nullptr;
};

#endif // AI_PROCESS_SUPERVISOR_H
