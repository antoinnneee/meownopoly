/*
 *      V3 / Phase 2 — S-1 · Cycle de vie d'une proposition (doc v3 13 §2)
 *
 * Machine à états `draft → … → applied` (D11) et FILE transactionnelle des
 * propositions en attente d'arbitre (`queued` si l'arbitre est indisponible,
 * D31 — pas perdu, ordre préservé, reprise depuis `prefiltered`).
 *
 * DEUX classes :
 *   - Proposal          : une enveloppe + son état courant + le journal de ses
 *                         transitions (rejouable, D19). Un seul écrivain : le
 *                         manager (= l'hôte). Émet stateChanged à chaque pas.
 *   - ProposalLifecycle : orchestrateur/hôte. Préfiltre P0 (recalcul du
 *                         requestType, détection stale_base), routage D25
 *                         (plancher : code/règles → arbitre), file `queued`,
 *                         et les transitions pilotées par les issues d'arbitrage
 *                         (S-2 construit le verdict complet et appelle ces
 *                         mêmes points d'entrée).
 *
 * Périmètre S-1 : le squelette d'états + la file. Le verdict à deux audiences
 * et son retour MCP bloquant (S-2), la vérification `requiresModules` (A4/S-5),
 * l'application atomique réelle (T3-1) et le transport collab (T3-2) se
 * branchent sur ces coutures sans réécrire la machine.
 */
#ifndef MEOW_PROPOSAL_LIFECYCLE_H
#define MEOW_PROPOSAL_LIFECYCLE_H

#include <QHash>
#include <QList>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "proposal_envelope.h"
#include "proposal_types.h"

// ---------------------------------------------------------------------------
// Proposal — une enveloppe et son cycle de vie.
// ---------------------------------------------------------------------------
class Proposal : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString proposalId READ proposalId CONSTANT)
    Q_PROPERTY(QString state READ stateName NOTIFY stateChanged)
    Q_PROPERTY(QString requestType READ requestTypeName CONSTANT)
    Q_PROPERTY(bool terminal READ isTerminal NOTIFY stateChanged)

public:
    explicit Proposal(meow::proposal::Envelope envelope, QObject *parent = nullptr);

    const meow::proposal::Envelope &envelope() const { return m_envelope; }
    meow::proposal::ProposalState   state() const    { return m_state; }
    meow::proposal::RequestType     requestType() const { return m_requestType; }

    QString proposalId() const   { return m_envelope.proposalId; }
    QString stateName() const    { return meow::proposal::proposalStateName(m_state); }
    QString requestTypeName() const { return meow::proposal::requestTypeName(m_requestType); }
    bool    isTerminal() const   { return meow::proposal::isTerminalState(m_state); }
    bool    hasArtifacts() const { return !m_envelope.artifacts.isEmpty(); }

    // Journal des transitions (rejouable, D19). Chaque entrée :
    // { from, to, reason, code, seq, wallTs }.
    Q_INVOKABLE QVariantList history() const { return m_history; }
    // Projection debug/journal complète : enveloppe (JSON) + état + historique.
    Q_INVOKABLE QVariantMap  toVariantMap() const;

    // Vrai si (from → to) est une arête légale du graphe d'états (doc 13 §2).
    static bool canTransition(meow::proposal::ProposalState from,
                              meow::proposal::ProposalState to);

signals:
    // Émis à chaque transition acceptée. `code` porte le code mécanique
    // éventuel (ex. "stale_base", "too_many_operations") — vide sinon.
    void stateChanged(const QString &from, const QString &to,
                      const QString &reason, const QString &code);

private:
    friend class ProposalLifecycle;

    // Applique une transition si elle est légale. Retourne false (et n'émet
    // rien) si l'arête n'existe pas — garde-fou contre un pilotage incohérent.
    // `code` est le code mécanique optionnel, journalisé dans l'historique.
    bool transitionTo(meow::proposal::ProposalState to, const QString &reason,
                      const QString &code = {});
    // Recalcule le requestType par le P0 (fait foi). Appelé au préfiltrage.
    void recomputeRequestType();

    meow::proposal::Envelope     m_envelope;
    meow::proposal::ProposalState m_state = meow::proposal::ProposalState::Draft;
    meow::proposal::RequestType   m_requestType = meow::proposal::RequestType::DataSafe;
    QVariantList                  m_history;
    quint64                       m_stepSeq = 0; // pas de transition, monotone
};

