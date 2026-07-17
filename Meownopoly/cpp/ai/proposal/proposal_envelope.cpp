#include "proposal_envelope.h"

#include <algorithm>

#include <QSet>
#include <QUuid>

namespace meow::proposal {

// ==================== BaseVersion ====================

QJsonObject BaseVersion::toJson() const
{
    QJsonObject o;
    if (rulebook >= 0)    o.insert(QStringLiteral("rulebook"),    static_cast<double>(rulebook));
    if (mapRevision >= 0) o.insert(QStringLiteral("mapRevision"), static_cast<double>(mapRevision));
    if (journalSeq >= 0)  o.insert(QStringLiteral("journalSeq"),  static_cast<double>(journalSeq));
    return o;
}

BaseVersion BaseVersion::fromJson(const QJsonObject &o)
{
    BaseVersion b;
    if (o.contains(QStringLiteral("rulebook")))
        b.rulebook = static_cast<qint64>(o.value(QStringLiteral("rulebook")).toDouble(-1));
    if (o.contains(QStringLiteral("mapRevision")))
        b.mapRevision = static_cast<qint64>(o.value(QStringLiteral("mapRevision")).toDouble(-1));
    if (o.contains(QStringLiteral("journalSeq")))
        b.journalSeq = static_cast<qint64>(o.value(QStringLiteral("journalSeq")).toDouble(-1));
    return b;
}

// ==================== Operation ====================

Operation Operation::fromJson(const QJsonObject &o)
{
    Operation op;
    op.op         = o.value(QStringLiteral("op")).toString();
    op.kind       = o.value(QStringLiteral("kind")).toString();
    // `subop` / `op` (sous-op de editor_edit) : accepte les deux clés courantes.
    op.subop      = o.value(QStringLiteral("subop")).toString();
    op.scope      = o.value(QStringLiteral("scope")).toString();
    op.uuid       = o.value(QStringLiteral("uuid")).toString();
    op.key        = o.value(QStringLiteral("key")).toString();
    op.clientOpId = o.value(QStringLiteral("clientOpId")).toString();
    op.raw        = o;
    return op;
}

QJsonObject Operation::toJson() const
{
    // Le brut d'origine est autoritaire pour l'application aval ; on le renvoie
    // tel quel (il contient déjà op/kind/params/clientOpId).
    return raw;
}

RequestType Operation::category() const
{
    // Modification du règlement (D12) → rules.
    if (op == QLatin1String("rules_set") || op == QLatin1String("rules_edit")
        || op == QLatin1String("rulebook_set")) {
        return RequestType::Rules;
    }
    // Roster (profils joueurs / limites map) et activation de module → structure.
    if (op == QLatin1String("roster_edit") || op == QLatin1String("module_config")
        || op == QLatin1String("set_map_player_limits")) {
        return RequestType::Structure;
    }
    // editor_edit : suppression / redimensionnement → structure ; déplacement /
    // (dé)liaison → data_safe (repositionnement dans les quotas).
    if (op == QLatin1String("editor_edit") || op == QLatin1String("editor_delete")
        || op == QLatin1String("editor_resize")) {
        const QString s = subop.isEmpty() ? op : subop;
        if (s.contains(QLatin1String("delete")) || s.contains(QLatin1String("resize")))
            return RequestType::Structure;
        return RequestType::DataSafe;
    }
    // editor_place / memory_set et le reste : poses / écritures → data_safe.
    return RequestType::DataSafe;
}

QStringList Operation::writeSet() const
{
    QStringList out;
    // memory_set : cible = "<uuid>/<key>".
    if (!uuid.isEmpty() && !key.isEmpty())
        out.append(uuid + QLatin1Char('/') + key);
    // Un write-set explicite porté par l'op est repris (union, pas foi).
    const QJsonValue ws = raw.value(QStringLiteral("writeSet"));
    if (ws.isArray()) {
        const QJsonArray arr = ws.toArray();
        for (const QJsonValue &v : arr) {
            const QString s = v.toString();
            if (!s.isEmpty()) out.append(s);
        }
    }
    return out;
}

// ==================== Artifact ====================

static QStringList jsonStringArray(const QJsonValue &v)
{
    QStringList out;
    if (!v.isArray()) return out;
    const QJsonArray arr = v.toArray();
    for (const QJsonValue &e : arr) {
        const QString s = e.toString();
        if (!s.isEmpty()) out.append(s);
    }
    return out;
}

Artifact Artifact::fromJson(const QJsonObject &o)
{
    Artifact a;
    a.contentHash      = o.value(QStringLiteral("contentHash")).toString();
    a.source           = o.value(QStringLiteral("source")).toString();
    a.targetUuid       = o.value(QStringLiteral("targetUuid")).toString();
    a.executionPolicy  = o.value(QStringLiteral("executionPolicy"))
                             .toString(QStringLiteral("host_only"));
    a.declaredWriteSet = jsonStringArray(o.value(QStringLiteral("declaredWriteSet")));
    a.listensTo        = jsonStringArray(o.value(QStringLiteral("listensTo")));
    a.requiresModules  = jsonStringArray(o.value(QStringLiteral("requiresModules")));
    return a;
}

QJsonObject Artifact::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("contentHash"), contentHash);
    o.insert(QStringLiteral("source"), source);
    if (!targetUuid.isEmpty())
        o.insert(QStringLiteral("targetUuid"), targetUuid);
    o.insert(QStringLiteral("executionPolicy"), executionPolicy);
    o.insert(QStringLiteral("declaredWriteSet"),
             QJsonArray::fromStringList(declaredWriteSet));
    o.insert(QStringLiteral("listensTo"), QJsonArray::fromStringList(listensTo));
    o.insert(QStringLiteral("requiresModules"),
             QJsonArray::fromStringList(requiresModules));
    return o;
}

