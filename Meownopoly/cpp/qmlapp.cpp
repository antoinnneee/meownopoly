#include <QDebug>
#include <QGuiApplication>
#include "tools/mouse_event_filter.h"

#include "qmlapp.h"

#include <QDir>
#include <QStandardPaths>
#include "game/game.h"
#include "game/meowstyle.h"
#include "game/item_snapable/ItemSnapable.h"
#include "launcher/launcher_manager.h"
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/QQmlContext>

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
#include "tools/test_manager.h"

#ifdef MEOW_HAS_CANVAS_PAINTER
#include "editor/painter/zone_canvas_painter.h"
#include "editor/painter/zones_overlay_painter.h"
#include "editor/painter/grid_canvas_painter.h"
#endif

#include "game/physics/physics_world.h"
#include "game/physics/physics_session.h"
#include "game/physics/item_snapable_events.h"

#include "game/map/map.h"
#include "game/map/maptypes.h"
#include "game/map/editdelta.h"
#include "game/map/mapinfo.h"
#include "game/map/playerprofile.h"
#include "game/map/screeneffect.h"
#include "game/map/mapfilemanager.h"
#include "game/map/templatefilemanager.h"
#include "tools/mouse_event_filter.h"
#include "game/item_snapable/itemsnapablefactory.h"

//#include "animationprovider.h"
#include "tools/logger.h"
#include "tools/cursor_manager.h"
#include "chat/chat_client.h"
#include "chat/chat_slash_commands.h"
#include "chat/chat_session_manager.h"
#include "account/account_manager.h"
#include "communication/catway.h"
#include "communication/player_network.h"
#include "game/network/game_session.h"
#include "game/network/minigame_sync.h"
#include "editor/network/editor_session.h"
#include "editor/ops/editor_op_bus.h"
#include "game/modules/gameplay_module_manager.h"
#include "game/events/gameplay_event_bus.h"
#include "ai/ai_process_supervisor.h"

// ── Briques V3 (phases 0-3) exposées à QML ──────────────────────────────────
// Singletons livrés par les phases V3 mais jamais câblés à la scène. Tous
// suivent le patron sibling registerQml()/qmlInstance() (lazy singletons —
// aucune instance globale à créer, cf. GameplayEventBus/AiProcessSupervisor).
#include "game/memory/state_bus.h"
#include "game/memory/memory_store.h"
#include "game/rules/rules_engine.h"
#include "ai/network/proposal_session.h"
#include "ai/network/proposal_collab_bridge.h"
#include "ai/proposal/proposal_lifecycle.h"
#include "ai/proposal/proposal_gateway.h"
#include "ai/instrumentation/slice_instrumentation.h"
#include "ai/instrumentation/slice_scenarios.h"
#include "artifacts/artifact_registry.h"
#include "game/save/game_save.h"

#include <QImageWriter>

