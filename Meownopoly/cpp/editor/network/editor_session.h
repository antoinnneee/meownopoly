#ifndef EDITOR_SESSION_H
#define EDITOR_SESSION_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonObject>
#include <QHash>
#include <QQueue>
#include <QElapsedTimer>

#include "editor_message_type.h"

/// Couche de session d'éditeur collaboratif, construite au-dessus de Catway.
///
/// Même modèle de rôle que GameSession :
///  - Hôte  : autoritaire sur la carte en cours d'édition, valide les ops,
///            les applique, puis les rediffuse à tous les clients.
///  - Client : envoie ses intentions (ops) à l'hôte, n'applique qu'au rebroadcast.
///
/// Coexiste avec GameSession sur le même canal Catway : le filtrage se fait
/// par plage de type-byte (EditorMessageType = 0x20+, GameMessageType = 0x01–0x11).
/// Par prudence, on refuse de démarrer EditorSession si GameSession est active.
class EditorSession : public QObject
{
    Q_OBJECT

    /// Vrai si la session est active (startAsHost ou startAsClient appelé).
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

    /// Vrai si le joueur local est l'hôte autoritaire.
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)

    /// Identifiant local du joueur (doit correspondre au playerId de Catway).
    Q_PROPERTY(QString localPlayerId READ localPlayerId NOTIFY localPlayerIdChanged)

    /// Identifiant de l'hôte de la session (vide si ce joueur est l'hôte).
    Q_PROPERTY(QString hostPlayerId READ hostPlayerId NOTIFY hostPlayerIdChanged)

    /// Identifiant de la session (transmis dans Welcome, utile pour les chemins d'autosave).
    Q_PROPERTY(QString sessionId READ sessionId NOTIFY sessionIdChanged)

    /// Sélections en cours des autres participants (présence).
    /// Format : { playerId -> [uuid, uuid, ...] } en valeurs QStringList.
    /// Mis à jour par onReliableReceived sur SelectionUpdate ; purgé quand un
    /// pair se déconnecte (best-effort, timeouts non implémentés en v1).
    Q_PROPERTY(QVariantMap remoteSelections READ remoteSelections NOTIFY remoteSelectionsChanged)

    /// roster connu des clients (du point de vue du dernier
    /// `PlayerRoster` reçu de l'hôte). Utilisé pour l'élection de succession
    /// quand l'hôte tombe. N'inclut PAS l'hôte lui-même.
    Q_PROPERTY(QStringList knownRoster READ knownRoster NOTIFY knownRosterChanged)

    // ── V3 T4-3 · Migration d'hôte (checkpoint D37) ─────────────────────────
    /// Vrai entre la réception/émission d'un `HostLeaving` et la reprise
    /// post-checkpoint (promotion locale ou `MigrationCheckpointAck` reçu).
    Q_PROPERTY(bool migrationInProgress READ migrationInProgress NOTIFY migrationStateChanged)
    /// D37 : les propositions IA restent suspendues tant que le nouvel arbitre
    /// n'a pas passé le handshake D24 ET que le checkpoint n'a pas été ACKé.
    /// À consulter par la couche de soumission (gateway/ProposalSession).
    Q_PROPERTY(bool proposalsSuspended READ proposalsSuspended NOTIFY migrationStateChanged)
    /// Dernier checkpoint D37 émis (hôte sortant) ou reçu (survivants).
    /// Vide hors migration ou sur le chemin timeout (départ brutal — les
    /// volets bloquants sont alors reconstruits depuis l'état répliqué local).
    Q_PROPERTY(QVariantMap migrationCheckpoint READ migrationCheckpoint NOTIFY migrationStateChanged)

