#include "proposal_types.h"

namespace meow::proposal {

QString requestTypeName(RequestType t)
{
    switch (t) {
    case RequestType::DataSafe:  return QStringLiteral("data_safe");
    case RequestType::Structure: return QStringLiteral("structure");
    case RequestType::Rules:     return QStringLiteral("rules");
    case RequestType::Code:      return QStringLiteral("code");
    }
    return QStringLiteral("data_safe");
}

RequestType requestTypeFromName(const QString &name, bool *ok)
{
    if (ok) *ok = true;
    if (name == QLatin1String("data_safe")) return RequestType::DataSafe;
    if (name == QLatin1String("structure")) return RequestType::Structure;
    if (name == QLatin1String("rules"))     return RequestType::Rules;
    if (name == QLatin1String("code"))      return RequestType::Code;
    if (ok) *ok = false;
    return RequestType::DataSafe;
}

QString proposalStateName(ProposalState s)
{
    switch (s) {
    case ProposalState::Draft:              return QStringLiteral("draft");
    case ProposalState::Submitted:          return QStringLiteral("submitted");
    case ProposalState::Prefiltered:        return QStringLiteral("prefiltered");
    case ProposalState::Queued:             return QStringLiteral("queued");
    case ProposalState::Arbitrating:        return QStringLiteral("arbitrating");
    case ProposalState::Amended:            return QStringLiteral("amended");
    case ProposalState::Benching:           return QStringLiteral("benching");
    case ProposalState::Validated:          return QStringLiteral("validated");
    case ProposalState::Applying:           return QStringLiteral("applying");
    case ProposalState::Applied:            return QStringLiteral("applied");
    case ProposalState::RejectedMechanical: return QStringLiteral("rejected_mechanical");
    case ProposalState::RejectedArbiter:    return QStringLiteral("rejected_arbiter");
    case ProposalState::RejectedBench:      return QStringLiteral("rejected_bench");
    case ProposalState::Failed:             return QStringLiteral("failed");
    }
    return QStringLiteral("draft");
}

ProposalState proposalStateFromName(const QString &name, bool *ok)
{
    if (ok) *ok = true;
    if (name == QLatin1String("draft"))               return ProposalState::Draft;
    if (name == QLatin1String("submitted"))           return ProposalState::Submitted;
    if (name == QLatin1String("prefiltered"))         return ProposalState::Prefiltered;
    if (name == QLatin1String("queued"))              return ProposalState::Queued;
    if (name == QLatin1String("arbitrating"))         return ProposalState::Arbitrating;
    if (name == QLatin1String("amended"))             return ProposalState::Amended;
    if (name == QLatin1String("benching"))            return ProposalState::Benching;
    if (name == QLatin1String("validated"))           return ProposalState::Validated;
    if (name == QLatin1String("applying"))            return ProposalState::Applying;
    if (name == QLatin1String("applied"))             return ProposalState::Applied;
    if (name == QLatin1String("rejected_mechanical")) return ProposalState::RejectedMechanical;
    if (name == QLatin1String("rejected_arbiter"))    return ProposalState::RejectedArbiter;
    if (name == QLatin1String("rejected_bench"))      return ProposalState::RejectedBench;
    if (name == QLatin1String("failed"))              return ProposalState::Failed;
    if (ok) *ok = false;
    return ProposalState::Draft;
}

bool isTerminalState(ProposalState s)
{
    switch (s) {
    case ProposalState::Applied:
    case ProposalState::RejectedMechanical:
    case ProposalState::RejectedArbiter:
    case ProposalState::RejectedBench:
    case ProposalState::Failed:
        return true;
    default:
        return false;
    }
}

bool isRejectedState(ProposalState s)
{
    switch (s) {
    case ProposalState::RejectedMechanical:
    case ProposalState::RejectedArbiter:
    case ProposalState::RejectedBench:
        return true;
    default:
        return false;
    }
}

QString verdictOutcomeName(VerdictOutcome v)
{
    switch (v) {
    case VerdictOutcome::Accepted: return QStringLiteral("accepted");
    case VerdictOutcome::Rejected: return QStringLiteral("rejected");
    case VerdictOutcome::Amended:  return QStringLiteral("amended");
    }
    return QStringLiteral("rejected");
}

VerdictOutcome verdictOutcomeFromName(const QString &name, bool *ok)
{
    if (ok) *ok = true;
    if (name == QLatin1String("accepted")) return VerdictOutcome::Accepted;
    if (name == QLatin1String("rejected")) return VerdictOutcome::Rejected;
    if (name == QLatin1String("amended"))  return VerdictOutcome::Amended;
    if (ok) *ok = false;
    return VerdictOutcome::Rejected;
}

} // namespace meow::proposal
