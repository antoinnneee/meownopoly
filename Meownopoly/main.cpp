#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSurfaceFormat>
#include "qmlapp.h"
#include <QLoggingCategory>

int main(int argc, char *argv[])
{
    qInstallMessageHandler(0);
    QGuiApplication app(argc, argv);
    QLoggingCategory::setFilterRules(QStringLiteral("qt.qml.binding.removal.info=true"));

    app.setOrganizationName("Pattoune Corp");
    app.setOrganizationDomain("pattounecorp.ovh");
    app.setApplicationName("Meownopoly");
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
