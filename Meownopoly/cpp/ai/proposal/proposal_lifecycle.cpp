#include "proposal_lifecycle.h"

#include <utility>

#include <QDateTime>
#include <QJsonDocument>
#include <QUuid>
#include <QtQml>

using meow::proposal::BenchOutcome;
using meow::proposal::Envelope;
using meow::proposal::ProposalState;
using meow::proposal::RequestType;
using meow::proposal::VerdictOutcome;

// ==================== Proposal ====================

Proposal::Proposal(Envelope envelope, QObject *parent)
    : QObject(parent)
    , m_envelope(std::move(envelope))
{
    m_requestType = m_envelope.computeRequestType();
}

void Proposal::recomputeRequestType()
{
    m_requestType = m_envelope.computeRequestType();
}

bool Proposal::canTransition(ProposalState from, ProposalState to)
{
    // Graphe d'états figé par doc 13 §2. Toute arête absente d'ici est illégale.
    switch (from) {
    case ProposalState::Draft:
        return to == ProposalState::Submitted;
    case ProposalState::Submitted:
        return to == ProposalState::Prefiltered
            || to == ProposalState::RejectedMechanical; // fail P0 précoce
    case ProposalState::Prefiltered:
        return to == ProposalState::Validated
            || to == ProposalState::Arbitrating
            || to == ProposalState::Queued
            || to == ProposalState::RejectedMechanical;
    case ProposalState::Queued:
        // Reprise : la file repart de `prefiltered` (doc 13 §2).
        return to == ProposalState::Prefiltered;
    case ProposalState::Arbitrating:
        return to == ProposalState::Amended
            || to == ProposalState::Benching
            || to == ProposalState::Validated
            || to == ProposalState::RejectedArbiter;
    case ProposalState::Amended:
        // Amendement code → repasse au banc ; données seules → validation méca.
        return to == ProposalState::Benching
            || to == ProposalState::Validated;
    case ProposalState::Benching:
        return to == ProposalState::Validated
            || to == ProposalState::RejectedBench;
    case ProposalState::Validated:
        return to == ProposalState::Applying;
    case ProposalState::Applying:
        return to == ProposalState::Applied
            || to == ProposalState::Failed;
    // États terminaux : aucune sortie.
    case ProposalState::Applied:
    case ProposalState::RejectedMechanical:
    case ProposalState::RejectedArbiter:
    case ProposalState::RejectedBench:
    case ProposalState::Failed:
        return false;
    }
    return false;
}

bool Proposal::transitionTo(ProposalState to, const QString &reason, const QString &code)
{
    if (!canTransition(m_state, to))
        return false;

    const QString from = stateName();
    m_state = to;
    const QString toName = stateName();

    QVariantMap entry;
    entry.insert(QStringLiteral("from"), from);
    entry.insert(QStringLiteral("to"), toName);
    entry.insert(QStringLiteral("reason"), reason);
    entry.insert(QStringLiteral("code"), code);
    entry.insert(QStringLiteral("seq"), ++m_stepSeq);
    entry.insert(QStringLiteral("wallTs"), QDateTime::currentMSecsSinceEpoch());
    m_history.append(entry);

    emit stateChanged(from, toName, reason, code);
    return true;
}

QVariantMap Proposal::toVariantMap() const
{
    QVariantMap m;
    m.insert(QStringLiteral("proposalId"), proposalId());
    m.insert(QStringLiteral("state"), stateName());
    m.insert(QStringLiteral("requestType"), requestTypeName());
    m.insert(QStringLiteral("terminal"), isTerminal());
    m.insert(QStringLiteral("envelope"),
             QJsonDocument(m_envelope.toJson()).toVariant());
    m.insert(QStringLiteral("history"), m_history);
    return m;
}

// ==================== ProposalLifecycle ====================

ProposalLifecycle *ProposalLifecycle::m_instance = nullptr;

ProposalLifecycle *ProposalLifecycle::instance()
{
    if (!m_instance) m_instance = new ProposalLifecycle();
    return m_instance;
}

