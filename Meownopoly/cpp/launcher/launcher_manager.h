#ifndef LAUNCHER_MANAGER_H
#define LAUNCHER_MANAGER_H

#include <QObject>
#include <QQmlEngine>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QHttpMultiPart>
#include <QTimer>
#include <QFile>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDateTime>
#include <QCryptographicHash>
#include <QQueue>
#include "tools/QtFolderCompressor/FolderCompressor.h"

class LauncherManager : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(QString currentVersion READ currentVersion NOTIFY currentVersionChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString downloadStatus READ downloadStatus NOTIFY downloadStatusChanged)
    Q_PROPERTY(bool packageCreated READ packageCreated NOTIFY packageCreatedChanged)
    Q_PROPERTY(QVariantList modelsList READ modelsList NOTIFY modelsListChanged)
    Q_PROPERTY(qint64 bytesReceived READ bytesReceived NOTIFY downloadProgressChanged)
    Q_PROPERTY(qint64 bytesTotal READ bytesTotal NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString versionDescription READ versionDescription NOTIFY latestVersionChanged)

public:
    static void registerQml();
    static LauncherManager *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    
    // Getters for properties
    QString currentVersion() const { return m_currentVersion; }
    QString latestVersion() const { return m_latestVersion; }
    bool isDownloading() const { return m_isDownloading; }
    double downloadProgress() const { return m_downloadProgress; }
    QString downloadStatus() const { return m_downloadStatus; }
    bool packageCreated() const { return m_packageCreated; }
    QVariantList modelsList() const { return m_modelsList; }
    qint64 bytesReceived() const { return m_bytesReceived; }
    qint64 bytesTotal() const { return m_bytesTotal; }
    QString versionDescription() const { return m_versionDescription; }
    
    // Launcher methods invokable from QML
    Q_INVOKABLE void testServerConnection(const QString &serverUrl);
    Q_INVOKABLE void checkForUpdates(const QString &serverUrl);
    Q_INVOKABLE void downloadResources(const QString &serverUrl, const QString &version);
    Q_INVOKABLE void forceDownloadResources(const QString &serverUrl);
    Q_INVOKABLE void createResourcePackage(const QString &folderPath, const QString &version);
    Q_INVOKABLE void uploadPackageToServer(const QString &serverUrl);
    Q_INVOKABLE void resetDownloadState();
    Q_INVOKABLE void setUploadToken(const QString &token);

    // Methods for Models
    Q_INVOKABLE void fetchModelsList(const QString &serverUrl);
    Q_INVOKABLE void downloadModel(const QString &serverUrl, const QString &name, const QString &version);
    Q_INVOKABLE void createModelPackage(const QString &folderPath, const QString &name, const QString &version);
    Q_INVOKABLE void uploadModelPackage(const QString &serverUrl, const QString &name, const QString &version);
    // Supprime un pack de modèle du serveur (DELETE /api/models/delete/:name/:version,
    // authentifié par le token d'upload). Rafraîchit la liste serveur au succès.
    Q_INVOKABLE void deleteModelPackage(const QString &serverUrl, const QString &name, const QString &version);

    // Model 3D Configurator helpers (préparation upload)
    // findModelQml : scanne <folderPath> et retourne le nom de base du
    // premier .qml trouvé (sans extension), ou "" si aucun. Utilisé pour
    // pré-remplir le champ Nom dans le configurateur.
    Q_INVOKABLE QString findModelQml(const QString &folderPath);
    // readModelManifest : lit <folderPath>/model_manifest.json s'il existe
    // et retourne { name, version, timestamp, type }. Map vide si absent.
    Q_INVOKABLE QVariantMap readModelManifest(const QString &folderPath);
    // writeModelManifest : écrit <folderPath>/model_manifest.json à partir
    // d'une string JSON (transform + colorId migrent ici, plus de marker .qml).
    Q_INVOKABLE bool writeModelManifest(const QString &folderPath, const QString &json) const;

    // createModelFromGlb : crée un nouveau dossier de modèle au format kura
    // (remplace l'ancien import .obj → balsam). Copie le .glb dans
    //   <parentDir>/<name>/base/<name>.glb
    // (+ base/skin_base.png si skinBaseSource fourni) et écrit un
    // model_manifest.json squelette. Si parentDir est vide, crée sous
    // <AppData>/model_drafts/. Retourne le chemin (clean) du dossier, ou "".
    Q_INVOKABLE QString createModelFromGlb(const QString &parentDir, const QString &name,
                                           const QString &glbSource,
                                           const QString &skinBaseSource = QString());
    // readModelTransform : lit le bloc marker injecté par le configurateur
    // dans <folderPath>/<modelName>.qml. Retourne {
    //   scale: [sx,sy,sz], eulerRotation: [rx,ry,rz], position: [px,py,pz]
    // }. Si pas de marker (ou bloc ancien sans position), retourne identité
    // pour les champs manquants. Compatible rétro avec l'ancien format
    // 2-lignes (scale + eulerRotation seulement).
    Q_INVOKABLE QVariantMap readModelTransform(const QString &folderPath, const QString &modelName);
    // writeModelTransform : insère/remplace dans <folderPath>/<modelName>.qml
    // un bloc :
    //     // __MODEL_TRANSFORM_BEGIN__
    //     position: Qt.vector3d(px, py, pz)
    //     eulerRotation: Qt.vector3d(rx, ry, rz)
    //     scale: Qt.vector3d(sx, sy, sz)
    //     // __MODEL_TRANSFORM_END__
    // juste après l'`id:` du premier Node racine. Retourne true si OK.
    Q_INVOKABLE bool writeModelTransform(const QString &folderPath, const QString &modelName,
                                         double sx, double sy, double sz,
                                         double rx, double ry, double rz,
                                         double px, double py, double pz);

    // ===================================================================
    // Color ID Map — re-skinning runtime par zone
    // (cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md)
    //
    // Format kuraViewer, SANS balsam : un modèle = un dossier
    //   base/<model>.glb + base/skin_base.png
    //   skins/<skin>/colorMap.png + skin.json + textures/ + variants/
    //   model_manifest.json (name, version, transform, colorId…)
    // chargé au runtime via RuntimeLoader (.glb) + KuraMaterial appliqué par
    // overrideMaterials. Le KuraMaterial.qml + shaders/tint.frag sont
    // UNIQUES et versionnés dans l'app (qrc) — pas de codegen par modèle.
    // ===================================================================

    // --- Créateur de skin : dossiers skins/<skin>/ ---------------------
    // Arborescence (cf. plan §4) :
    //   <folderPath>/skins/<skin>/colorMap.png
    //   <folderPath>/skins/<skin>/skin.json
    //   <folderPath>/skins/<skin>/textures/*.png
    //   <folderPath>/skins/<skin>/variants/*.json

    // Crée skins/<skinName>/ (+ textures/ + variants/), copie la color map
    // source vers colorMap.png et écrit skin.json avec autant de zones que
    // la color map en contient (cf. detectColorMapZones).
    Q_INVOKABLE bool createModelSkin(const QString &folderPath, const QString &skinName,
                                     const QString &colorMapSource);
    // Compte les zones d'une color ID map : nombre de couleurs de palette
    // (≤20) présentes dans l'image → (index max + 1). 1 si échec/aucune.
    Q_INVOKABLE int detectColorMapZones(const QString &colorMapSource) const;
    // Sous-dossiers de <folderPath>/skins (les skins disponibles), triés.
    Q_INVOKABLE QStringList listModelSkins(const QString &folderPath) const;
    // Noms de fichiers image de skins/<skin>/textures.
    Q_INVOKABLE QStringList listSkinTextures(const QString &folderPath, const QString &skin) const;
    // Copie une image source dans skins/<skin>/textures/.
    Q_INVOKABLE bool importSkinTexture(const QString &folderPath, const QString &skin,
                                       const QString &textureSource);
    // Lit/écrit skins/<skin>/skin.json (string JSON, "" si absent).
    Q_INVOKABLE QString readSkinJson(const QString &folderPath, const QString &skin) const;
    Q_INVOKABLE bool    writeSkinJson(const QString &folderPath, const QString &skin,
                                      const QString &json) const;
    // Variantes (presets d'auteur) de skins/<skin>/variants/.
    Q_INVOKABLE QStringList listSkinVariants(const QString &folderPath, const QString &skin) const;
    Q_INVOKABLE bool    saveSkinVariant(const QString &folderPath, const QString &skin,
                                        const QString &name, const QString &json) const;
    Q_INVOKABLE QString loadSkinVariant(const QString &folderPath, const QString &skin,
                                        const QString &name) const;
    Q_INVOKABLE bool    deleteSkinVariant(const QString &folderPath, const QString &skin,
                                          const QString &name) const;
    // Supprime un fichier texture de skins/<skin>/textures/.
    Q_INVOKABLE bool deleteSkinTexture(const QString &folderPath, const QString &skin,
                                       const QString &file) const;

    // --- Bibliothèque de textures générales (partagée entre modèles) ----
    // Dossier <AppData>/model_textures/. On y importe des textures réutilisables,
    // puis on les copie vers le skin d'un modèle à la demande.
    Q_INVOKABLE QString     generalTextureDir() const;
    Q_INVOKABLE QStringList listGeneralTextures() const;
    Q_INVOKABLE bool        importGeneralTexture(const QString &source);
    Q_INVOKABLE bool        deleteGeneralTexture(const QString &file) const;
    Q_INVOKABLE bool        copyGeneralTextureToSkin(const QString &folderPath, const QString &skin,
                                                     const QString &file);

    // Dossier (clean, sans file://) d'un modèle installé : <AppData>/models/<name>.
    Q_INVOKABLE QString installedModelDir(const QString &name) const;

    // Supprime un modèle 3D téléchargé : efface récursivement
    // <AppData>/models/<name> et met à jour m_modelsList en place
    // (isInstalled=false, localVersion="0.0.0" pour cette entrée) +
    // modelsListChanged. Retourne true si le dossier a bien été supprimé.
    Q_INVOKABLE bool deleteModel(const QString &name);

    // Utilitaire de comparaison sémantique de versions
    // Retourne -1 si v1 < v2, 0 si égales, 1 si v1 > v2
    static int compareVersions(const QString &v1, const QString &v2);

