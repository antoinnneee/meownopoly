#include "proposal_collab_bridge.h"

#include <QDebug>
#include <QJsonObject>
#include <QUuid>
#include <QtQml>

#include "proposal_session.h"
#include "ai/proposal/proposal_lifecycle.h"
#include "ai/proposal/proposal_envelope.h"
#include "editor/ops/editor_op_bus.h"
#include "editor/network/editor_session.h"
#include "game/rules/rules_engine.h"

// ==================== ProposalCollabBridge ====================

ProposalCollabBridge *ProposalCollabBridge::m_pThis = nullptr;

ProposalCollabBridge *ProposalCollabBridge::instance()
{
    if (!m_pThis) m_pThis = new ProposalCollabBridge();
    return m_pThis;
}

QObject *ProposalCollabBridge::qmlInstance(QQmlEngine *, QJSEngine *)
{
    ProposalCollabBridge *inst = ProposalCollabBridge::instance();
    // Consommé côté C++ (couture hôte) autant que QML → ownership C++.
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void ProposalCollabBridge::registerQml()
{
    qmlRegisterSingletonType<ProposalCollabBridge>(
        "MeowProposal", 1, 0, "ProposalCollabBridge",
        &ProposalCollabBridge::qmlInstance);
}

ProposalCollabBridge::ProposalCollabBridge(QObject *parent)
    : QObject(parent)
{
    // Les singletons cibles se créent à la demande ; on câble tout de suite.
    attach();
}

ProposalSession *ProposalCollabBridge::session() const
{
    return ProposalSession::instance();
}

ProposalLifecycle *ProposalCollabBridge::lifecycle() const
{
    return ProposalLifecycle::instance();
}

void ProposalCollabBridge::attach()
{
    if (m_attached) return;

    ProposalSession   *s  = session();
    ProposalLifecycle *lc = lifecycle();

    // ── Rôle HÔTE : réception réseau → P0 local, transitions → notification ──
    connect(s, &ProposalSession::proposalReceived,
            this, &ProposalCollabBridge::onProposalReceived);
    connect(lc, &ProposalLifecycle::proposalStateChanged,
            this, &ProposalCollabBridge::onLifecycleStateChanged);
    connect(lc, &ProposalLifecycle::proposalVerdictReady,
            this, &ProposalCollabBridge::onLifecycleVerdictReady);

    // ── Rôle AUTEUR : retours de l'hôte ré-exposés tels quels ───────────────
    connect(s, &ProposalSession::stateReceived, this,
            [this](const QString &pid, const QString &state,
                   const QString &reason, const QString &code) {
        emit authorStateReceived(pid, state, reason, code);
    });
    connect(s, &ProposalSession::verdictReceived, this,
            [this](const QString &pid, const QVariantMap &v) {
        emit authorVerdictReceived(pid, v);
    });
    connect(s, &ProposalSession::proposalDelivered, this,
            [this](const QString &pid) { emit authorProposalDelivered(pid); });
    connect(s, &ProposalSession::proposalSendFailed, this,
            [this](const QString &pid, const QString &reason) {
        emit authorProposalSendFailed(pid, reason);
    });

    m_attached = true;
    emit attachedChanged();
}

void ProposalCollabBridge::setDeferHostApply(bool defer)
{
    if (m_deferHostApply == defer) return;
    m_deferHostApply = defer;
    emit deferHostApplyChanged();
}

QString ProposalCollabBridge::submitProposal(const QVariantMap &envelopeJson)
{
    return session()->submitProposal(envelopeJson);
}

// ── Hôte : une proposition entre dans le pipeline P0 (fait foi) ─────────────
void ProposalCollabBridge::onProposalReceived(const QString &authorId,
                                              const QString &proposalId,
                                              const QVariantMap &envelopeJson)
{
    // T4-5 / D37 : pendant une migration d'hôte, l'hôte suspend le traitement des
    // propositions (le checkpoint doit d'abord être appliqué + le handshake
    // arbitre D24 rejoué). On notifie un rejet ACTIONNABLE (retryable) à l'auteur
    // plutôt que d'entamer un cycle qui échouerait — le transport ProposalSession
    // est lui aussi arrêté pendant la fenêtre, cette garde est la ceinture.
    if (EditorSession::instance()->proposalsSuspended()) {
        session()->notifyState(proposalId, QStringLiteral("rejected"),
                               QStringLiteral("migration d'hôte en cours — réessayez"),
                               QStringLiteral("migration_in_progress"));
        return;
    }

    // Mémorise le contexte AVANT de piloter la machine : submit() déclenche des
    // transitions synchrones (submitted → prefiltered → validated/…), et notre
    // handler onLifecycleStateChanged a besoin du write-set/enveloppe dès la
    // première.
    HostEntry entry;
    entry.authorId = authorId;
    entry.envelope = envelopeJson;

    // Write-set calculé par le P0 (jamais le champ déclaré, doc 13 §3).
    meow::proposal::Envelope env;
    QString err;
    if (meow::proposal::Envelope::fromJson(
            QJsonObject::fromVariantMap(envelopeJson), env, err)) {
        entry.writeSet = env.computeWriteSet();
    }
    m_hostByProposal.insert(proposalId, entry);

    // P0 hôte fait foi : recalcul du requestType, stale_base, routage.
    lifecycle()->submit(envelopeJson);
}

void ProposalCollabBridge::onLifecycleStateChanged(const QString &proposalId,
                                                   const QString &state)
{
    // Ne renotifie/n'applique que les propositions issues du canal réseau
    // (suivies par le bridge) : les propositions locales pures (tests, solo)
    // n'ont pas d'entrée hôte et ne doivent rien émettre sur le réseau.
    if (!m_hostByProposal.contains(proposalId))
        return;

    // Renvoie la transition à l'auteur (terminal → libère la garde de flux).
    notifyAuthorState(proposalId, state);

    // À `validated`, l'hôte applique (autorité). Garde anti-ré-entrée : les
    // transitions `applying`/`applied` que l'application elle-même déclenche ne
    // doivent pas relancer un cycle d'application.
    if (state == QLatin1String("validated")) {
        HostEntry &e = m_hostByProposal[proposalId];
        if (!e.applying)
            beginHostApply(proposalId);
    }
}

void ProposalCollabBridge::onLifecycleVerdictReady(const QString &proposalId)
{
    if (!m_hostByProposal.contains(proposalId))
        return;
    Proposal *p = lifecycle()->proposalById(proposalId);
    if (!p || !p->hasVerdict())
        return;
    session()->notifyVerdict(proposalId, p->verdict().toJson().toVariantMap());
}

void ProposalCollabBridge::notifyAuthorState(const QString &proposalId,
                                             const QString &state)
{
    // reason/code = dernière entrée du journal de transitions de la proposition.
    QString reason, code;
    if (Proposal *p = lifecycle()->proposalById(proposalId)) {
        const QVariantList hist = p->history();
        if (!hist.isEmpty()) {
            const QVariantMap last = hist.last().toMap();
            reason = last.value(QStringLiteral("reason")).toString();
            code   = last.value(QStringLiteral("code")).toString();
        }
    }
    session()->notifyState(proposalId, state, reason, code);
}

void ProposalCollabBridge::beginHostApply(const QString &proposalId)
{
    HostEntry &e = m_hostByProposal[proposalId];
    e.applying = true;

    // groupId = clé triple (transaction M4 / undo ciblé D28 / batch réseau).
    e.groupId = QUuid::createUuid().toString(QUuid::WithoutBraces);

    // Enregistre le write-set durable : source de vérité de l'undo ciblé (T3-4).
    // À faire AVANT le rejeu structurel pour que les deltas posés sous ce
    // groupId soient adressables par undoProposal(groupId).
    EditorOpBus::instance()->registerProposalWriteSet(e.groupId, e.writeSet);

    // Seam de rejeu structurel : les hooks éditeur QML matérialisent les deltas
    // durables sous `groupId` (pose/edit/mémoire). Direct connection → traité
    // synchroniquement s'il y a un handler.
    emit applyRequested(proposalId, e.groupId, e.envelope, e.writeSet);

    // Hors mode différé : application optimiste immédiate. Le rejeu (s'il
    // existe) a déjà tourné dans l'émission ci-dessus. Le vrai chemin d'échec
    // (rejeu hôte non livré) arrivera avec `deferHostApply=true`.
    if (!m_deferHostApply)
        finishHostApply(proposalId, /*ok=*/true, {});
}

void ProposalCollabBridge::completeHostApply(const QString &proposalId, bool ok,
                                             const QString &reason)
{
    if (!m_hostByProposal.contains(proposalId))
        return;
    const HostEntry &e = m_hostByProposal[proposalId];
    if (!e.applying) // n'a jamais démarré d'application
        return;
    finishHostApply(proposalId, ok, reason);
}

void ProposalCollabBridge::finishHostApply(const QString &proposalId, bool ok,
                                           const QString &reason)
{
    auto it = m_hostByProposal.find(proposalId);
    if (it == m_hostByProposal.end())
        return;
    HostEntry &e = it.value();

    // applyProposal pilote validated → applying → applied/failed. Les
    // transitions émises retombent dans onLifecycleStateChanged → notifyState
    // (l'auteur reçoit `applied`/`failed`, garde de flux libérée).
    const bool driven = lifecycle()->applyProposal(proposalId, ok, reason);

    if (ok && driven) {
        // T4-5 : la proposition a atteint `applied` sous autorité hôte. Si c'est
        // une enveloppe `rules`, on matérialise ses ops de règlement dans le
        // RulesEngine (bump de version + publication `rules.changed`) — c'est ce
        // qui rend les règles « déclenchées en partie » à partir d'ici.
        applyRulesOps(proposalId, e.envelope, e.authorId);
        m_appliedGroup.insert(proposalId, e.groupId);
        emit proposalApplied(proposalId, e.groupId);
    } else {
        // Échec (ou transition refusée) : rien ne persiste. On dé-enregistre le
        // write-set en le ramenant à vide (registerProposalWriteSet écrase) et
        // on jette le batch réseau éventuellement accumulé sous ce groupId.
        EditorOpBus::instance()->registerProposalWriteSet(e.groupId, {});
        EditorOpBus::instance()->discardGroup(QUuid::fromString(e.groupId));
    }

    // Le suivi hôte n'est plus utile (l'undo ciblé passe par m_appliedGroup).
    m_hostByProposal.erase(it);
}

bool ProposalCollabBridge::undoAppliedProposal(const QString &proposalId)
{
    const QString groupId = m_appliedGroup.value(proposalId);
    if (groupId.isEmpty())
        return false;
    return EditorOpBus::instance()->undoProposal(groupId);
}

void ProposalCollabBridge::applyRulesOps(const QString &proposalId,
                                         const QVariantMap &envelopeJson,
                                         const QString &authorId)
{
    meow::proposal::Envelope env;
    QString err;
    if (!meow::proposal::Envelope::fromJson(
            QJsonObject::fromVariantMap(envelopeJson), env, err))
        return;

    // Seules les enveloppes dont le P0 recalcule `requestType == rules` portent
    // des ops de règlement (le champ déclaré ne fait jamais foi, doc 13 §3).
    if (env.computeRequestType() != meow::proposal::RequestType::Rules)
        return;

    const QString author =
        env.author.playerId.isEmpty() ? authorId : env.author.playerId;

    RulesEngine *rules = RulesEngine::instance();
    for (const meow::proposal::Operation &op : env.operations) {
        if (op.op != QLatin1String("rulebook_set")
            && op.op != QLatin1String("rules_set")
            && op.op != QLatin1String("rules_edit"))
            continue;
        // L'objet brut d'origine porte { op, mode, rulebook|rule|ruleId } —
        // applyRulebookOp lit `mode` et ignore le champ `op`.
        if (!rules->applyRulebookOp(op.raw.toVariantMap(), author, proposalId)) {
            qWarning() << "[ProposalCollabBridge] rulebook_set refusé pour"
                       << proposalId << ":" << rules->lastError();
        }
    }
}
