#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/QQmlContext>

#include "qmlapp.h"

#include <QDir>
#include <QStandardPaths>
#include "game/game.h"
#include "game/meowstyle.h"
#include "game/item_snapable/ItemSnapable.h"
#include "launcher/launcher_manager.h"

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
#include "tools/QtFolderCompressor/FolderCompressor.h"
#include "assetManager/asset_manager.h"

#include "tools/editorenum.h"
#include "tools/uistyle.h"

#include "game/physics/pattounx_engine.h"

#include "game/map/map.h"
#include "game/map/maptypes.h"
#include "game/map/undoredomanager.h"
#include "game/map/mapinfo.h"
#include "game/map/mapfilemanager.h"

#include "game/item_snapable/itemsnapablefactory.h"

//#include "animationprovider.h"
#include "tools/logger.h"
#include "tools/cursor_manager.h"
#include "chat/chat_client.h"
#include "account/account_manager.h"

#include <QImageWriter>

QmlApp::QmlApp(QWindow *parent) : QQmlApplicationEngine(parent)
{
    // qDebug() << QImageWriter::supportedImageFormats();
    QQuickStyle::setStyle("Material");
    UiStyle::registerQml();
    Game::registerQml();
    MeowStyle::registerQml();
    ItemSnapable::registerQml();
    FolderCompressor::registerQml();
    LauncherManager::registerQml();
    AssetManager::registerQml();
    MapFileManager::registerQml();
    MapInfo::registerQml();
    EditorEnum::registerQml();
    ItemSnapableFactory::registerQml();
//    AnimationProvider::registerQml();
    Logger::registerQml();
    CursorManager::registerQml();
    UndoRedoManager::registerQml();
    
    PattounX_engine::registerQml();
    ChatClient::registerQml(this);
    AccountManager::registerQml();


    // Register MapTypes namespace for QML
    qmlRegisterUncreatableMetaObject(MapTypes::staticMetaObject, "MapTypes", 1, 0, "MapTypes", "Error: only enums");
    
    // Create and expose FolderCompressor instance to QML
    folderCompressor = new FolderCompressor(this);
    rootContext()->setContextProperty("folderCompressor", folderCompressor);
    
    // Initialize network manager
    networkManager = new QNetworkAccessManager(this);
    
    // Create and expose AssetManager instance to QML
    assetManager = AssetManager::instance();

    // Connect Game signals to UndoRedoManager
    connect(Game::instance(), &Game::updateListEdits, UndoRedoManager::instance(), &UndoRedoManager::onUpdateListEdits);
    connect(Game::instance(), &Game::askEdit, UndoRedoManager::instance(), &UndoRedoManager::onAskEdit);
    connect(UndoRedoManager::instance(), &UndoRedoManager::returnEdit, Game::instance(), &Game::onReturnEdit);
    /*
    // Charger l'animation depuis le dossier anim et la démarrer automatiquement
    QString animFolderPath = "C:/Users/Antoine/Documents/GitHub/meownopoly/Meownopoly/anim";
    animationManager->loadAnimationFromFolder("test", animFolderPath);
    animationManager->startAnimation("test", 15); // 15 FPS pour une animation fluide
*/
//    qmlRegisterType<LiveImage>("MyApp.Images", 1, 0, "LiveImage");
//    AnimationProvider * provider = AnimationProvider::instance();
//    provider->loadImagesFromFolder("C:/Users/Antoine/Documents/GitHub/meownopoly/Meownopoly/anim");



    //To declare module in QML

    //1) Create a qmldir file in the resource folder. The qmldir is wrote like this:
    //  module name_of_the_folder
    //  TypeName 1.0 TypeFileName.qml
    //  TypeName2 1.0 TypeFileName2.qml

    //2) Add the path of the parent's module/folder below with addImportPath()

    //3) In QML, import the module with <import name_of_the_folder>

    // ** In order to respect the current typo, folder/module has to be named with lowercase letters, and the file's name with uppercase letters **
    // ** the module-system of Qt IS case sensitive **

    addImportPath("qrc:/qml");  // Contains: ui_item, utils
    addImportPath("qrc:/qml/editor");  // Contains: editor qmldir
    addImportPath("qrc:/qml/editor/panel");  // Contains: mapInfoPanel qmldir, bottomPanel qmldir, zonePanel qmldir
    addImportPath("qrc:/qml/editor/panel/bottomPanel");  // Contains: bottomMainPanel, bottomSidePanel
    addImportPath("qrc:/qml/editor/panel/mapInfoPanel");  // Contains: mapInfoPanelMain
    addImportPath("qrc:/qml/editor/panel/bottomPanel/bottomMainPanel");  // Contains: assetSelectionPanel, caseSelectionPanel, editorBottomPanel, mapSelectionPanel, menuSelectionPanel
    addImportPath("qrc:/qml/editor/panel/bottomPanel/bottomSidePanel");  // Contains: caseConfigPanel, connectionConfigPanel, sidePanel, visualEffectPanel
    addImportPath("qrc:/qml/editor/panel/bottomPanel/bottomMainPanel/caseSelectionPanel");  // Contains: caseSelectionPanelMain
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
