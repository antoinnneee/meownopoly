/*
 *      V3 / Phase 3 — T3-2 · ProposalSession (D40, doc v3 13)
 *
 * Session réseau *dédiée* au transport des propositions d'IA, verdicts et
 * notifications d'état, host-authoritative, bâtie sur le patron
 * `COLLAB_SESSION_PATTERN` (doc architecture) MAIS sur sa PROPRE pile réseau V3
 * (plage `V3MessageType` 0x60+, enveloppe commune B1, fiabilité applicative M3),
 * distincte d'EditorSession/PhysicsSession. C'est la décision D40 : l'arbitrage
 * est le mécanisme central des trois modes (D23) — dont le mode runtime qui n'a
 * pas d'`EditorSession` ouverte — donc il ne doit PAS être couplé au module
 * éditeur. La plage 0x60+ étant disjointe de Game/Editor/Physics, cette session
 * COEXISTE avec les autres (aucune règle d'exclusivité) : c'est précisément ce
 * qu'apporte une session à part.
 *
 * Rôle transport UNIQUEMENT (T3-2). Le schéma métier de l'enveloppe (doc 13,
 * `proposal_envelope`/`proposal_lifecycle`) voyage OPAQUE dans le payload : la
 * session ne lit que `proposalId` pour la corrélation et la sérialisation du
 * pipeline. Le pré-filtre P0, l'arbitrage et le banc restent le fait de l'hôte,
 * branchés sur les signaux ci-dessous.
 *
 * Invariants portés ici :
 *   - D16 : source auteur → hôte UNIQUEMENT (jamais de diffusion pair-à-pair
 *     d'une proposition brute). L'hôte fait foi, notifie l'auteur en point-à-
 *     point (état, verdict).
 *   - « une proposition en benching/applying à la fois » : garde de flux unique
 *     côté hôte (les propositions reçues pendant qu'une autre est en cours sont
 *     mises en file, ordre d'arrivée préservé, aucune perte).
 *   - Transport commit M3 : chaque message part en `sendV3Reliable` (ACK
 *     applicatif + retry + dédup par messageId, côté worker) ; les enveloppes
 *     volumineuses (artefacts) sont fragmentées par le chunking réparable B4.
 */
#ifndef MEOW_PROPOSAL_SESSION_H
#define MEOW_PROPOSAL_SESSION_H

#include <QHash>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariantMap>

#include "net/v3/v3_chunk_transfer.h"

class ProposalSession : public QObject
{
    Q_OBJECT

    /// Vrai si la session est active (startAsHost ou startAsClient appelé).
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    /// Vrai si le joueur local est l'hôte autoritaire (arbitre + banc).
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    /// Identifiant local (doit correspondre au playerId Catway).
    Q_PROPERTY(QString localPlayerId READ localPlayerId NOTIFY localPlayerIdChanged)
    /// Identifiant de l'hôte (vide si ce joueur est l'hôte).
    Q_PROPERTY(QString hostPlayerId READ hostPlayerId NOTIFY hostPlayerIdChanged)
    /// Identifiant de session V3 (porté par l'enveloppe B1).
    Q_PROPERTY(QString sessionId READ sessionId NOTIFY sessionIdChanged)
    /// Vrai (hôte) quand une proposition occupe le pipeline (benching/applying) :
    /// la garde de flux unique bloque l'émission de la suivante tant que c'est vrai.
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    /// (hôte) proposition actuellement dans le pipeline, vide sinon.
    Q_PROPERTY(QString currentProposalId READ currentProposalId NOTIFY busyChanged)
    /// (hôte) nombre de propositions reçues en attente derrière la garde de flux.
    Q_PROPERTY(int pendingCount READ pendingCount NOTIFY pendingCountChanged)

public:
    static void registerQml();
    static ProposalSession *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool    active() const        { return m_active; }
    bool    isHost() const        { return m_isHost; }
    QString localPlayerId() const { return m_localPlayerId; }
    QString hostPlayerId() const  { return m_hostPlayerId; }
    QString sessionId() const     { return m_sessionId; }
    bool    busy() const          { return m_processing; }
    QString currentProposalId() const { return m_currentProposalId; }
    int     pendingCount() const  { return m_inbound.size(); }

