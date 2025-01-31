#include "game.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>

Game *Game::m_pThis = nullptr;

Game::Game(QObject *parent)
    : QObject(parent)
{}

void Game::registerQml()
{
    qmlRegisterSingletonType<Game>("Game", 1, 0, "Game", &Game::qmlInstance);
}

Game *Game::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new Game;
    }
    return m_pThis;
}

QObject *Game::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return Game::instance();
}

void Game::debugButton()
{
    qDebug()<<"HelloWorld";

}
