#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSurfaceFormat>
#include <QLoggingCategory>
#include <QSettings>

#include "qmlapp.h"
#include "automation/automation_server.h"
#include "ai/gateway/ai_gateway_server.h"

#include <QQuickWindow>
#include <QSGRendererInterface>

int main(int argc, char *argv[])
{
    qInstallMessageHandler(0);
    QGuiApplication app(argc, argv);
    QLoggingCategory::setFilterRules(QStringLiteral("qt.qml.binding.removal.info=true"));

    app.setOrganizationName("Pattoune Corp");
    app.setOrganizationDomain("pattounecorp.ovh");

    // Support multi-instance : --instance N sépare les données (QSettings, DB, etc.)
    QString appName = "Meownopoly";
    const QStringList args = app.arguments();
    int instanceIdx = args.indexOf("--instance");
    if (instanceIdx != -1 && instanceIdx + 1 < args.size()) {
        QString instanceId = args.at(instanceIdx + 1);
        if (instanceId != "1") {
            appName = QString("Meownopoly_%1").arg(instanceId);
            app.setApplicationDisplayName(QString("Meownopoly (Instance %1)").arg(instanceId));
        }
    }
    app.setApplicationName(appName);

    // Configure surface format to reduce flickering during resize
    /*
    QSurfaceFormat format;
    format.setSwapInterval(0);  // Disable VSync to prevent resize flickering
    format.setRenderableType(QSurfaceFormat::OpenGL);
    QSurfaceFormat::setDefaultFormat(format);
    */

    QQuickWindow w;
    const auto api = w.rendererInterface()->graphicsApi();

    QString apiName = "Unknown";
    switch (api) {
    case QSGRendererInterface::OpenGL: apiName = "OpenGL"; break;
    case QSGRendererInterface::Vulkan: apiName = "Vulkan"; break;
    case QSGRendererInterface::Direct3D11: apiName = "D3D11"; break;
    case QSGRendererInterface::Direct3D12: apiName = "D3D12"; break;
    case QSGRendererInterface::Metal: apiName = "Metal"; break;
    case QSGRendererInterface::Null: apiName = "Null"; break;
    default: break;
    }

    qDebug() << "Qt Quick backend =" << apiName;

    QmlApp a;
    qInstallMessageHandler(0);

    // Serveur d'automation/test embarqué (opt-in). Instancié uniquement si
    // --automation-port <N> ou MEOW_AUTOMATION_PORT est fourni. Écoute sur
    // 127.0.0.1 strictement. Convention de port pour le dual-instance :
    // 7700 (instance 1) / 7701 (instance 2). Cf. doc/architecture/AUTOMATION_API.md.
    // Créé après QmlApp (l'engine a chargé main.qml → la QQuickWindow existe).
    AutomationServer *automation = AutomationServer::maybeCreate(app.arguments(), &app);
    Q_UNUSED(automation);

    // Passerelle MCP du canal IA (D2/D20/D21) — surface distincte et durcie,
    // sans rapport avec l'automation ci-dessus. TOUJOURS active par défaut
    // (MEOW_AI_GATEWAY_ALWAYS_ON, port 7790 + instance-1) ; port explicite via
    // --ai-gateway-port <N> ou MEOW_AI_GATEWAY_PORT (0 = opt-out). Écoute sur
    // 127.0.0.1 strictement. Inerte tant que l'add-on QtHttpServer n'est pas
    // installé (P0-1). Cf. cpp/ai/gateway/.
    AiGatewayServer *aiGateway = AiGatewayServer::maybeCreate(app.arguments(), &app);
    Q_UNUSED(aiGateway);

    return app.exec();
}
