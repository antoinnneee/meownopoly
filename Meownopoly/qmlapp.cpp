#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml/QQmlContext>

#include "qmlapp.h"

#include <QDir>
#include <QStandardPaths>
#include "game.h"

#ifdef Q_OS_ANDROID
#include <QJniObject.h>
#endif

QmlApp::QmlApp(QWindow *parent)
    : QQmlApplicationEngine(parent)
{
    QQuickStyle::setStyle("Material");
    Game::registerQml();
    load(QUrl("qrc:/qml/main.qml"));
    game = Game::instance();
    game->init();
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
