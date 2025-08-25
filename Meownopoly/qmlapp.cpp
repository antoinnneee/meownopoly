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
#include "asset_manager.h"

QmlApp::QmlApp(QWindow *parent)
    : QQmlApplicationEngine(parent)
{
    QQuickStyle::setStyle("Material");
    Game::registerQml();
    MeowStyle::registerQml();
    ItemSnapable::registerQml();
    FolderCompressor::registerQml();
    LauncherManager::registerQml();
    AssetManager::registerQml();

    // Create and expose FolderCompressor instance to QML
    folderCompressor = new FolderCompressor(this);
    rootContext()->setContextProperty("folderCompressor", folderCompressor);
    
    // Initialize network manager
    networkManager = new QNetworkAccessManager(this);
    
    // Initialize assets path and expose this instance to QML
    m_assetsPath = "asset_extracted/"; // Default fallback path
    rootContext()->setContextProperty("appInstance", this);
    
    // Create and expose AssetManager instance to QML
    assetManager = AssetManager::instance();
    assetManager->setAssetsBasePath(m_assetsPath);

    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();
    
    // Auto-extract assets at startup if compressed file exists
//    autoExtractAssets();
 //   downloadAssetsFile();
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

QString QmlApp::assetsPath() const {
    return m_assetsPath;
}

void QmlApp::setAssetsPath(const QString &path) {
    if (m_assetsPath != path) {
        m_assetsPath = path;
        emit assetsPathChanged();
        qDebug() << "Assets path updated to:" << m_assetsPath;
        
        // Update AssetManager with new path
        if (assetManager) {
            assetManager->setAssetsBasePath(path);
        }
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



