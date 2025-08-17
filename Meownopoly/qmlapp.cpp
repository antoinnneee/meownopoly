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

#include <QJsonArray>
#include <QJsonObject>
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

    // Create and expose FolderCompressor instance to QML
    folderCompressor = new FolderCompressor(this);
    rootContext()->setContextProperty("folderCompressor", folderCompressor);

    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();
    
    // Auto-extract assets at startup if compressed file exists
    autoExtractAssets();
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
    
    QFile file(compressedFile);
    if (file.exists()) {
        qDebug() << "Compressed assets file found, extracting...";
        
        // Check if extraction folder already exists
        QDir extractDir(extractPath);
        if (!extractDir.exists()) {
            bool success = folderCompressor->decompressFolder(compressedFile, extractPath);
            if (success) {
                qDebug() << "Assets extracted successfully to:" << extractPath;
            } else {
                qDebug() << "Failed to extract assets";
            }
        } else {
            qDebug() << "Assets already extracted to:" << extractPath;
        }
    } else {
        qDebug() << "No compressed assets file found";
    }
}