public:
    static void registerQml();
    static EditorSession *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool active() const           { return m_active; }
    bool isHost() const           { return m_isHost; }
    QString localPlayerId() const { return m_localPlayerId; }
    QString hostPlayerId() const  { return m_hostPlayerId; }
    QString sessionId() const     { return m_sessionId; }
    QVariantMap remoteSelections() const { return m_remoteSelections; }
    QStringList knownRoster() const { return m_knownRoster; }
    bool migrationInProgress() const { return m_migrationInProgress; }
    bool proposalsSuspended() const  { return m_proposalsSuspended; }
    QVariantMap migrationCheckpoint() const { return m_migrationCheckpoint; }

    /// détermine (déterministiquement) l'id du nouvel hôte parmi les
    /// survivants. Basé uniquement sur le roster cache + localPlayerId, en
    /// excluant l'ancien hôte. Plus petit id lexicographique gagne. Tous les
    /// pairs qui partagent le même roster élisent le même gagnant.
    /// Retourne QString() si aucun candidat.
    Q_INVOKABLE QString electNewHost() const;

    /// bascule le pair local en hôte tout en préservant l'état local
    /// (tuiles, pile undo). Appelé par le client élu à la perte de l'hôte.
    /// Retourne false si la session n'était pas active.
    Q_INVOKABLE bool promoteToHost();

    /// (hôte uniquement) annonce aux clients que l'hôte quitte proprement.
    /// À appeler AVANT `stop()` dans le flow de sortie volontaire. Les clients
    /// reçoivent `HostLeaving` et déclenchent l'élection immédiatement (sans
    /// attendre le timeout Catway ~10 s).
    ///
    /// V3 T4-3 (D37) : le payload embarque le checkpoint de migration
    /// (règlement + hashes d'artefacts + hash du bus d'état + contexte
    /// arbitre best-effort), et la méthode COORDONNE les deux `HostLeaving` :
    /// l'annonce éditeur (0x2A) part D'ABORD, puis PhysicsSession::stop()
    /// émet la sienne (0x46). Les survivants sont donc déjà en mode migration
    /// quand la physique se coupe → jamais deux autorités simultanées (le
    /// 0x46 reçu pendant une migration n'est qu'un repli local transitoire,
    /// pas une bascule d'autorité).
    Q_INVOKABLE void announceHostLeaving();

    // ── V3 T4-3 · Migration d'hôte (D37) ─────────────────────────────────────

    /// Point d'entrée UNIQUE de sortie de session (consolidation de la logique
    /// éclatée C++/QML) : hôte → announceHostLeaving() (checkpoint + 0x2A puis
    /// 0x46) ; client → arrêt ordonné des sessions V3 dépendantes
    /// (ProposalSession, StateBus, PhysicsSession client). Puis stop().
    /// À appeler depuis QML à la place des paires announce+stop historiques.
    Q_INVOKABLE void beginHostHandover();

    /// (pair élu) applique les volets BLOQUANTS du checkpoint D37 avant la
    /// promotion : 1) règlement versionné → RulesEngine ; 2) hashes des
    /// artefacts actifs → diagnostic de disponibilité (D16) ; 3) hash du bus
    /// d'état vs miroir répliqué local (StateBus conserve son miroir au stop).
    /// Le volet 4 (contexte arbitre) est best-effort — exposé via
    /// `migrationArbiterContext()` pour l'injection en pré-prompt du nouvel
    /// arbitre. Retourne true si tous les volets bloquants passent (condition
    /// nécessaire à la reprise des propositions). Sans checkpoint (timeout /
    /// départ brutal), reconstruit best-effort depuis l'état répliqué local
    /// et retourne true si le règlement local est exploitable.
    Q_INVOKABLE bool applyMigrationCheckpoint();

    /// Volet 4 du checkpoint (journal D19 + verdicts) — best-effort, à
    /// injecter en pré-prompt du nouvel arbitre (D37). Vide si non transmis.
    Q_INVOKABLE QVariantMap migrationArbiterContext() const;

    /// (nouvel hôte) lève la suspension des propositions et broadcast
    /// `MigrationCheckpointAck` (0x2B) aux survivants. Appelée automatiquement
    /// quand checkpoint appliqué + arbitre D24 prêt ; exposée pour un pilotage
    /// manuel (harness) ou un mode sans arbitre.
    Q_INVOKABLE void resumeProposals();

    /// Purge l'état de migration (nouvelle entrée de session PROPRE via le
    /// lobby — à ne PAS appeler sur le chemin reconnect post-migration).
    Q_INVOKABLE void clearMigrationState();

    // ── Initialisation ───────────────────────────────────────────────────────

    /// Démarre la session en tant qu'hôte autoritaire.
    /// Échoue si GameSession est active.
    Q_INVOKABLE bool startAsHost(const QString &localPlayerId,
                                 const QString &sessionId = QString{});

    /// Démarre la session en tant que client.
    /// hostPlayerId doit correspondre au playerId Catway de l'hôte.
    /// Échoue si GameSession est active.
    Q_INVOKABLE bool startAsClient(const QString &localPlayerId,
                                   const QString &hostPlayerId,
                                   const QString &sessionId = QString{});

    /// Arrête la session et déconnecte les signaux.
    Q_INVOKABLE void stop();

    // ── Envoi ─────────────────────────────────────────────────────────────────

    /// Client → hôte : soumet une op d'édition (reliable).
    /// Si appelé par l'hôte, broadcast directement à tous (auteur inclus).
    Q_INVOKABLE void sendOp(const QJsonObject &op);

    /// Hôte uniquement : diffuse une op validée à tous les clients (reliable).
    Q_INVOKABLE void broadcastOp(const QJsonObject &op);

    /// Envoi générique d'un événement éditeur (reliable).
    Q_INVOKABLE void sendEvent(int type, const QJsonObject &payload = {});

    /// Hôte uniquement : broadcast d'un événement à tous (reliable).
    Q_INVOKABLE void broadcastEvent(int type, const QJsonObject &payload = {});

    /// Envoi point-à-point d'un événement éditeur (reliable).
    /// Utilisé notamment par l'hôte pour pousser un FullSync au seul client
    /// qui vient de rejoindre, sans polluer les autres pairs.
    Q_INVOKABLE void sendEventTo(const QString &playerId,
                                 int type,
                                 const QJsonObject &payload = {});

    /// Mise à jour de curseur — UDP brut (lossy), haute fréquence.
    Q_INVOKABLE void sendCursor(qreal x, qreal y);

