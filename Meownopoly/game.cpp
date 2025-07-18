#include "game.h"

#include <QColor>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include "case/CaseRestArea.h"

Game *Game::m_pThis = nullptr;

Game::Game(QObject *parent) : QObject(parent) {}

void Game::registerQml() {
    qmlRegisterSingletonType<Game>("Game", 1, 0, "Game", &Game::qmlInstance);
    qmlRegisterType<Player>("Player", 1, 0, "Player"); // Register Player class
    
    // Register the complete inheritance hierarchy for proper QML inheritance
    qmlRegisterUncreatableType<Case>("Case", 1, 0, "Case", 
                                     "Case is an abstract base class"); // Register Case class with enum
    qmlRegisterUncreatableType<CaseCatPerks>("CaseCatPerks", 1, 0, "CaseCatPerks", 
                                            "CaseCatPerks is an intermediate base class"); // Register intermediate class
    qmlRegisterType<CaseRestArea>("CaseRestArea", 1, 0,
                                  "CaseRestArea"); // Register CaseRestArea class
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

void Game::initPlayers(int nbr) {}

void Game::initCases() {}

void Game::initCards() {}


Case *Game::getCaseAt(int position) {
    if (position >= 0 && position < m_board.size()) {
        return m_board.at(position);
    }
    return nullptr;
}

Player* Game::createPlayer(const QString name, QColor color, int indexLogo, int kibbles) {
    Player *newPlayer = new Player(name, color, indexLogo, kibbles, this); // Create with parent first
    qDebug() << "Player created: " << name;
    emit playersChanged();
    return newPlayer;
}


void Game::setupPlayers(const QVariantList &playerData)
{
    m_listPlayers.clear();
    for (const QVariant &data : playerData) {
        QVariantMap playerInfo = data.toMap();
        Player *player(createPlayer(playerInfo["name"].toString(), playerInfo["color"].toString(), playerInfo["indexLogo"].toInt(), playerInfo["kibbles"].toInt()));
        m_listPlayers.append(player);
    }
}

void Game::startGame() {
    qDebug() << "Starting game...";

    init_caseFile();

    // Set all players at the starting position
    for (Player *player : m_listPlayers) {
        player->setPosition(0); // Start at position 0 (GO)
    }

    m_currentPlayerIndex = 0;
    emit currentPlayerIndexChanged();
    emit playersChanged();
    emit gameStarted();
}

int Game::currentPlayerIndex() const { return m_currentPlayerIndex; }

Case *Game::getNewCaseType(Case::CaseType type)
{
    qDebug() << "get case type : " << type;
    switch (type) {
    case Case::CS_RestArea:
    {
        CaseRestArea *caseReq = new CaseRestArea("test restArea");
        return caseReq;
    }
    default:
        return NULL;
    }
}

void Game::nextPlayer() {

    m_currentPlayerIndex = (m_currentPlayerIndex + 1) % m_listPlayers.size();
    emit currentPlayerIndexChanged();
}
