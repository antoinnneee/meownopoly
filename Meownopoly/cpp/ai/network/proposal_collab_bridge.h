/*
 *      V3 / Phase 3 — T3-5 · Slice collab (intégration)
 *
 * Couture d'INTÉGRATION qui relie les briques déjà livrées pour faire vivre le
 * scénario « proposition d'un client distant, autorité hôte, P0 hôte fait foi »
 * (plan V3 doc 15, hors-périmètre post-slice doc 11 §6) :
 *
 *   ProposalSession (T3-2, transport)  ⟷  ProposalLifecycle (S-1, P0 hôte)
 *                                       ⟷  EditorOpBus (T3-4, undo ciblé D28)
 *
 * Aucune de ces trois briques ne se connaît : ProposalSession est *transport
 * pur* (opaque), ProposalLifecycle est *logique d'hôte* (aucun réseau),
 * EditorOpBus est *mutation/undo*. Ce bridge est le SEUL point qui les câble,
 * conformément au découplage voulu par T3-2/T3-4. Il n'introduit aucune règle
 * métier : il route des signaux.
 *
 * Rôle HÔTE (autorité, D16) :
 *   - `proposalReceived` (une à la fois, sous la garde de flux unique de la
 *     session) → `ProposalLifecycle::submit` : c'est l'hôte, et lui seul, qui
 *     recalcule le requestType (P0 fait foi), détecte `stale_base`, arbitre,
 *     passe au banc.
 *   - à chaque transition (`proposalStateChanged`) → `notifyState` renvoie
 *     l'état à l'AUTEUR d'origine (point-à-point) ; un état terminal libère la
 *     garde et draine la file de la session.
 *   - `proposalVerdictReady` → `notifyVerdict` renvoie le document complet.
 *   - à `validated`, l'hôte APPLIQUE : write-set durable enregistré sur un
 *     `groupId` (source de vérité de l'undo ciblé T3-4), seam `applyRequested`
 *     pour le rejeu structurel (hooks éditeur QML), puis `applyProposal` mène
 *     à `applied`. Undo concurrent ultérieur : `undoProposal(groupId)`.
 *
 * Rôle AUTEUR (client distant) :
 *   - `submitProposal` délègue à la session (part UNIQUEMENT vers l'hôte, D16).
 *   - les retours de l'hôte (`stateReceived`/`verdictReceived`/ACK/échec) sont
 *     ré-exposés tels quels pour l'UI / le retour MCP (le blocage 60 s de
 *     ProposalGateway côté auteur distant reste piste C, non câblé au MVP).
 *
 * Périmètre T3-5 : ce fichier. `registerQml()` est fourni (patron sibling
 * S-1/S-2/T3-2) mais NON appelé — le câblage dans qmlapp.cpp est [pat],
 * laissé à une tâche d'intégration de scène.
 */
#ifndef MEOW_PROPOSAL_COLLAB_BRIDGE_H
#define MEOW_PROPOSAL_COLLAB_BRIDGE_H

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class ProposalSession;
class ProposalLifecycle;

class ProposalCollabBridge : public QObject
{
    Q_OBJECT

    /// Vrai si les coutures ProposalSession/ProposalLifecycle sont branchées.
    Q_PROPERTY(bool attached READ attached NOTIFY attachedChanged)
    /// Si vrai (défaut faux), l'hôte n'appelle PAS `applyProposal` tout de suite
    /// à `validated` : il émet `applyRequested` et ATTEND que le rejeu structurel
    /// (hooks éditeur QML) rappelle `completeHostApply(pid, ok, reason)`. Faux =
    /// application optimiste immédiate (le seam reste émis pour un rejeu
    /// synchrone). Permet de brancher un vrai chemin d'échec quand le rejeu hôte
    /// sera livré (QML).
    Q_PROPERTY(bool deferHostApply READ deferHostApply WRITE setDeferHostApply
                   NOTIFY deferHostApplyChanged)

public:
    static void registerQml();
    static ProposalCollabBridge *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool attached() const { return m_attached; }
    bool deferHostApply() const { return m_deferHostApply; }
    void setDeferHostApply(bool defer);

    /// Établit (idempotent) les connexions persistantes entre les singletons.
    /// Appelé automatiquement à la construction ; ré-exposé pour un pilotage
    /// explicite (tests).
    Q_INVOKABLE void attach();