// ---------------------------------------------------------------------------
// ProposalLifecycle — orchestrateur (rôle hôte).
// ---------------------------------------------------------------------------
class ProposalLifecycle : public QObject
{
    Q_OBJECT
    // Disponibilité de l'arbitre (D31). Faux → les propositions à arbitrer sont
    // mises en `queued` ; repasser à vrai draine la file.
    Q_PROPERTY(bool arbiterAvailable READ arbiterAvailable WRITE setArbiterAvailable
                   NOTIFY arbiterAvailableChanged)
    // Nombre de propositions actuellement en `queued`.
    Q_PROPERTY(int queuedCount READ queuedCount NOTIFY queuedCountChanged)
    // Nombre total de propositions suivies (vivantes + terminées conservées).
    Q_PROPERTY(int proposalCount READ proposalCount NOTIFY proposalCountChanged)

public:
    static void registerQml();
    static ProposalLifecycle *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool arbiterAvailable() const { return m_arbiterAvailable; }
    void setArbiterAvailable(bool available);
    int  queuedCount() const { return m_queue.size(); }
    int  proposalCount() const { return m_proposals.size(); }

    // Version courante de l'hôte, référence de la détection stale_base (doc 13
    // §3). Le slice solo peut laisser -1 partout (un seul écrivain → jamais
    // stale) ; le collab (T3-x) la tiendra à jour.
    void setHostBaseVersion(const meow::proposal::BaseVersion &bv) { m_hostBase = bv; }
    meow::proposal::BaseVersion hostBaseVersion() const { return m_hostBase; }

    // — Points d'entrée du cycle de vie (rôle hôte) —

    // Reçoit une enveloppe JSON, la valide en FORME, la préfiltre (P0 : recalcul
    // du requestType, stale_base) et la route. Retourne la Proposal créée (jamais
    // nullptr) ; son état reflète l'issue (rejected_mechanical si la forme ou le
    // P0 échoue ; validated / arbitrating / queued sinon). L'ownership reste au
    // manager.
    Q_INVOKABLE Proposal *submit(const QVariantMap &envelopeJson);

    // Idem depuis une chaîne JSON brute (confort tests / MCP).
    Q_INVOKABLE Proposal *submitJson(const QString &json);

    // Issue d'arbitrage sur une proposition en `arbitrating` (S-2 fournit le
    // verdict complet). `outcome` ∈ {accepted, rejected, amended}. `reason`
    // journalisé (phrase joueur/IA construites en S-2). Retourne false si
    // l'id est inconnu ou l'état n'est pas `arbitrating`.
    Q_INVOKABLE bool provideVerdict(const QString &proposalId, const QString &outcome,
                                    const QString &reason = {});

    // Résultat d'un passage au banc sur une proposition en `benching` (A5).
    // `pass` vrai → validated ; faux → rejected_bench.
    Q_INVOKABLE bool provideBenchResult(const QString &proposalId, bool pass,
                                        const QString &reason = {});

    // Application atomique d'une proposition en `validated` (T3-1 fournira le
    // staging réel). Passe par `applying` puis `applied`/`failed`.
    Q_INVOKABLE bool applyProposal(const QString &proposalId, bool success = true,
                                   const QString &reason = {});

    // Accès (debug / tests / futur canal). nullptr si inconnu.
    Q_INVOKABLE Proposal   *proposalById(const QString &proposalId) const;
    Q_INVOKABLE QVariantList proposals() const;   // projections, du + ancien au + récent
    Q_INVOKABLE QVariantList queuedIds() const;   // ordre de la file transactionnelle

signals:
    void arbiterAvailableChanged();
    void queuedCountChanged();
    void proposalCountChanged();
    // Émis quand une proposition change d'état (relais pratique pour QML).
    void proposalStateChanged(const QString &proposalId, const QString &state);
    // Émis quand une proposition entre dans un état terminal.
    void proposalSettled(const QString &proposalId, const QString &state);

private:
    explicit ProposalLifecycle(QObject *parent = nullptr);
    static ProposalLifecycle *m_instance;

    // Préfiltre P0 : recalcul du requestType + détection stale_base. Renseigne
    // `code`/`reason` et retourne false si la proposition doit être rejetée
    // mécaniquement.
    bool prefilter(Proposal *p, QString &code, QString &reason);
    // Route une proposition PRÉFILTRÉE : validated (pas d'arbitrage requis),
    // arbitrating (requis + arbitre dispo) ou queued (requis + arbitre absent).
    void route(Proposal *p);
    // Vrai si le requestType exige un arbitrage (plancher + config D25).
    bool requiresArbitration(meow::proposal::RequestType t) const;
    // Branche le relais de signaux d'une Proposal vers le manager.
    void wire(Proposal *p);

    bool m_arbiterAvailable = true;
    meow::proposal::BaseVersion m_hostBase; // référence stale_base (défaut : non set)

    // Toutes les propositions suivies, dans l'ordre de soumission (l'ownership
    // est au manager ; parent QObject).
    QList<Proposal *>        m_proposals;
    QHash<QString, Proposal *> m_byId;

    // File transactionnelle (D12) des propositions en `queued`, ordre d'arrivée.
    QList<QString>           m_queue;
};

#endif // MEOW_PROPOSAL_LIFECYCLE_H