QmlApp::QmlApp(QWindow *parent) : QQmlApplicationEngine(parent)
{
    qDebug() << "Device supports OpenSSL: " << QSslSocket::supportsSsl();

    qApp->installEventFilter(MouseEventFilter::instance());
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
    TemplateFileManager::registerQml();
    MapInfo::registerQml();
    PlayerProfile::registerQml();
    ScreenEffect::registerQml();
    EditorEnum::registerQml();
    ItemSnapableFactory::registerQml();
    Logger::registerQml();
    CursorManager::registerQml();
    TestManager::registerQml();
    
    PhysicsWorld::registerQml();
    PhysicsSession::registerQml();
    ItemSnapableEvents::registerQml();
    ChatClient::registerQml(this);
    ChatSlashCommands::registerQml();
    ChatSessionManager::registerQml();
    AccountManager::registerQml();
    Catway::registerQml();
    PlayerNetwork::registerQml();
    GameSession::registerQml();
    MinigameSync::registerQml();
    EditorSession::registerQml();
    EditorOpBus::registerQml();
    GameplayModuleManager::registerQml();
    // Journal d'événements métier (M5, piste D). D4 : enregistrement formel du
    // singleton ici (l'auto-bootstrap Q_COREAPP_STARTUP_FUNCTION de D1 est
    // retiré). Les sources d'ingestion (Game / EditorOpBus / ItemSnapableEvents
    // / PhysicsSession) sont câblées une fois l'event loop lancée, quand ces
    // singletons existent — d'où le singleShot différé.
    GameplayEventBus::registerQml();
    QTimer::singleShot(0, []() {
        GameplayEventBus::instance()->connectSources();
    });
    // Superviseur des processus d'agents IA (M2, C5). Singleton QML : cycle de
    // vie des CLIs proposante/arbitre, aucun orphelin à la fermeture.
    AiProcessSupervisor::registerQml();

    // ── Briques V3 (phases 0-3) — câblage QML (étape 1 du harness de test) ───
    // Ces singletons sont livrés mais n'étaient encore enregistrés nulle part.
    // Même patron lazy que GameplayEventBus/AiProcessSupervisor : instanciés à
    // la première résolution QML, aucune instance globale (contextProperty) à
    // créer. Le câblage des sources/coutures inter-singletons (StateBus↔Catway,
    // ProposalCollabBridge.attach…) est fait par les briques elles-mêmes à leur
    // construction ; rien à différer ici.
    //
    // Modules exposés :
    //   MeowMemory 1.0   — StateBus, MemoryStore (+ MemoryScope uncreatable)
    //   ProposalSession 1.0 — ProposalSession
    //   MeowProposal 1.0 — ProposalLifecycle (+ Proposal), ProposalGateway,
    //                      ProposalCollabBridge
    //   MeowSlice 1.0    — SliceInstrumentation, SliceScenarioRunner
    StateBus::registerQml();               // MeowMemory 1.0 · StateBus
    MemoryStore::registerQml();            // MeowMemory 1.0 · MemoryStore
    RulesEngine::registerQml();            // MeowRules 1.0 · RulesEngine (T4-4)
    ProposalSession::registerQml();        // ProposalSession 1.0 · ProposalSession
    ProposalLifecycle::registerQml();      // MeowProposal 1.0 · ProposalLifecycle
    ProposalGateway::registerQml();        // MeowProposal 1.0 · ProposalGateway
    ProposalCollabBridge::registerQml();   // MeowProposal 1.0 · ProposalCollabBridge
    SliceInstrumentation::registerQml();   // MeowSlice 1.0 · SliceInstrumentation
    SliceScenarioRunner::registerQml();    // MeowSlice 1.0 · SliceScenarioRunner
    ArtifactRegistry::registerQml();       // MeowArtifacts 1.0 · ArtifactRegistry (T4-1)
    GameSave::registerQml();               // MeowSave 1.0 · GameSave (type instanciable, T4-2)


#ifdef MEOW_HAS_CANVAS_PAINTER
    // ZoneCanvasPainter : rendu GPU 2D d'une zone via QtCanvasPainter
    // (Qt 6.11+). Importable depuis QML via `import MeowPainter 1.0`.
    qmlRegisterType<ZoneCanvasPainter>("MeowPainter", 1, 0, "ZoneCanvasPainter");
    qmlRegisterType<ZonesOverlayPainter>("MeowPainter", 1, 0, "ZonesOverlayPainter");
    qmlRegisterType<GridCanvasPainter>("MeowPainter", 1, 0, "GridCanvasPainter");

    // Toggle Repeater (legacy) vs GridCanvasPainter pour la grille de l'éditeur.
    // Lu UNE fois ici, exposé en context property pour le QML. Bypass via
    // MEOW_GRID_RENDERER=repeater (ou =canvas pour forcer canvas explicitement).
    {
        const QByteArray raw = qgetenv("MEOW_GRID_RENDERER").toLower();
        bool useCanvas = true; // défaut : canvas (gain attendu sur burst zoom/pan)
        if (raw == "repeater") useCanvas = false;
        else if (raw == "canvas") useCanvas = true;
        rootContext()->setContextProperty(
            "_gridRendererUseCanvas", QVariant(useCanvas));
    }

    // Toggle overlay zones global (un seul canvas viewport-cullé, défaut)
    // vs canvas par tile (legacy). MEOW_ZONES_RENDERER=per-tile pour forcer
    // l'ancien mode. L'overlay résout les freezes GPU au zoom extrême.
    {
        const QByteArray raw = qgetenv("MEOW_ZONES_RENDERER").toLower();
        bool useOverlay = true;
        if (raw == "per-tile") useOverlay = false;
        else if (raw == "overlay") useOverlay = true;
        rootContext()->setContextProperty(
            "_useZonesOverlay", QVariant(useOverlay));
    }
#else
    // Pas de CanvasPainter dispo (Qt < 6.11) → forcer le mode Repeater
    // côté QML pour que GridManager.qml ne tente pas d'instancier un
    // GridCanvasPainter introuvable.
    rootContext()->setContextProperty(
        "_gridRendererUseCanvas", QVariant(false));
    rootContext()->setContextProperty(
        "_useZonesOverlay", QVariant(false));
#endif

    // Register MapTypes namespace for QML
    qmlRegisterUncreatableMetaObject(MapTypes::staticMetaObject, "MapTypes", 1, 0, "MapTypes", "Error: only enums");

    // Register EditDeltaType namespace for QML
    qmlRegisterUncreatableMetaObject(EditDeltaType::staticMetaObject, "EditDelta", 1, 0, "EditDelta", "Error: only enums");
    
    // Create and expose FolderCompressor instance to QML
    folderCompressor = new FolderCompressor(this);
    rootContext()->setContextProperty("folderCompressor", folderCompressor);
    
    // Initialize network manager
    networkManager = new QNetworkAccessManager(this);
    
    // Create and expose AssetManager instance to QML
    assetManager = AssetManager::instance();

    // Instance globale du moteur physique. Exposée via contextProperty
    // `pattounxWorld` accessible depuis tout QML (éditeur, CatwayTest, etc.)
    // et survivant aux navigations entre scènes — sinon le worker thread
    // serait recréé à chaque ouverture de tab et il faudrait re-poser zones
    // et bodies à chaque fois.
    //
    // Nom préfixé `pattounx` volontaire : éviter la collision de scope QML
    // dans des bindings comme `EditorPhysicsBridge { physicsWorld: pattounxWorld }`
    // où le LHS du binding masquerait un RHS homonyme (résolution circulaire
    // → undefined). Cf. mémoire feedback_qml_scope_resolution.
    physicsWorld = new PhysicsWorld(this);
    rootContext()->setContextProperty("pattounxWorld", physicsWorld);

    // PhysicsSession (singleton) a besoin du pointeur PhysicsWorld pour
    // piloter la simu locale et lire/écrire les snapshots.
    PhysicsSession::instance()->setPhysicsWorld(physicsWorld);

    //To declare module in QML

    //1) Create a qmldir file in the resource folder. The qmldir is wrote like this:
    //  module name_of_the_folder
    //  TypeName 1.0 TypeFileName.qml
    //  TypeName2 1.0 TypeFileName2.qml

    //2) Add the path of the parent's module/folder below with addImportPath()

    //3) In QML, import the module with <import name_of_the_folder>

    // ** In order to respect the current typo, folder/module has to be named with lowercase letters, and the file's name with uppercase letters **
    // ** the module-system of Qt IS case sensitive **

    addImportPath("qrc:/qml");  // Contains: ui_item, utils, world3d
    addImportPath("qrc:/qml/editor");  // Contains: editor qmldir
    addImportPath("qrc:/qml/editor/moduleManager");  // Contains: moduleManager (ModuleManager*), assetSelectionPanel, caseSelectionPanel, editorBottomPanel, zonePanel, templatePanel, playerPanel
    addImportPath("qrc:/qml/editor/moduleManager/caseSelectionPanel");  // Contains: caseSelectionPanelMain
    addImportPath("qrc:/qml/editor/moduleManager/assetSelectionPanel");  // Contains: playerConfigPanel, screenEffectPanel
    addImportPath("qrc:/qml/editor/panel");  // Contains: mapInfoPanel qmldir
    addImportPath("qrc:/qml/editor/panel/mapInfoPanel");  // Contains: mapInfoPanelMain
    addImportPath("qrc:/qml/editor/configPanel");  // Contains: caseConfigPanel, connectionConfigPanel, visualEffectPanel, zoneConfigPanel
    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();

    Logger* loggerInstance = Logger::instance();
    Catway* catwayInstance = Catway::instance();
    connect(catwayInstance, &Catway::log, loggerInstance, &Logger::log);

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