QObject *ProposalLifecycle::qmlInstance(QQmlEngine *, QJSEngine *)
{
    ProposalLifecycle *inst = ProposalLifecycle::instance();
    // Consommé côté C++ (hôte) autant que QML → ownership C++.
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void ProposalLifecycle::registerQml()
{
    qmlRegisterUncreatableType<Proposal>(
        "MeowProposal", 1, 0, "Proposal",
        QStringLiteral("Proposal est créé par ProposalLifecycle.submit()."));
    qmlRegisterSingletonType<ProposalLifecycle>(
        "MeowProposal", 1, 0, "ProposalLifecycle",
        &ProposalLifecycle::qmlInstance);
}

ProposalLifecycle::ProposalLifecycle(QObject *parent)
    : QObject(parent)
{
}

void ProposalLifecycle::wire(Proposal *p)
{
    connect(p, &Proposal::stateChanged, this,
            [this, p](const QString &, const QString &to, const QString &, const QString &) {
        emit proposalStateChanged(p->proposalId(), to);
        if (p->isTerminal())
            emit proposalSettled(p->proposalId(), to);
    });
}

bool ProposalLifecycle::requiresArbitration(RequestType t) const
{
    // Plancher D25 non contournable : le code et les règles passent TOUJOURS par
    // l'arbitre. Les catégories `data_safe`/`structure` sont routées directement
    // vers `validated` au MVP (la config D25 fine — grain par catégorie — est
    // hors périmètre S-1 et se branchera ici).
    return t == RequestType::Code || t == RequestType::Rules;
}

bool ProposalLifecycle::prefilter(Proposal *p, QString &code, QString &reason)
{
    // 1) requestType recalculé par le P0 (fait foi, jamais le champ déclaré).
    p->recomputeRequestType();

    // 2) Détection de conflit optimiste (stale_base, doc 13 §3). N'a de sens que
    //    si l'hôte tient une version de référence ET que l'enveloppe en porte une.
    const meow::proposal::BaseVersion &eb = p->envelope().baseVersion;
    if (eb.isSet() && m_hostBase.isSet()) {
        const bool ruleStale = (eb.rulebook >= 0 && m_hostBase.rulebook >= 0
                                && eb.rulebook != m_hostBase.rulebook);
        const bool mapStale  = (eb.mapRevision >= 0 && m_hostBase.mapRevision >= 0
                                && eb.mapRevision != m_hostBase.mapRevision);
        if (ruleStale || mapStale) {
            code   = QStringLiteral("stale_base");
            reason = QStringLiteral("Base divergente : reconstruis avec "
                                    "events_poll / state_query puis re-propose.");
            return false;
        }
    }
    return true;
}

void ProposalLifecycle::route(Proposal *p)
{
    if (!requiresArbitration(p->requestType())) {
        p->transitionTo(ProposalState::Validated,
                        QStringLiteral("route: données sûres, arbitrage non requis"));
        return;
    }
    if (m_arbiterAvailable) {
        p->transitionTo(ProposalState::Arbitrating,
                        QStringLiteral("route: soumis à l'arbitre"));
    } else {
        // Arbitre indisponible (D31) : file transactionnelle, pas perdu.
        p->transitionTo(ProposalState::Queued,
                        QStringLiteral("route: arbitre indisponible, mis en file"));
        m_queue.append(p->proposalId());
        emit queuedCountChanged();
    }
}

Proposal *ProposalLifecycle::submit(const QVariantMap &envelopeJson)
{
    return submitJson(QString::fromUtf8(
        QJsonDocument(QJsonObject::fromVariantMap(envelopeJson)).toJson(QJsonDocument::Compact)));
}

Proposal *ProposalLifecycle::submitJson(const QString &json)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &perr);

    Envelope env;
    QString formError;
    if (perr.error != QJsonParseError::NoError || !doc.isObject()) {
        formError = QStringLiteral("invalid_json: %1").arg(perr.errorString());
    } else if (!Envelope::fromJson(doc.object(), env, formError)) {
        // formError renseigné par fromJson (unsupported_envelope, too_many_*, …).
    }

    if (!formError.isEmpty()) {
        // Enveloppe inexploitable : on crée quand même une Proposal (traçabilité
        // D19) et on la mène directement à un rejet mécanique via submitted.
        if (env.proposalId.isEmpty())
            env.proposalId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        Proposal *p = new Proposal(std::move(env), this);
        m_proposals.append(p);
        m_byId.insert(p->proposalId(), p);
        wire(p);
        emit proposalCountChanged();
        p->transitionTo(ProposalState::Submitted, QStringLiteral("submitted"));
        p->transitionTo(ProposalState::RejectedMechanical,
                        QStringLiteral("préfiltre P0 : forme invalide"), formError);
        return p;
    }

    Proposal *p = new Proposal(std::move(env), this);
    m_proposals.append(p);
    m_byId.insert(p->proposalId(), p);
    wire(p);
    emit proposalCountChanged();

    p->transitionTo(ProposalState::Submitted, QStringLiteral("submitted"));

    QString code, reason;
    if (!prefilter(p, code, reason)) {
        p->transitionTo(ProposalState::RejectedMechanical, reason, code);
        return p;
    }
    p->transitionTo(ProposalState::Prefiltered,
                    QStringLiteral("préfiltré : requestType = %1").arg(p->requestTypeName()));
    route(p);
    return p;
}

