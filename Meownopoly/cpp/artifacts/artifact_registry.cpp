#include "artifact_registry.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QQmlEngine>
#include <QStandardPaths>

#include <utility>

// ============================================================================
// ArtifactManifest (de)sérialisation
// ============================================================================
QJsonObject ArtifactManifest::toJson() const
{
    QJsonObject o;
    o["contentHash"] = contentHash;
    o["kind"] = kind;
    o["manifestVersion"] = manifestVersion;
    o["author"] = author;
    o["execPolicy"] = execPolicy;
    QJsonArray depsArr;
    for (const QString &d : deps)
        depsArr.append(d);
    o["deps"] = depsArr;
    o["budgets"] = QJsonObject::fromVariantMap(budgets);
    // Champs de confiance réservés (D38) — sérialisés même vides pour figer le
    // format dès la v1.
    o["signature"] = signature;
    o["publisherKeyId"] = publisherKeyId;
    return o;
}

ArtifactManifest ArtifactManifest::fromJson(const QJsonObject &json)
{
    ArtifactManifest m;
    m.contentHash = json.value("contentHash").toString();
    m.kind = json.value("kind").toString();
    m.manifestVersion = json.value("manifestVersion").toInt(1);
    m.author = json.value("author").toString();
    m.execPolicy = json.value("execPolicy").toString(QStringLiteral("host_only"));
    const QJsonArray depsArr = json.value("deps").toArray();
    for (const QJsonValue &v : depsArr)
        m.deps.append(v.toString());
    m.budgets = json.value("budgets").toObject().toVariantMap();
    m.signature = json.value("signature").toString();
    m.publisherKeyId = json.value("publisherKeyId").toString();
    return m;
}

// ============================================================================
// ArtifactRef (de)sérialisation
// ============================================================================
QJsonObject ArtifactRef::toJson() const
{
    QJsonObject o;
    o["instanceId"] = instanceId;
    o["contentHash"] = contentHash;
    o["manifestVersion"] = manifestVersion;
    return o;
}

QVariantMap ArtifactRef::toVariantMap() const
{
    QVariantMap m;
    m["instanceId"] = instanceId;
    m["contentHash"] = contentHash;
    m["manifestVersion"] = manifestVersion;
    return m;
}

ArtifactRef ArtifactRef::fromJson(const QJsonObject &json)
{
    ArtifactRef r;
    r.instanceId = json.value("instanceId").toString();
    r.contentHash = json.value("contentHash").toString();
    r.manifestVersion = json.value("manifestVersion").toInt(1);
    return r;
}

ArtifactRef ArtifactRef::fromVariantMap(const QVariantMap &map)
{
    ArtifactRef r;
    r.instanceId = map.value("instanceId").toString();
    r.contentHash = map.value("contentHash").toString();
    r.manifestVersion = map.value("manifestVersion").toInt();
    if (r.manifestVersion == 0)
        r.manifestVersion = 1;
    return r;
}

// ============================================================================
// ArtifactRegistry
// ============================================================================
ArtifactRegistry *ArtifactRegistry::s_instance = nullptr;

ArtifactRegistry::ArtifactRegistry(QObject *parent)
    : QObject(parent)
{
    if (!s_instance)
        s_instance = this;
    QDir().mkpath(manifestDir());
    loadManifests();
}

ArtifactRegistry *ArtifactRegistry::instance()
{
    if (!s_instance)
        s_instance = new ArtifactRegistry();
    return s_instance;
}

void ArtifactRegistry::registerQml()
{
    qmlRegisterSingletonType<ArtifactRegistry>(
        "MeowArtifacts", 1, 0, "ArtifactRegistry", &ArtifactRegistry::qmlInstance);
}

QObject *ArtifactRegistry::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    ArtifactRegistry *reg = instance();
    QQmlEngine::setObjectOwnership(reg, QQmlEngine::CppOwnership);
    return reg;
}

QString ArtifactRegistry::registerTextArtifact(const QString &content,
                                               const QString &kind,
                                               const QString &author)
{
    ArtifactManifest m;
    m.kind = kind;
    m.author = author;
    return registerArtifact(content.toUtf8(), std::move(m));
}

QString ArtifactRegistry::contentText(const QString &contentHash) const
{
    return QString::fromUtf8(content(contentHash));
}

QVariantMap ArtifactRegistry::manifestInfo(const QString &contentHash) const
{
    const ArtifactManifest m = manifest(contentHash);
    if (!m.isValid())
        return {};
    QVariantMap info = m.toJson().toVariantMap();
    info.insert(QStringLiteral("available"), isAvailable(contentHash));
    info.insert(QStringLiteral("refCount"), refCount(contentHash));
    return info;
}