    // ── Auteur → hôte ────────────────────────────────────────────────────────

    /// (auteur) soumet une enveloppe : délègue à ProposalSession (part vers
    /// l'hôte, ou auto-soumission locale si le local est l'hôte). Retourne le
    /// proposalId, vide si la session est inactive ou l'enveloppe inexploitable.
    Q_INVOKABLE QString submitProposal(const QVariantMap &envelopeJson);

    // ── Rejeu structurel hôte (seam) ─────────────────────────────────────────

    /// (hôte, mode `deferHostApply`) finalise l'application d'une proposition
    /// après rejeu structurel : `ok` vrai → `applied` (+ le write-set reste
    /// enregistré pour l'undo ciblé) ; faux → `failed` (write-set dé-enregistré,
    /// batch réseau jeté). No-op si l'id est inconnu ou hors mode différé.
    Q_INVOKABLE void completeHostApply(const QString &proposalId, bool ok,
                                       const QString &reason = {});

    /// (hôte) undo ciblé D28 d'une proposition appliquée, adressé par proposalId
    /// (le groupId sous-jacent est résolu ici). Délègue à
    /// EditorOpBus::undoProposal. Retourne false si inconnu / jamais appliqué.
    Q_INVOKABLE bool undoAppliedProposal(const QString &proposalId);

signals:
    void attachedChanged();
    void deferHostApplyChanged();

    /// (hôte) rejeu structurel demandé pour une proposition passée `validated`.
    /// `groupId` = clé de transaction/undo à utiliser pour matérialiser les
    /// deltas durables (les hooks éditeur QML posent sous ce groupId).
    /// `writeSet` = clés durables déclarées (déjà enregistrées côté undo).
    void applyRequested(const QString &proposalId, const QString &groupId,
                        const QVariantMap &envelopeJson, const QStringList &writeSet);

    /// (hôte) une proposition a été menée à `applied` sous `groupId`.
    void proposalApplied(const QString &proposalId, const QString &groupId);

    // Retours de l'hôte ré-exposés côté AUTEUR (client distant).
    void authorStateReceived(const QString &proposalId, const QString &state,
                             const QString &reason, const QString &code);
    void authorVerdictReceived(const QString &proposalId, const QVariantMap &verdictJson);
    void authorProposalDelivered(const QString &proposalId);
    void authorProposalSendFailed(const QString &proposalId, const QString &reason);

private slots:
    // Hôte
    void onProposalReceived(const QString &authorId, const QString &proposalId,
                            const QVariantMap &envelopeJson);
    void onLifecycleStateChanged(const QString &proposalId, const QString &state);
    void onLifecycleVerdictReady(const QString &proposalId);

private:
    explicit ProposalCollabBridge(QObject *parent = nullptr);
    static ProposalCollabBridge *m_pThis;

    ProposalSession   *session() const;
    ProposalLifecycle *lifecycle() const;

    // Renvoie à l'auteur la transition (reason/code lus du journal de la
    // proposition). Un état terminal libère la garde de flux de la session.
    void notifyAuthorState(const QString &proposalId, const QString &state);

    // Démarre l'application hôte d'une proposition `validated` : enregistre le
    // write-set durable, émet le seam de rejeu, puis (hors mode différé)
    // finalise optimistiquement.
    void beginHostApply(const QString &proposalId);
    // Finalisation commune (optimiste ou via completeHostApply).
    void finishHostApply(const QString &proposalId, bool ok, const QString &reason);

    bool m_attached = false;
    bool m_deferHostApply = false;

    // Contexte d'une proposition suivie côté hôte (de la réception à l'application).
    struct HostEntry {
        QString      authorId;
        QVariantMap  envelope;
        QStringList  writeSet;   // computeWriteSet() de l'enveloppe (P0 fait foi)
        QString      groupId;    // assigné à l'entrée en application (QUuid)
        bool         applying = false; // garde anti-ré-entrée sur `validated`
    };
    QHash<QString, HostEntry> m_hostByProposal;
    // proposalId → groupId des propositions APPLIQUÉES (pour l'undo ciblé).
    QHash<QString, QString>   m_appliedGroup;
};

#endif // MEOW_PROPOSAL_COLLAB_BRIDGE_H
