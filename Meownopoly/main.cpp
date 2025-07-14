#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "qmlapp.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
//    qInstallMessageHandler(0);

    QmlApp a;

    return app.exec();
}