int ArtifactRegistry::collectGarbageList(const QStringList &liveHashes)
{
    return collectGarbage(QSet<QString>(liveHashes.begin(), liveHashes.end()));
}

QString ArtifactRegistry::manifestDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/artifacts/manifests");
}

QString ArtifactRegistry::manifestPath(const QString &contentHash) const
{
    return manifestDir() + QStringLiteral("/") + contentHash
           + QStringLiteral(".json");
}

void ArtifactRegistry::loadManifests()
{
    if (m_manifestsLoaded)
        return;
    m_manifestsLoaded = true;

    QDir dir(manifestDir());
    const QStringList files = dir.entryList(QStringList() << "*.json", QDir::Files);
    for (const QString &f : files) {
        QFile file(dir.filePath(f));
        if (!file.open(QIODevice::ReadOnly))
            continue;
        const QByteArray raw = file.readAll();
        file.close();
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject())
            continue;
        const ArtifactManifest m = ArtifactManifest::fromJson(doc.object());
        if (m.isValid())
            m_manifests.insert(m.contentHash, m);
    }
}

bool ArtifactRegistry::writeManifest(const ArtifactManifest &manifest)
{
    const QString path = manifestPath(manifest.contentHash);
    const QString tmp = path + QStringLiteral(".tmp");
    QFile file(tmp);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    const QByteArray raw =
        QJsonDocument(manifest.toJson()).toJson(QJsonDocument::Indented);
    const qint64 written = file.write(raw);
    file.close();
    if (written != raw.size()) {
        QFile::remove(tmp);
        return false;
    }
    QFile::remove(path);
    if (!QFile::rename(tmp, path)) {
        QFile::remove(tmp);
        return false;
    }
    return true;
}

QString ArtifactRegistry::registerArtifact(const QByteArray &content,
                                           ArtifactManifest manifest)
{
    const QString contentHash = m_store.put(content);
    if (contentHash.isEmpty())
        return QString();

    // Invariant D16 : le hash est TOUJOURS recalculé sur le contenu, jamais
    // déclaré par l'auteur. On écrase un éventuel champ fourni.
    manifest.contentHash = contentHash;

    m_manifests.insert(contentHash, manifest);
    writeManifest(manifest);

    emit artifactRegistered(contentHash);
    return contentHash;
}

bool ArtifactRegistry::isAvailable(const QString &contentHash) const
{
    return m_store.contains(contentHash) && m_manifests.contains(contentHash);
}

ArtifactManifest ArtifactRegistry::manifest(const QString &contentHash) const
{
    return m_manifests.value(contentHash);
}

QByteArray ArtifactRegistry::content(const QString &contentHash) const
{
    return m_store.get(contentHash);
}

void ArtifactRegistry::addRef(const QString &contentHash)
{
    if (contentHash.isEmpty())
        return;
    m_refCounts[contentHash] = m_refCounts.value(contentHash, 0) + 1;
}

void ArtifactRegistry::releaseRef(const QString &contentHash)
{
    if (contentHash.isEmpty())
        return;
    const int n = m_refCounts.value(contentHash, 0);
    if (n <= 1)
        m_refCounts.remove(contentHash);
    else
        m_refCounts[contentHash] = n - 1;
    // Pas de purge immédiate (D36) : l'artefact devient « orphelin » et n'est
    // retiré qu'au save via collectGarbage — préserve l'undo de la suppression.
}

int ArtifactRegistry::refCount(const QString &contentHash) const
{
    return m_refCounts.value(contentHash, 0);
}

int ArtifactRegistry::collectGarbage(const QSet<QString> &liveHashes)
{
    int purged = 0;
    // Sweep autoritatif (D36) : on part de l'état réel du store, pas du
    // refcount en mémoire (qui peut avoir dérivé après des undo/redo).
    const QStringList stored = m_store.list();
    for (const QString &hash : stored) {
        if (liveHashes.contains(hash))
            continue;
        // Orphelin : plus aucune tuile ne le référence → purge blob + manifeste.
        if (m_store.remove(hash))
            ++purged;
        m_manifests.remove(hash);
        m_refCounts.remove(hash);
        QFile::remove(manifestPath(hash));
        emit artifactPurged(hash);
    }
    return purged;
}

QStringList ArtifactRegistry::knownHashes() const
{
    return m_manifests.keys();
}
