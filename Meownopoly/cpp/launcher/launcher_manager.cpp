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
    // Initialize network manager
    m_networkManager = new QNetworkAccessManager(this);
    
    // Initialize folder compressor
    m_folderCompressor = new FolderCompressor(this);

    m_basePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString downloadPath = m_basePath + "/download";
    QDir().mkpath(downloadPath);
    QString assetsPath = m_basePath + "/assets";
    QDir().mkpath(assetsPath);
    QString modelsPath = m_basePath + "/models"; // New folder
    QDir().mkpath(modelsPath);
    // Load current version from file
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
    if (m_currentDownload) {
        m_currentDownload->deleteLater();
        m_currentDownload = nullptr;
    }
    
    emit logMessage("Début du téléchargement des ressources...");
    setIsDownloading(true);
    setDownloadProgress(0.0);
    setDownloadStatus("Téléchargement...");
    
    QString formattedServerUrl = reformat_server_url(serverUrl);
    QString downloadUrl = formattedServerUrl + "/api/download/" + version;
    QString fileName = m_basePath + "/download/" + QString("assets_v%1.meow").arg(version);
    
    m_downloadFile = new QFile(fileName, this);
    if (!m_downloadFile->open(QIODevice::WriteOnly)) {
        emit logMessage("❌ Erreur: Impossible d'ouvrir le fichier pour écriture");
        setDownloadStatus("Erreur");
        setIsDownloading(false);
        return;
    }
    
    QNetworkRequest request;
    request.setUrl(downloadUrl);
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    
    m_currentDownload = m_networkManager->get(request);
    
    connect(m_currentDownload, &QNetworkReply::downloadProgress, 
            this, &LauncherManager::onDownloadProgress);
    connect(m_currentDownload, &QNetworkReply::finished, 
            this, &LauncherManager::onDownloadFinished);
    connect(m_currentDownload, &QNetworkReply::readyRead, [this]() {
        if (m_downloadFile) {
            m_downloadFile->write(m_currentDownload->readAll());
        }
    });
}

