#include "launcher_manager.h"
#include <QDir>
#include <QDebug>
#include <QFileInfo>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QUrl>
#include <QString>
#include <QJsonArray>
#include <algorithm>

#include <iostream>

LauncherManager *LauncherManager::m_instance = nullptr;

LauncherManager::LauncherManager(QObject *parent)
    : QObject(parent)
{
    m_networkManager = new QNetworkAccessManager(this);
    m_folderCompressor = new FolderCompressor(this);

    m_basePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(m_basePath + "/download");
    QDir().mkpath(m_basePath + "/assets");
    QDir().mkpath(m_basePath + "/models");

    // Download timeout (5 minutes sans activité)
    m_downloadTimer = new QTimer(this);
    m_downloadTimer->setSingleShot(true);
    connect(m_downloadTimer, &QTimer::timeout, this, [this]() {
        if (m_currentDownload && m_currentDownload->isRunning()) {
            emit logMessage("Timeout du telechargement (5 min sans activite)");
            m_currentDownload->abort();
        }
    });

    m_currentVersion = getCurrentVersionFromFile();
    emit logMessage("LauncherManager initialisé");
}

void LauncherManager::registerQml()
{
    qmlRegisterSingletonType<LauncherManager>("LauncherManager", 1, 0, "LauncherManager", &LauncherManager::qmlInstance);
}

LauncherManager *LauncherManager::instance()
{
    if (m_instance == nullptr) {
        m_instance = new LauncherManager();
    }
    return m_instance;
}

QObject *LauncherManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    return LauncherManager::instance();
}

QString reformat_server_url(const QString &serverUrl)
{
    if (!serverUrl.startsWith("https://") && !serverUrl.startsWith("http://"))
    {
        return QString("https://") + serverUrl;
    }
    return serverUrl;
}

void LauncherManager::setUploadToken(const QString &token)
{
    m_uploadToken = token;
}

int LauncherManager::compareVersions(const QString &v1, const QString &v2)
{
    QStringList p1 = v1.split('.');
    QStringList p2 = v2.split('.');
    while (p1.size() < 3) p1.append("0");
    while (p2.size() < 3) p2.append("0");
    for (int i = 0; i < 3; ++i) {
        int n1 = p1[i].toInt();
        int n2 = p2[i].toInt();
        if (n1 < n2) return -1;
        if (n1 > n2) return 1;
    }
    return 0;
}

void LauncherManager::testServerConnection(const QString &serverUrl)
{
    if (m_connectionTestReply) {
        m_connectionTestReply->deleteLater();
        m_connectionTestReply = nullptr;
    }

    emit logMessage("Test de connexion vers: " + serverUrl);
    
    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/ping"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    m_connectionTestReply = m_networkManager->get(request);
    connect(m_connectionTestReply, &QNetworkReply::finished, this, &LauncherManager::onConnectionTestFinished);
    
    // Timeout après 5 secondes
    QTimer::singleShot(5000, this, [this]() {
        if (m_connectionTestReply && m_connectionTestReply->isRunning()) {
            m_connectionTestReply->abort();
        }
    });
}

void LauncherManager::checkForUpdates(const QString &serverUrl)
{
    if (m_versionCheckReply) {
        m_versionCheckReply->deleteLater();
        m_versionCheckReply = nullptr;
    }
    
    emit logMessage("Vérification des mises à jour...");
    setDownloadStatus("Vérification...");
    
    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/version"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    
    m_versionCheckReply = m_networkManager->get(request);
    connect(m_versionCheckReply, &QNetworkReply::finished, this, &LauncherManager::onVersionCheckFinished);
}

void LauncherManager::downloadResources(const QString &serverUrl, const QString &version)
{
    DownloadRequest req;
    req.type = DownloadRequest::Asset;
    req.serverUrl = serverUrl;
    req.version = version;

    if (m_currentDownload) {
        m_downloadQueue.enqueue(req);
        emit logMessage("Telechargement ajouté à la file d'attente");
        return;
    }
    m_retryCount = 0;
    executeDownload(req);
}

void LauncherManager::executeDownload(const DownloadRequest &req)
{
    m_currentRequest = req;

    QString formattedServerUrl = reformat_server_url(req.serverUrl);
    QString downloadUrl;
    QString fileName;

    if (req.type == DownloadRequest::Model) {
        downloadUrl = formattedServerUrl + "/api/models/download/" + req.modelName + "/" + req.modelVersion;
        fileName = m_basePath + "/download/" + QString("%1_v%2.meow").arg(req.modelName, req.modelVersion);
        emit logMessage("Début du telechargement du modele: " + req.modelName + " v" + req.modelVersion);
    } else {
        downloadUrl = formattedServerUrl + "/api/download/" + req.version;
        fileName = m_basePath + "/download/" + QString("assets_v%1.meow").arg(req.version);
        emit logMessage("Début du telechargement des ressources v" + req.version + "...");
    }

    setIsDownloading(true);
    setDownloadProgress(0.0);
    m_bytesReceived = 0;
    m_bytesTotal = 0;
    setDownloadStatus("Telechargement...");

    // Checksum init
    delete m_downloadHash;
    m_downloadHash = new QCryptographicHash(QCryptographicHash::Sha256);

    // Reprise de téléchargement : détection de fichier partiel
    qint64 resumeOffset = 0;
    QFileInfo partialInfo(fileName);
    if (partialInfo.exists() && partialInfo.size() > 0 && m_retryCount > 0) {
        // Fichier partiel existant d'une tentative précédente
        resumeOffset = partialInfo.size();

        // Pré-hasher le contenu existant pour le checksum final
        QFile existingFile(fileName);
        if (existingFile.open(QIODevice::ReadOnly)) {
            while (!existingFile.atEnd()) {
                m_downloadHash->addData(existingFile.read(64 * 1024));
            }
            existingFile.close();
        }

        emit logMessage(QString("Reprise du telechargement a %1 octets").arg(resumeOffset));
    }

    m_downloadFile = new QFile(fileName, this);
    QIODevice::OpenMode openMode = (resumeOffset > 0) ? QIODevice::Append : QIODevice::WriteOnly;
    if (!m_downloadFile->open(openMode)) {
        emit logMessage("Erreur: Impossible d'ouvrir le fichier pour ecriture");
        setDownloadStatus("Erreur");
        setIsDownloading(false);
        delete m_downloadHash;
        m_downloadHash = nullptr;
        processNextDownload();
        return;
    }

    QNetworkRequest request;
    request.setUrl(QUrl(downloadUrl));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");

    // Header Range pour reprise
    if (resumeOffset > 0) {
        request.setRawHeader("Range", QString("bytes=%1-").arg(resumeOffset).toUtf8());
    }

    m_currentDownload = m_networkManager->get(request);
    m_downloadTimer->start(DOWNLOAD_TIMEOUT_MS);

    connect(m_currentDownload, &QNetworkReply::downloadProgress,
            this, &LauncherManager::onDownloadProgress);
    connect(m_currentDownload, &QNetworkReply::finished,
            this, &LauncherManager::onDownloadFinished);
    connect(m_currentDownload, &QNetworkReply::readyRead, [this]() {
        if (m_downloadFile && m_currentDownload) {
            QByteArray data = m_currentDownload->readAll();
            if (m_downloadHash) m_downloadHash->addData(data);
            m_downloadFile->write(data);
        }
    });
}

