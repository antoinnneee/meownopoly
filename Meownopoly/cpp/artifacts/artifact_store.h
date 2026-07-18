#ifndef ARTIFACT_STORE_H
#define ARTIFACT_STORE_H

#include <QByteArray>
#include <QString>
#include <QStringList>

// =============================================================================
// ArtifactStore — store de contenu adressé par hash (D16/D36, plan V3 T4-1/M8)
// -----------------------------------------------------------------------------
// Une **seule** copie par SHA-256 sous `<AppDataLocation>/artifacts/blobs/`.
// Les tuiles ne portent que des références `{instanceId, contentHash,
// manifestVersion}` (cf. ArtifactRef) — jamais de copie par tuile (D36).
//
// Le calcul SHA-256 est une ré-implémentation *prudente* du motif de
// `launcher_manager.cpp:179-192` (streaming 64 Ko, QCryptographicHash::Sha256,
// `.result().toHex()`). Le launcher reste inchangé ([pat]) : on n'en extrait
// que la recette, pas le code, pour ne pas coupler ce module au monolithe
// launcher (1618 l.).
// =============================================================================
class ArtifactStore
{
public:
    ArtifactStore();
    explicit ArtifactStore(const QString &rootDir);

    // ---- Hash (recette launcher, streaming 64 Ko) ----
    // SHA-256 hexadécimal (64 chars minuscules) d'un buffer en mémoire.
    static QString computeSha256(const QByteArray &content);
    // SHA-256 hexadécimal d'un fichier, lu par blocs de 64 Ko (évite de charger
    // un gros artefact entier en RAM). Chaîne vide si le fichier est illisible.
    static QString computeFileSha256(const QString &filePath);

    // ---- Écriture / lecture adressées par hash ----
    // Insère `content` dans le store. Dédup : si le hash existe déjà, aucune
    // ré-écriture. Écriture atomique (.tmp + rename). Retourne le contentHash,
    // ou une chaîne vide en cas d'échec d'écriture.
    QString put(const QByteArray &content);

    bool contains(const QString &contentHash) const;
    QByteArray get(const QString &contentHash) const;

    // Supprime le blob (GC D36). Vrai si un fichier a été retiré.
    bool remove(const QString &contentHash);

    // Liste des hashes présents dans le store.
    QStringList list() const;

    // Chemin disque absolu du blob pour un hash (existe ou non).
    QString pathForHash(const QString &contentHash) const;

    QString rootDir() const { return m_rootDir; }

private:
    // `<AppDataLocation>/artifacts/blobs/` par défaut.
    static QString defaultRootDir();
    // Garantit l'existence du sous-dossier de fan-out (`<root>/<2 premiers>/`).
    QString ensureBucketDir(const QString &contentHash) const;
    // Un hash SHA-256 valide = 64 caractères hexadécimaux.
    static bool isValidHash(const QString &contentHash);

    QString m_rootDir;
};

#endif // ARTIFACT_STORE_H
