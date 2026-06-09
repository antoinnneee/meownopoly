#include "launcher_manager.h"
#include <QDir>
#include <QDebug>
#include <QFileInfo>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QUrl>
#include <QString>
#include <QJsonArray>
#include <QImage>
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
    QDir().mkpath(m_basePath + "/model_textures");   // bibliothèque de textures partagée

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

bool LauncherManager::writeModelManifest(const QString &folderPath, const QString &json) const
{
    const QString cleanPath = sanitizeFolderPath(folderPath);
    QFile f(cleanPath + "/model_manifest.json");
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    f.write(json.toUtf8());
    f.close();
    return true;
}

QString LauncherManager::createModelFromGlb(const QString &parentDir, const QString &name,
                                            const QString &glbSource, const QString &skinBaseSource)
{
    const QString safe = name.trimmed();
    if (safe.isEmpty()) { emit logMessage("createModelFromGlb: nom vide"); return QString(); }

    const QString src = sanitizeFolderPath(glbSource);
    if (src.isEmpty() || !QFile::exists(src)) {
        emit logMessage("createModelFromGlb: .glb introuvable: " + src);
        return QString();
    }

    QString parent = sanitizeFolderPath(parentDir);
    if (parent.isEmpty()) parent = m_basePath + QStringLiteral("/model_drafts");
    const QString folder = parent + "/" + safe;
    QDir().mkpath(folder + "/base");
    QDir().mkpath(folder + "/skins");

    const QString glbName = safe + QStringLiteral(".glb");
    const QString dstGlb = folder + "/base/" + glbName;
    QFile::remove(dstGlb);
    if (!QFile::copy(src, dstGlb)) {
        emit logMessage("createModelFromGlb: échec copie du .glb vers " + dstGlb);
        return QString();
    }

    bool hasSkinBase = false;
    const QString sb = sanitizeFolderPath(skinBaseSource);
    if (!sb.isEmpty() && QFile::exists(sb)) {
        const QString dstSb = folder + "/base/skin_base.png";
        QFile::remove(dstSb);
        hasSkinBase = QFile::copy(sb, dstSb);
    }

    // Échelle par défaut 100 : les modèles importés sont minuscules à l'échelle
    // native, on les met d'emblée à une taille visible (cohérent avec le slider).
    QJsonArray s; s.append(100); s.append(100); s.append(100);
    QJsonArray e; e.append(0); e.append(0); e.append(0);
    QJsonArray p; p.append(0); p.append(0); p.append(0);
    QJsonObject tr; tr["scale"] = s; tr["eulerRotation"] = e; tr["position"] = p;

    QJsonObject colorId;
    colorId["version"] = 1;
    colorId["defaultSkin"] = "";
    colorId["defaultVariant"] = "";

    QJsonObject m;
    m["name"] = safe;
    m["version"] = "1.0.0";
    m["type"] = "model";
    m["glb"] = "base/" + glbName;
    m["skinBase"] = hasSkinBase ? "base/skin_base.png" : "";
    m["transform"] = tr;
    m["colorId"] = colorId;

    QFile f(folder + "/model_manifest.json");
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        f.write(QJsonDocument(m).toJson());
        f.close();
    }
    emit logMessage("Modèle créé depuis .glb : " + folder);
    return folder;
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

// ====================================================================
// Color ID Map — créateur de skin (port du pont C++ Catalog de kura).
// Arborescence : <folder>/skins/<skin>/{colorMap.png, skin.json,
// textures/*.png, variants/*.json}.
// ====================================================================

// Garde lettres/chiffres/espace/-/_ (évite toute traversée de chemin).
static QString sanitizeAssetName(const QString &name)
{
    QString out;
    for (const QChar c : name.trimmed()) {
        if (c.isLetterOrNumber() || c == QLatin1Char('_')
            || c == QLatin1Char('-') || c == QLatin1Char(' '))
            out += c;
    }
    return out.trimmed();
}

