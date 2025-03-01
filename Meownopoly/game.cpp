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

void Game::createPlayer(const QString &name) {
    Player* newPlayer = new Player(name, this);
    m_players.append(newPlayer);
    qDebug() << "Player created: " << name;
}

int Game::boardSize() const {
    return m_board.size();
}

Case* Game::getCaseAt(int position) {
    if (position >= 0 && position < m_board.size()) {
        return m_board.at(position);
    }
    return nullptr;
}