signals:
    void currentVersionChanged();
    void latestVersionChanged();
    void isDownloadingChanged();
    void downloadProgressChanged();
    void downloadStatusChanged();
    void packageCreatedChanged();
    void modelsListChanged();
    void connectionTestResult(bool success, const QString &message);
    void logMessage(const QString &message);
    void updateAvailable();
    void downloadSucess();
    void modelDeleteFinished(bool success, const QString &name, const QString &version);

private slots:
    void onDownloadFinished();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onVersionCheckFinished();
    void onConnectionTestFinished();
    void onModelsListFinished();

private:
    explicit LauncherManager(QObject *parent = nullptr);
    static LauncherManager *m_instance;

    // --- Requête de téléchargement (queue) ---
    struct DownloadRequest {
        enum Type { Asset, Model };
        Type type;
        QString serverUrl;
        QString version;
        QString modelName;
        QString modelVersion;
    };
    QQueue<DownloadRequest> m_downloadQueue;
    void executeDownload(const DownloadRequest &req);
    void processNextDownload();

    // Network components
    QNetworkAccessManager *m_networkManager = nullptr;
    QNetworkReply *m_currentDownload = nullptr;
    QNetworkReply *m_versionCheckReply = nullptr;
    QNetworkReply *m_connectionTestReply = nullptr;
    QNetworkReply *m_modelsListReply = nullptr;
    QFile *m_downloadFile = nullptr;

    // FolderCompressor instance
    FolderCompressor *m_folderCompressor = nullptr;

    // Properties
    QString m_currentVersion = "0.0.0";
    QString m_latestVersion = "0.0.0";
    QString m_versionDescription;
    bool m_isDownloading = false;
    double m_downloadProgress = 0.0;
    QString m_downloadStatus = "Prêt";
    bool m_packageCreated = false;
    QString m_lastCreatedPackage;
    QVariantList m_modelsList;
    qint64 m_bytesReceived = 0;
    qint64 m_bytesTotal = 0;

    // Auth
    QString m_uploadToken;

    // Checksum verification
    QString m_expectedChecksum;
    QCryptographicHash *m_downloadHash = nullptr;

    // Download timeout
    QTimer *m_downloadTimer = nullptr;
    static constexpr int DOWNLOAD_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

    // Retry
    int m_retryCount = 0;
    static constexpr int MAX_RETRIES = 3;
    DownloadRequest m_currentRequest;

    // Helper methods
    QString getCurrentVersionFromFile();
    void saveVersionInfo(const QString &version);
    QJsonObject createVersionManifest(const QString &version);
    bool parseVersionInfo(const QJsonObject &versionInfo);
    void setCurrentVersion(const QString &version);
    void setLatestVersion(const QString &version);
    void setIsDownloading(bool downloading);
    void setDownloadProgress(double progress);
    void setDownloadStatus(const QString &status);
    void setPackageCreated(bool created);
    void setModelsList(const QVariantList &list);
    QString getLocalModelVersion(const QString &modelName);

    QString m_basePath;
};

#endif // LAUNCHER_MANAGER_H