static QString skinDirPath(const QString &folderPath, const QString &skin)
{
    return sanitizeFolderPath(folderPath) + QStringLiteral("/skins/") + sanitizeAssetName(skin);
}

static QStringList imageNameFilters()
{
    return QStringList{ "*.png", "*.jpg", "*.jpeg", "*.tga", "*.bmp" };
}

// Détecte le nombre de zones d'une color ID map : compte les pixels qui
// matchent chacune des 20 couleurs de palette (COLOR_ID_MAP.md §2, 0-255
// linéaire brut), puis ne retient un slot que s'il couvre une AIRE
// significative (filtre l'anti-aliasing/compression/pixels parasites qui,
// sinon, gonflent le compte). Renvoie (index max retenu + 1), ou 1 si rien.
// Tolérance de comptage volontairement stricte (~28/255 ; distance min entre
// IDs voisins ≈ 153/255, donc aucune confusion entre zones réelles).
static int detectColorMapZoneCountImpl(const QString &imagePath)
{
    QImage img(imagePath);
    if (img.isNull()) { qDebug() << "[colorId] image illisible:" << imagePath; return 1; }
    img = img.convertToFormat(QImage::Format_RGB888);

    static const int PAL[20][3] = {
        {242, 24, 24},  {24, 242, 242}, {133, 242, 24}, {133, 24, 242},
        {242, 188, 24}, {24, 79, 242},  {24, 242, 79},  {242, 24, 188},
        {242, 106, 24}, {24, 161, 242}, {52, 242, 24},  {215, 24, 242},
        {215, 242, 24}, {52, 24, 242},  {24, 242, 161}, {242, 24, 106},
        {242, 65, 24},  {24, 201, 242}, {92, 242, 24},  {174, 24, 242}
    };
    const int TOL2 = 28 * 28;

    qint64 counts[20] = { 0 };
    qint64 sampled = 0;
    const int W = img.width(), H = img.height();
    const int step = qMax(1, qMin(W, H) / 400); // sous-échantillonnage gros fichiers

    for (int y = 0; y < H; y += step) {
        const uchar *line = img.constScanLine(y);
        for (int x = 0; x < W; x += step) {
            const uchar *p = line + x * 3;
            const int r = p[0], g = p[1], b = p[2];
            ++sampled;
            if (r < 24 && g < 24 && b < 24) continue; // fond noir = aucune zone
            for (int i = 0; i < 20; ++i) {
                const int dr = r - PAL[i][0], dg = g - PAL[i][1], db = b - PAL[i][2];
                if (dr * dr + dg * dg + db * db <= TOL2) { counts[i]++; break; }
            }
        }
    }

    // Seuil d'aire : une zone réelle couvre une surface notable. ≥ 0.2 % des
    // pixels échantillonnés (plancher absolu 8) → ignore le bruit épars.
    const qint64 thresh = qMax<qint64>(8, sampled / 500);
    int highest = -1;
    QStringList dbg;
    for (int i = 0; i < 20; ++i) {
        if (counts[i] >= thresh) highest = i;
        if (counts[i] > 0) dbg << QStringLiteral("%1:%2").arg(i).arg(counts[i]);
    }
    qDebug().noquote() << "[colorId] détection zones — échantillonnés" << sampled
                       << "seuil" << thresh << "| counts" << dbg.join(" ")
                       << "=> zones =" << (highest + 1);
    return highest >= 0 ? highest + 1 : 1;
}

int LauncherManager::detectColorMapZones(const QString &colorMapSource) const
{
    return detectColorMapZoneCountImpl(sanitizeFolderPath(colorMapSource));
}