void LauncherManager::forceDownloadResources(const QString &serverUrl)
{
    emit logMessage("Telechargement forcé des ressources...");
    setIsDownloading(true);
    setDownloadProgress(0.0);
    setDownloadStatus("Telechargement forcé...");

    m_currentVersion = "0.0.0";
    checkForUpdates(serverUrl);
}

void LauncherManager::createResourcePackage(const QString &folderPath, const QString &version)
{
    QString cleanPath = folderPath;
    if (cleanPath.startsWith("file:///")) {
        cleanPath = cleanPath.mid(8); // Remove file:/// prefix
    }
    
    QDir sourceDir(cleanPath);
    if (!sourceDir.exists()) {
        emit logMessage("❌ Dossier source inexistant: " + cleanPath);
        setPackageCreated(false);
        return;
    }
    
    emit logMessage("Création du paquet version " + version + " depuis: " + cleanPath);
    
    QString packageName = QString("assets_v%1.meow").arg(version);
    QString packagePath = m_basePath + "/download"+ "/" + packageName;
    
    // Create version manifest
    QJsonObject manifest = createVersionManifest(version);
    
    // Save manifest to temp file
    QString manifestPath = QDir::tempPath() + "/version_manifest.json";
    QFile manifestFile(manifestPath);
    if (manifestFile.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(manifest);
        manifestFile.write(doc.toJson());
        manifestFile.close();
    }
    
    // Add manifest to the folder temporarily
    QString tempManifestInFolder = cleanPath + "/version_manifest.json";
    QFile::copy(manifestPath, tempManifestInFolder);
    
    bool success = m_folderCompressor->compressFolder(cleanPath, packagePath);
    
    // Clean up temporary manifest
    QFile::remove(tempManifestInFolder);
    QFile::remove(manifestPath);
    
    if (success) {
        m_lastCreatedPackage = packagePath;
        setPackageCreated(true);
        emit logMessage("✅ Paquet créé: " + packagePath);
    } else {
        setPackageCreated(false);
        emit logMessage("❌ Erreur lors de la compression");
    }
}

void LauncherManager::uploadPackageToServer(const QString &serverUrl)
{
    if (m_lastCreatedPackage.isEmpty() || !QFile::exists(m_lastCreatedPackage)) {
        emit logMessage("Aucun paquet à uploader");
        setDownloadStatus("Aucun paquet à uploader");
        return;
    }

    QString fileName = QFileInfo(m_lastCreatedPackage).fileName();
    QRegularExpression versionRegex("assets_v([0-9]+\\.[0-9]+\\.[0-9]+)\\.meow");
    QRegularExpressionMatch match = versionRegex.match(fileName);

    if (!match.hasMatch()) {
        emit logMessage("Erreur: Format de nom de fichier invalide");
        setDownloadStatus("Format de fichier invalide");
        return;
    }

    QString version = match.captured(1);
    emit logMessage("Upload du paquet version " + version + "...");

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // Streaming : on utilise setBodyDevice au lieu de readAll()
    QFile *packageFileDevice = new QFile(m_lastCreatedPackage, multiPart);
    if (!packageFileDevice->open(QIODevice::ReadOnly)) {
        emit logMessage("Erreur: Impossible de lire le paquet");
        setDownloadStatus("Erreur de lecture");
        delete multiPart;
        return;
    }

    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("application/octet-stream"));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant("form-data; name=\"package\"; filename=\"" + fileName + "\""));
    filePart.setBodyDevice(packageFileDevice);
    multiPart->append(filePart);

    QHttpPart versionPart;
    versionPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"version\""));
    versionPart.setBody(version.toUtf8());
    multiPart->append(versionPart);

    QHttpPart timestampPart;
    timestampPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"timestamp\""));
    timestampPart.setBody(QDateTime::currentDateTime().toString(Qt::ISODate).toUtf8());
    multiPart->append(timestampPart);

    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/upload"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    if (!m_uploadToken.isEmpty()) {
        request.setRawHeader("Authorization", ("Bearer " + m_uploadToken).toUtf8());
    }

    QNetworkReply *uploadReply = m_networkManager->post(request, multiPart);
    multiPart->setParent(uploadReply);

    setDownloadStatus("Upload en cours...");

    connect(uploadReply, &QNetworkReply::finished, [this, uploadReply, version]() {
        if (uploadReply->error() == QNetworkReply::NoError) {
            emit logMessage("Upload du paquet v" + version + " terminé avec succès");
            setDownloadStatus("Upload terminé");

            QByteArray response = uploadReply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(response);
            QJsonObject obj = doc.object();

            if (obj["success"].toBool()) {
                emit logMessage("Paquet validé par le serveur");
            } else {
                emit logMessage("Le serveur signale une erreur: " + obj["message"].toString());
            }
        } else {
            emit logMessage("Erreur d'upload: " + uploadReply->errorString());
            setDownloadStatus("Erreur d'upload");
        }
        uploadReply->deleteLater();
    });

    connect(uploadReply, &QNetworkReply::uploadProgress, [this](qint64 sent, qint64 total) {
        if (total > 0) {
            setDownloadProgress(static_cast<double>(sent) / total);
        }
    });
}

void LauncherManager::resetDownloadState()
{
    setIsDownloading(false);
    setDownloadProgress(0.0);
    setDownloadStatus("Prêt");
    emit logMessage("🔄 État de téléchargement réinitialisé manuellement");
}

// ---------------------------------------------------------
// MODEL MANAGEMENT IMPLEMENTATION
// ---------------------------------------------------------

void LauncherManager::fetchModelsList(const QString &serverUrl)
{
    if (m_modelsListReply) {
        m_modelsListReply->deleteLater();
        m_modelsListReply = nullptr;
    }

    emit logMessage("Récupération de la liste des modèles...");
    
    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/models/list"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    
    m_modelsListReply = m_networkManager->get(request);
    connect(m_modelsListReply, &QNetworkReply::finished, this, &LauncherManager::onModelsListFinished);
}

void LauncherManager::downloadModel(const QString &serverUrl, const QString &name, const QString &version)
{
    DownloadRequest req;
    req.type = DownloadRequest::Model;
    req.serverUrl = serverUrl;
    req.modelName = name;
    req.modelVersion = version;

    if (m_currentDownload) {
        m_downloadQueue.enqueue(req);
        emit logMessage("Telechargement du modele ajouté à la file d'attente");
        return;
    }
    m_retryCount = 0;
    executeDownload(req);
}

