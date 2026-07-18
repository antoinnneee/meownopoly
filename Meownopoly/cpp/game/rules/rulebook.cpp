#include "rulebook.h"

#include <QJsonValue>
#include <QSet>
#include <QUuid>

namespace meow::rules {

// ==================== RuleCondition ====================

bool RuleCondition::isValid(QString *error) const
{
    static const QSet<QString> kOps = {
        QStringLiteral("eq"),  QStringLiteral("neq"),      QStringLiteral("lt"),
        QStringLiteral("lte"), QStringLiteral("gt"),       QStringLiteral("gte"),
        QStringLiteral("contains"), QStringLiteral("exists"),
        QStringLiteral("missing"),
    };
    if (!kOps.contains(op)) {
        if (error) *error = QStringLiteral("condition: opérateur inconnu '%1'").arg(op);
        return false;
    }
    const bool eventSrc  = source.startsWith(QLatin1String("event."));
    const bool memorySrc = source.startsWith(QLatin1String("memory."));
    if (!eventSrc && !memorySrc) {
        if (error)
            *error = QStringLiteral(
                         "condition: source '%1' invalide (attendu event.<champ> "
                         "ou memory.<portée>.<clé>)")
                         .arg(source);
        return false;
    }
    return true;
}

RuleCondition RuleCondition::fromJson(const QJsonObject &o)
{
    RuleCondition c;
    c.source = o.value(QStringLiteral("source")).toString();
    c.op     = o.value(QStringLiteral("op")).toString(QStringLiteral("eq"));
    c.value  = o.value(QStringLiteral("value")).toVariant();
    return c;
}

QJsonObject RuleCondition::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("source"), source);
    o.insert(QStringLiteral("op"), op);
    if (value.isValid())
        o.insert(QStringLiteral("value"), QJsonValue::fromVariant(value));
    return o;
}

// ==================== RuleEffect ====================

bool RuleEffect::isValid(QString *error) const
{
    if (action == QLatin1String("memory.set")) {
        const QString scope = args.value(QStringLiteral("scope")).toString();
        const QString key   = args.value(QStringLiteral("key")).toString();
        if (key.isEmpty()) {
            if (error) *error = QStringLiteral("memory.set: 'key' requis");
            return false;
        }
        if (scope != QLatin1String("session") && scope != QLatin1String("player")
            && scope != QLatin1String("tile")) {
            if (error)
                *error = QStringLiteral("memory.set: scope '%1' invalide "
                                        "(session|player|tile)").arg(scope);
            return false;
        }
        if (scope == QLatin1String("player")
            && args.value(QStringLiteral("playerId")).toString().isEmpty()) {
            if (error) *error = QStringLiteral("memory.set: 'playerId' requis (scope player)");
            return false;
        }
        if (scope == QLatin1String("tile")
            && args.value(QStringLiteral("uuid")).toString().isEmpty()) {
            if (error) *error = QStringLiteral("memory.set: 'uuid' requis (scope tile)");
            return false;
        }
        return true;
    }
    if (action == QLatin1String("event.emit")) {
        if (args.value(QStringLiteral("name")).toString().isEmpty()) {
            if (error) *error = QStringLiteral("event.emit: 'name' requis");
            return false;
        }
        return true;
    }
    if (action == QLatin1String("module.config")) {
        if (args.value(QStringLiteral("id")).toString().isEmpty()) {
            if (error) *error = QStringLiteral("module.config: 'id' requis");
            return false;
        }
        return true;
    }
    if (error) *error = QStringLiteral("effet: action inconnue '%1'").arg(action);
    return false;
}

RuleEffect RuleEffect::fromJson(const QJsonObject &o)
{
    RuleEffect e;
    e.action = o.value(QStringLiteral("action")).toString();
    e.args   = o.value(QStringLiteral("args")).toObject().toVariantMap();
    return e;
}

QJsonObject RuleEffect::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("action"), action);
    o.insert(QStringLiteral("args"), QJsonObject::fromVariantMap(args));
    return o;
}

// ==================== Rule ====================

bool Rule::isValid(QString *error) const
{
    if (id.trimmed().isEmpty()) {
        if (error) *error = QStringLiteral("règle: id vide");
        return false;
    }
    if (form == form::kModule) {
        if (moduleId.trimmed().isEmpty()) {
            if (error) *error = QStringLiteral("règle %1: 'moduleId' requis (forme module)").arg(id);
            return false;
        }
        return true;
    }
    if (form == form::kDsl) {
        if (trigger.trimmed().isEmpty()) {
            if (error) *error = QStringLiteral("règle %1: 'trigger' requis (forme dsl)").arg(id);
            return false;
        }
        if (conditions.size() > kMaxConditionsPerRule) {
            if (error)
                *error = QStringLiteral("règle %1: trop de conditions (%2 > %3)")
                             .arg(id).arg(conditions.size()).arg(kMaxConditionsPerRule);
            return false;
        }
        if (effects.isEmpty() || effects.size() > kMaxEffectsPerRule) {
            if (error)
                *error = QStringLiteral("règle %1: nombre d'effets invalide (%2, max %3)")
                             .arg(id).arg(effects.size()).arg(kMaxEffectsPerRule);
            return false;
        }
        for (const RuleCondition &c : conditions)
            if (!c.isValid(error)) return false;
        for (const RuleEffect &e : effects)
            if (!e.isValid(error)) return false;
        return true;
    }
    if (form == form::kArtifact) {
        if (trigger.trimmed().isEmpty() || artifactHash.trimmed().isEmpty()) {
            if (error)
                *error = QStringLiteral("règle %1: 'trigger' et 'artifactHash' requis "
                                        "(forme artifact)").arg(id);
            return false;
        }
        return true;
    }
    if (error) *error = QStringLiteral("règle %1: forme inconnue '%2'").arg(id, form);
    return false;
}

