#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "qmlapp.h"

int main(int argc, char *argv[])
{
    qInstallMessageHandler(0);
    QGuiApplication app(argc, argv);

    QmlApp a;

    return app.exec();
}
