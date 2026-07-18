#include "artifact_store.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

ArtifactStore::ArtifactStore()
    : m_rootDir(defaultRootDir())
{
    QDir().mkpath(m_rootDir);
}

ArtifactStore::ArtifactStore(const QString &rootDir)
    : m_rootDir(rootDir)
{
    if (m_rootDir.isEmpty())
        m_rootDir = defaultRootDir();
    QDir().mkpath(m_rootDir);
}

QString ArtifactStore::defaultRootDir()
{
    // Isolation par instance déjà portée par applicationName (--instance N) →
    // AppDataLocation renvoie des dossiers distincts (cf. CLAUDE.md dual-test).
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/artifacts/blobs");
}

bool ArtifactStore::isValidHash(const QString &contentHash)
{
    if (contentHash.size() != 64)
        return false;
    for (const QChar c : contentHash) {
        const bool hex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
        if (!hex)
            return false;
    }
    return true;
}

QString ArtifactStore::computeSha256(const QByteArray &content)
{
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(content);
    // .result().toHex() → hex minuscule (même forme que launcher_manager.cpp:1331).
    return QString::fromLatin1(hash.result().toHex());
}

QString ArtifactStore::computeFileSha256(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return QString();

    QCryptographicHash hash(QCryptographicHash::Sha256);
    // Streaming 64 Ko : recette de launcher_manager.cpp:191-193 (pré-hash du
    // contenu partiel). Évite de charger un artefact volumineux entier en RAM.
    while (!file.atEnd())
        hash.addData(file.read(64 * 1024));
    file.close();
    return QString::fromLatin1(hash.result().toHex());
}

QString ArtifactStore::ensureBucketDir(const QString &contentHash) const
{
    // Fan-out par 2 premiers caractères pour éviter un dossier plat géant.
    const QString bucket = m_rootDir + QStringLiteral("/") + contentHash.left(2);
    QDir().mkpath(bucket);
    return bucket;
}

QString ArtifactStore::pathForHash(const QString &contentHash) const
{
    if (!isValidHash(contentHash))
        return QString();
    return m_rootDir + QStringLiteral("/") + contentHash.left(2)
           + QStringLiteral("/") + contentHash;
}

QString ArtifactStore::put(const QByteArray &content)
{
    const QString contentHash = computeSha256(content);
    const QString target = pathForHash(contentHash);
    if (target.isEmpty())
        return QString();

    // Dédup (D36) : une copie par hash, jamais de ré-écriture.
    if (QFileInfo::exists(target))
        return contentHash;

    ensureBucketDir(contentHash);

    // Écriture atomique : .tmp puis rename (même garantie que
    // mapfilemanager.cpp:261-284). Un crash pendant l'écriture ne laisse jamais
    // un blob tronqué visible sous son hash définitif.
    const QString tmp = target + QStringLiteral(".tmp");
    QFile tmpFile(tmp);
    if (!tmpFile.open(QIODevice::WriteOnly))
        return QString();
    const qint64 written = tmpFile.write(content);
    tmpFile.close();
    if (written != content.size()) {
        QFile::remove(tmp);
        return QString();
    }
    // rename ne remplace pas une cible existante sur certains OS : on a déjà
    // écarté ce cas (dédup ci-dessus), mais on nettoie par prudence.
    QFile::remove(target);
    if (!QFile::rename(tmp, target)) {
        QFile::remove(tmp);
        return QString();
    }
    return contentHash;
}

bool ArtifactStore::contains(const QString &contentHash) const
{
    const QString p = pathForHash(contentHash);
    return !p.isEmpty() && QFileInfo::exists(p);
}

QByteArray ArtifactStore::get(const QString &contentHash) const
{
    const QString p = pathForHash(contentHash);
    if (p.isEmpty())
        return QByteArray();
    QFile file(p);
    if (!file.open(QIODevice::ReadOnly))
        return QByteArray();
    const QByteArray data = file.readAll();
    file.close();
    return data;
}

bool ArtifactStore::remove(const QString &contentHash)
{
    const QString p = pathForHash(contentHash);
    if (p.isEmpty() || !QFileInfo::exists(p))
        return false;
    return QFile::remove(p);
}

QStringList ArtifactStore::list() const
{
    QStringList hashes;
    QDir root(m_rootDir);
    const QStringList buckets =
        root.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &bucket : buckets) {
        QDir bucketDir(root.filePath(bucket));
        const QStringList files = bucketDir.entryList(QDir::Files);
        for (const QString &f : files) {
            if (isValidHash(f))
                hashes.append(f);
        }
    }
    return hashes;
}
