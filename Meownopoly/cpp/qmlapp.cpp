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

#include "game/map/map.h"
#include "game/map/maptypes.h"
#include "game/map/undoredomanager.h"
#include "game/map/mapinfo.h"
#include "game/map/mapfilemanager.h"

#include "game/item_snapable/itemsnapablefactory.h"

//#include "animationprovider.h"
#include "tools/logger.h"
#include "tools/cursor_manager.h"


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
    MapFileManager::registerQml();
    MapInfo::registerQml();
    EditorEnum::registerQml();
    ItemSnapableFactory::registerQml();
//    AnimationProvider::registerQml();
    Logger::registerQml();
    CursorManager::registerQml();
    UndoRedoManager::registerQml();
    
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

    // Add QML module import paths for custom modules
    // The path should be the PARENT directory of the module folder
    // Module folder name must match the module name declared in qmldir
    addImportPath("qrc:/qml");  // Contains: ui_item, Editor
    addImportPath("qrc:/qml/Editor/panel/bottomPanel/bottomMainPanel");  // Contains: AssetSelectionPanel, CaseSelectionPanel, EditorBottomPanel, MapSelectionPanel, MenuSelectionPanel
    addImportPath("qrc:/qml/Editor/panel/bottomPanel/bottomMainPanel/CaseSelectionPanel");  // Contains: CaseSelectionPanelMain
    addImportPath("qrc:/qml/Editor/panel/bottomPanel/bottomSidePanel");  // Contains: CaseConfigPanel, ConnectionConfigPanel, SidePanel, VisualEffectPanel
    addImportPath("qrc:/qml/Editor/panel");  // Contains: MapInfoPanel
    addImportPath("qrc:/qml/Editor");  // Contains: EditorPanel (panel folder)

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