    // ── Cycle de vie ─────────────────────────────────────────────────────────

    /// Démarre comme hôte autoritaire (reçoit les propositions, notifie).
    Q_INVOKABLE bool startAsHost(const QString &localPlayerId,
                                 const QString &sessionId = QString{});

    /// Démarre comme client (auteur) : `hostPlayerId` = playerId Catway de l'hôte.
    Q_INVOKABLE bool startAsClient(const QString &localPlayerId,
                                   const QString &hostPlayerId,
                                   const QString &sessionId = QString{});

    /// Arrête la session, déconnecte de Catway et purge l'état de transport.
    Q_INVOKABLE void stop();

    // ── Auteur → hôte ────────────────────────────────────────────────────────

    /// (auteur) soumet une enveloppe de proposition (schéma doc 13, opaque ici).
    /// La proposition part UNIQUEMENT vers l'hôte (D16) — via chunking réparable
    /// si elle dépasse la taille d'un paquet. Si le joueur local EST l'hôte, la
    /// proposition entre directement dans le pipeline local (auto-soumission).
    /// Retourne le `proposalId` (généré/lu de l'enveloppe), vide si l'enveloppe
    /// est inexploitable ou la session inactive.
    Q_INVOKABLE QString submitProposal(const QVariantMap &envelopeJson);

    // ── Hôte → auteur ────────────────────────────────────────────────────────

    /// (hôte) notifie l'auteur d'une transition d'état de sa proposition
    /// (doc 13 §2). Si l'état est terminal, libère AUSSI la garde de flux unique
    /// et fait avancer la file (équivalent d'un `endProcessing`).
    Q_INVOKABLE void notifyState(const QString &proposalId, const QString &state,
                                 const QString &reason = {}, const QString &code = {});

    /// (hôte) renvoie à l'auteur le document de verdict complet (S-2, doc 13 §4).
    /// N'affecte pas la garde de flux (le verdict n'est pas un état terminal :
    /// l'application aval l'est).
    Q_INVOKABLE void notifyVerdict(const QString &proposalId,
                                   const QVariantMap &verdictJson);

    /// (hôte) libère explicitement la garde de flux unique pour `proposalId`
    /// (idempotent) et fait avancer la file. `notifyState` avec un état terminal
    /// l'appelle déjà ; exposé pour un pilotage manuel/atypique.
    Q_INVOKABLE void endProcessing(const QString &proposalId);

signals:
    /// (hôte) une proposition est prête à entrer dans le pipeline P0 → arbitre →
    /// banc. Émise sous la garde de flux unique : une seule à la fois. `authorId`
    /// est l'auteur d'origine (ou le local en auto-soumission).
    void proposalReceived(const QString &authorId, const QString &proposalId,
                          const QVariantMap &envelopeJson);

    /// (auteur) transition d'état notifiée par l'hôte pour sa proposition.
    void stateReceived(const QString &proposalId, const QString &state,
                       const QString &reason, const QString &code);

    /// (auteur) document de verdict complet reçu de l'hôte.
    void verdictReceived(const QString &proposalId, const QVariantMap &verdictJson);

    /// (auteur) la proposition a bien atteint l'hôte (ACK applicatif M3 du dernier
    /// segment). Confort UI ; l'issue métier arrive via stateReceived/verdict.
    void proposalDelivered(const QString &proposalId);

    /// (auteur) échec DÉFINITIF d'acheminement (retries M3 épuisés, file pleine,
    /// pair injoignable, transfert chunké rompu). Le métier décide de re-soumettre.
    void proposalSendFailed(const QString &proposalId, const QString &reason);