bool LauncherManager::createModelSkin(const QString &folderPath, const QString &skinName,
                                      const QString &colorMapSource)
{
    const QString skin = sanitizeAssetName(skinName);
    if (skin.isEmpty()) {
        emit logMessage("createModelSkin: nom de skin vide/invalide");
        return false;
    }
    const QString dir = skinDirPath(folderPath, skin);
    QDir().mkpath(dir);
    QDir().mkpath(dir + "/textures");
    QDir().mkpath(dir + "/variants");

    // Copie la color map (si fournie) vers colorMap.png + détecte les zones.
    int zoneCount = 1;
    const QString src = sanitizeFolderPath(colorMapSource);
    if (!src.isEmpty() && QFile::exists(src)) {
        const QString dst = dir + "/colorMap.png";
        QFile::remove(dst);
        if (!QFile::copy(src, dst)) {
            emit logMessage("createModelSkin: échec copie colorMap depuis " + src);
            return false;
        }
        zoneCount = detectColorMapZoneCountImpl(dst);
        emit logMessage(QStringLiteral("createModelSkin: %1 zone(s) détectée(s) dans la color map").arg(zoneCount));
    }

    // skin.json (zones détectées) s'il n'existe pas déjà.
    const QString skinJson = dir + "/skin.json";
    if (!QFile::exists(skinJson)) {
        QJsonObject zones;
        for (int i = 0; i < zoneCount; ++i) {
            QJsonObject z; z["name"] = QStringLiteral("zone %1").arg(i);
            zones[QString::number(i)] = z;
        }
        QJsonObject root; root["name"] = skin; root["zones"] = zones;
        QFile f(skinJson);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            f.write(QJsonDocument(root).toJson());
            f.close();
        }
    }
    emit logMessage("Skin créé : " + dir + QStringLiteral(" (%1 zones)").arg(zoneCount));
    return true;
}

QStringList LauncherManager::listModelSkins(const QString &folderPath) const
{
    QDir d(sanitizeFolderPath(folderPath) + QStringLiteral("/skins"));
    if (!d.exists()) return {};
    return d.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
}

QStringList LauncherManager::listSkinTextures(const QString &folderPath, const QString &skin) const
{
    QDir d(skinDirPath(folderPath, skin) + QStringLiteral("/textures"));
    if (!d.exists()) return {};
    return d.entryList(imageNameFilters(), QDir::Files, QDir::Name);
}

bool LauncherManager::importSkinTexture(const QString &folderPath, const QString &skin,
                                        const QString &textureSource)
{
    const QString src = sanitizeFolderPath(textureSource);
    if (src.isEmpty() || !QFile::exists(src)) {
        emit logMessage("importSkinTexture: source introuvable " + src);
        return false;
    }
    const QString dir = skinDirPath(folderPath, skin) + QStringLiteral("/textures");
    QDir().mkpath(dir);
    const QString dst = dir + "/" + QFileInfo(src).fileName();
    QFile::remove(dst);
    if (!QFile::copy(src, dst)) {
        emit logMessage("importSkinTexture: échec copie vers " + dst);
        return false;
    }
    return true;
}