signals:
    /// Op d'édition reçue (après validation/rebroadcast hôte pour un client,
    /// directement pour l'hôte).
    void opReceived(const QString &senderId, const QJsonObject &op);

    /// Op rejetée par l'hôte (reçue uniquement par l'émetteur originel).
    void opRejected(const QJsonObject &reject);

    /// Événement éditeur générique non-op (Hello/Welcome/FullSync/PlayerRoster…).
    void editorEventReceived(int type, const QString &senderId, const QJsonObject &payload);

    /// Mise à jour de sélection d'un autre joueur (reliable).
    void selectionReceived(const QString &senderId, const QJsonObject &payload);

    /// Mise à jour de curseur d'un autre joueur (UDP brut).
    void cursorReceived(const QString &senderId, qreal x, qreal y);

    /// l'hôte est tombé (timeout Catway). `electedHostId` est l'id
    /// du nouvel hôte désigné par l'élection (ou vide si aucun candidat). Si
    /// `electedHostId == localPlayerId`, le pair local doit s'auto-promouvoir
    /// via `promoteToHost()`. Sinon, fallback monoposte recommandé.
    void hostLost(const QString &electedHostId);

    /// émis une fois que `promoteToHost()` a réussi. Main.qml s'en
    /// sert pour publier une nouvelle session lobby et permettre aux clients
    /// survivants de découvrir et rejoindre le nouvel hôte automatiquement.
    void promotedToHost();

    void knownRosterChanged();

    // ── V3 T4-3 (D37) ────────────────────────────────────────────────────────
    /// migrationInProgress / proposalsSuspended / migrationCheckpoint.
    void migrationStateChanged();
    /// La suspension D37 est levée (localement ou via MigrationCheckpointAck).
    void proposalsResumed();

    /// un pair a quitté (timeout). Émis côté hôte. Les consumers QML
    /// doivent purger curseur/sélection associés au `playerId`.
    void peerLeft(const QString &playerId);

    /// op rate-limitée côté hôte → notif locale à l'émetteur.
    void opRateLimited(const QString &senderId, int dropped);

    void activeChanged();
    void isHostChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();
    void sessionIdChanged();
    void remoteSelectionsChanged();

private slots:
    void onReliableReceived(const QString &senderId, const QByteArray &data);
    void onUdpReceived(const QString &senderId, const QString &message);
    void onPlayerTimedOut(const QString &playerId);

