#include "memory_store.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QtQml>

// ============================================================================
// MemoryScope
// ============================================================================

MemoryScope::MemoryScope(QString scopeName, QObject *parent)
    : QObject(parent)
    , m_scopeName(std::move(scopeName))
{
}

int MemoryScope::variantSizeBytes(const QVariant &value)
{
    // Estimation via JSON compact — cohérente avec le transport (D35 raisonne en
    // octets sérialisés). Une valeur scalaire est enveloppée dans un tableau pour
    // que QJsonDocument accepte de la sérialiser.
    const QJsonValue jv = QJsonValue::fromVariant(value);
    return QJsonDocument(QJsonArray{ jv }).toJson(QJsonDocument::Compact).size();
}

int MemoryScope::estimatedSizeBytes() const
{
    return QJsonDocument(QJsonObject::fromVariantMap(m_userMemory))
        .toJson(QJsonDocument::Compact)
        .size();
}

void MemoryScope::setUserMemory(const QVariantMap &memory)
{
    // Garde anti-boucle : pas de ré-émission si la map est identique.
    if (m_userMemory == memory)
        return;
    m_userMemory = memory;
    ++m_memoryVersion;
    emit userMemoryChanged();
}

bool MemoryScope::setMemoryValue(const QString &key, const QVariant &value)
{
    // Garde anti-boucle (D15) : pas d'émission si la valeur n'a pas réellement
    // changé — casse la cascade écriture→signal→ré-écriture.
    if (m_userMemory.contains(key) && m_userMemory.value(key) == value)
        return false;

    // Plafond D35 par valeur (1 KB). Rejet à la source, pas de troncature.
    const int valueBytes = variantSizeBytes(value);
    if (valueBytes > kMaxValueBytes) {
        qWarning() << "MEMORY_STORE: valeur trop grande (" << valueBytes
                   << "o >" << kMaxValueBytes << ") sur la clé" << key
                   << "portée" << m_scopeName << "- écriture refusée";
        emit quotaExceeded(m_scopeName, key, QStringLiteral("value"));
        return false;
    }

    // Plafond D35 par portée (256 KB), évalué sur l'état résultant.
    QVariantMap candidate = m_userMemory;
    candidate.insert(key, value);
    const int scopeBytes = QJsonDocument(QJsonObject::fromVariantMap(candidate))
                               .toJson(QJsonDocument::Compact)
                               .size();
    if (scopeBytes > kMaxScopeBytes) {
        qWarning() << "MEMORY_STORE: portée saturée (" << scopeBytes << "o >"
                   << kMaxScopeBytes << ") en écrivant" << key << "dans"
                   << m_scopeName << "- écriture refusée";
        emit quotaExceeded(m_scopeName, key, QStringLiteral("scope"));
        return false;
    }

    // Garde de réentrance : plafonne les cascades légitimes mais non convergentes.
    if (m_memoryWriteDepth >= kMaxMemoryCascadeDepth) {
        qWarning() << "MEMORY_STORE: cascade mémoire trop profonde ("
                   << m_memoryWriteDepth << ") sur la clé" << key << "portée"
                   << m_scopeName << "- écriture ignorée pour éviter la boucle";
        return false;
    }

    ++m_memoryWriteDepth;
    m_userMemory.insert(key, value);
    ++m_memoryVersion;
    // Réveil ciblé d'abord (abonnés fins), puis réveil global (bindings QML).
    emit memoryValueChanged(m_scopeName, key, value, int(m_memoryVersion));
    emit userMemoryChanged();
    --m_memoryWriteDepth;
    return true;
}

bool MemoryScope::removeMemoryValue(const QString &key)
{
    if (!m_userMemory.contains(key))
        return false;
    m_userMemory.remove(key);
    ++m_memoryVersion;
    // Réveil ciblé avec une valeur invalide = « clé supprimée ».
    emit memoryValueChanged(m_scopeName, key, QVariant(), int(m_memoryVersion));
    emit userMemoryChanged();
    return true;
}

void MemoryScope::clear()
{
    if (m_userMemory.isEmpty())
        return;
    m_userMemory.clear();
    ++m_memoryVersion;
    emit userMemoryChanged();
}

QJsonObject MemoryScope::toJson() const
{
    return QJsonObject::fromVariantMap(m_userMemory);
}

void MemoryScope::loadJson(const QJsonObject &memory)
{
    // Passe par setUserMemory pour émettre userMemoryChanged (la restauration
    // réveille les abonnés, comme ItemSnapable::applyJson, doc v3/05 §3 Étape A).
    setUserMemory(memory.toVariantMap());
}

// ============================================================================
// MemoryStore
// ============================================================================