void LauncherManager::createModelPackage(const QString &folderPath, const QString &name, const QString &version)
{
    QString cleanPath = folderPath;
    if (cleanPath.startsWith("file:///")) {
        cleanPath = cleanPath.mid(8);
    }
    
    QDir sourceDir(cleanPath);
    if (!sourceDir.exists()) {
        emit logMessage("❌ Dossier source inexistant: " + cleanPath);
        setPackageCreated(false);
        return;
    }
    
    emit logMessage("Création du pack modèle '" + name + "' v" + version);
    
    // Naming convention: name_vVersion.meow
    QString safeName = name; // Should sanitise this
    QString packageName = QString("%1_v%2.meow").arg(safeName, version);
    QString packagePath = m_basePath + "/download/" + packageName;
    
    // Create simple manifest
    QJsonObject manifest;
    manifest["version"] = version;
    manifest["name"] = name;
    manifest["type"] = "model";
    manifest["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    
    QString manifestPath = QDir::tempPath() + "/model_manifest.json";
    QFile manifestFile(manifestPath);
    if (manifestFile.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(manifest);
        manifestFile.write(doc.toJson());
        manifestFile.close();
    }
    
    QString tempManifestInFolder = cleanPath + "/model_manifest.json";
    QFile::copy(manifestPath, tempManifestInFolder);
    
    bool success = m_folderCompressor->compressFolder(cleanPath, packagePath);
    
    QFile::remove(tempManifestInFolder);
    QFile::remove(manifestPath);
    
    if (success) {
        m_lastCreatedPackage = packagePath;
        setPackageCreated(true);
        emit logMessage("✅ Pack modèle créé: " + packagePath);
    } else {
        setPackageCreated(false);
        emit logMessage("❌ Erreur lors de la compression du modèle");
    }
}

void LauncherManager::uploadModelPackage(const QString &serverUrl, const QString &name, const QString &version)
{
    if (m_lastCreatedPackage.isEmpty() || !QFile::exists(m_lastCreatedPackage)) {
        emit logMessage("Aucun paquet modele à uploader");
        return;
    }

    emit logMessage("Upload du modele '" + name + "' v" + version + "...");

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // Streaming upload
    QFile *packageFileDevice = new QFile(m_lastCreatedPackage, multiPart);
    if (!packageFileDevice->open(QIODevice::ReadOnly)) {
        emit logMessage("Erreur lecture fichier");
        delete multiPart;
        return;
    }

    QHttpPart filePart;
    QString fileName = QFileInfo(m_lastCreatedPackage).fileName();
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("application/octet-stream"));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant("form-data; name=\"package\"; filename=\"" + fileName + "\""));
    filePart.setBodyDevice(packageFileDevice);
    multiPart->append(filePart);

    QHttpPart namePart;
    namePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"name\""));
    namePart.setBody(name.toUtf8());
    multiPart->append(namePart);

    QHttpPart versionPart;
    versionPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"version\""));
    versionPart.setBody(version.toUtf8());
    multiPart->append(versionPart);

    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/models/upload"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    if (!m_uploadToken.isEmpty()) {
        request.setRawHeader("Authorization", ("Bearer " + m_uploadToken).toUtf8());
    }

    QNetworkReply *uploadReply = m_networkManager->post(request, multiPart);
    multiPart->setParent(uploadReply);

    setDownloadStatus("Upload modele...");
    setIsDownloading(true);
    setDownloadProgress(0.0);

    connect(uploadReply, &QNetworkReply::finished, [this, uploadReply, name, version]() {
        if (uploadReply->error() == QNetworkReply::NoError) {
            emit logMessage("Upload modele terminé");
            setDownloadStatus("Upload OK");
        } else {
            emit logMessage("Erreur upload: " + uploadReply->errorString());
            setDownloadStatus("Erreur Upload");
        }
        setIsDownloading(false);
        uploadReply->deleteLater();
    });

    connect(uploadReply, &QNetworkReply::uploadProgress, [this](qint64 sent, qint64 total) {
        if (total > 0) {
            setDownloadProgress(static_cast<double>(sent) / total);
        }
    });
}

// ---------------------------------------------------------
// BALSAM (import .obj/.glb/.gltf/.fbx → .qml)
// ---------------------------------------------------------

void LauncherManager::setBalsamPath(const QString &p)
{
    if (m_balsamPath != p) {
        m_balsamPath = p;
        emit balsamPathChanged();
    }
}

