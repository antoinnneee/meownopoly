#include "game.h"

#include <QColor>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

// Include all case types
#include "case/CaseStart.h"
#include "case/CaseRestArea.h"
#include "case/CaseCardBoardBox.h"
#include "case/CaseCatNip.h"
#include "case/CaseJail.h"
#include "case/CaseToJail.h"
#include "case/CaseCatDoor.h"
#include "case/CaseFreeNap.h"
#include "case/CaseCatDevice.h"
#include "case/CaseKibbleDispenser.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

Game *Game::m_pThis = nullptr;

Game::Game(QObject *parent) : QObject(parent) {

    m_players = new Player();
    init();
}

QList<Card *> Game::listCards() const
{
    return m_listCards;
}

QList<Case *> Game::listCases() const
{
    return m_listCases;
}

QList<Player *> Game::listPlayers() const
{
    return m_listPlayers;
}

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

Case *Game::getCase(const QStringList &currentCaseJson) {
    qDebug() << "getCase called with data:" << currentCaseJson;
    
    if (currentCaseJson.size() < 3) {
        qDebug() << "Invalid case data - not enough fields";
        return nullptr;
    }

    int type = currentCaseJson[0].toInt();
    QString name = currentCaseJson[1];
    int position = currentCaseJson[2].toInt();
    
    qDebug() << "Creating case - Type:" << type << "Name:" << name << "Position:" << position;

    Case* newCase = nullptr;

    switch (type) {
    case 0: // Start (Départ)
    {
        newCase = new CaseKibbleDispenser(name, position, 200, this);
        break;
    }
    case 1: // Property (RestArea)
    {
        int price = currentCaseJson[3].isEmpty() ? 0 : currentCaseJson[3].toInt();
        int mortgagePrice = currentCaseJson[4].isEmpty() ? 0 : currentCaseJson[4].toInt();
        int family = currentCaseJson[5].isEmpty() ? 0 : currentCaseJson[5].toInt();
        int housePrice = currentCaseJson[11].isEmpty() ? 0 : currentCaseJson[11].toInt();
        int hotelPrice = currentCaseJson[12].isEmpty() ? 0 : currentCaseJson[12].toInt();

        // Build rent prices list
        QList<int> rentPrices;
        for (int i = 6; i <= 10; i++) {
            rentPrices << (currentCaseJson[i].isEmpty() ? 0 : currentCaseJson[i].toInt());
        }

        newCase = new CaseRestArea(name, position, mortgagePrice, price, price, this,
                                   static_cast<FamilyType>(family), housePrice, hotelPrice, rentPrices);
        break;
    }
    case 2: // Community Chest (Caisse de Communauté)
    {
        newCase = new CaseCardBoardBox(name, position, this);
        break;
    }
    case 3: // Chance
    {
        newCase = new CaseCatNip(name, position, this);
        break;
    }
    case 4: // Jail (Prison)
    {
        newCase = new CaseJail(name, position, 50); // Default fine of 50
        break;
    }
    case 5: // Go to Jail (Allez en Prison)
    {
        newCase = new CaseToJail(name, position, this);
        break;
    }
    case 6: // Railroad (Gare)
    {
        int price = currentCaseJson[3].isEmpty() ? 0 : currentCaseJson[3].toInt();
        int mortgagePrice = currentCaseJson[4].isEmpty() ? 0 : currentCaseJson[4].toInt();
        newCase = new CaseCatDoor(name, position, mortgagePrice, price, price, this);
        break;
    }
    case 7: // Free Parking (Parc Gratuit)
    {
        newCase = new CaseFreeNap(name, position, this);
        break;
    }
    case 8: // Utility (Compagnie)
    {
        int price = currentCaseJson[3].isEmpty() ? 0 : currentCaseJson[3].toInt();
        int mortgagePrice = currentCaseJson[4].isEmpty() ? 0 : currentCaseJson[4].toInt();
        newCase = new CaseCatDevice(name, position, mortgagePrice, price, price, this, 0);
        break;
    }
    case 9: // Tax (Taxe)
    {
        int taxAmount = currentCaseJson[13].isEmpty() ? 0 : currentCaseJson[13].toInt();
        newCase = new CaseKibbleDispenser(name, position, -taxAmount, this);
        break;
    }
    default:
        qDebug() << "Unknown case type:" << type << "- returning nullptr";
        return nullptr;
    }
    
    if (newCase) {
        qDebug() << "getCase created:" << newCase->name() << "Type:" << newCase->getType() << "Position:" << newCase->position();
    } else {
        qDebug() << "getCase failed to create case";
    }

    return newCase;
}

