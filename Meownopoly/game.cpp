#include "game.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QColor>

Game *Game::m_pThis = nullptr;

Game::Game(QObject *parent)
    : QObject(parent)
{}

void Game::registerQml()
{
    qmlRegisterSingletonType<Game>("Game", 1, 0, "Game", &Game::qmlInstance);
    qmlRegisterType<Player>("Game", 1, 0, "Player");  // Register Player class
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
    qDebug() << "HelloWorld";
}

void Game::createPlayer(const QString &name) {
    Player* newPlayer = new Player(this);  // Create with parent first
    newPlayer->setName(name);
    newPlayer->setColor(QColor("#7f8c8d"));  // Default gray color
    newPlayer->setKibble(1500);  // Starting money
    m_players.append(newPlayer);
    emit playersChanged();
    qDebug() << "Player created: " << name;
}

Case* Game::getCaseAt(int position) {
    if (position >= 0 && position < m_board.size()) {
        return m_board.at(position);
    }
    return nullptr;
}

void Game::setupPlayers(const QVariantList &playerData)
{
    // Clear existing players
    while (!m_players.isEmpty()) {
        delete m_players.takeLast();
    }

    // Create new players from the setup data
    for (const QVariant &data : playerData) {
        QVariantMap playerInfo = data.toMap();
        QString name = playerInfo["name"].toString();
        QColor color = QColor(playerInfo["color"].toString());
        
        Player* player = new Player(this);
        player->setName(name);
        player->setColor(color);
        player->setKibble(1500);  // Starting money
        player->setPosition(0);   // Start at position 0 (GO)
        m_players.append(player);
    }

    emit playersChanged();
}

void Game::startGame()
{
    qDebug() << "Starting game...";

    init_caseFile();

    // If no players were set up, create a default player
    if (m_players.isEmpty())
    {
        createPlayer("Player1");
    }

    // Set all players at the starting position
    for (Player* player : m_players) {
        player->setPosition(0);  // Start at position 0 (GO)
    }

    m_currentPlayerIndex = 0;
    emit currentPlayerIndexChanged();
    emit playersChanged();
    emit gameStarted();
}

void Game::movePlayer(int playerIndex, int steps)
{
    if (playerIndex >= 0 && playerIndex < m_players.size()) {
        Player* player = m_players[playerIndex];
        int newPosition = (player->position() + steps) % m_board.size();
        player->setPosition(newPosition, steps);
        
        qDebug() << "Player" << player->name() << "moved to position" << newPosition;
        
        // Check if player passed GO
        if (player->position() < steps) {
            // Player passed GO, give them money
            player->setKibble(player->kibble() + 200);
            qDebug() << "Player" << player->name() << "passed GO, received 200K";
        }
        
        emit playersChanged();
    }
}

int Game::currentPlayerIndex() const
{
    return m_currentPlayerIndex;
}

void Game::nextPlayer()
{
    m_currentPlayerIndex = (m_currentPlayerIndex + 1) % m_players.size();
    emit currentPlayerIndexChanged();
}

bool Game::buyProperty(int playerIndex, int position)
{
    // Check if player index is valid
    if (playerIndex < 0 || playerIndex >= m_players.size())
        return false;
        
    // Get the player
    Player* player = m_players[playerIndex];
    
    // Check if position is valid
    if (position < 0 || position >= m_board.size())
        return false;
        
    // Get the case at the position
    Case* boardCase = m_board[position];
    
    // Check if the case is a buyable property type
    bool isBuyableProperty = (boardCase->getType() == 1 || boardCase->getType() == 2);
    if (!isBuyableProperty) {
        qDebug() << "Not a buyable property type:" << boardCase->getType();
        return false;
    }
    
    // Check if it's already owned
    if (((CaseRestArea*)boardCase)->owner()) {
        qDebug() << "Property already owned";
        return false;
    }
    
    // Get property price
    int price = 0;
    if (boardCase->getType() == 1) {
        // RestArea
        CaseRestArea* restArea = qobject_cast<CaseRestArea*>(boardCase);
        if (!restArea) return false;
        price = restArea->get_price();
    } else if (boardCase->getType() == 2) {
        // CardBoardBox
        price =( (CaseRestArea*)boardCase)->get_price();
    }
    
    // Check if player has enough money
    if (player->kibble() < price) {
        qDebug() << "Player doesn't have enough money";
        return false;
    }
    
    // Deduct money from player
    player->setKibble(player->kibble() - price);
    
    // Set the owner of the property
    ((CaseRestArea*)boardCase)->setOwner(player);
    
    // If it's a RestArea, add it to the player's properties
    if (boardCase->getType() == 1) {
        CaseRestArea* restArea = qobject_cast<CaseRestArea*>(boardCase);
        player->addProperty(restArea);
    }
    
    // Emit signals to update UI
    emit playersChanged();
    emit propertyPurchased(position, player);
    
    qDebug() << "Property purchased successfully:" << boardCase->name() << "by" << player->name();
    return true;
}

