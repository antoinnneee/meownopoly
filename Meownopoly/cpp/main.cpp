#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSurfaceFormat>
#include <QLoggingCategory>
#include <QSettings>

#include "qmlapp.h"

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

    QmlApp a;
    qInstallMessageHandler(0);

    return app.exec();
}
