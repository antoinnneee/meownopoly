#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/QQmlContext>

#include "qmlapp.h"

#include <QDir>
#include <QStandardPaths>
#include "game.h"
#include "meowstyle.h"
#include "item_snapable/ItemSnapable.h"
#include "launcher_manager.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QFile>
#include <QUrl>
#include <QRegularExpression>
#include <QFileInfo>
#include <QTimer>
#include <QDateTime>
#ifdef Q_OS_ANDROID
#include <QJniObject.h>
#endif
#include "QtFolderCompressor/FolderCompressor.h"

QmlApp::QmlApp(QWindow *parent)
    : QQmlApplicationEngine(parent)
{
    QQuickStyle::setStyle("Material");
    Game::registerQml();
    MeowStyle::registerQml();
    ItemSnapable::registerQml();
    FolderCompressor::registerQml();
    LauncherManager::registerQml();

    // Create and expose FolderCompressor instance to QML
    folderCompressor = new FolderCompressor(this);
    rootContext()->setContextProperty("folderCompressor", folderCompressor);
    
    // Initialize network manager
    networkManager = new QNetworkAccessManager(this);
    
    // Initialize assets path and expose this instance to QML
    m_assetsPath = "asset_extracted/"; // Default fallback path
    rootContext()->setContextProperty("appInstance", this);

    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();
    
    // Auto-extract assets at startup if compressed file exists
//    autoExtractAssets();
    downloadAssetsFile();
}

/*
 * Gestion Close Event
 */
bool QmlApp::event(QEvent *event)
{
    if (event->type() == QEvent::Close) {
        // return true to cancel close event
    }
    return QQmlApplicationEngine::event(event);
}

QmlApp::~QmlApp() {

}

void QmlApp::autoExtractAssets() {
    QString compressedFile = "assets_compressed.meow";
    QString extractPath = "asset_extracted";
    
    // Check if extraction folder already exists
    QDir extractDir(extractPath);
    if (extractDir.exists()) {
        qDebug() << "Assets already extracted to:" << extractPath;
        setAssetsPath(extractPath + "/");
        return;
    }
    
    QFile file(compressedFile);
    if (file.exists()) {
        qDebug() << "Compressed assets file found, extracting...";
        
        bool success = folderCompressor->decompressFolder(compressedFile, extractPath);
        if (success) {
            qDebug() << "Assets extracted successfully to:" << extractPath;
            setAssetsPath(extractPath + "/");
        } else {
            qDebug() << "Failed to extract assets";
            // Keep default path
        }
    } else {
        qDebug() << "No compressed assets file found, downloading from Google Drive...";
    }
}

QString QmlApp::getDirectDownloadUrl(const QString &shareableUrl) {
    // Convert Google Drive shareable URL to direct download URL
    // From: https://drive.google.com/file/d/FILE_ID/view?usp=sharing
    // To: https://drive.google.com/uc?export=download&id=FILE_ID
    
    QString fileId;
    QRegularExpression regex(R"(/file/d/([a-zA-Z0-9_-]+)/view)");
    QRegularExpressionMatch match = regex.match(shareableUrl);
    
    if (match.hasMatch()) {
        fileId = match.captured(1);
        return QString("https://drive.google.com/uc?export=download&id=%1").arg(fileId);
    }
    
    return shareableUrl; // Return original URL if pattern doesn't match
}

void QmlApp::downloadAssetsFile() {
    QString directUrl = getDirectDownloadUrl(ASSET_URL);
    QString fileName = "assets_compressed.meow";
    
    qDebug() << "Starting download from:" << directUrl;
    
    // Create the file to write to
    downloadFile = new QFile(fileName, this);
    if (downloadFile->exists())
    {
        #if FORCE_DOWNLOAD == 0
            qDebug() << "asset file already exist, remove it, or put FORCE_DOWNLOAD flag to 1 in qmlApp.h";
            return;
        #endif
    }
    if (!downloadFile->open(QIODevice::WriteOnly)) {
        qDebug() << "Failed to open file for writing:" << fileName;
        delete downloadFile;
        downloadFile = nullptr;
        return;
    }
    
    // Start the download
    QNetworkRequest request;
    request.setUrl(directUrl);
    request.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
    
    currentDownload = networkManager->get(request);

    qDebug()<<currentDownload;
    
    // Connect signals
    connect(currentDownload, &QNetworkReply::downloadProgress, 
            this, &QmlApp::onDownloadProgress);
    connect(currentDownload, &QNetworkReply::finished, 
            this, &QmlApp::onDownloadFinished);
    connect(currentDownload, &QNetworkReply::readyRead, [this]() {
        if (downloadFile) {
            downloadFile->write(currentDownload->readAll());
        }
    });
}

void QmlApp::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal) {
    if (bytesTotal > 0) {
        double progress = static_cast<double>(bytesReceived) / bytesTotal * 100.0;
        qDebug() << QString("Download progress: %1% (%2/%3 bytes)")
                    .arg(progress, 0, 'f', 1)
                    .arg(bytesReceived)
                    .arg(bytesTotal);
    }
}

void QmlApp::onDownloadFinished() {
    if (!currentDownload) {
        return;
    }
    
    // Close the file
    if (downloadFile) {
        downloadFile->close();
        delete downloadFile;
        downloadFile = nullptr;
    }
    
    if (currentDownload->error() == QNetworkReply::NoError) {
        qDebug() << "Assets file downloaded successfully!";
        
        // Now extract the downloaded file
        QString compressedFile = "assets_compressed.meow";
        QString extractPath = "asset_extracted";
        
        bool success = folderCompressor->decompressFolder(compressedFile, extractPath);
        if (success) {
            qDebug() << "Assets extracted successfully to:" << extractPath;
            setAssetsPath(extractPath + "/");
        } else {
            qDebug() << "Failed to extract downloaded assets";
            // Keep default path
        }
    } else {
        qDebug() << "Download failed:" << currentDownload->errorString();
        
        // Clean up the incomplete file
        QFile::remove("assets_compressed.meow");
    }
    
    // Clean up
    currentDownload->deleteLater();
    currentDownload = nullptr;
}

QString QmlApp::assetsPath() const {
    return m_assetsPath;
}

void QmlApp::setAssetsPath(const QString &path) {
    if (m_assetsPath != path) {
        m_assetsPath = path;
        emit assetsPathChanged();
        qDebug() << "Assets path updated to:" << m_assetsPath;
    }
}

QString QmlApp::getAssetPath(const QString &relativePath) const {
    // Remove leading slash if present to avoid double slashes
    QString cleanPath = relativePath;
    if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.mid(1);
    }
    
    QString fullPath = m_assetsPath + cleanPath;
    
    // Convert to file URL for QML Image components
    if (!fullPath.startsWith("qrc:") && !fullPath.startsWith("file:") && !fullPath.startsWith("http")) {
        QDir dir(fullPath);
        if (dir.exists() || QFile::exists(fullPath)) {
            fullPath = QUrl::fromLocalFile(QFileInfo(fullPath).absoluteFilePath()).toString();
        }
    }
    
    qDebug() << "Asset path requested:" << relativePath << "-> Full path:" << fullPath;
    return fullPath;
}