void LauncherManager::forceDownloadResources(const QString &serverUrl)
{
    emit logMessage("Téléchargement forcé des ressources...");
    setIsDownloading(true);
    setDownloadProgress(0.0);
    setDownloadStatus("Téléchargement forcé...");
    
    m_currentVersion = "0.0.0";
    // First check for updates to get the latest version
    checkForUpdates(serverUrl);
    // The download will be triggered in onVersionCheckFinished
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
        emit logMessage("❌ Aucun paquet à uploader");
        setDownloadStatus("Aucun paquet à uploader");
        return;
    }
    
    // Extraire la version du nom du fichier (format: assets_vX.X.X.meow)
    QString fileName = QFileInfo(m_lastCreatedPackage).fileName();
    QRegularExpression versionRegex("assets_v([0-9]+\\.[0-9]+\\.[0-9]+)\\.meow");
    QRegularExpressionMatch match = versionRegex.match(fileName);
    
    if (!match.hasMatch()) {
        emit logMessage("❌ Erreur: Format de nom de fichier invalide");
        setDownloadStatus("Format de fichier invalide");
        return;
    }
    
    QString version = match.captured(1);
    emit logMessage("📦 Upload du paquet version " + version + "...");
    
    // Lire le contenu du fichier en mémoire
    QFile packageFile(m_lastCreatedPackage);
    if (!packageFile.open(QIODevice::ReadOnly)) {
        emit logMessage("❌ Erreur: Impossible de lire le paquet");
        setDownloadStatus("Erreur de lecture");
        return;
    }
    
    QByteArray fileData = packageFile.readAll();
    packageFile.close();
    
    if (fileData.isEmpty()) {
        emit logMessage("❌ Erreur: Fichier vide");
        setDownloadStatus("Fichier vide");
        return;
    }
    
    // Créer une requête multipart/form-data
    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    
    // Partie fichier
    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("application/octet-stream"));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                       QVariant("form-data; name=\"package\"; filename=\"" + fileName + "\""));
    filePart.setBody(fileData);
    multiPart->append(filePart);
    
    // Partie version
    QHttpPart versionPart;
    versionPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"version\""));
    versionPart.setBody(version.toUtf8());
    multiPart->append(versionPart);
    
    // Partie timestamp
    QHttpPart timestampPart;
    timestampPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"timestamp\""));
    timestampPart.setBody(QDateTime::currentDateTime().toString(Qt::ISODate).toUtf8());
    multiPart->append(timestampPart);
    
    // Configurer et envoyer la requête
    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/upload"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    
    QNetworkReply *uploadReply = m_networkManager->post(request, multiPart);
    multiPart->setParent(uploadReply); // Nettoyer automatiquement
    
    setDownloadStatus("Upload en cours...");
    
    // Gérer la fin de l'upload
    connect(uploadReply, &QNetworkReply::finished, [this, uploadReply, version]() {
        if (uploadReply->error() == QNetworkReply::NoError) {
            emit logMessage("✅ Upload du paquet v" + version + " terminé avec succès");
            setDownloadStatus("Upload terminé");
            
            // Vérifier la réponse du serveur
            QByteArray response = uploadReply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(response);
            QJsonObject obj = doc.object();

            if (obj["success"].toBool()) {
                emit logMessage("✅ Paquet validé par le serveur");
            } else {
                emit logMessage("⚠️ Le serveur signale une erreur: " + obj["message"].toString());
            }
        } else {
            emit logMessage("❌ Erreur d'upload: " + uploadReply->errorString());
            setDownloadStatus("Erreur d'upload");
        }
        uploadReply->deleteLater();
    });
    
    // Gérer la progression
    connect(uploadReply, &QNetworkReply::uploadProgress, [this](qint64 sent, qint64 total) {
        if (total > 0) {
            double progress = static_cast<double>(sent) / total;
            setDownloadProgress(progress);
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
    if (m_currentDownload) {
        emit logMessage("❌ Un téléchargement est déjà en cours");
        return;
    }

    emit logMessage("Début du téléchargement du modèle: " + name + " v" + version);
    setIsDownloading(true);
    setDownloadProgress(0.0);
    setDownloadStatus("Téléchargement modèle...");
    
    // Set flags for onDownloadFinished
    m_isModelDownload = true;
    m_currentModelName = name;
    m_currentModelVersion = version;

    QString formattedServerUrl = reformat_server_url(serverUrl);
    // Encoding URL parameters manually or using QUrlQuery would be safer, but simple concat here matches existing style
    QString downloadUrl = formattedServerUrl + "/api/models/download/" + name + "/" + version;
    
    QString fileName = QString("%1_v%2.meow").arg(name, version);
    QString filePath = m_basePath + "/download/" + fileName;
    
    m_downloadFile = new QFile(filePath, this);
    if (!m_downloadFile->open(QIODevice::WriteOnly)) {
        emit logMessage("❌ Erreur: Impossible d'ouvrir le fichier pour écriture");
        setDownloadStatus("Erreur Fichier");
        setIsDownloading(false);
        m_isModelDownload = false;
        return;
    }
    
    QNetworkRequest request;
    request.setUrl(downloadUrl);
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    
    m_currentDownload = m_networkManager->get(request);
    
    connect(m_currentDownload, &QNetworkReply::downloadProgress, this, &LauncherManager::onDownloadProgress);
    connect(m_currentDownload, &QNetworkReply::finished, this, &LauncherManager::onDownloadFinished);
    connect(m_currentDownload, &QNetworkReply::readyRead, [this]() {
        if (m_downloadFile) {
            m_downloadFile->write(m_currentDownload->readAll());
        }
    });
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
        emit logMessage("❌ Aucun paquet modèle à uploader");
        return;
    }
    
    emit logMessage("📦 Upload du modèle '" + name + "' v" + version + "...");
    
    QFile packageFile(m_lastCreatedPackage);
    if (!packageFile.open(QIODevice::ReadOnly)) {
        emit logMessage("❌ Erreur lecture fichier");
        return;
    }
    
    QByteArray fileData = packageFile.readAll();
    packageFile.close();
    
    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    
    // File Part
    QHttpPart filePart;
    QString fileName = QFileInfo(m_lastCreatedPackage).fileName();
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("application/octet-stream"));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                       QVariant("form-data; name=\"package\"; filename=\"" + fileName + "\""));
    filePart.setBody(fileData);
    multiPart->append(filePart);
    
    // Name Part
    QHttpPart namePart;
    namePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"name\""));
    namePart.setBody(name.toUtf8());
    multiPart->append(namePart);

    // Version Part
    QHttpPart versionPart;
    versionPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"version\""));
    versionPart.setBody(version.toUtf8());
    multiPart->append(versionPart);
    
    QNetworkRequest request;
    QString formattedServerUrl = reformat_server_url(serverUrl);
    request.setUrl(QUrl(formattedServerUrl + "/api/models/upload"));
    request.setRawHeader("User-Agent", "Meownopoly-Launcher/1.0");
    
    QNetworkReply *uploadReply = m_networkManager->post(request, multiPart);
    multiPart->setParent(uploadReply);
    
    setDownloadStatus("Upload modèle...");
    setIsDownloading(true);
    setDownloadProgress(0.0);

    connect(uploadReply, &QNetworkReply::finished, [this, uploadReply, name, version]() {
        if (uploadReply->error() == QNetworkReply::NoError) {
            emit logMessage("✅ Upload modèle terminé");
            setDownloadStatus("Upload OK");
            // Refresh list
        } else {
            emit logMessage("❌ Erreur upload: " + uploadReply->errorString());
            setDownloadStatus("Erreur Upload");
        }
        setIsDownloading(false);
        uploadReply->deleteLater();
    });
    
    connect(uploadReply, &QNetworkReply::uploadProgress, [this](qint64 sent, qint64 total) {
        if (total > 0) {
            setDownloadProgress((double)sent / total);
        }
    });
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
                        
                        // Fallback for converting from QVariantMap if needed (QVariant::toJsonObject might need explicit conversion)
                        if (ver1.isEmpty() && v1.canConvert<QVariantMap>()) ver1 = v1.toMap()["version"].toString();
                        if (ver2.isEmpty() && v2.canConvert<QVariantMap>()) ver2 = v2.toMap()["version"].toString();

                        QStringList p1 = ver1.split('.');
                        QStringList p2 = ver2.split('.');
                        
                        // Normalize length to 3 parts
                        while(p1.length() < 3) p1.append("0");
                        while(p2.length() < 3) p2.append("0");
                        
                        for(int i=0; i<3; i++) {
                            int n1 = p1[i].toInt();
                            int n2 = p2[i].toInt();
                            if (n1 != n2) return n1 > n2; // Descending
                        }
                        return false;
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
        
        qDebug() << QString("Download progress: %1% (%2/%3 bytes)")
                    .arg(progress * 100.0, 0, 'f', 1)
                    .arg(bytesReceived)
                    .arg(bytesTotal);
    }
}