QVariantList LauncherManager::balsamOptionDefinitions() const
{
    // Référence : `balsam --help` (Qt 6.11). Convention : chaque flag a sa
    // forme inverse `--disable-<flag>`. Les défauts ci-dessous reflètent
    // ceux de balsamui.
    auto mk = [](const QString &key, const QString &flag, const QString &label,
                 const QString &type, const QVariant &def, const QString &group,
                 const QString &tooltip,
                 const QString &dependsOn = QString()) {
        QVariantMap m;
        m["key"] = key;
        m["flag"] = flag;
        m["label"] = label;
        m["type"] = type;
        m["default"] = def;
        m["group"] = group;
        m["tooltip"] = tooltip;
        if (!dependsOn.isEmpty()) m["dependsOn"] = dependsOn;
        return m;
    };

    QVariantList list;

    // --- Géométrie
    list << mk("joinIdenticalVertices", "--joinIdenticalVertices",
               "Fusionner les vertices identiques", "bool", true, "Géométrie",
               "Identifie et fusionne les sommets dupliqués pour réduire la taille du mesh et améliorer les perfs GPU.");
    list << mk("generateNormals", "--generateNormals",
               "Générer les normales (face)", "bool", false, "Géométrie",
               "Calcule les normales par face. Utile si le .obj n'en exporte pas. Désactive `Generate Smooth Normals`.");
    list << mk("generateSmoothNormals", "--generateSmoothNormals",
               "Générer les normales lissées", "bool", true, "Géométrie",
               "Calcule des normales lissées par sommet (averaging). Donne un rendu doux pour les surfaces courbes.");
    list << mk("calculateTangentSpace", "--calculateTangentSpace",
               "Calculer l'espace tangent", "bool", false, "Géométrie",
               "Calcule tangentes/bitangentes pour les meshes. Nécessaire pour le bon rendu des normalMaps.");
    list << mk("optimizeMeshes", "--optimizeMeshes",
               "Optimiser les meshes", "bool", false, "Géométrie",
               "Étape de post-traitement qui réduit le nombre de meshes par fusion logique.");
    list << mk("optimizeGraph", "--optimizeGraph",
               "Optimiser le graphe de scène", "bool", false, "Géométrie",
               "Étape de post-traitement qui simplifie la hiérarchie de la scène (collapse de nodes inutiles).");
    list << mk("improveCacheLocality", "--improveCacheLocality",
               "Améliorer la localité de cache", "bool", true, "Géométrie",
               "Réordonne les triangles pour mieux exploiter le cache vertex GPU.");
    list << mk("preTransformVertices", "--preTransformVertices",
               "Pré-transformer les vertices", "bool", false, "Géométrie",
               "Supprime le graphe de nodes et applique les matrices de transformation locales aux vertices. Casse l'animation et la hiérarchie.");
    list << mk("splitLargeMeshes", "--splitLargeMeshes",
               "Découper les gros meshes", "bool", true, "Géométrie",
               "Découpe les meshes volumineux en sous-meshes plus petits pour respecter les limites GPU.");
    list << mk("findInstances", "--findInstances",
               "Détecter les instances", "bool", false, "Géométrie",
               "Recherche les meshes dupliqués et les remplace par des références au premier (instancing).");
    list << mk("removeRedundantMaterials", "--removeRedundantMaterials",
               "Retirer les matériaux redondants", "bool", false, "Géométrie",
               "Recherche et supprime les matériaux dupliqués ou non référencés.");
    list << mk("fixInfacingNormals", "--fixInfacingNormals",
               "Corriger les normales internes", "bool", false, "Géométrie",
               "Détecte les meshes dont les normales pointent vers l'intérieur et les inverse.");
    list << mk("findDegenerates", "--findDegenerates",
               "Détecter les primitives dégénérées", "bool", true, "Géométrie",
               "Recherche les triangles dégénérés (aire nulle) et les convertit en lignes ou points propres.");
    list << mk("findInvalidData", "--findInvalidData",
               "Détecter les données invalides", "bool", true, "Géométrie",
               "Recherche dans tous les meshes des données invalides (normales nulles, UVs invalides…) et les corrige. Évite les erreurs courantes des exporteurs.");
    list << mk("transformUVCoordinates", "--transformUVCoordinates",
               "Appliquer les transformations UV", "bool", false, "Géométrie",
               "Applique les transformations UV par texture et les bake dans des canaux UV indépendants.");

    // --- Échelle
    list << mk("globalScale", "--globalScale",
               "Activer le scale global", "bool", false, "Échelle",
               "Applique un facteur d'échelle global au modèle entier au moment de l'import (alternative au scale du marker).");
    list << mk("globalScaleValue", "--globalScaleValue",
               "Valeur du scale global", "real", 1.0, "Échelle",
               "Facteur multiplicatif appliqué quand `Activer le scale global` est coché.",
               "globalScale");

    // --- Textures
    list << mk("generateMipMaps", "--generateMipMaps",
               "Générer les mipmaps", "bool", true, "Textures",
               "Force la génération de mipmaps pour toutes les textures importées (filtrage trilinéaire/anisotrope plus propre).");

    // --- Animations
    list << mk("useBinaryKeyframes", "--useBinaryKeyframes",
               "Keyframes binaires", "bool", true, "Animations",
               "Stocke les keyframes d'animation en binaire externe (chargement plus rapide, .qml plus léger).");
    list << mk("manualAnimations", "--manualAnimations",
               "Animations manuelles", "bool", false, "Animations",
               "Pas de TimelineAnimation auto-générée — les Timelines doivent être déclenchées manuellement depuis le code.");
    list << mk("removeComponentAnimations", "--removeComponentAnimations",
               "Retirer les composants d'animation", "bool", false, "Animations",
               "Supprime tous les composants d'animation des meshes.");

    // --- LODs (les 3 angles dépendent de generateMeshLevelsOfDetail)
    list << mk("generateMeshLevelsOfDetail", "--generateMeshLevelsOfDetail",
               "Générer les LODs de mesh", "bool", false, "LODs",
               "Crée automatiquement des Levels Of Detail (versions simplifiées) du mesh source.");
    list << mk("recalculateLodNormals", "--recalculateLodNormals",
               "Recalculer normales pour LODs", "bool", true, "LODs",
               "Recalcule de nouvelles normales si nécessaire pour les LODs générés (sinon les normales d'origine sont conservées).",
               "generateMeshLevelsOfDetail");
    list << mk("recalculateLodNormalsMergeAngle", "--recalculateLodNormalsMergeAngle",
               "Angle de fusion (merge angle) des normales LOD", "real", 60.0, "LODs",
               "Angle maximum (en degrés) pour fusionner/lisser des normales sur les LODs.",
               "generateMeshLevelsOfDetail");
    list << mk("recalculateLodNormalsSplitAngle", "--recalculateLodNormalsSplitAngle",
               "Angle de séparation (split angle) des normales LOD", "real", 25.0, "LODs",
               "Angle maximum (en degrés) au-delà duquel on sépare les normales (création de nouveaux vertices).",
               "generateMeshLevelsOfDetail");

    // --- Composants à retirer (rare usage, économise de la mémoire)
    list << mk("dropNormals", "--dropNormals",
               "Supprimer les normales", "bool", false, "Composants",
               "Supprime toutes les normales de toutes les faces. À combiner avec generateNormals si on veut les recalculer.");
    list << mk("removeComponentUVs", "--removeComponentUVs",
               "Retirer les UVs", "bool", false, "Composants",
               "Supprime les composants UV des meshes (utile uniquement pour modèles non-texturés).");
    list << mk("removeComponentColors", "--removeComponentColors",
               "Retirer les couleurs vertex", "bool", false, "Composants",
               "Supprime les couleurs par vertex.");
    list << mk("removeComponentNormals", "--removeComponentNormals",
               "Retirer les normales", "bool", false, "Composants",
               "Supprime le composant normal des meshes.");
    list << mk("removeComponentTangentsAndBitangents", "--removeComponentTangentsAndBitangents",
               "Retirer tangentes/bitangentes", "bool", false, "Composants",
               "Supprime tangentes et bitangentes des meshes (économise mémoire si pas de normalMap).");
    list << mk("removeComponentBoneWeights", "--removeComponentBoneWeights",
               "Retirer les bone weights", "bool", false, "Composants",
               "Supprime les poids d'os des meshes (à activer si pas de skinning).");
    list << mk("removeComponentTextures", "--removeComponentTextures",
               "Retirer les textures embarquées", "bool", false, "Composants",
               "Supprime les composants texture intégrés au fichier source.");

    // --- Avancé
    list << mk("useFloatJointIndices", "--useFloatJointIndices",
               "Indices d'articulation en float", "bool", false, "Avancé",
               "Stocke les indices d'articulation en flottants (compatibilité GLES 2.0).");
    list << mk("fbxPreservePivots", "--fbxPreservePivots",
               "Préserver les pivots FBX", "bool", false, "Avancé",
               "Pour les .fbx : conserve les pivots comme nodes supplémentaires dans la hiérarchie.");
    list << mk("expandValueComponents", "--expandValueComponents",
               "Décomposer les value types", "bool", false, "Avancé",
               "Décompose les types valeur (vector3d, quaternion) en propriétés scalaires séparées.");
    list << mk("designStudioWorkarounds", "--designStudioWorkarounds",
               "Compatibilité Qt Design Studio", "bool", false, "Avancé",
               "Active des contournements nécessaires pour générer des composants compatibles avec Qt Design Studio.");

    return list;
}

