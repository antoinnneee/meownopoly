#include "rules_engine.h"

#include <algorithm>
#include <utility>

#include <QJsonDocument>
#include <QTimer>
#include <QUuid>
#include <QtQml>

#include "game/events/gameplay_event_bus.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/map/map.h"
#include "game/map/mapfilemanager.h"
#include "game/memory/memory_store.h"
#include "game/modules/gameplay_module_manager.h"

using meow::rules::Rule;
using meow::rules::RuleCondition;
using meow::rules::RuleEffect;
using meow::rules::Rulebook;

// ==================== singleton / enregistrement QML ====================

RulesEngine *RulesEngine::m_instance = nullptr;

RulesEngine::RulesEngine(QObject *parent)
    : QObject(parent)
{
}

RulesEngine *RulesEngine::instance()
{
    if (!m_instance) m_instance = new RulesEngine();
    return m_instance;
}

QObject *RulesEngine::qmlInstance(QQmlEngine *, QJSEngine *)
{
    RulesEngine *inst = RulesEngine::instance();
    // Consommé aussi côté C++ (GameSave T4-2, checkpoint T4-3) → ownership C++.
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void RulesEngine::registerQml()
{
    qmlRegisterSingletonType<RulesEngine>(
        "MeowRules", 1, 0, "RulesEngine", &RulesEngine::qmlInstance);
}

// ==================== propriétés simples ====================

void RulesEngine::setEngineEnabled(bool enabled)
{
    if (m_engineEnabled == enabled) return;
    m_engineEnabled = enabled;
    emit engineEnabledChanged();
}

void RulesEngine::setHostAuthority(bool host)
{
    if (m_hostAuthority == host) return;
    m_hostAuthority = host;
    emit hostAuthorityChanged();
}

void RulesEngine::setLastError(const QString &error)
{
    if (m_lastError == error) return;
    m_lastError = error;
    emit lastErrorChanged();
}

// ==================== câblage des sources ====================

void RulesEngine::connectSources()
{
    if (m_sourcesConnected) return;
    m_sourcesConnected = true;

    // Bus d'événements : source unique du pipeline D33 (file transactionnelle
    // D12 déjà en place — profondeur, budget, cycles).
    GameplayEventBus *bus = GameplayEventBus::instance();
    connect(bus, &GameplayEventBus::eventPublished,
            this, &RulesEngine::onBusEvent, Qt::UniqueConnection);

    // Ingestion mémoire (doc v3/06 §5.3) : les écritures session/joueur du
    // MemoryStore deviennent des événements `memory.changed` du bus — l'espace
    // mémoire est le bus de variables des règles. Le causeId courant est
    // propagé : une écriture faite PENDANT un effet de règle est rattachée à
    // la cascade de l'événement déclencheur (garde-fous D12 gratuits).
    // NB : la mémoire des TUILES (ItemSnapable) n'est pas agrégée centralement
    // au MVP — question ouverte doc v3/06 §6.
    MemoryStore *store = MemoryStore::instance();
    connect(store, &MemoryStore::memoryValueChanged, this,
            [this](const QString &ns, const QString &key, const QVariant &value,
                   int version) {
                QVariantMap payload;
                payload.insert(QStringLiteral("ns"), ns);
                payload.insert(QStringLiteral("scope"),
                               ns == MemoryStore::sessionScopeName()
                                   ? QStringLiteral("session")
                                   : QStringLiteral("player"));
                payload.insert(QStringLiteral("key"), key);
                payload.insert(QStringLiteral("value"), value);
                payload.insert(QStringLiteral("version"), version);
                GameplayEventBus::instance()->publish(
                    static_cast<int>(meow::EventType::MemoryChanged),
                    static_cast<int>(meow::EventSource::Memory),
                    QStringLiteral("memory"), payload, m_currentCauseId);
            });
}

// ==================== règlement (rulebook_set) ====================

bool RulesEngine::applyRulebookOp(const QVariantMap &op, const QString &author,
                                  const QString &proposalId)
{
    QString mode = op.value(QStringLiteral("mode")).toString();
    // Compat : un payload sans mode mais avec `rulebook` = set complet.
    if (mode.isEmpty() && op.contains(QStringLiteral("rulebook")))
        mode = QStringLiteral("set");
    QString error;

    const auto stampOrigin = [&](Rule &r) {
        if (!proposalId.isEmpty()) r.originProposalId = proposalId;
        if (!author.isEmpty() && r.author.isEmpty()) r.author = author;
    };

    if (mode == QLatin1String("set")) {
        const QJsonObject bookJson = QJsonObject::fromVariantMap(
            op.value(QStringLiteral("rulebook")).toMap());
        Rulebook incoming;
        if (!Rulebook::fromJson(bookJson, incoming, error)) {
            setLastError(error);
            return false;
        }
        // Version : monotone côté hôte, jamais reprise telle quelle du payload
        // (l'hôte fait foi — au mieux on saute au-delà d'une version annoncée).
        const qint64 next = qMax(m_book.version, incoming.version) + 1;
        for (Rule &r : incoming.rules) stampOrigin(r);
        m_book         = incoming;
        m_book.version = next;
    } else if (mode == QLatin1String("add_rule")) {
        Rule r = Rule::fromJson(
            QJsonObject::fromVariantMap(op.value(QStringLiteral("rule")).toMap()));
        stampOrigin(r);
        if (!r.isValid(&error)) { setLastError(error); return false; }
        if (m_book.indexOfRule(r.id) >= 0) {
            setLastError(QStringLiteral("rulebook_set: règle '%1' déjà présente "
                                        "(utiliser update_rule)").arg(r.id));
            return false;
        }
        if (m_book.rules.size() >= meow::rules::kMaxRules) {
            setLastError(QStringLiteral("rulebook_set: plafond de règles atteint (%1)")
                             .arg(meow::rules::kMaxRules));
            return false;
        }
        m_book.rules.append(r);
        ++m_book.version;
    } else if (mode == QLatin1String("update_rule")) {
        Rule r = Rule::fromJson(
            QJsonObject::fromVariantMap(op.value(QStringLiteral("rule")).toMap()));
        stampOrigin(r);
        if (!r.isValid(&error)) { setLastError(error); return false; }
        const int idx = m_book.indexOfRule(r.id);
        if (idx < 0) {
            setLastError(QStringLiteral("rulebook_set: règle '%1' inconnue").arg(r.id));
            return false;
        }
        m_book.rules[idx] = r;
        ++m_book.version;
    } else if (mode == QLatin1String("remove_rule")) {
        const QString ruleId = op.value(QStringLiteral("ruleId")).toString();
        const int idx = m_book.indexOfRule(ruleId);
        if (idx < 0) {
            setLastError(QStringLiteral("rulebook_set: règle '%1' inconnue").arg(ruleId));
            return false;
        }
        m_book.rules.removeAt(idx);
        ++m_book.version;
    } else if (mode == QLatin1String("clear")) {
        m_book.rules.clear();
        ++m_book.version;
    } else {
        setLastError(QStringLiteral("rulebook_set: mode inconnu '%1'").arg(mode));
        return false;
    }

    setLastError(QString());
    emit rulebookChanged();
    publishRulesChanged(mode, op.value(QStringLiteral("ruleId")).toString(),
                        author, proposalId);
    return true;
}

void RulesEngine::publishRulesChanged(const QString &mode, const QString &ruleId,
                                      const QString &author,
                                      const QString &proposalId)
{
    QVariantMap payload;
    payload.insert(QStringLiteral("version"), m_book.version);
    payload.insert(QStringLiteral("mode"), mode);
    if (!ruleId.isEmpty()) payload.insert(QStringLiteral("ruleId"), ruleId);
    if (!proposalId.isEmpty())
        payload.insert(QStringLiteral("proposalId"), proposalId);
    payload.insert(QStringLiteral("ruleCount"), m_book.rules.size());
    GameplayEventBus::instance()->publish(
        static_cast<int>(meow::EventType::RulesChanged),
        static_cast<int>(meow::EventSource::Rules), author, payload,
        /*causeId=*/QString());
}

QVariantMap RulesEngine::rulebookMap() const
{
    return m_book.toJson().toVariantMap();
}

QVariantList RulesEngine::rulesList() const
{
    QVariantList out;
    for (const Rule &r : m_book.rules)
        out.append(r.toJson().toVariantMap());
    return out;
}

// ==================== persistance (M7 / D37) ====================

QJsonObject RulesEngine::toJson() const
{
    QJsonObject o;
    o.insert(QStringLiteral("rulebook"), m_book.toJson());
    return o;
}

bool RulesEngine::loadJson(const QJsonObject &obj, QString *error)
{
    QString err;
    Rulebook incoming;
    if (!Rulebook::fromJson(obj.value(QStringLiteral("rulebook")).toObject(),
                            incoming, err)) {
        if (error) *error = err;
        setLastError(err);
        return false;
    }
    m_book = incoming;
    setLastError(QString());
    emit rulebookChanged();
    return true;
}

QVariantMap RulesEngine::toVariantMap() const
{
    return toJson().toVariantMap();
}

bool RulesEngine::loadVariantMap(const QVariantMap &map)
{
    return loadJson(QJsonObject::fromVariantMap(map));
}

void RulesEngine::reset()
{
    m_book.rules.clear();
    m_book.title.clear();
    // `version` reste monotone (les enveloppes en vol restent comparables).
    ++m_book.version;
    for (auto &bucket : m_buckets) bucket.clear();
    setLastError(QString());
    emit rulebookChanged();
}

// ==================== pipeline D33 ====================

int RulesEngine::phaseOf(int type)
{
    // Doc v3/06 §5.3 : physique (4xx) → mémoire (5xx) → actions/édition
    // (2xx-3xx) → tick/divers (1xx cycle de vie, 6xx règles, inconnus).
    if (type >= 400 && type < 500) return 0;
    if (type >= 500 && type < 600) return 1;
    if (type >= 200 && type < 400) return 2;
    return 3;
}

void RulesEngine::onBusEvent(const QVariantMap &event)
{
    if (!m_engineEnabled || !m_hostAuthority) return;
    if (m_book.rules.isEmpty()) return;

    const int type = event.value(QStringLiteral("type")).toInt();
    m_buckets[phaseOf(type)].append(event);
    scheduleDrain();
}

void RulesEngine::scheduleDrain()
{
    if (m_drainScheduled || m_draining) return;
    m_drainScheduled = true;
    // Pas de simulation MVP = coalescence sur le tour de boucle d'événements :
    // tout ce qui est publié dans le même tour est classé puis traité dans
    // l'ordre D33 (phases, puis seq intra-phase).
    QTimer::singleShot(0, this, [this]() {
        m_drainScheduled = false;
        drainBuckets();
    });
}

int RulesEngine::drainNow()
{
    return drainBuckets();
}

void RulesEngine::tick()
{
    if (!m_engineEnabled || !m_hostAuthority) return;
    GameplayEventBus::instance()->publish(
        static_cast<int>(meow::EventType::GameTick),
        static_cast<int>(meow::EventSource::Game), QStringLiteral("host"),
        QVariantMap(), /*causeId=*/QString());
}

int RulesEngine::drainBuckets()
{
    if (m_draining) return 0;
    m_draining = true;
    int processed = 0;

    // Des événements peuvent arriver PENDANT le drain (effets → bus → retour
    // synchrone) : on itère par passes bornées ; ce qui déborde attend le
    // prochain pas (les garde-fous D12 du bus bornent de toute façon les
    // cascades).
    for (int pass = 0; pass < kMaxDrainPasses; ++pass) {
        bool any = false;
        for (auto &bucket : m_buckets)
            if (!bucket.isEmpty()) { any = true; break; }
        if (!any) break;

        for (int phase = 0; phase < 4; ++phase) {
            QVector<QVariantMap> batch;
            batch.swap(m_buckets[phase]);
            if (batch.isEmpty()) continue;
            // Ordre intra-phase : séquence d'arrivée hôte (D33).
            std::sort(batch.begin(), batch.end(),
                      [](const QVariantMap &a, const QVariantMap &b) {
                          return a.value(QStringLiteral("seq")).toULongLong()
                                 < b.value(QStringLiteral("seq")).toULongLong();
                      });
            for (const QVariantMap &event : batch) {
                evaluateEvent(event);
                if (++processed >= kMaxEventsPerPass) break;
            }
            if (processed >= kMaxEventsPerPass) break;
        }
        if (processed >= kMaxEventsPerPass) break;
    }

    m_draining = false;
    // Un reliquat (dépassement de passes/quota) sera traité au prochain pas.
    bool leftover = false;
    for (auto &bucket : m_buckets)
        if (!bucket.isEmpty()) { leftover = true; break; }
    if (leftover) scheduleDrain();
    return processed;
}

void RulesEngine::evaluateEvent(const QVariantMap &event)
{
    if (!m_engineEnabled || !m_hostAuthority) return;

    const auto type = static_cast<meow::EventType>(
        event.value(QStringLiteral("type")).toInt());
    const QString canalType = GameplayEventBus::canalTypeName(type);

    for (const Rule &rule : std::as_const(m_book.rules)) {
        if (!rule.enabled) continue;
        // La forme `module` est une configuration appliquée à l'acceptation
        // (applyRulebookOp), pas un déclencheur runtime — sauf si un trigger
        // est déclaré (ré-application, ex. « désactive la monnaie au tick »).
        if (rule.form == meow::rules::form::kModule && rule.trigger.isEmpty())
            continue;
        if (!ruleMatches(rule, canalType, event)) continue;
        executeRule(rule, event);
    }
}

bool RulesEngine::ruleMatches(const Rule &rule, const QString &canalType,
                              const QVariantMap &event) const
{
    if (rule.trigger != QLatin1String("*") && rule.trigger != canalType)
        return false;
    for (const RuleCondition &cond : rule.conditions)
        if (!conditionHolds(cond, event)) return false;
    return true;
}

QVariant RulesEngine::resolveSource(const QString &source,
                                    const QVariantMap &event) const
{
    if (source.startsWith(QLatin1String("event."))) {
        const QString field = source.mid(6);
        if (field == QLatin1String("type")) {
            const auto type = static_cast<meow::EventType>(
                event.value(QStringLiteral("type")).toInt());
            return GameplayEventBus::canalTypeName(type);
        }
        const QVariantMap payload =
            event.value(QStringLiteral("payload")).toMap();
        if (payload.contains(field)) return payload.value(field);
        return event.value(field);   // champs d'entête (author, seq, …)
    }

    if (source.startsWith(QLatin1String("memory."))) {
        const QString rest = source.mid(7);
        if (rest.startsWith(QLatin1String("session."))) {
            return MemoryStore::instance()->sessionValue(rest.mid(8));
        }
        if (rest.startsWith(QLatin1String("player."))) {
            const QString tail = rest.mid(7);
            const int dot = tail.indexOf(QLatin1Char('.'));
            if (dot <= 0) return QVariant();
            const QString playerId = tail.left(dot);
            const QString key      = tail.mid(dot + 1);
            MemoryScope *scope = MemoryStore::instance()->playerIfExists(playerId);
            return scope ? scope->memoryValue(key) : QVariant();
        }
        if (rest.startsWith(QLatin1String("tile."))) {
            const QString tail = rest.mid(5);
            const int dot = tail.indexOf(QLatin1Char('.'));
            if (dot <= 0) return QVariant();
            const QString uuid = tail.left(dot);
            const QString key  = tail.mid(dot + 1);
            Map *map = MapFileManager::instance()->getCurrentMap();
            if (!map) return QVariant();
            const QUuid parsed(uuid);
            const QString wanted =
                parsed.isNull() ? uuid : parsed.toString(QUuid::WithoutBraces);
            const QList<ItemSnapable *> tiles = map->tiles();
            for (ItemSnapable *tile : tiles) {
                if (!tile) continue;
                if (tile->uniqueId().toString(QUuid::WithoutBraces) == wanted)
                    return tile->memoryValue(key);
            }
            return QVariant();
        }
    }
    return QVariant();
}

bool RulesEngine::conditionHolds(const RuleCondition &cond,
                                 const QVariantMap &event) const
{
    const QVariant left = resolveSource(cond.source, event);

    if (cond.op == QLatin1String("exists"))  return left.isValid();
    if (cond.op == QLatin1String("missing")) return !left.isValid();

    if (cond.op == QLatin1String("contains")) {
        if (left.typeId() == QMetaType::QVariantList)
            return left.toList().contains(cond.value);
        return left.toString().contains(cond.value.toString());
    }

    if (cond.op == QLatin1String("eq"))  return left == cond.value;
    if (cond.op == QLatin1String("neq")) return !(left == cond.value);

    // Comparaisons ordonnées : numériques si possible, sinon lexicales.
    bool okL = false, okR = false;
    const double l = left.toDouble(&okL);
    const double r = cond.value.toDouble(&okR);
    if (okL && okR) {
        if (cond.op == QLatin1String("lt"))  return l <  r;
        if (cond.op == QLatin1String("lte")) return l <= r;
        if (cond.op == QLatin1String("gt"))  return l >  r;
        if (cond.op == QLatin1String("gte")) return l >= r;
        return false;
    }
    const int c = QString::compare(left.toString(), cond.value.toString());
    if (cond.op == QLatin1String("lt"))  return c <  0;
    if (cond.op == QLatin1String("lte")) return c <= 0;
    if (cond.op == QLatin1String("gt"))  return c >  0;
    if (cond.op == QLatin1String("gte")) return c >= 0;
    return false;
}

// ==================== exécution des effets ====================

void RulesEngine::executeRule(const Rule &rule, const QVariantMap &event)
{
    const QString eventId = event.value(QStringLiteral("id")).toString();

    // Contexte causal : tout ce que produit la règle (effets, écritures
    // mémoire relayées) est rattaché à l'événement déclencheur → cascade
    // couverte par les garde-fous D12 du bus.
    const QString previousCause = m_currentCauseId;
    m_currentCauseId = eventId;

    if (rule.form == meow::rules::form::kDsl) {
        for (const RuleEffect &effect : rule.effects) {
            if (!executeEffect(effect, rule, event)) {
                ++m_effectRejectedCount;
            }
        }
    } else if (rule.form == meow::rules::form::kModule) {
        GameplayModuleManager::instance()->setModuleEnabled(rule.moduleId,
                                                            rule.moduleEnabled);
    }
    // Forme artifact : rien à exécuter ici — l'artefact validé au banc est
    // pris en charge par la couche sandbox (S-6/D13) qui consomme
    // rule.triggered / le signal ruleTriggered. Aucun code hors banc (D32).

    ++m_triggeredCount;

    QVariantMap payload;
    payload.insert(QStringLiteral("ruleId"), rule.id);
    payload.insert(QStringLiteral("form"), rule.form);
    payload.insert(QStringLiteral("trigger"), rule.trigger);
    if (!rule.artifactHash.isEmpty()) {
        payload.insert(QStringLiteral("artifactHash"), rule.artifactHash);
        if (!rule.artifactUuid.isEmpty())
            payload.insert(QStringLiteral("uuid"), rule.artifactUuid);
    }
    GameplayEventBus::instance()->publish(
        static_cast<int>(meow::EventType::RuleTriggered),
        static_cast<int>(meow::EventSource::Rules), QStringLiteral("rules"),
        payload, eventId);

    m_currentCauseId = previousCause;

    emit ruleTriggered(rule.id, rule.form, event);
    emit statsChanged();
}

bool RulesEngine::executeEffect(const RuleEffect &effect, const Rule &rule,
                                const QVariantMap &event)
{
    const QString eventId = event.value(QStringLiteral("id")).toString();

    if (effect.action == QLatin1String("memory.set")) {
        const QString  scope = effect.args.value(QStringLiteral("scope")).toString();
        const QString  key   = effect.args.value(QStringLiteral("key")).toString();
        const QVariant value = effect.args.value(QStringLiteral("value"));
        if (scope == QLatin1String("session"))
            return MemoryStore::instance()->setSessionValue(key, value);
        if (scope == QLatin1String("player")) {
            const QString playerId =
                effect.args.value(QStringLiteral("playerId")).toString();
            return MemoryStore::instance()->setPlayerValue(playerId, key, value);
        }
        if (scope == QLatin1String("tile")) {
            const QString uuid = effect.args.value(QStringLiteral("uuid")).toString();
            Map *map = MapFileManager::instance()->getCurrentMap();
            if (!map) return false;
            const QUuid parsed(uuid);
            const QString wanted =
                parsed.isNull() ? uuid : parsed.toString(QUuid::WithoutBraces);
            const QList<ItemSnapable *> tiles = map->tiles();
            for (ItemSnapable *tile : tiles) {
                if (!tile) continue;
                if (tile->uniqueId().toString(QUuid::WithoutBraces) == wanted) {
                    tile->setMemoryValue(key, value);
                    return true;
                }
            }
            qWarning() << "RULES: memory.set — tuile introuvable" << uuid
                       << "(règle" << rule.id << ")";
            return false;
        }
        return false;
    }

    if (effect.action == QLatin1String("event.emit")) {
        QVariantMap payload =
            effect.args.value(QStringLiteral("payload")).toMap();
        payload.insert(QStringLiteral("name"),
                       effect.args.value(QStringLiteral("name")).toString());
        payload.insert(QStringLiteral("ruleId"), rule.id);
        GameplayEventBus::instance()->publish(
            static_cast<int>(meow::EventType::RuleEventEmitted),
            static_cast<int>(meow::EventSource::Rules), QStringLiteral("rules"),
            payload, eventId);
        return true;
    }

    if (effect.action == QLatin1String("module.config")) {
        const QString moduleId = effect.args.value(QStringLiteral("id")).toString();
        const bool enabled = effect.args.value(QStringLiteral("enabled")).toBool();
        return GameplayModuleManager::instance()->setModuleEnabled(moduleId, enabled);
    }

    qWarning() << "RULES: effet inconnu" << effect.action << "(règle" << rule.id << ")";
    return false;
}