Rule Rule::fromJson(const QJsonObject &o)
{
    Rule r;
    r.id      = o.value(QStringLiteral("id")).toString();
    if (r.id.trimmed().isEmpty())
        r.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    r.title   = o.value(QStringLiteral("title")).toString();
    r.notes   = o.value(QStringLiteral("notes")).toString();
    r.form    = o.value(QStringLiteral("form")).toString(form::kDsl);
    r.enabled = o.value(QStringLiteral("enabled")).toBool(true);
    r.trigger = o.value(QStringLiteral("trigger")).toString();

    const QJsonArray conds = o.value(QStringLiteral("conditions")).toArray();
    for (const QJsonValue &v : conds)
        r.conditions.append(RuleCondition::fromJson(v.toObject()));
    const QJsonArray effs = o.value(QStringLiteral("effects")).toArray();
    for (const QJsonValue &v : effs)
        r.effects.append(RuleEffect::fromJson(v.toObject()));

    r.moduleId      = o.value(QStringLiteral("moduleId")).toString();
    r.moduleEnabled = o.value(QStringLiteral("moduleEnabled")).toBool(true);
    r.artifactHash  = o.value(QStringLiteral("artifactHash")).toString();
    r.artifactUuid  = o.value(QStringLiteral("artifactUuid")).toString();

    r.originProposalId = o.value(QStringLiteral("originProposalId")).toString();
    r.author           = o.value(QStringLiteral("author")).toString();
    return r;
}

QJsonObject Rule::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("id"), id);
    o.insert(QStringLiteral("title"), title);
    if (!notes.isEmpty()) o.insert(QStringLiteral("notes"), notes);
    o.insert(QStringLiteral("form"), form);
    o.insert(QStringLiteral("enabled"), enabled);
    if (!trigger.isEmpty()) o.insert(QStringLiteral("trigger"), trigger);

    if (!conditions.isEmpty()) {
        QJsonArray conds;
        for (const RuleCondition &c : conditions) conds.append(c.toJson());
        o.insert(QStringLiteral("conditions"), conds);
    }
    if (!effects.isEmpty()) {
        QJsonArray effs;
        for (const RuleEffect &e : effects) effs.append(e.toJson());
        o.insert(QStringLiteral("effects"), effs);
    }

    if (!moduleId.isEmpty()) {
        o.insert(QStringLiteral("moduleId"), moduleId);
        o.insert(QStringLiteral("moduleEnabled"), moduleEnabled);
    }
    if (!artifactHash.isEmpty()) o.insert(QStringLiteral("artifactHash"), artifactHash);
    if (!artifactUuid.isEmpty()) o.insert(QStringLiteral("artifactUuid"), artifactUuid);

    if (!originProposalId.isEmpty())
        o.insert(QStringLiteral("originProposalId"), originProposalId);
    if (!author.isEmpty()) o.insert(QStringLiteral("author"), author);
    return o;
}

// ==================== Rulebook ====================

int Rulebook::indexOfRule(const QString &ruleId) const
{
    for (int i = 0; i < rules.size(); ++i)
        if (rules.at(i).id == ruleId) return i;
    return -1;
}

bool Rulebook::fromJson(const QJsonObject &o, Rulebook &out, QString &error)
{
    Rulebook b;
    b.schemaVersion = o.value(QStringLiteral("schemaVersion")).toInt(kRulebookSchemaVersion);
    if (b.schemaVersion > kRulebookSchemaVersion) {
        error = QStringLiteral("rulebook: schemaVersion %1 non supporté (courant %2)")
                    .arg(b.schemaVersion).arg(kRulebookSchemaVersion);
        return false;
    }
    b.version = static_cast<qint64>(o.value(QStringLiteral("version")).toDouble(0));
    b.title   = o.value(QStringLiteral("title")).toString();

    const QJsonArray rules = o.value(QStringLiteral("rules")).toArray();
    if (rules.size() > kMaxRules) {
        error = QStringLiteral("rulebook: trop de règles (%1 > %2)")
                    .arg(rules.size()).arg(kMaxRules);
        return false;
    }
    for (const QJsonValue &v : rules) {
        Rule r = Rule::fromJson(v.toObject());
        if (!r.isValid(&error)) return false;
        b.rules.append(r);
    }
    out = b;
    return true;
}

QJsonObject Rulebook::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("schemaVersion"), schemaVersion);
    o.insert(QStringLiteral("version"), static_cast<double>(version));
    if (!title.isEmpty()) o.insert(QStringLiteral("title"), title);
    QJsonArray arr;
    for (const Rule &r : rules) arr.append(r.toJson());
    o.insert(QStringLiteral("rules"), arr);
    return o;
}

} // namespace meow::rules