void LauncherManager::runBalsamImport(const QString &sourceFile,
                                      const QString &outputDir,
                                      const QVariantMap &options)
{
    if (m_balsamProcess) {
        emit balsamFinished(false, QString(), "Une conversion balsam est deja en cours");
        return;
    }

    QString balsam = m_balsamPath;
    if (balsam.startsWith("file:///")) balsam = balsam.mid(8);
    else if (balsam.startsWith("file://")) balsam = balsam.mid(7);

    if (balsam.isEmpty()) {
        emit balsamFinished(false, QString(), "Path balsam non configure");
        return;
    }
    if (!QFile::exists(balsam)) {
        emit balsamFinished(false, QString(), "Executable balsam introuvable : " + balsam);
        return;
    }

    QString cleanSource = sourceFile;
    if (cleanSource.startsWith("file:///")) cleanSource = cleanSource.mid(8);
    else if (cleanSource.startsWith("file://")) cleanSource = cleanSource.mid(7);
    if (!QFile::exists(cleanSource)) {
        emit balsamFinished(false, QString(), "Source introuvable : " + cleanSource);
        return;
    }

    QString cleanOutput = outputDir;
    if (cleanOutput.startsWith("file:///")) cleanOutput = cleanOutput.mid(8);
    else if (cleanOutput.startsWith("file://")) cleanOutput = cleanOutput.mid(7);
    if (cleanOutput.isEmpty()) {
        emit balsamFinished(false, QString(), "Dossier de sortie non specifie");
        return;
    }
    if (!QDir().mkpath(cleanOutput)) {
        emit balsamFinished(false, QString(), "Impossible de creer le dossier de sortie : " + cleanOutput);
        return;
    }

    // Snapshot des .qml préexistants pour identifier le nouveau après run.
    QSet<QString> beforeQmls;
    {
        QDir d(cleanOutput);
        const QStringList existing = d.entryList(QStringList{"*.qml"}, QDir::Files);
        for (const QString &n : existing) beforeQmls.insert(n);
    }

    // Construction des args. Pour les bool, balsam supporte la convention
    // `--flag` (active) / `--disable-flag` (désactive). Pour les options
    // qui n'apparaissent pas dans la map utilisateur, on ne passe rien :
    // balsam appliquera son défaut (qu'on s'efforce de garder cohérent
    // avec celui exposé en UI). Pour celles présentes, on passe la forme
    // explicite correspondant à la valeur — comme ça l'utilisateur voit
    // toujours le résultat attendu de la checkbox.
    auto disableFlagOf = [](const QString &flag) {
        // "--joinIdenticalVertices" → "--disable-joinIdenticalVertices"
        if (flag.startsWith("--")) return QStringLiteral("--disable-") + flag.mid(2);
        return QStringLiteral("--disable-") + flag;
    };

    // Helper pour résoudre la dépendance (présence dans options en
    // priorité, sinon défaut de la définition).
    const QVariantList defs = balsamOptionDefinitions();
    auto resolveBool = [&](const QString &key, const QVariantMap &fallbackDef) {
        if (options.contains(key)) return options.value(key).toBool();
        // Cherche le default dans defs
        for (const QVariant &dv : defs) {
            const QVariantMap dd = dv.toMap();
            if (dd.value("key").toString() == key)
                return dd.value("default").toBool();
        }
        return fallbackDef.value("default").toBool();
    };

    QStringList args;
    for (const QVariant &v : defs) {
        const QVariantMap def = v.toMap();
        const QString key = def.value("key").toString();
        const QString flag = def.value("flag").toString();
        const QString type = def.value("type").toString();
        const QString dep = def.value("dependsOn").toString();

        if (!options.contains(key)) continue;
        const QVariant val = options.value(key);

        if (type == "bool") {
            if (val.toBool()) args << flag;
            else              args << disableFlagOf(flag);
        } else if (type == "real") {
            // Ne pas passer si la dépendance n'est pas active.
            if (!dep.isEmpty() && !resolveBool(dep, def)) continue;
            args << flag << QString::number(val.toDouble(), 'f', 6);
        }
    }
    args << "--outputPath" << cleanOutput;
    args << cleanSource;
    emit logMessage("balsam: " + balsam + " " + args.join(" "));

    m_balsamProcess = new QProcess(this);
    emit balsamRunningChanged();

    connect(m_balsamProcess, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError err) {
        emit logMessage("balsam errorOccurred: " + QString::number(err));
    });

    connect(m_balsamProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, cleanOutput, beforeQmls](int exitCode, QProcess::ExitStatus status) {
        const QString stdoutText = QString::fromLocal8Bit(m_balsamProcess->readAllStandardOutput());
        const QString stderrText = QString::fromLocal8Bit(m_balsamProcess->readAllStandardError());
        if (!stdoutText.isEmpty()) emit logMessage("balsam stdout: " + stdoutText.trimmed());
        if (!stderrText.isEmpty()) emit logMessage("balsam stderr: " + stderrText.trimmed());

        bool ok = (status == QProcess::NormalExit) && (exitCode == 0);
        QString qmlPath, error;

        if (!ok) {
            error = stderrText.isEmpty()
                ? QString("balsam a termine en erreur (code %1)").arg(exitCode)
                : stderrText.trimmed();
        } else {
            // Cherche un .qml apparu après le run
            QDir d(cleanOutput);
            const QStringList nowQmls = d.entryList(QStringList{"*.qml"}, QDir::Files, QDir::Time);
            QString chosen;
            for (const QString &n : nowQmls) {
                if (!beforeQmls.contains(n)) { chosen = n; break; }
            }
            if (chosen.isEmpty() && !nowQmls.isEmpty()) {
                // Fallback : pas de delta (cas overwrite) → on prend le plus récent
                chosen = nowQmls.first();
            }
            if (chosen.isEmpty()) {
                ok = false;
                error = "balsam OK mais aucun .qml dans " + cleanOutput;
            } else {
                qmlPath = d.absoluteFilePath(chosen);
                emit logMessage("balsam OK : " + qmlPath);
            }
        }

        m_balsamProcess->deleteLater();
        m_balsamProcess = nullptr;
        emit balsamRunningChanged();
        emit balsamFinished(ok, qmlPath, error);
    });

    m_balsamProcess->start(balsam, args);
}

// ---------------------------------------------------------
// MODEL 3D CONFIGURATOR HELPERS
// ---------------------------------------------------------

static QString sanitizeFolderPath(const QString &p)
{
    QString cleaned = p;
    if (cleaned.startsWith("file:///")) cleaned = cleaned.mid(8);
    else if (cleaned.startsWith("file://")) cleaned = cleaned.mid(7);
    return cleaned;
}