void LauncherManager::onDownloadFinished()
{
    if (!m_currentDownload) {
        return;
    }
    
    // Close the file
    if (m_downloadFile) {
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }
    
    if (m_currentDownload->error() == QNetworkReply::NoError) {
        emit logMessage("✅ Fichier téléchargé avec succès!");
        
        if (m_isModelDownload) {
            // Extraction du modèle
            QString fileName = QString("%1_v%2.meow").arg(m_currentModelName, m_currentModelVersion);
            QString compressedFile = m_basePath + "/download/" + fileName;
            // Dossier cible: assets/models/NomDuModele/
            // Ou juste assets/ ? Le user a dit "Ne les mets pas dans le meme dossier que les assets" sur le serveur.
            // Côté client, Unity/Godot/etc s'attend probablement à les trouver quelque part.
            // Disons m_basePath/models/NomDuPack/
            QString extractPath = m_basePath + "/models/" + m_currentModelName + "/";
            QDir().mkpath(extractPath);

            bool success = m_folderCompressor->decompressFolder(compressedFile, extractPath, FC_DELETE_BOTH);
            if (success) {
                 emit logMessage("✅ Modèle extrait avec succès vers: " + extractPath);
                 
                 // Sauvegarder la version locale du modèle
                 QJsonObject verObj;
                 verObj["version"] = m_currentModelVersion;
                 verObj["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
                 
                 QFile verFile(extractPath + "version.json");
                 if (verFile.open(QIODevice::WriteOnly)) {
                     verFile.write(QJsonDocument(verObj).toJson());
                     verFile.close();
                 }
                 
                 setDownloadStatus("Download success");
                 
                 // Update internal list to refresh UI instantly
                 QVariantList list = m_modelsList;
                 bool found = false;
                 for(int i=0; i<list.size(); i++) {
                     QVariantMap map = list[i].toMap();
                     if (map["name"].toString() == m_currentModelName) {
                         map["localVersion"] = m_currentModelVersion;
                         map["isInstalled"] = true;
                         list[i] = map;
                         found = true;
                         break;
                     }
                 }
                 
                 if (found) {
                     setModelsList(list);
                 } else {
                     // Should not happen if we downloaded from the list, but maybe if manual download?
                     // In that case we might want to re-fetch the list completely.
                 }

            } else {
                 emit logMessage("❌ Échec de l'extraction du modèle");
                 setDownloadStatus("Erreur d'extraction");
            }
            // Reset flags
            m_isModelDownload = false;
            m_currentModelName = "";
            m_currentModelVersion = "";

        } else {
            // Extraction des assets principaux (Logique existante)
            QString compressedFile = m_basePath + "/download/" +QString("assets_v%1.meow").arg(m_latestVersion);
            QString extractPath = m_basePath + "/assets/";
            
            bool success = m_folderCompressor->decompressFolder(compressedFile, extractPath, FC_DELETE_BOTH);
            if (success) {
                emit logMessage("✅ Assets extraits avec succès vers: " + extractPath);
                setCurrentVersion(m_latestVersion);
                saveVersionInfo(m_latestVersion);
                setDownloadStatus("Download success");
                emit downloadSucess();
            } else {
                emit logMessage("❌ Échec de l'extraction des assets");
                setDownloadStatus("Erreur d'extraction");
            }
        }
    } else {
        emit logMessage("❌ Échec du téléchargement: " + m_currentDownload->errorString());
        setDownloadStatus("Erreur de téléchargement");
        
        // Clean up the incomplete file
        QString compressedFile;
        if (m_isModelDownload) {
             compressedFile = m_basePath + "/download/" + QString("%1_v%2.meow").arg(m_currentModelName, m_currentModelVersion);
             m_isModelDownload = false;
        } else {
             compressedFile = m_basePath + "/download/" + QString("assets_v%1.meow").arg(m_latestVersion);
        }
        if (QFile::exists(compressedFile)) {
             QFile::remove(compressedFile);
        }
    }
    
    setIsDownloading(false);
    setDownloadProgress(m_currentDownload->error() == QNetworkReply::NoError ? 1.0 : 0.0);
    
    // Clean up
    m_currentDownload->deleteLater();
    m_currentDownload = nullptr;
}

void LauncherManager::onVersionCheckFinished()
{
    if (!m_versionCheckReply) {
        return;
    }
    
    if (m_versionCheckReply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(m_versionCheckReply->readAll());
        QJsonObject obj = doc.object();
        
        if (parseVersionInfo(obj)) {
            emit logMessage("Version actuelle: " + m_currentVersion + ", Dernière: " + m_latestVersion);
            setDownloadStatus("Vérification terminée");
            if (m_currentVersion != m_latestVersion)
            {
                emit updateAvailable();
            }

        } else {
            emit logMessage("❌ Erreur: Format de version invalide");
            setDownloadStatus("Format invalide");
        }
    } else {
        emit logMessage("❌ Erreur de vérification: " + m_versionCheckReply->errorString());
        qDebug() << "ENUM ERROR " <<  m_versionCheckReply->error();

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
