#include "slice_instrumentation.h"

#include <QDateTime>
#include <algorithm>
#include <cmath>

#include "../proposal/proposal_lifecycle.h" // Proposal::canTransition
#include "../proposal/proposal_types.h"     // proposalStateFromName

SliceInstrumentation *SliceInstrumentation::m_instance = nullptr;

SliceInstrumentation::SliceInstrumentation(QObject *parent) : QObject(parent) {}

SliceInstrumentation *SliceInstrumentation::instance()
{
    if (!m_instance) m_instance = new SliceInstrumentation();
    return m_instance;
}

QObject *SliceInstrumentation::qmlInstance(QQmlEngine *, QJSEngine *)
{
    SliceInstrumentation *inst = SliceInstrumentation::instance();
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void SliceInstrumentation::registerQml()
{
    qmlRegisterSingletonType<SliceInstrumentation>(
        "MeowSlice", 1, 0, "SliceInstrumentation", &SliceInstrumentation::qmlInstance);
}

void SliceInstrumentation::reset()
{
    m_invocations.clear();
    m_arbStart.clear();
    m_arbLatenciesMs.clear();
    m_accepted = m_amended = m_rejected = 0;
    m_convergence.clear();
    m_maxConvergence = 0;
    m_offChannelAccessCount = 0;
    m_maxGuiStallMs = 0.0;
    m_auditTotal = m_auditOk = 0;
    m_productSeen = false;
    m_savedLoadedOk = true;
    m_undoCleanOk = true;
    emit reportChanged();
}

int SliceInstrumentation::beginInvocation(const QString &intentId)
{
    Invocation inv;
    inv.intentId = intentId;
    m_invocations.append(inv);
    emit reportChanged();
    return m_invocations.size() - 1;
}

void SliceInstrumentation::recordInvocationTokens(int promptTokens, int completionTokens)
{
    if (m_invocations.isEmpty()) return;
    Invocation &inv = m_invocations.last();
    inv.promptTokens = promptTokens;
    inv.completionTokens = completionTokens;
    inv.tokensMeasured = true;
    emit reportChanged();
}

void SliceInstrumentation::markArbitrationStart(const QString &proposalId)
{
    m_arbStart.insert(proposalId, QDateTime::currentMSecsSinceEpoch());
}

void SliceInstrumentation::markArbitrationEnd(const QString &proposalId)
{
    const auto it = m_arbStart.constFind(proposalId);
    if (it == m_arbStart.constEnd()) return;
    const double latency = double(QDateTime::currentMSecsSinceEpoch() - it.value());
    m_arbLatenciesMs.append(latency < 0.0 ? 0.0 : latency);
    m_arbStart.erase(it);
    emit reportChanged();
}

void SliceInstrumentation::recordVerdictOutcome(const QString &outcome)
{
    if (outcome == QStringLiteral("accepted"))      ++m_accepted;
    else if (outcome == QStringLiteral("amended"))  ++m_amended;
    else if (outcome == QStringLiteral("rejected")) ++m_rejected;
    emit reportChanged();
}

void SliceInstrumentation::recordConvergence(const QString &intentId, int iterations)
{
    QVariantMap e;
    e.insert(QStringLiteral("intentId"), intentId);
    e.insert(QStringLiteral("iterations"), iterations);
    e.insert(QStringLiteral("pass"), iterations <= MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS);
    m_convergence.append(e);
    if (iterations > m_maxConvergence) m_maxConvergence = iterations;
    emit reportChanged();
}

void SliceInstrumentation::recordOffChannelAccess(const QString &what)
{
    ++m_offChannelAccessCount;
    emit offChannelAccessDetected(what);
    emit reportChanged();
}

void SliceInstrumentation::recordGuiStallMs(double ms)
{
    if (ms > m_maxGuiStallMs) m_maxGuiStallMs = ms;
    emit reportChanged();
}

void SliceInstrumentation::recordAuditReplay(const QString &proposalId, bool ok)
{
    Q_UNUSED(proposalId);
    ++m_auditTotal;
    if (ok) ++m_auditOk;
    emit reportChanged();
}

bool SliceInstrumentation::replayHistory(const QVariantList &history)
{
    if (history.isEmpty()) return false;

    quint64 lastSeq = 0;
    bool     firstEntry = true;
    for (const QVariant &v : history) {
        const QVariantMap e = v.toMap();

        // seq strictement monotone (reprise sans trou, D19).
        const quint64 seq = e.value(QStringLiteral("seq")).toULongLong();
        if (!firstEntry && seq <= lastSeq) return false;
        lastSeq = seq;

        // Arête (from → to) légale du graphe d'états (doc 13 §2). La toute
        // première transition part de "draft" (état initial de Proposal).
        bool okFrom = false, okTo = false;
        const meow::proposal::ProposalState from =
            meow::proposal::proposalStateFromName(e.value(QStringLiteral("from")).toString(), &okFrom);
        const meow::proposal::ProposalState to =
            meow::proposal::proposalStateFromName(e.value(QStringLiteral("to")).toString(), &okTo);
        if (!okFrom || !okTo) return false;
        if (!Proposal::canTransition(from, to)) return false;

        firstEntry = false;
    }
    return true;
}

void SliceInstrumentation::recordProductCriterion(bool savedLoadedOk, bool undoCleanOk)
{
    m_productSeen = true;
    m_savedLoadedOk = m_savedLoadedOk && savedLoadedOk;
    m_undoCleanOk = m_undoCleanOk && undoCleanOk;
    emit reportChanged();
}

double SliceInstrumentation::percentile(QList<double> samples, double p)
{
    if (samples.isEmpty()) return 0.0;
    std::sort(samples.begin(), samples.end());
    if (samples.size() == 1) return samples.first();
    const double rank = p * (samples.size() - 1);
    const int lo = int(std::floor(rank));
    const int hi = int(std::ceil(rank));
    const double frac = rank - lo;
    return samples[lo] + (samples[hi] - samples[lo]) * frac;
}

bool SliceInstrumentation::overallPass() const
{
    return report().value(QStringLiteral("overallPass")).toBool();
}

QVariantMap SliceInstrumentation::report() const
{
    QVariantMap out;

    // --- Critère 1 : aucun accès hors canal ---
    const bool passOffChannel = (m_offChannelAccessCount == 0);
    {
        QVariantMap c;
        c.insert(QStringLiteral("count"), m_offChannelAccessCount);
        c.insert(QStringLiteral("pass"), passOffChannel);
        out.insert(QStringLiteral("offChannelAccess"), c);
    }

    // --- Critère 2 : aucun gel GUI ---
    const bool passNoFreeze = (m_maxGuiStallMs <= MEOW_SLICE_GUI_STALL_BUDGET_MS);
    {
        QVariantMap c;
        c.insert(QStringLiteral("maxStallMs"), m_maxGuiStallMs);
        c.insert(QStringLiteral("budgetMs"), double(MEOW_SLICE_GUI_STALL_BUDGET_MS));
        c.insert(QStringLiteral("pass"), passNoFreeze);
        out.insert(QStringLiteral("noGuiFreeze"), c);
    }

    // --- Critère 3 : audit rejouable ---
    const bool passAudit = (m_auditTotal > 0 && m_auditOk == m_auditTotal);
    {
        QVariantMap c;
        c.insert(QStringLiteral("total"), m_auditTotal);
        c.insert(QStringLiteral("ok"), m_auditOk);
        c.insert(QStringLiteral("pass"), passAudit);
        out.insert(QStringLiteral("auditReplayable"), c);
    }

    // --- Critère 4 : économie mesurée (relevé, pas de seuil dur au MVP) ---
    int totalPrompt = 0, totalCompletion = 0, measured = 0;
    QVariantList perInvocation;
    for (const Invocation &inv : m_invocations) {
        totalPrompt += inv.promptTokens;
        totalCompletion += inv.completionTokens;
        if (inv.tokensMeasured) ++measured;
        QVariantMap m;
        m.insert(QStringLiteral("intentId"), inv.intentId);
        m.insert(QStringLiteral("promptTokens"), inv.promptTokens);
        m.insert(QStringLiteral("completionTokens"), inv.completionTokens);
        m.insert(QStringLiteral("measured"), inv.tokensMeasured);
        perInvocation.append(m);
    }
    const bool passTokens = (!m_invocations.isEmpty() && measured == m_invocations.size());
    {
        QVariantMap c;
        c.insert(QStringLiteral("invocations"), m_invocations.size());
        c.insert(QStringLiteral("measuredInvocations"), measured);
        c.insert(QStringLiteral("totalPromptTokens"), totalPrompt);
        c.insert(QStringLiteral("totalCompletionTokens"), totalCompletion);
        c.insert(QStringLiteral("totalTokens"), totalPrompt + totalCompletion);
        c.insert(QStringLiteral("avgTokensPerInvocation"),
                 m_invocations.isEmpty() ? 0.0
                     : double(totalPrompt + totalCompletion) / m_invocations.size());
        c.insert(QStringLiteral("perInvocation"), perInvocation);
        c.insert(QStringLiteral("pass"), passTokens);
        out.insert(QStringLiteral("tokenEconomy"), c);
    }

    // --- Critère 5 : produit D9 ---
    const bool passProduct = (m_productSeen && m_savedLoadedOk && m_undoCleanOk);
    {
        QVariantMap c;
        c.insert(QStringLiteral("evaluated"), m_productSeen);
        c.insert(QStringLiteral("savedLoadedOk"), m_savedLoadedOk);
        c.insert(QStringLiteral("undoCleanOk"), m_undoCleanOk);
        c.insert(QStringLiteral("pass"), passProduct);
        out.insert(QStringLiteral("productD9"), c);
    }

    // --- Q-J04 : indicateurs d'exploitation ---
    {
        QVariantMap lat;
        lat.insert(QStringLiteral("count"), m_arbLatenciesMs.size());
        lat.insert(QStringLiteral("p50"), percentile(m_arbLatenciesMs, 0.50));
        lat.insert(QStringLiteral("p95"), percentile(m_arbLatenciesMs, 0.95));
        double maxLat = 0.0;
        for (double d : m_arbLatenciesMs) maxLat = std::max(maxLat, d);
        lat.insert(QStringLiteral("max"), maxLat);

        const int totalVerdicts = m_accepted + m_amended + m_rejected;
        QVariantMap verdicts;
        verdicts.insert(QStringLiteral("accepted"), m_accepted);
        verdicts.insert(QStringLiteral("amended"), m_amended);
        verdicts.insert(QStringLiteral("rejected"), m_rejected);
        verdicts.insert(QStringLiteral("total"), totalVerdicts);
        verdicts.insert(QStringLiteral("acceptRate"),
                        totalVerdicts ? double(m_accepted) / totalVerdicts : 0.0);
        verdicts.insert(QStringLiteral("amendRate"),
                        totalVerdicts ? double(m_amended) / totalVerdicts : 0.0);

        const bool passConvergence =
            (m_convergence.isEmpty()
             || m_maxConvergence <= MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS);
        QVariantMap conv;
        conv.insert(QStringLiteral("maxIterations"), m_maxConvergence);
        conv.insert(QStringLiteral("budgetIterations"),
                    int(MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS));
        conv.insert(QStringLiteral("samples"), m_convergence);
        conv.insert(QStringLiteral("pass"), passConvergence);

        QVariantMap qj04;
        qj04.insert(QStringLiteral("arbitrationLatencyMs"), lat);
        qj04.insert(QStringLiteral("verdicts"), verdicts);
        qj04.insert(QStringLiteral("convergence"), conv);
        out.insert(QStringLiteral("qj04"), qj04);
    }

    // Verdict global : les 5 critères + la convergence Q-J04 (seul indicateur
    // Q-J04 doté d'un seuil dur, S3). La latence/taux sont observés, pas gated.
    const bool passConvergence =
        (m_convergence.isEmpty()
         || m_maxConvergence <= MEOW_SLICE_MAX_CONVERGENCE_ITERATIONS);
    const bool overall = passOffChannel && passNoFreeze && passAudit
                         && passTokens && passProduct && passConvergence;
    out.insert(QStringLiteral("overallPass"), overall);

    return out;
}