// ==================== Envelope ====================

RequestType Envelope::computeRequestType() const
{
    // Un seul artefact ⇒ code (le plancher le plus haut, non contournable).
    if (!artifacts.isEmpty())
        return RequestType::Code;

    // Sinon, MAX des catégories des opérations.
    RequestType max = RequestType::DataSafe;
    for (const Operation &op : operations) {
        const RequestType c = op.category();
        if (static_cast<int>(c) > static_cast<int>(max))
            max = c;
    }
    return max;
}

QStringList Envelope::computeWriteSet() const
{
    QStringList out;
    for (const Operation &op : operations)
        out += op.writeSet();
    for (const Artifact &a : artifacts)
        out += a.declaredWriteSet;

    // Trier + dédupliquer (stable, déterministe pour le journal / undo ciblé).
    std::sort(out.begin(), out.end());
    out.erase(std::unique(out.begin(), out.end()), out.end());
    return out;
}

QStringList Envelope::requiredModules() const
{
    QSet<QString> seen;
    QStringList out;
    for (const Artifact &a : artifacts) {
        for (const QString &m : a.requiresModules) {
            if (!m.isEmpty() && !seen.contains(m)) {
                seen.insert(m);
                out.append(m);
            }
        }
    }
    return out;
}

bool Envelope::fromJson(const QJsonObject &o, Envelope &out, QString &error)
{
    error.clear();
    Envelope e;

    e.envelopeVersion = o.value(QStringLiteral("envelopeVersion")).toInt(kEnvelopeVersion);
    if (e.envelopeVersion > kEnvelopeVersion) {
        error = QStringLiteral("unsupported_envelope: version %1 > %2")
                    .arg(e.envelopeVersion).arg(kEnvelopeVersion);
        return false;
    }

    e.proposalId = o.value(QStringLiteral("proposalId")).toString();
    if (e.proposalId.isEmpty())
        e.proposalId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    e.channelVersion = o.value(QStringLiteral("channelVersion")).toString();

    const QJsonObject authorO = o.value(QStringLiteral("author")).toObject();
    e.author.playerId = authorO.value(QStringLiteral("playerId")).toString();
    e.author.role     = authorO.value(QStringLiteral("role"))
                            .toString(QStringLiteral("proposer"));
    e.author.agent    = authorO.value(QStringLiteral("agent")).toObject();

    const QJsonObject intentO = o.value(QStringLiteral("intent")).toObject();
    e.intent.playerPrompt = intentO.value(QStringLiteral("playerPrompt")).toString();
    e.intent.aiSummary    = intentO.value(QStringLiteral("aiSummary")).toString();

    e.baseVersion = BaseVersion::fromJson(o.value(QStringLiteral("baseVersion")).toObject());

    const QJsonArray opsArr = o.value(QStringLiteral("operations")).toArray();
    if (opsArr.size() > kMaxOps) {
        error = QStringLiteral("too_many_operations: %1 > %2")
                    .arg(opsArr.size()).arg(kMaxOps);
        return false;
    }
    for (const QJsonValue &v : opsArr)
        e.operations.append(Operation::fromJson(v.toObject()));

    const QJsonArray artArr = o.value(QStringLiteral("artifacts")).toArray();
    if (artArr.size() > kMaxArtifacts) {
        error = QStringLiteral("too_many_artifacts: %1 > %2")
                    .arg(artArr.size()).arg(kMaxArtifacts);
        return false;
    }
    for (const QJsonValue &v : artArr) {
        Artifact a = Artifact::fromJson(v.toObject());
        if (a.source.toUtf8().size() > kMaxArtifactBytes) {
            error = QStringLiteral("artifact_too_large: %1 > %2 octets")
                        .arg(a.source.toUtf8().size()).arg(kMaxArtifactBytes);
            return false;
        }
        e.artifacts.append(a);
    }

    e.createdAt = o.value(QStringLiteral("createdAt")).toString();
    e.expiresAt = o.value(QStringLiteral("expiresAt")).toString();

    out = std::move(e);
    return true;
}