QString LauncherManager::findModelQml(const QString &folderPath)
{
    QString cleanPath = sanitizeFolderPath(folderPath);
    QDir dir(cleanPath);
    if (!dir.exists()) return QString();

    const QStringList qmls = dir.entryList(QStringList{"*.qml"}, QDir::Files);
    if (qmls.isEmpty()) return QString();

    // Heuristique : on prend le 1er .qml. Pour des dossiers exportés
    // depuis Balsam (Princess/Princess.qml), il n'y en a en général qu'un.
    return QFileInfo(qmls.first()).completeBaseName();
}

QVariantMap LauncherManager::readModelManifest(const QString &folderPath)
{
    QVariantMap result;
    QString cleanPath = sanitizeFolderPath(folderPath);
    QFile f(cleanPath + "/model_manifest.json");
    if (!f.open(QIODevice::ReadOnly)) return result;

    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject()) return result;
    QJsonObject obj = doc.object();
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        result.insert(it.key(), it.value().toVariant());
    }
    return result;
}

QVariantMap LauncherManager::readModelTransform(const QString &folderPath, const QString &modelName)
{
    QVariantMap result;
    QVariantList scaleDefault = { 1.0, 1.0, 1.0 };
    QVariantList rotDefault   = { 0.0, 0.0, 0.0 };
    QVariantList posDefault   = { 0.0, 0.0, 0.0 };
    result["scale"] = scaleDefault;
    result["eulerRotation"] = rotDefault;
    result["position"] = posDefault;

    if (modelName.isEmpty()) return result;

    QString cleanPath = sanitizeFolderPath(folderPath);
    QFile f(cleanPath + "/" + modelName + ".qml");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return result;
    QString content = QString::fromUtf8(f.readAll());
    f.close();

    // Format actuel (3 lignes : position + eulerRotation + scale)
    QRegularExpression blockV2(
        R"(//\s*__MODEL_TRANSFORM_BEGIN__\s*\r?\n\s*position:\s*Qt\.vector3d\(\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*\)\s*\r?\n\s*eulerRotation:\s*Qt\.vector3d\(\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*\)\s*\r?\n\s*scale:\s*Qt\.vector3d\(\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*\)\s*\r?\n\s*//\s*__MODEL_TRANSFORM_END__)"
    );
    QRegularExpressionMatch m2 = blockV2.match(content);
    if (m2.hasMatch()) {
        result["position"]      = QVariantList{ m2.captured(1).toDouble(), m2.captured(2).toDouble(), m2.captured(3).toDouble() };
        result["eulerRotation"] = QVariantList{ m2.captured(4).toDouble(), m2.captured(5).toDouble(), m2.captured(6).toDouble() };
        result["scale"]         = QVariantList{ m2.captured(7).toDouble(), m2.captured(8).toDouble(), m2.captured(9).toDouble() };
        return result;
    }

    // Format ancien (2 lignes : eulerRotation + scale, position implicite 0)
    QRegularExpression blockV1(
        R"(//\s*__MODEL_TRANSFORM_BEGIN__\s*\r?\n\s*eulerRotation:\s*Qt\.vector3d\(\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*\)\s*\r?\n\s*scale:\s*Qt\.vector3d\(\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*,\s*([\-\d.eE+]+)\s*\)\s*\r?\n\s*//\s*__MODEL_TRANSFORM_END__)"
    );
    QRegularExpressionMatch m1 = blockV1.match(content);
    if (m1.hasMatch()) {
        result["eulerRotation"] = QVariantList{ m1.captured(1).toDouble(), m1.captured(2).toDouble(), m1.captured(3).toDouble() };
        result["scale"]         = QVariantList{ m1.captured(4).toDouble(), m1.captured(5).toDouble(), m1.captured(6).toDouble() };
        // position laissée à (0,0,0)
    }
    return result;
}

bool LauncherManager::writeModelTransform(const QString &folderPath, const QString &modelName,
                                          double sx, double sy, double sz,
                                          double rx, double ry, double rz,
                                          double px, double py, double pz)
{
    if (modelName.isEmpty()) {
        emit logMessage("writeModelTransform: nom du modele vide");
        return false;
    }

    QString cleanPath = sanitizeFolderPath(folderPath);
    QString qmlPath = cleanPath + "/" + modelName + ".qml";
    QFile f(qmlPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit logMessage("writeModelTransform: impossible d'ouvrir " + qmlPath);
        return false;
    }
    QString content = QString::fromUtf8(f.readAll());
    f.close();

    auto fmt = [](double v) {
        // Évite la notation scientifique pour rester lisible dans le QML.
        return QString::number(v, 'f', 6);
    };

    QString blockText = QStringLiteral(
        "// __MODEL_TRANSFORM_BEGIN__\n"
        "    position: Qt.vector3d(%1, %2, %3)\n"
        "    eulerRotation: Qt.vector3d(%4, %5, %6)\n"
        "    scale: Qt.vector3d(%7, %8, %9)\n"
        "    // __MODEL_TRANSFORM_END__"
    ).arg(fmt(px), fmt(py), fmt(pz),
          fmt(rx), fmt(ry), fmt(rz),
          fmt(sx), fmt(sy), fmt(sz));

    QRegularExpression existingBlock(
        R"(//\s*__MODEL_TRANSFORM_BEGIN__[\s\S]*?//\s*__MODEL_TRANSFORM_END__)"
    );

    QString updated;
    if (existingBlock.match(content).hasMatch()) {
        // Remplacement in-place
        updated = content;
        updated.replace(existingBlock, blockText);
    } else {
        // Insertion après l'`id: <name>` du premier Node racine.
        QRegularExpression rootIdRe(
            R"((Node\s*\{\s*\r?\n\s*id:\s*\w+))"
        );
        QRegularExpressionMatch rootMatch = rootIdRe.match(content);
        if (!rootMatch.hasMatch()) {
            emit logMessage("writeModelTransform: Node racine introuvable dans " + qmlPath);
            return false;
        }
        const int insertPos = rootMatch.capturedEnd(1);
        updated = content.left(insertPos)
                + "\n    " + blockText
                + content.mid(insertPos);
    }

    QFile out(qmlPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        emit logMessage("writeModelTransform: impossible d'ecrire " + qmlPath);
        return false;
    }
    out.write(updated.toUtf8());
    out.close();
    emit logMessage("Transform applique a " + qmlPath);
    return true;
}