QString LauncherManager::readSkinJson(const QString &folderPath, const QString &skin) const
{
    QFile f(skinDirPath(folderPath, skin) + QStringLiteral("/skin.json"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
    const QString s = QString::fromUtf8(f.readAll());
    f.close();
    return s;
}

bool LauncherManager::writeSkinJson(const QString &folderPath, const QString &skin,
                                    const QString &json) const
{
    const QString dir = skinDirPath(folderPath, skin);
    QDir().mkpath(dir);
    QFile f(dir + QStringLiteral("/skin.json"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    f.write(json.toUtf8());
    f.close();
    return true;
}

QStringList LauncherManager::listSkinVariants(const QString &folderPath, const QString &skin) const
{
    QDir d(skinDirPath(folderPath, skin) + QStringLiteral("/variants"));
    if (!d.exists()) return {};
    QStringList names;
    for (const QString &f : d.entryList(QStringList() << QStringLiteral("*.json"),
                                        QDir::Files, QDir::Name))
        names << QFileInfo(f).completeBaseName();
    return names;
}

bool LauncherManager::saveSkinVariant(const QString &folderPath, const QString &skin,
                                      const QString &name, const QString &json) const
{
    const QString safe = sanitizeAssetName(name);
    if (safe.isEmpty()) return false;
    const QString dir = skinDirPath(folderPath, skin) + QStringLiteral("/variants");
    QDir().mkpath(dir);
    QFile f(dir + "/" + safe + QStringLiteral(".json"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    f.write(json.toUtf8());
    f.close();
    return true;
}

QString LauncherManager::loadSkinVariant(const QString &folderPath, const QString &skin,
                                         const QString &name) const
{
    QFile f(skinDirPath(folderPath, skin) + QStringLiteral("/variants/")
            + sanitizeAssetName(name) + QStringLiteral(".json"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return QString();
    const QString s = QString::fromUtf8(f.readAll());
    f.close();
    return s;
}

bool LauncherManager::deleteSkinVariant(const QString &folderPath, const QString &skin,
                                        const QString &name) const
{
    const QString safe = sanitizeAssetName(name);
    if (safe.isEmpty()) return false;
    return QFile::remove(skinDirPath(folderPath, skin) + QStringLiteral("/variants/")
                         + safe + QStringLiteral(".json"));
}

bool LauncherManager::deleteSkinTexture(const QString &folderPath, const QString &skin,
                                        const QString &file) const
{
    const QString name = QFileInfo(file).fileName();   // garde-fou : pas de traversée
    if (name.isEmpty()) return false;
    return QFile::remove(skinDirPath(folderPath, skin)
                         + QStringLiteral("/textures/") + name);
}

// --- Bibliothèque de textures générales (<AppData>/model_textures) ----------

QString LauncherManager::generalTextureDir() const
{
    return m_basePath + QStringLiteral("/model_textures");
}

QStringList LauncherManager::listGeneralTextures() const
{
    QDir d(generalTextureDir());
    if (!d.exists()) return {};
    return d.entryList(imageNameFilters(), QDir::Files, QDir::Name);
}

bool LauncherManager::importGeneralTexture(const QString &source)
{
    const QString src = sanitizeFolderPath(source);
    if (src.isEmpty() || !QFile::exists(src)) {
        emit logMessage("importGeneralTexture: source introuvable " + src);
        return false;
    }
    const QString dir = generalTextureDir();
    QDir().mkpath(dir);
    const QString dst = dir + "/" + QFileInfo(src).fileName();
    QFile::remove(dst);
    if (!QFile::copy(src, dst)) {
        emit logMessage("importGeneralTexture: échec copie vers " + dst);
        return false;
    }
    return true;
}

bool LauncherManager::deleteGeneralTexture(const QString &file) const
{
    const QString name = QFileInfo(file).fileName();
    if (name.isEmpty()) return false;
    return QFile::remove(generalTextureDir() + "/" + name);
}

bool LauncherManager::copyGeneralTextureToSkin(const QString &folderPath, const QString &skin,
                                               const QString &file)
{
    const QString name = QFileInfo(file).fileName();
    const QString src = generalTextureDir() + "/" + name;
    if (name.isEmpty() || !QFile::exists(src)) {
        emit logMessage("copyGeneralTextureToSkin: texture générale introuvable " + src);
        return false;
    }
    const QString dir = skinDirPath(folderPath, skin) + QStringLiteral("/textures");
    QDir().mkpath(dir);
    const QString dst = dir + "/" + name;
    QFile::remove(dst);
    if (!QFile::copy(src, dst)) {
        emit logMessage("copyGeneralTextureToSkin: échec copie vers " + dst);
        return false;
    }
    return true;
}

QString LauncherManager::installedModelDir(const QString &name) const
{
    const QString safe = QFileInfo(name.trimmed()).fileName();
    if (safe.isEmpty()) return QString();
    return m_basePath + QStringLiteral("/models/") + safe;
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
