#include <QColor>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>


#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QVariant>

#include "item_snapable/ItemSnapable.h"
#include "game.h"
#include "case/Case.h"
#include "case/CaseFactory.h"

Game *Game::m_pThis = nullptr;

Game::Game(QObject *parent) : QObject(parent) {
}

Game::~Game()
{

}

void Game::registerQml() {
    qmlRegisterSingletonType<Game>("Game", 1, 0, "Game", &Game::qmlInstance);
    qmlRegisterType<Player>("Player", 1, 0, "Player"); // Register Player class
    CaseFactory::registerCaseQml();
}

Game *Game::instance() {
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new Game;
    }
    return m_pThis;
}

QObject *Game::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine) {
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return Game::instance();
}

void Game::startGame() {
    emit gameStarted();
}


