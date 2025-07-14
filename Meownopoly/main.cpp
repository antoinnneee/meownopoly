#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "qmlapp.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QmlApp a;
    qInstallMessageHandler(0);

    return app.exec();
}
