#include "proposal_verdict.h"

#include <QJsonDocument>

namespace meow::proposal {

QString audiencePlayer() { return QStringLiteral("player"); }
QString audienceAi()     { return QStringLiteral("ai"); }

// ==================== VerdictReason ====================

QJsonObject VerdictReason::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("audience"), audience);
    if (!code.isEmpty())
        o.insert(QStringLiteral("code"), code);
    o.insert(QStringLiteral("text"), text);
    // `retryable` n'a de sens que pour l'IA — on ne le sérialise que là.
    if (audience == audienceAi())
        o.insert(QStringLiteral("retryable"), retryable);
    return o;
}

VerdictReason VerdictReason::fromJson(const QJsonObject &o)
{
    VerdictReason r;
    r.audience  = o.value(QStringLiteral("audience")).toString();
    r.code      = o.value(QStringLiteral("code")).toString();
    r.text      = o.value(QStringLiteral("text")).toString();
    r.retryable = o.value(QStringLiteral("retryable")).toBool(false);
    return r;
}

// ==================== VerdictAmendment ====================

bool VerdictAmendment::isEmpty() const
{
    return operationsPatch.isEmpty() && artifactsPatch.isEmpty() && note.isEmpty();
}

QJsonObject VerdictAmendment::toJson() const
{
    QJsonObject o;
    if (!operationsPatch.isEmpty())
        o.insert(QStringLiteral("operationsPatch"), operationsPatch);
    if (!artifactsPatch.isEmpty())
        o.insert(QStringLiteral("artifactsPatch"), artifactsPatch);
    if (!note.isEmpty())
        o.insert(QStringLiteral("note"), note);
    return o;
}

VerdictAmendment VerdictAmendment::fromJson(const QJsonObject &o)
{
    VerdictAmendment a;
    a.operationsPatch = o.value(QStringLiteral("operationsPatch")).toArray();
    a.artifactsPatch  = o.value(QStringLiteral("artifactsPatch")).toArray();
    a.note            = o.value(QStringLiteral("note")).toString();
    return a;
}

// ==================== BenchReport ====================

QJsonObject BenchReport::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("verdict"), verdict);
    if (!metricsRef.isEmpty())
        o.insert(QStringLiteral("metricsRef"), metricsRef);
    return o;
}

BenchReport BenchReport::fromJson(const QJsonObject &o)
{
    BenchReport b;
    b.verdict    = o.value(QStringLiteral("verdict")).toString();
    b.metricsRef = o.value(QStringLiteral("metricsRef")).toString();
    return b;
}

// ==================== Verdict ====================

QString Verdict::playerText() const
{
    QStringList parts;
    for (const VerdictReason &r : reasons) {
        if (r.audience == audiencePlayer() && !r.text.isEmpty())
            parts << r.text;
    }
    return parts.join(QStringLiteral(" "));
}

VerdictReason Verdict::aiReason() const
{
    for (const VerdictReason &r : reasons) {
        if (r.audience == audienceAi())
            return r;
    }
    return VerdictReason{};
}

QVariantMap Verdict::toMcpReturn() const
{
    // Ce que lit le tool MCP bloquant (doc 13 §5) : le verdict, l'entrée `ai`
    // (code stable + consigne + retryable) et, si amendé, le diff résumé.
    QVariantMap m;
    m.insert(QStringLiteral("status"), QStringLiteral("decided"));
    m.insert(QStringLiteral("proposalId"), proposalId);
    m.insert(QStringLiteral("verdict"), verdictOutcomeName(outcome));

    const VerdictReason ai = aiReason();
    QVariantMap aiMap;
    aiMap.insert(QStringLiteral("code"), ai.code);
    aiMap.insert(QStringLiteral("text"), ai.text);
    aiMap.insert(QStringLiteral("retryable"), ai.retryable);
    m.insert(QStringLiteral("reason"), aiMap);

    if (hasAmendment())
        m.insert(QStringLiteral("amendment"),
                 QJsonDocument(amendment.toJson()).toVariant());
    if (benchReport.isSet())
        m.insert(QStringLiteral("benchReport"),
                 QJsonDocument(benchReport.toJson()).toVariant());
    return m;
}

QJsonObject Verdict::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("proposalId"), proposalId);
    o.insert(QStringLiteral("verdict"), verdictOutcomeName(outcome));
    if (!decidedBy.isEmpty())
        o.insert(QStringLiteral("decidedBy"), decidedBy);

    QJsonArray rs;
    for (const VerdictReason &r : reasons)
        rs.append(r.toJson());
    o.insert(QStringLiteral("reasons"), rs);

    if (hasAmendment())
        o.insert(QStringLiteral("amendment"), amendment.toJson());
    if (benchReport.isSet())
        o.insert(QStringLiteral("benchReport"), benchReport.toJson());
    if (appliedVersion.isSet())
        o.insert(QStringLiteral("appliedVersion"), appliedVersion.toJson());
    if (!decidedAt.isEmpty())
        o.insert(QStringLiteral("decidedAt"), decidedAt);
    return o;
}

bool Verdict::fromJson(const QJsonObject &o, Verdict &out, QString &error)
{
    Verdict v;
    v.proposalId = o.value(QStringLiteral("proposalId")).toString();

    const QString verdictStr = o.value(QStringLiteral("verdict")).toString();
    if (verdictStr.isEmpty()) {
        error = QStringLiteral("invalid_verdict: champ 'verdict' manquant");
        return false;
    }
    bool okOutcome = false;
    v.outcome = verdictOutcomeFromName(verdictStr, &okOutcome);
    if (!okOutcome) {
        error = QStringLiteral("invalid_verdict: valeur 'verdict' inconnue (%1)")
                    .arg(verdictStr);
        return false;
    }

    v.decidedBy = o.value(QStringLiteral("decidedBy")).toObject();

    const QJsonArray rs = o.value(QStringLiteral("reasons")).toArray();
    for (const QJsonValue &rv : rs) {
        if (!rv.isObject()) continue;
        VerdictReason r = VerdictReason::fromJson(rv.toObject());
        if (r.audience != audiencePlayer() && r.audience != audienceAi()) {
            error = QStringLiteral("invalid_verdict: audience inconnue (%1)")
                        .arg(r.audience);
            return false;
        }
        v.reasons.append(r);
    }

    if (o.contains(QStringLiteral("amendment")))
        v.amendment = VerdictAmendment::fromJson(
            o.value(QStringLiteral("amendment")).toObject());
    if (o.contains(QStringLiteral("benchReport")))
        v.benchReport = BenchReport::fromJson(
            o.value(QStringLiteral("benchReport")).toObject());
    if (o.contains(QStringLiteral("appliedVersion")))
        v.appliedVersion = BaseVersion::fromJson(
            o.value(QStringLiteral("appliedVersion")).toObject());
    v.decidedAt = o.value(QStringLiteral("decidedAt")).toString();

    out = std::move(v);
    return true;
}

bool Verdict::fromVariantMap(const QVariantMap &m, Verdict &out, QString &error)
{
    return fromJson(QJsonObject::fromVariantMap(m), out, error);
}

} // namespace meow::proposal