QJsonObject Envelope::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("envelopeVersion"), envelopeVersion);
    o.insert(QStringLiteral("proposalId"), proposalId);
    if (!channelVersion.isEmpty())
        o.insert(QStringLiteral("channelVersion"), channelVersion);

    QJsonObject authorO;
    authorO.insert(QStringLiteral("playerId"), author.playerId);
    authorO.insert(QStringLiteral("role"), author.role);
    if (!author.agent.isEmpty())
        authorO.insert(QStringLiteral("agent"), author.agent);
    o.insert(QStringLiteral("author"), authorO);

    QJsonObject intentO;
    intentO.insert(QStringLiteral("playerPrompt"), intent.playerPrompt);
    intentO.insert(QStringLiteral("aiSummary"), intent.aiSummary);
    o.insert(QStringLiteral("intent"), intentO);

    // requestType : la valeur CALCULÉE par le P0 fait foi au journal.
    o.insert(QStringLiteral("requestType"), requestTypeName(computeRequestType()));

    if (baseVersion.isSet())
        o.insert(QStringLiteral("baseVersion"), baseVersion.toJson());

    QJsonArray opsArr;
    for (const Operation &op : operations)
        opsArr.append(op.toJson());
    o.insert(QStringLiteral("operations"), opsArr);

    QJsonArray artArr;
    for (const Artifact &a : artifacts)
        artArr.append(a.toJson());
    o.insert(QStringLiteral("artifacts"), artArr);

    o.insert(QStringLiteral("writeSet"), QJsonArray::fromStringList(computeWriteSet()));

    if (!createdAt.isEmpty()) o.insert(QStringLiteral("createdAt"), createdAt);
    if (!expiresAt.isEmpty()) o.insert(QStringLiteral("expiresAt"), expiresAt);
    return o;
}

} // namespace meow::proposal