void LauncherManager::onModelsListFinished()
{
    if (!m_modelsListReply) return;

    if (m_modelsListReply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(m_modelsListReply->readAll());
        QJsonObject root = doc.object();
        
        if (root["success"].toBool()) {
            QJsonObject packs = root["packs"].toObject();
            QVariantList list;
            
            // Convert JSON object to QVariantList for QML
            // Structure: packs[modelName] = [ {version, filename...}, ... ]
            for(auto it = packs.begin(); it != packs.end(); ++it) {
                QString modelName = it.key();
                QJsonArray versionsJson = it.value().toArray();
                
                if (!versionsJson.isEmpty()) {
                    QVariantList versionsList = versionsJson.toVariantList();

                    // Sort versions descending (newest first)
                    std::sort(versionsList.begin(), versionsList.end(), [](const QVariant &v1, const QVariant &v2) {
                        QString ver1 = v1.toJsonObject()["version"].toString();
                        QString ver2 = v2.toJsonObject()["version"].toString();

                        if (ver1.isEmpty() && v1.canConvert<QVariantMap>()) ver1 = v1.toMap()["version"].toString();
                        if (ver2.isEmpty() && v2.canConvert<QVariantMap>()) ver2 = v2.toMap()["version"].toString();

                        return compareVersions(ver1, ver2) > 0; // Descending
                    });

                    QVariantMap modelData;
                    modelData["name"] = modelName;
                    modelData["versions"] = versionsList;
                    
                    // Check local version
                    QString localVer = getLocalModelVersion(modelName);
                    modelData["localVersion"] = localVer;
                    modelData["isInstalled"] = (localVer != "0.0.0");
                    
                    // Helper to get latest version string from sorted list
                    if (versionsList.size() > 0) {
                        QVariant first = versionsList[0];
                        if (first.canConvert<QVariantMap>()) {
                             modelData["latestVersion"] = first.toMap()["version"].toString();
                        } else {
                             modelData["latestVersion"] = first.toJsonObject()["version"].toString();
                        }
                    }
                    list.append(modelData);
                }
            }
            
            setModelsList(list);
            emit logMessage("Liste des modèles mise à jour (" + QString::number(list.size()) + " packs)");
        }
    } else {
        emit logMessage("❌ Erreur récupération liste modèles");
    }
    
    m_modelsListReply->deleteLater();
    m_modelsListReply = nullptr;
}

void LauncherManager::setModelsList(const QVariantList &list)
{
    m_modelsList = list;
    emit modelsListChanged();
}

// Private slots implementations
void LauncherManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (bytesTotal > 0) {
        double progress = static_cast<double>(bytesReceived) / bytesTotal;
        setDownloadProgress(progress);
        m_bytesReceived = bytesReceived;
        m_bytesTotal = bytesTotal;
        emit downloadProgressChanged();
    }

    // Reset timeout sur activité
    if (m_downloadTimer && m_downloadTimer->isActive()) {
        m_downloadTimer->start(DOWNLOAD_TIMEOUT_MS);
    }
}