    void activeChanged();
    void isHostChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();
    void sessionIdChanged();
    void busyChanged();
    void pendingCountChanged();

private slots:
    void onReliableReceived(const QString &senderId, const QByteArray &data);
    void onV3MessageAcked(const QString &playerId, const QString &messageId);
    void onV3MessageFailed(const QString &playerId, const QString &messageId,
                           const QString &reason);
    void onPlayerTimedOut(const QString &playerId);

private:
    explicit ProposalSession(QObject *parent = nullptr);
    static ProposalSession *m_pThis;

    void connectToCatway();
    void disconnectFromCatway();

    // ── Kinds applicatifs (champ `kind` de l'enveloppe B1) ───────────────────
    static constexpr const char *k_kindSubmit    = "proposal.submit";
    static constexpr const char *k_kindState     = "proposal.state";
    static constexpr const char *k_kindVerdict   = "proposal.verdict";
    static constexpr const char *k_kindChunkData = "proposal.chunk.data";
    static constexpr const char *k_kindChunkReq  = "proposal.chunk.request";

    // Seuil de bascule vers le chunking B4 (marge sous le max reliable.io ~32 KB).
    static constexpr int k_chunkThresholdBytes = 20000;

    // Envoi d'une enveloppe V3 point-à-point vers un pair (kind quelconque).
    // Enregistre le suivi ACK/échec (m_inflight) pour router l'issue au métier.
    void sendEnvelopeTo(const QString &playerId, const QString &kind,
                        const QJsonObject &payload, const QString &proposalId,
                        const QString &correlationId = {});

    // Auteur : achemine une enveloppe de proposition vers l'hôte, en un paquet
    // ou fragmentée (B4) si elle dépasse le seuil.
    void sendSubmitToHost(const QString &proposalId, const QJsonObject &envelope);

    // Hôte : intègre une proposition reçue (ou auto-soumise) dans la file puis
    // fait avancer la garde de flux unique.
    void enqueueInbound(const QString &authorId, const QString &proposalId,
                        const QJsonObject &envelope);
    void pumpInbound();

    // Réception : dispatch d'un frame de chunk (data/request).
    void handleChunkData(const QString &senderId, const QJsonObject &payload);
    void handleChunkRequest(const QString &senderId, const QJsonObject &payload);

    bool    m_active  = false;
    bool    m_isHost  = false;
    QString m_localPlayerId;
    QString m_hostPlayerId;
    QString m_sessionId;

    // Séquence monotone par (session, émetteur) pour l'enveloppe B1.
    quint64 m_outSeq = 0;

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_ackConn;
    QMetaObject::Connection m_failConn;
    QMetaObject::Connection m_timeoutConn;

    // Suivi des envois en vol : messageId → (proposalId, kind). Permet de router
    // v3MessageAcked/Failed vers proposalDelivered/proposalSendFailed.
    struct Inflight { QString proposalId; QString kind; };
    QHash<QString, Inflight> m_inflight;

    // ── Garde de flux unique + file (hôte) ───────────────────────────────────
    struct Inbound { QString authorId; QString proposalId; QJsonObject envelope; };
    QList<Inbound>  m_inbound;          // file d'attente derrière la garde
    bool            m_processing = false;
    QString         m_currentProposalId;
    // proposalId → auteur, pour router notifyState/notifyVerdict en point-à-point.
    QHash<QString, QString> m_authorByProposal;
    // Dédup grossière des propositions déjà vues (proposalId).
    QList<QString>  m_seenProposals;
    static constexpr int k_seenMemory = 256;

    // ── Chunking réparable B4 ────────────────────────────────────────────────
    V3ChunkSender   m_chunkSender;
    V3ChunkReceiver m_chunkReceiver;
    // transferId → proposalId, pour remonter un échec de transfert au métier.
    QHash<QString, QString> m_transferProposal;
};

#endif // MEOW_PROPOSAL_SESSION_H
