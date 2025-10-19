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

#include <map/map.h>
#include <map/maploader.h>
#include <map/mapinfo.h>
#include "tools/debug_info.h"
#include "tools/editorenum.h"
#include "animation_manager.h"
#include "liveimage.h"
#include "tools/undoredomanager.h"

//#include "animationprovider.h"
#include "tools/logger.h"
#include "item_snapable/itemsnapablefactory.h"
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
    MapLoader::registerQml();
    MapInfo::registerQml();
    EditorEnum::registerQml();
    ItemSnapableFactory::registerQml();
//    AnimationProvider::registerQml();
    Logger::registerQml();
    UndoRedoManager::registerQml();
    // Create and expose FolderCompressor instance to QML
    folderCompressor = new FolderCompressor(this);
    rootContext()->setContextProperty("folderCompressor", folderCompressor);
    
    // Initialize network manager
    networkManager = new QNetworkAccessManager(this);
    
    // Create and expose AssetManager instance to QML
    assetManager = AssetManager::instance();

    connect(MapLoader::instance(), &MapLoader::updateListEdits, UndoRedoManager::instance(), &UndoRedoManager::onUpdateListEdits);
    connect(MapLoader::instance(), &MapLoader::askEdit, UndoRedoManager::instance(), &UndoRedoManager::onAskEdit);
    connect(UndoRedoManager::instance(), &UndoRedoManager::returnEdit, MapLoader::instance(), &MapLoader::onReturnEdit);


    /*
    // Charger l'animation depuis le dossier anim et la démarrer automatiquement
    QString animFolderPath = "C:/Users/Antoine/Documents/GitHub/meownopoly/Meownopoly/anim";
    animationManager->loadAnimationFromFolder("test", animFolderPath);
    animationManager->startAnimation("test", 15); // 15 FPS pour une animation fluide
*/
//    qmlRegisterType<LiveImage>("MyApp.Images", 1, 0, "LiveImage");
//    AnimationProvider * provider = AnimationProvider::instance();
//    provider->loadImagesFromFolder("C:/Users/Antoine/Documents/GitHub/meownopoly/Meownopoly/anim");

    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();

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
