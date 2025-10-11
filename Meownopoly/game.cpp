#include <QColor>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

// Include all case types
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
#include <QVariant>

#include "item_snapable/ItemSnapable.h"
#include "game.h"

Game *Game::m_pThis = nullptr;

Game::Game(QObject *parent) : QObject(parent) {
    init();
}

Game::~Game()
{

}

QList<Card *> Game::listCards() const
{
    return m_listCards;
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
    qmlRegisterType<CaseKibbleDispenser>("CaseKibbleDispenser", 1, 0,
                                         "CaseKibbleDispenser"); // Register CaseKibbleDispenser class
    qmlRegisterType<CaseCardBoardBox>("CaseCardBoardBox", 1, 0,
                                      "CaseCardBoardBox"); // Register CaseCardBoardBox class
    qmlRegisterType<CaseCatNip>("CaseCatNip", 1, 0,
                                "CaseCatNip"); // Register CaseCatNip class
    qmlRegisterType<CaseJail>("CaseJail", 1, 0,
                              "CaseJail"); // Register CaseJail class
    qmlRegisterType<CaseToJail>("CaseToJail", 1, 0,
                                "CaseToJail"); // Register CaseToJail class
    qmlRegisterType<CaseCatDoor>("CaseCatDoor", 1, 0,
                                 "CaseCatDoor"); // Register CaseCatDoor class
    qmlRegisterType<CaseFreeNap>("CaseFreeNap", 1, 0,
                                 "CaseFreeNap"); // Register CaseFreeNap class
    qmlRegisterType<CaseCatDevice>("CaseCatDevice", 1, 0,
                                   "CaseCatDevice"); // Register CaseCatDevice class
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

void Game::init() {
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
    Case* newCase = nullptr;

    switch (type) {
    case Case::CS_RestArea:
    {
        newCase = new CaseRestArea("test restArea");
        QList<int> rentList;
        rentList.append(50);
        rentList.append(100);
        rentList.append(200);
        rentList.append(300);
        rentList.append(400);
        rentList.append(5000);
        ((CaseRestArea*)newCase)->setRentPrice(rentList);
        break;
    }
    case Case::CS_KibbleDispenser:
        newCase = new CaseKibbleDispenser("test KibbleDispenser", QUuid::createUuid(), 200);
        break;
    case Case::CS_CardBoardBox:
        newCase = new CaseCardBoardBox("test CardBoardBox", QUuid::createUuid());
        break;
    case Case::CS_CatNip:
        newCase = new CaseCatNip("test CatNip", QUuid::createUuid());
        break;
    case Case::CS_Jail:
        newCase = new CaseJail("test Jail", QUuid::createUuid());
        break;
    case Case::CS_ToJail:
        newCase = new CaseToJail("test ToJail", QUuid::createUuid());
        break;
    case Case::CS_CatDoor:
        newCase = new CaseCatDoor("test CatDoor", QUuid::createUuid());
        break;
    case Case::CS_FreeNap:
        newCase = new CaseFreeNap("test FreeNap", QUuid::createUuid());
        break;
    case Case::CS_Device:
        newCase = new CaseCatDevice("test CatDevice", QUuid::createUuid());
        break;
    case Case::CS_Taxe:
        newCase = new CaseKibbleDispenser("TAXE NOT IMPLEMENTED", QUuid::createUuid());
        break;
    default:
        qDebug() << "Unknown case type:" << type << "returning NULL";
        break;
    }

    return newCase;
}

Player *Game::getNewPlayer()
{
    // Créer un joueur avec des valeurs par défaut
    static int playerCount = 0;
    QString playerName = "Joueur " + QString::number(++playerCount);

    // Générer une couleur semi-aléatoire basée sur le playerCount
    QColor playerColor;
    switch (playerCount % 6) {
        case 0: playerColor = QColor("#e74c3c"); break; // Rouge
        case 1: playerColor = QColor("#3498db"); break; // Bleu
        case 2: playerColor = QColor("#2ecc71"); break; // Vert
        case 3: playerColor = QColor("#f39c12"); break; // Orange
        case 4: playerColor = QColor("#9b59b6"); break; // Violet
        case 5: playerColor = QColor("#1abc9c"); break; // Turquoise
    }

    int indexLogo = (playerCount - 1) % 6;  // Les avatars vont de 1 à 6
    int startingKibbles = 1500;

    Player* newPlayer = new Player(playerName, playerColor, indexLogo, startingKibbles);
    return newPlayer;
}

void Game::nextPlayer() {

    m_currentPlayerIndex = (m_currentPlayerIndex + 1) % m_listPlayers.size();
    emit currentPlayerIndexChanged();
}

Player *Game::getPlayer()
{
    return m_players;
}



QVariantList Game::assetPath() const
{
    return m_assetPath;
}

QVariant Game::getAssetPath(int index) const
{
    QString path = m_assetPath.value(index).toString();

    if (index <= m_assetPath.size() && !path.isEmpty()) {
        return QUrl::fromLocalFile(path).toString();
    }
    else
        return "";
}


void Game::setAssetPath(const QVariantList &newAssetPath)
{
    if (m_assetPath == newAssetPath)
        return;
    m_assetPath = newAssetPath;
    emit assetPathChanged();
}

QList<Case*> Game::getPurchasableCases() const
{
    QList<Case*> purchasableCases;
    
    // Traverse all cases to find purchasable ones (with price > 0)
    for (Case* caseObj : m_board) {
        // Check if it's a purchasable type
        CaseCatPerks* catPerks = qobject_cast<CaseCatPerks*>(caseObj);
        if (catPerks && catPerks->price() > 0) {
            purchasableCases.append(caseObj);
        }
    }
    
    return purchasableCases;
}

QList<Case*> Game::getTemporaryCases() const
{
    QList<Case*> temporaryCases;
    
    // Traverse all cases to find non-purchasable ones
    for (Case* caseObj : m_board) {
        // Check if it's not a purchasable type or has no price
        CaseCatPerks* catPerks = qobject_cast<CaseCatPerks*>(caseObj);
        if (!catPerks || catPerks->price() <= 0) {
            temporaryCases.append(caseObj);
        }
    }
    
    return temporaryCases;
}

Case* Game::getCaseById(const QString &uniqueId) const
{
    // Find a case by its unique ID
    for (Case* caseObj : m_board) {
        if (caseObj->uniqueId().toString() == uniqueId) {
            return caseObj;
        }
    }
    
    return nullptr;
}