void Game::initCases() {
    // Clear existing cases
    m_listCases.clear();
    
    // Load JSON file
    QFile file(CASE_FILE_PATH);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Failed to open cases.json file";
        return;
    }
    
    QByteArray data = file.readAll();

    qDebug() << "Last bytes:" << data.right(10).toHex();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qDebug() << "JSON parse error:" << parseError.errorString();
        return;
    }
    if (!doc.isArray()) {
        qDebug() << "Invalid JSON format – expected array, got"
                 << (doc.isObject() ? "object" : "unknown");
        return;
    }
    QJsonArray casesArray = doc.array();
    qDebug() << "Processing" << casesArray.size() << "cases from JSON";

    // Process each case in the JSON array
    int caseIndex = 0;
    for (const QJsonValue &value : casesArray) {
        if (value.isObject()) {
            QJsonObject caseObj = value.toObject();
            
            qDebug() << "Processing case" << caseIndex << ":" << caseObj["name"].toString() 
                     << "Type:" << caseObj["type"].toInt() 
                     << "Position:" << caseObj["position"].toInt();
            
            // Convert JSON object to QStringList for getCase function
            QStringList caseData;
            caseData << QString::number(caseObj["type"].toInt());
            caseData << caseObj["name"].toString();
            caseData << QString::number(caseObj["position"].toInt());
            caseData << (caseObj["price"].isNull() ? "" : QString::number(caseObj["price"].toInt()));
            caseData << (caseObj["mortgagePrice"].isNull() ? "" : QString::number(caseObj["mortgagePrice"].toInt()));

            caseData << (caseObj["familly"].isNull() ? "" : QString::number(caseObj["familly"].toInt()));
            caseData << (caseObj["rent_0"].isNull() ? "" : QString::number(caseObj["rent_0"].toInt()));
            caseData << (caseObj["rent_1"].isNull() ? "" : QString::number(caseObj["rent_1"].toInt()));
            caseData << (caseObj["rent_2"].isNull() ? "" : QString::number(caseObj["rent_2"].toInt()));
            caseData << (caseObj["rent_3"].isNull() ? "" : QString::number(caseObj["rent_3"].toInt()));
            caseData << (caseObj["rent_4"].isNull() ? "" : QString::number(caseObj["rent_4"].toInt()));
            caseData << (caseObj["housePrice"].isNull() ? "" : QString::number(caseObj["housePrice"].toInt()));
            caseData << (caseObj["hotelPrice"].isNull() ? "" : QString::number(caseObj["hotelPrice"].toInt()));
            caseData << (caseObj["taxe"].isNull() ? "" : QString::number(caseObj["taxe"].toInt()));
            
            qDebug() << "CaseData for case" << caseIndex << ":" << caseData;
            
            // Create case and add to list
            Case* newCase = getCase(caseData);
            if (newCase) {
                m_listCases.append(newCase);
                qDebug() << "Successfully created case" << caseIndex << ":" << newCase->name() 
                         << "Type:" << newCase->getType() 
                         << "Position:" << newCase->position();
            } else {
                qDebug() << "Failed to create case" << caseIndex;
            }
        }
        caseIndex++;
    }
    
    qDebug() << "Successfully loaded" << m_listCases.size() << "cases from JSON";
}


void Game::init() {
    qDebug() << "Initializing game...";
    initCases();
}

void Game::initCards() {
}


Case *Game::getCaseAt(int position) {
    if (position >= 0 && position < m_listCases.size()) {
        return m_listCases.at(position);
    }
    return nullptr;
}

Player* Game::createPlayer(const QString name, QColor color, int indexLogo, int kibbles) {
    Player *newPlayer = new Player(name, color, indexLogo, kibbles, this); // Create with parent first
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
    qDebug() << "List of players " << m_listPlayers;
}

void Game::startGame() {
    qDebug() << "Starting game...";

    initCases();

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

void Game::nextPlayer() {

    m_currentPlayerIndex = (m_currentPlayerIndex + 1) % m_listPlayers.size();
    emit currentPlayerIndexChanged();
}

Player *Game::getPlayer()
{
    return m_players;
}