void LauncherManager::onDownloadFinished()
{
    if (!m_currentDownload)
        return;

    // Arrêter le timer de timeout
    if (m_downloadTimer) m_downloadTimer->stop();

    // Fermer le fichier
    if (m_downloadFile) {
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    bool success = (m_currentDownload->error() == QNetworkReply::NoError);

    if (!success) {
        emit logMessage("Echec du telechargement: " + m_currentDownload->errorString());

        // Cleanup hash (sera recréé au retry avec pré-hash du fichier partiel)
        delete m_downloadHash;
        m_downloadHash = nullptr;

        // Retry automatique (3 tentatives, backoff exponentiel)
        // On garde le fichier partiel pour permettre la reprise via Range
        if (m_retryCount < MAX_RETRIES) {
            m_retryCount++;
            int delayMs = 1000 * (1 << m_retryCount); // 2s, 4s, 8s
            emit logMessage(QString("Nouvelle tentative %1/%2 dans %3s (avec reprise)...")
                            .arg(m_retryCount).arg(MAX_RETRIES).arg(delayMs / 1000));
            setDownloadStatus(QString("Retry %1/%2...").arg(m_retryCount).arg(MAX_RETRIES));

            m_currentDownload->deleteLater();
            m_currentDownload = nullptr;

            QTimer::singleShot(delayMs, this, [this]() {
                executeDownload(m_currentRequest);
            });
            return;
        }

        // Toutes les tentatives échouées — supprimer le fichier incomplet
        QString compressedFile;
        if (m_currentRequest.type == DownloadRequest::Model) {
            compressedFile = m_basePath + "/download/" + QString("%1_v%2.meow").arg(m_currentRequest.modelName, m_currentRequest.modelVersion);
        } else {
            compressedFile = m_basePath + "/download/" + QString("assets_v%1.meow").arg(m_currentRequest.version);
        }
        if (QFile::exists(compressedFile))
            QFile::remove(compressedFile);

        m_retryCount = 0;
        setDownloadStatus("Erreur de telechargement");
        setIsDownloading(false);
        setDownloadProgress(0.0);
        m_currentDownload->deleteLater();
        m_currentDownload = nullptr;
        processNextDownload();
        return;
    }

    // --- Téléchargement réussi ---
    emit logMessage("Fichier telecharge avec succes!");
    m_retryCount = 0;

    // Vérification du checksum SHA-256
    if (m_downloadHash) {
        QString actualHash = m_downloadHash->result().toHex();

        // Récupérer le checksum attendu depuis le header HTTP (modèles) ou depuis parseVersionInfo (assets)
        QString serverChecksum = QString::fromUtf8(m_currentDownload->rawHeader("X-Checksum-Sha256"));
        if (serverChecksum.isEmpty() && !m_expectedChecksum.isEmpty()) {
            serverChecksum = m_expectedChecksum;
        }

        if (!serverChecksum.isEmpty() && actualHash != serverChecksum) {
            emit logMessage("ERREUR: Checksum invalide! Attendu: " + serverChecksum + " Obtenu: " + actualHash);
            setDownloadStatus("Erreur de verification");

            // Supprimer le fichier corrompu
            QString compressedFile;
            if (m_currentRequest.type == DownloadRequest::Model)
                compressedFile = m_basePath + "/download/" + QString("%1_v%2.meow").arg(m_currentRequest.modelName, m_currentRequest.modelVersion);
            else
                compressedFile = m_basePath + "/download/" + QString("assets_v%1.meow").arg(m_currentRequest.version);
            QFile::remove(compressedFile);

            delete m_downloadHash;
            m_downloadHash = nullptr;
            setIsDownloading(false);
            setDownloadProgress(0.0);
            m_currentDownload->deleteLater();
            m_currentDownload = nullptr;
            processNextDownload();
            return;
        }

        if (!serverChecksum.isEmpty()) {
            emit logMessage("Checksum SHA-256 verifie OK");
        }

        delete m_downloadHash;
        m_downloadHash = nullptr;
    }

    // Extraction
    if (m_currentRequest.type == DownloadRequest::Model) {
        QString fileName = QString("%1_v%2.meow").arg(m_currentRequest.modelName, m_currentRequest.modelVersion);
        QString compressedFile = m_basePath + "/download/" + fileName;
        QString extractPath = m_basePath + "/models/" + m_currentRequest.modelName + "/";
        QDir().mkpath(extractPath);

        bool extractOk = m_folderCompressor->decompressFolder(compressedFile, extractPath, FC_DELETE_BOTH);
        if (extractOk) {
            emit logMessage("Modele extrait avec succes vers: " + extractPath);

            // Sauvegarder la version locale
            QJsonObject verObj;
            verObj["version"] = m_currentRequest.modelVersion;
            verObj["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);

            QFile verFile(extractPath + "version.json");
            if (verFile.open(QIODevice::WriteOnly)) {
                verFile.write(QJsonDocument(verObj).toJson());
                verFile.close();
            }

            setDownloadStatus("Download success");

            // Mettre à jour la liste pour rafraîchir l'UI
            QVariantList list = m_modelsList;
            for (int i = 0; i < list.size(); i++) {
                QVariantMap map = list[i].toMap();
                if (map["name"].toString() == m_currentRequest.modelName) {
                    map["localVersion"] = m_currentRequest.modelVersion;
                    map["isInstalled"] = true;
                    list[i] = map;
                    break;
                }
            }
            setModelsList(list);
        } else {
            emit logMessage("Echec de l'extraction du modele");
            setDownloadStatus("Erreur d'extraction");
        }
    } else {
        // Assets principaux
        QString compressedFile = m_basePath + "/download/" + QString("assets_v%1.meow").arg(m_currentRequest.version);
        QString extractPath = m_basePath + "/assets/";

        bool extractOk = m_folderCompressor->decompressFolder(compressedFile, extractPath, FC_DELETE_BOTH);
        if (extractOk) {
            emit logMessage("Assets extraits avec succes vers: " + extractPath);
            setCurrentVersion(m_currentRequest.version);
            saveVersionInfo(m_currentRequest.version);
            setDownloadStatus("Download success");
            emit downloadSucess();
        } else {
            emit logMessage("Echec de l'extraction des assets");
            setDownloadStatus("Erreur d'extraction");
        }
    }

    setIsDownloading(false);
    setDownloadProgress(1.0);

    m_currentDownload->deleteLater();
    m_currentDownload = nullptr;

    processNextDownload();
}

void LauncherManager::processNextDownload()
{
    if (!m_downloadQueue.isEmpty()) {
        DownloadRequest next = m_downloadQueue.dequeue();
        m_retryCount = 0;
        executeDownload(next);
    }
}

void LauncherManager::onVersionCheckFinished()
{
    if (!m_versionCheckReply)
        return;

    if (m_versionCheckReply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(m_versionCheckReply->readAll());
        QJsonObject obj = doc.object();

        if (parseVersionInfo(obj)) {
            emit logMessage("Version actuelle: " + m_currentVersion + ", Dernière: " + m_latestVersion);
            setDownloadStatus("Vérification terminée");

            // Comparaison sémantique : mise à jour seulement si le serveur a une version supérieure
            if (compareVersions(m_currentVersion, m_latestVersion) < 0) {
                emit updateAvailable();
            }
        } else {
            emit logMessage("Erreur: Format de version invalide");
            setDownloadStatus("Format invalide");
        }
    } else {
        emit logMessage("Erreur de vérification: " + m_versionCheckReply->errorString());
        qDebug() << "ENUM ERROR " << m_versionCheckReply->error();
        setDownloadStatus("Erreur de vérification");
    }

    m_versionCheckReply->deleteLater();
    m_versionCheckReply = nullptr;
}

void LauncherManager::onConnectionTestFinished()
{
    if (!m_connectionTestReply) {
        return;
    }
    
    bool success = (m_connectionTestReply->error() == QNetworkReply::NoError);
    QString message;
    
    if (success) {
        QJsonDocument doc = QJsonDocument::fromJson(m_connectionTestReply->readAll());
        QJsonObject obj = doc.object();
        message = obj["message"].toString("Serveur accessible");
        emit logMessage("✅ Connexion au serveur réussie: " + message);
    } else {
        message = m_connectionTestReply->errorString();
        emit logMessage("❌ Échec de connexion: " + message);
    }
    
    emit connectionTestResult(success, message);
    
    m_connectionTestReply->deleteLater();
    m_connectionTestReply = nullptr;
}

// Private helper methods implementations
QString LauncherManager::getCurrentVersionFromFile()
{
    QString versionFile = m_basePath + "/download/version.json";
    QFile file(versionFile);
    
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        QJsonObject obj = doc.object();
        return obj["version"].toString("0.0.0");
    }
    
    return "0.0.0";
}

void LauncherManager::saveVersionInfo(const QString &version)
{
    QString versionFile = m_basePath + "/download/version.json";
    QJsonObject obj = createVersionManifest(version);
    
    QFile file(versionFile);
    if (file.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(obj);
        file.write(doc.toJson());
        file.close();
    }
}

QJsonObject LauncherManager::createVersionManifest(const QString &version)
{
    QJsonObject manifest;
    manifest["version"] = version;
    manifest["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    manifest["created_by"] = "Meownopoly-Launcher";
    return manifest;
}

bool LauncherManager::parseVersionInfo(const QJsonObject &versionInfo)
{
    if (versionInfo.contains("version")) {
        setLatestVersion(versionInfo["version"].toString());

        // Extraire le checksum attendu pour la vérification après téléchargement
        QString checksum = versionInfo["checksum"].toString();
        if (checksum.startsWith("sha256:"))
            checksum = checksum.mid(7);
        m_expectedChecksum = checksum;

        // Extraire la description de version
        m_versionDescription = versionInfo["description"].toString();

        return true;
    }
    return false;
}

QString LauncherManager::getLocalModelVersion(const QString &modelName)
{
    QString versionFile = m_basePath + "/models/" + modelName + "/version.json";
    QFile file(versionFile);
    
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        QJsonObject obj = doc.object();
        return obj["version"].toString("0.0.0");
    }
    
    return "0.0.0";
}

// Property setters with signal emission
void LauncherManager::setCurrentVersion(const QString &version)
{
    if (m_currentVersion != version) {
        m_currentVersion = version;
        emit currentVersionChanged();
    }
}

void LauncherManager::setLatestVersion(const QString &version)
{
    if (m_latestVersion != version) {
        m_latestVersion = version;
        emit latestVersionChanged();
    }
}

void LauncherManager::setIsDownloading(bool downloading)
{
    if (m_isDownloading != downloading) {
        m_isDownloading = downloading;
        emit isDownloadingChanged();
    }
}

void LauncherManager::setDownloadProgress(double progress)
{
    if (m_downloadProgress != progress) {
        m_downloadProgress = progress;
        emit downloadProgressChanged();
    }
}

void LauncherManager::setDownloadStatus(const QString &status)
{
    if (m_downloadStatus != status) {
        m_downloadStatus = status;
        emit downloadStatusChanged();
    }
}

void LauncherManager::setPackageCreated(bool created)
{
    if (m_packageCreated != created) {
        m_packageCreated = created;
        emit packageCreatedChanged();
    }
}
