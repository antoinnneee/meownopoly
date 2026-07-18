#ifndef ARTIFACT_REGISTRY_H
#define ARTIFACT_REGISTRY_H

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#include "artifact_store.h"

// =============================================================================
// ArtifactManifest — métadonnées immuables d'un artefact (D16/D38)
// -----------------------------------------------------------------------------
// Voyage à côté du blob dans le store, adressé par le même contentHash. Champs
// `signature`/`publisherKeyId` **réservés** dès la v1 (D38 : modèle de confiance
// différé, R16) pour ne pas casser le format quand la signature arrivera.
// =============================================================================
struct ArtifactManifest
{
    QString contentHash;   // SHA-256 du blob (source de vérité de l'identité)
    QString kind;          // "asset3d|primitive|module|skin|qml" (D38)
    int manifestVersion = 1;
    QString author;
    QStringList deps;                 // ids d'artefacts dépendants (D38)
    QString execPolicy = QStringLiteral("host_only"); // D16 (défaut sûr)
    QVariantMap budgets;              // budgets runtime D34 (opaques ici)

    // Confiance — RÉSERVÉ (D38/R16). Toujours vide au MVP.
    QString signature;
    QString publisherKeyId;

    QJsonObject toJson() const;
    static ArtifactManifest fromJson(const QJsonObject &json);
    bool isValid() const { return !contentHash.isEmpty(); }
};

// =============================================================================
// ArtifactRef — référence portée par une tuile (D36)
// -----------------------------------------------------------------------------
// `{instanceId, contentHash, manifestVersion}`. instanceId = identité
// d'instance (le QUuid existant reste l'identité de tuile, D16) ; contentHash +
// manifestVersion = identité d'artefact immuable.
// =============================================================================
struct ArtifactRef
{
    QString instanceId;
    QString contentHash;
    int manifestVersion = 1;

    QJsonObject toJson() const;
    QVariantMap toVariantMap() const;
    static ArtifactRef fromJson(const QJsonObject &json);
    static ArtifactRef fromVariantMap(const QVariantMap &map);
    bool isValid() const { return !contentHash.isEmpty(); }
};

// =============================================================================
// ArtifactRegistry — index des manifestes + refcount + GC au save (D16/D36)
// -----------------------------------------------------------------------------
// Singleton C++ (motif AssetManager). Les manifestes sont persistés sous
// `<AppDataLocation>/artifacts/manifests/<hash>.json`, les blobs dans
// ArtifactStore. Un artefact absent → l'appelant désactive l'élément avec
// diagnostic (D16), la référence n'est pas perdue.
// =============================================================================
class ArtifactRegistry : public QObject
{
    Q_OBJECT
public:
    explicit ArtifactRegistry(QObject *parent = nullptr);
    static ArtifactRegistry *instance();

    // Enregistre un artefact : écrit le blob (dédup) + le manifeste. Le
    // contentHash du manifeste est (re)calculé sur le contenu — jamais déclaré
    // par l'appelant (invariant D16). Retourne le contentHash, vide si échec.
    QString registerArtifact(const QByteArray &content, ArtifactManifest manifest);

    // Diagnostic (D16) : le blob ET le manifeste sont présents.
    Q_INVOKABLE bool isAvailable(const QString &contentHash) const;

    ArtifactManifest manifest(const QString &contentHash) const;
    QByteArray content(const QString &contentHash) const;

    // ---- Refcount (D36) ----
    // Comptage en mémoire, alimenté au fil des ajouts/retraits de références de
    // tuiles. La suppression n'entraîne PAS de purge immédiate (préserve l'undo
    // de la suppression) ; la purge se fait au save (collectGarbage).
    void addRef(const QString &contentHash);
    void releaseRef(const QString &contentHash);
    int refCount(const QString &contentHash) const;

    // GC au save (D36). Balaye le store : tout artefact dont le hash n'est pas
    // dans `liveHashes` (= référencé par au moins une tuile de la map courante)
    // est purgé (blob + manifeste). Le sweep est autoritatif — indépendant du
    // refcount en mémoire, robuste aux compteurs désynchronisés. Retourne le
    // nombre d'artefacts purgés.
    Q_INVOKABLE int collectGarbage(const QSet<QString> &liveHashes);

    QStringList knownHashes() const;

signals:
    void artifactRegistered(const QString &contentHash);
    void artifactPurged(const QString &contentHash);

private:
    QString manifestDir() const;
    QString manifestPath(const QString &contentHash) const;
    void loadManifests();
    bool writeManifest(const ArtifactManifest &manifest);

    static ArtifactRegistry *s_instance;
    ArtifactStore m_store;
    QHash<QString, ArtifactManifest> m_manifests; // contentHash -> manifeste
    QHash<QString, int> m_refCounts;              // contentHash -> refcount
    bool m_manifestsLoaded = false;
};

#endif // ARTIFACT_REGISTRY_H