private:
    explicit EditorSession(QObject *parent = nullptr);
    static EditorSession *m_pThis;

    void connectToCatway();
    void disconnectFromCatway();

    /// Hôte : relay un paquet fiable à tous les joueurs P2P connectés sauf senderId.
    void relayReliableToOthers(const QString &senderId, const QByteArray &packet);

    /// send avec fallback chunké si packet > k_chunkThresholdBytes.
    /// Route le paquet à travers sendFn(playerId, bytes).
    void sendReliableOrChunked(const QString &playerId,
                               EditorMessageType::Value type,
                               const QJsonObject &payload,
                               bool broadcast);

    /// rate-limit token bucket par sender. Retourne true si accepté.
    bool consumeOpToken(const QString &senderId);

    /// accumulation des chunks OpChunk par (senderId, opId).
    void handleOpChunk(const QString &senderId, const QJsonObject &payload);

    /// (hôte) construit et diffuse le roster courant à tous.
    void broadcastRoster();

    // ── V3 T4-3 (D37) ────────────────────────────────────────────────────────
    /// (hôte sortant) assemble le checkpoint D37 : règlement (bloquant),
    /// hashes d'artefacts actifs (bloquant), hash+volume du bus d'état
    /// (bloquant — l'état lui-même est déjà répliqué en continu par D35),
    /// contexte arbitre (journal D19, best-effort).
    QJsonObject buildCheckpointJson() const;
    /// (survivant) marque la migration en cours + arrêt ordonné des sessions
    /// V3 dépendantes (ProposalSession, StateBus — miroir conservé —,
    /// PhysicsSession côté client). Idempotent.
    void enterMigrationMode(const QJsonObject &checkpoint);
    /// Arme la reprise D37 : si l'arbitre a déjà passé le handshake D24
    /// (résultat latché), reprend immédiatement ; sinon s'abonne à
    /// handshakeCompleted du superviseur IA.
    void armProposalResume();

    bool    m_active        = false;
    bool    m_isHost        = false;
    QString m_localPlayerId;
    QString m_hostPlayerId;
    QString m_sessionId;
    QVariantMap m_remoteSelections;  // playerId → QStringList d'uuids
    QStringList m_knownRoster;       // clients connus (hors hôte)

    // ── V3 T4-3 · État de migration (D37) ───────────────────────────────────
    bool        m_migrationInProgress = false;
    bool        m_proposalsSuspended  = false;
    QVariantMap m_migrationCheckpoint;      // checkpoint émis/reçu (D37)
    bool        m_checkpointApplied   = false; // volets bloquants passés
    bool        m_wasMigrated         = false; // ce pair est un hôte promu
    QMetaObject::Connection m_arbiterHsConn;   // abonnement handshake D24

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_udpConn;
    QMetaObject::Connection m_timeoutConn;

    // compteur monotone attribué côté hôte à chaque op rebroadcastée.
    quint64 m_serverSeq = 0;

    // rate-limit. Token bucket par sender (capacité k_opBurst,
    // refill k_opRatePerSec). Clé = senderId (ou localPlayerId pour local).
    struct TokenBucket { double tokens; qint64 lastRefillMs; };
    QHash<QString, TokenBucket> m_opBuckets;
    QElapsedTimer m_rateClock;

    // réassemblage des ops chunkées. Clé = senderId + "/" + opId.
    struct ChunkBuffer {
        int      chunkCount = 0;
        int      origType   = 0;
        QByteArray joined;              // payload B64 concaténé dans l'ordre
        QHash<int, QByteArray> chunks;  // index → fragment B64
    };
    QHash<QString, ChunkBuffer> m_chunkBuffers;

    static constexpr const char *k_cursorPrefix = "EC:";  // Editor Cursor (UDP brut)
    // Seuil en-dessous de reliable.io max packet (32 KB). Marge pour header
    // JSON (opId, chunkIndex, …) + base64 overhead ~33 %.
    static constexpr int k_chunkThresholdBytes = 20000;
    static constexpr double k_opRatePerSec  = 30.0;
    static constexpr double k_opBurst       = 60.0;
};

#endif // EDITOR_SESSION_H