MemoryStore *MemoryStore::m_instance = nullptr;

MemoryStore::MemoryStore(QObject *parent)
    : QObject(parent)
{
    m_session = new MemoryScope(sessionScopeName(), this);
    wireScope(m_session);
}

MemoryStore *MemoryStore::instance()
{
    if (!m_instance)
        m_instance = new MemoryStore();
    return m_instance;
}

QObject *MemoryStore::qmlInstance(QQmlEngine *, QJSEngine *)
{
    MemoryStore *inst = MemoryStore::instance();
    // Aussi consommé côté C++ (persistance GameSave, futur bus d'état) → garder
    // l'ownership C++ pour survivre à la destruction de l'engine.
    QQmlEngine::setObjectOwnership(inst, QQmlEngine::CppOwnership);
    return inst;
}

void MemoryStore::registerQml()
{
    // MemoryScope est renvoyé par des Q_INVOKABLE mais jamais instancié depuis QML.
    qmlRegisterUncreatableType<MemoryScope>(
        "MeowMemory", 1, 0, "MemoryScope",
        QStringLiteral("MemoryScope est fourni par MemoryStore, pas instanciable."));
    qmlRegisterSingletonType<MemoryStore>(
        "MeowMemory", 1, 0, "MemoryStore", &MemoryStore::qmlInstance);
}

void MemoryStore::wireScope(MemoryScope *scope)
{
    // Relais des signaux fins vers les signaux agrégés du store (point
    // d'abonnement unique pour l'IA/règles).
    connect(scope, &MemoryScope::memoryValueChanged,
            this, &MemoryStore::memoryValueChanged);
    connect(scope, &MemoryScope::quotaExceeded,
            this, &MemoryStore::quotaExceeded);
}

MemoryScope *MemoryStore::player(const QString &playerId)
{
    auto it = m_players.constFind(playerId);
    if (it != m_players.constEnd())
        return it.value();

    auto *scope = new MemoryScope(playerId, this);
    wireScope(scope);
    m_players.insert(playerId, scope);
    emit playerAdded(playerId);
    emit playersChanged();
    return scope;
}

MemoryScope *MemoryStore::playerIfExists(const QString &playerId) const
{
    return m_players.value(playerId, nullptr);
}

bool MemoryStore::removePlayer(const QString &playerId)
{
    auto it = m_players.constFind(playerId);
    if (it == m_players.constEnd())
        return false;
    it.value()->deleteLater();
    m_players.erase(it);
    emit playerRemoved(playerId);
    emit playersChanged();
    return true;
}

bool MemoryStore::setSessionValue(const QString &key, const QVariant &value)
{
    return m_session->setMemoryValue(key, value);
}

QVariant MemoryStore::sessionValue(const QString &key) const
{
    return m_session->memoryValue(key);
}

bool MemoryStore::setPlayerValue(const QString &playerId, const QString &key,
                                 const QVariant &value)
{
    return player(playerId)->setMemoryValue(key, value);
}

QVariant MemoryStore::playerValue(const QString &playerId, const QString &key) const
{
    MemoryScope *scope = playerIfExists(playerId);
    return scope ? scope->memoryValue(key) : QVariant();
}

void MemoryStore::reset()
{
    m_session->clear();
    const QStringList ids = m_players.keys();
    for (const QString &id : ids)
        removePlayer(id);
}

QJsonObject MemoryStore::toJson() const
{
    QJsonObject root;
    root.insert(QStringLiteral("version"), kSchemaVersion);
    root.insert(QStringLiteral("session"), m_session->toJson());

    QJsonObject players;
    for (auto it = m_players.constBegin(); it != m_players.constEnd(); ++it)
        players.insert(it.key(), it.value()->toJson());
    root.insert(QStringLiteral("players"), players);
    return root;
}

void MemoryStore::loadJson(const QJsonObject &obj)
{
    // On ne fait pas de reset() brutal : loadJson remplace les portées présentes
    // dans le blob et laisse le reste. Pour un remplacement complet, appeler
    // reset() avant.
    if (obj.contains(QStringLiteral("session")))
        m_session->loadJson(obj.value(QStringLiteral("session")).toObject());

    const QJsonObject players = obj.value(QStringLiteral("players")).toObject();
    for (auto it = players.constBegin(); it != players.constEnd(); ++it)
        player(it.key())->loadJson(it.value().toObject());
}

QVariantMap MemoryStore::toVariantMap() const
{
    return toJson().toVariantMap();
}

void MemoryStore::loadVariantMap(const QVariantMap &map)
{
    loadJson(QJsonObject::fromVariantMap(map));
}
