#include "proposal_gateway.h"

#include <QEventLoop>
#include <QJsonDocument>
#include <QTimer>
#include <QtQml>

#include "proposal_lifecycle.h"
#include "proposal_types.h"
#include "proposal_verdict.h"

using meow::proposal::isRejectedState;
using meow::proposal::ProposalState;

// ==================== ProposalGateway ====================

ProposalGateway *ProposalGateway::m_instance = nullptr;

ProposalGateway *ProposalGateway::instance()
{
    if (!m_instance) m_instance = new ProposalGateway();
    return m_instance;
}

QObject *ProposalGateway::qmlInstance(QQmlEngine *, QJSEngine *)
{
    ProposalGateway *inst = ProposalGateway::instance();
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void ProposalGateway::registerQml()
{
    qmlRegisterSingletonType<ProposalGateway>(
        "MeowProposal", 1, 0, "ProposalGateway", &ProposalGateway::qmlInstance);
}

ProposalGateway::ProposalGateway(QObject *parent)
    : QObject(parent)
{
}

int ProposalGateway::timeoutMs() const
{
    return meow::proposal::kProposalTimeoutMs;
}

bool ProposalGateway::hasOutcome(const Proposal *p)
{
    if (!p) return false;
    return p->hasVerdict() || p->isTerminal();
}

QVariantMap ProposalGateway::buildDecidedReturn(const Proposal *p)
{
    // Cas nominal : l'arbitre a statué → on rend le document complet.
    if (p->hasVerdict())
        return p->verdict().toMcpReturn();

    // Pas de verdict d'arbitre (rejet mécanique du P0, échec du banc, échec
    // d'application) : on synthétise une réponse verdict-shaped pour que l'IA
    // puisse itérer (scénario S3). Le code/raison viennent de la dernière
    // transition journalisée.
    const QVariantList hist = p->history();
    QString code, text;
    if (!hist.isEmpty()) {
        const QVariantMap last = hist.last().toMap();
        code = last.value(QStringLiteral("code")).toString();
        text = last.value(QStringLiteral("reason")).toString();
    }

    // `retryable` : un rejet mécanique est en général corrigeable par l'IA
    // (forme, module manquant, base périmée…). Un échec d'application (`failed`)
    // ne l'est pas nécessairement — on reste prudent (retryable si rejet).
    const bool retryable = isRejectedState(p->state());

    QVariantMap reason;
    reason.insert(QStringLiteral("code"), code);
    reason.insert(QStringLiteral("text"), text);
    reason.insert(QStringLiteral("retryable"), retryable);

    QVariantMap m;
    m.insert(QStringLiteral("status"), QStringLiteral("decided"));
    m.insert(QStringLiteral("proposalId"), p->proposalId());
    // Un état non-`applied` rendu au tool est un refus du point de vue auteur.
    m.insert(QStringLiteral("verdict"),
             p->state() == ProposalState::Applied ? QStringLiteral("accepted")
                                                   : QStringLiteral("rejected"));
    m.insert(QStringLiteral("reason"), reason);
    m.insert(QStringLiteral("state"), p->stateName());
    return m;
}

QVariantMap ProposalGateway::artifactSubmit(const QVariantMap &envelopeJson)
{
    ProposalLifecycle *lc = ProposalLifecycle::instance();
    Proposal *p = lc->submit(envelopeJson); // jamais nullptr (contrat S-1)

    // Résultat déjà disponible (rejet mécanique immédiat, ou data_safe routé
    // directement en validated sans arbitre) → pas d'attente.
    if (hasOutcome(p) || p->hasVerdict())
        return buildDecidedReturn(p);

    // Attente bloquante (nested event loop) : réveil au verdict d'arbitre, à un
    // état terminal, ou au timeout MEOW_PROPOSAL_TIMEOUT_MS.
    const QString pid = p->proposalId();
    QEventLoop loop;
    bool timedOut = false;

    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, [&loop, &timedOut]() {
        timedOut = true;
        loop.quit();
    });

    auto cVerdict = QObject::connect(
        lc, &ProposalLifecycle::proposalVerdictReady, &loop,
        [&loop, pid](const QString &id) { if (id == pid) loop.quit(); });
    auto cSettled = QObject::connect(
        lc, &ProposalLifecycle::proposalSettled, &loop,
        [&loop, pid](const QString &id, const QString &) { if (id == pid) loop.quit(); });

    timer.start(timeoutMs());
    loop.exec();

    QObject::disconnect(cVerdict);
    QObject::disconnect(cSettled);

    // La proposition peut avoir disparu si l'ownership avait changé (il ne change
    // pas au MVP), on relit par id pour être robuste.
    p = lc->proposalById(pid);
    if (p && hasOutcome(p))
        return buildDecidedReturn(p);

    // Timeout sans verdict : l'IA repart, le verdict arrivera au tour suivant.
    QVariantMap pending;
    pending.insert(QStringLiteral("status"), QStringLiteral("pending"));
    pending.insert(QStringLiteral("proposalId"), pid);
    Q_UNUSED(timedOut);
    return pending;
}

QVariantMap ProposalGateway::artifactSubmitJson(const QString &json)
{
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isObject()) {
        QVariantMap err;
        err.insert(QStringLiteral("status"), QStringLiteral("error"));
        err.insert(QStringLiteral("error"), QStringLiteral("invalid_json"));
        return err;
    }
    return artifactSubmit(doc.object().toVariantMap());
}