bool ProposalLifecycle::provideVerdict(const QString &proposalId, const QString &outcome,
                                       const QString &reason)
{
    Proposal *p = proposalById(proposalId);
    if (!p || p->state() != ProposalState::Arbitrating)
        return false;

    bool ok = false;
    const VerdictOutcome v = meow::proposal::verdictOutcomeFromName(outcome, &ok);
    if (!ok) return false;

    switch (v) {
    case VerdictOutcome::Rejected:
        return p->transitionTo(ProposalState::RejectedArbiter,
                               reason.isEmpty() ? QStringLiteral("verdict: rejeté") : reason);
    case VerdictOutcome::Accepted:
        // Accepté : au banc si code (D26), sinon directement validé.
        if (p->hasArtifacts())
            return p->transitionTo(ProposalState::Benching,
                                   reason.isEmpty() ? QStringLiteral("verdict: accepté → banc")
                                                    : reason);
        return p->transitionTo(ProposalState::Validated,
                               reason.isEmpty() ? QStringLiteral("verdict: accepté") : reason);
    case VerdictOutcome::Amended:
        // Amendement : passe par `amended`. Code → repasse au banc (D32) ;
        // données seules → validation mécanique.
        if (!p->transitionTo(ProposalState::Amended,
                             reason.isEmpty() ? QStringLiteral("verdict: amendé") : reason))
            return false;
        if (p->hasArtifacts())
            return p->transitionTo(ProposalState::Benching,
                                   QStringLiteral("amendement code → repasse au banc (D32)"));
        return p->transitionTo(ProposalState::Validated,
                               QStringLiteral("amendement données → validation mécanique"));
    }
    return false;
}

bool ProposalLifecycle::provideBenchResult(const QString &proposalId, bool pass,
                                           const QString &reason)
{
    Proposal *p = proposalById(proposalId);
    if (!p || p->state() != ProposalState::Benching)
        return false;

    if (pass)
        return p->transitionTo(ProposalState::Validated,
                               reason.isEmpty() ? QStringLiteral("banc: pass") : reason);
    return p->transitionTo(ProposalState::RejectedBench,
                           reason.isEmpty() ? QStringLiteral("banc: fail") : reason);
}

bool ProposalLifecycle::applyProposal(const QString &proposalId, bool success,
                                      const QString &reason)
{
    Proposal *p = proposalById(proposalId);
    if (!p || p->state() != ProposalState::Validated)
        return false;

    if (!p->transitionTo(ProposalState::Applying, QStringLiteral("application (staging hôte)")))
        return false;

    if (success)
        return p->transitionTo(ProposalState::Applied,
                               reason.isEmpty() ? QStringLiteral("appliqué") : reason);
    return p->transitionTo(ProposalState::Failed,
                           reason.isEmpty() ? QStringLiteral("échec d'application") : reason);
}

void ProposalLifecycle::setArbiterAvailable(bool available)
{
    if (m_arbiterAvailable == available) return;
    m_arbiterAvailable = available;
    emit arbiterAvailableChanged();

    if (!available) return;

    // Reprise (D31) : draine la file dans l'ordre. Chaque proposition repart de
    // `prefiltered` puis est re-routée (arbitre désormais disponible).
    const QList<QString> pending = std::move(m_queue);
    m_queue.clear();
    emit queuedCountChanged();

    for (const QString &id : pending) {
        Proposal *p = proposalById(id);
        if (!p || p->state() != ProposalState::Queued) continue;
        p->transitionTo(ProposalState::Prefiltered,
                        QStringLiteral("reprise : arbitre disponible"));
        route(p);
    }
}

Proposal *ProposalLifecycle::proposalById(const QString &proposalId) const
{
    return m_byId.value(proposalId, nullptr);
}

QVariantList ProposalLifecycle::proposals() const
{
    QVariantList out;
    out.reserve(m_proposals.size());
    for (Proposal *p : m_proposals)
        out.append(p->toVariantMap());
    return out;
}

QVariantList ProposalLifecycle::queuedIds() const
{
    QVariantList out;
    out.reserve(m_queue.size());
    for (const QString &id : m_queue)
        out.append(id);
    return out;
}
