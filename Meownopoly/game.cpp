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

QJsonArray Game::formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray)
{
    QJsonParseError parseError;
    QString ISjsonDoc = is.toJSON();
    QJsonDocument tileDoc = QJsonDocument::fromJson(ISjsonDoc.toUtf8(), &parseError);
    if (parseError.error == QJsonParseError::NoError && tileDoc.isObject()) {
        snapableTilesArray.append(tileDoc.object());
    } else {
        qDebug().noquote() << "Error parsing ItemSnapable JSON:" << parseError.errorString()<< "\n" << ISjsonDoc;
    }
    return snapableTilesArray;
}

bool Game::addTileToJson(QJsonObject jsonObject, QString mapName)
{

    QJsonDocument jsonDoc(jsonObject);
    QByteArray jsonData = jsonDoc.toJson(QJsonDocument::Indented);

    // Sauvegarder le fichier JSON
    QString fileName = mapName.toLower().replace(" ", "_") + "_map.json";
    QFile file(fileName);

    if (!file.open(QIODevice::WriteOnly)) {
        qDebug() << "Failed to open file for writing:" << fileName;
        return false;
    }

    qint64 bytesWritten = file.write(jsonData);
    file.close();

    if (bytesWritten == -1) {
        qDebug() << "Failed to write to file:" << fileName;
        return false;
    }

    qDebug() << "Map saved successfully to:" << fileName;
    qDebug().noquote() << QString::fromUtf8(jsonData);
    return true;
}

DisplayParameter *Game::getDisplayerParameter(const QVariantMap &displayInfoMap) {
    int unit_s_w = displayInfoMap["unitSizeWidth"].toInt();
    int unit_s_h = displayInfoMap["unitSizeHeight"].toInt();
    int gr_p_x = displayInfoMap["gridRelativePositionX"].toInt();
    int gr_p_y = displayInfoMap["gridRelativePositionY"].toInt();
    int zLayer = displayInfoMap["zLayer"].toInt();
    DisplayParameter *dp = new DisplayParameter(unit_s_w, unit_s_h, gr_p_x, gr_p_y, zLayer);
    return dp;
}

bool Game::registerMap(QVariantMap mapInfo, QVariantList caseList, QVariantList decorationList)
{
    QJsonArray snapableTilesArray;

    // Ajouter les informations de la map
    QJsonObject jsonObject;
    
    // Extraire le nom de la map du QVariantMap
    QString mapName = "mapName"; // valeur par défaut
    if (mapInfo.contains("name")) {
        mapName = mapInfo["name"].toString();
    }

    jsonObject["name"] = mapName;
    jsonObject["version"] = "version X";
    jsonObject["description"] = "description X";


    for (int i = 0; i < caseList.size(); ++i) {
        QVariantList caseInfo = caseList.at(i).toList();
        if (caseInfo.size() >= 2) {
            // Extraction de caseData
            QVariant caseData = caseInfo.at(0);
            Case* currentCase = qvariant_cast<Case*>(caseData);

            // Extraction de displayInfo
            QVariantMap displayInfoMap = caseInfo.at(1).toMap();
            DisplayParameter* dp = getDisplayerParameter(displayInfoMap);

            ItemSnapable is(currentCase, dp);
            snapableTilesArray = formatTileDataToJson(is, snapableTilesArray);
        }
    }
    
    jsonObject["snapableTiles"] = snapableTilesArray;
    addTileToJson(jsonObject, mapName);
    return true;
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



bool Game::saveCaseToJson(const QVariantMap &caseData) {
    const QString TEST_CASES_FILE_PATH = "config/test_cases.json";

    // Read existing JSON file
    QFile file(TEST_CASES_FILE_PATH);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Failed to open test_cases.json file for reading";
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qDebug() << "JSON parse error:" << parseError.errorString();
        return false;
    }

    if (!doc.isArray()) {
        qDebug() << "Invalid JSON format – expected array";
        return false;
    }

    // Get the array and add new case
    QJsonArray casesArray = doc.array();

    // Convert QVariantMap to QJsonObject
    QJsonObject newCase;
    for (auto it = caseData.begin(); it != caseData.end(); ++it) {
        if (it.value().isNull()) {
            newCase[it.key()] = QJsonValue();
        } else {
            newCase[it.key()] = QJsonValue::fromVariant(it.value());
        }
    }

    // Add the new case to the array
    casesArray.append(newCase);

    // Create new document with updated array
    QJsonDocument newDoc(casesArray);

    // Write back to file
    if (!file.open(QIODevice::WriteOnly)) {
        qDebug() << "Failed to open test_cases.json file for writing";
        return false;
    }

    QByteArray jsonData = newDoc.toJson(QJsonDocument::Indented);
    qint64 bytesWritten = file.write(jsonData);
    file.close();

    if (bytesWritten == -1) {
        qDebug() << "Failed to write to test_cases.json file";
        return false;
    }

    qDebug() << "Successfully saved new case to test_cases.json";
    return true;
}

bool Game::saveMultipleCasesToJson(const QVariantList &casesData) {
    const QString TEST_CASES_FILE_PATH = "config/test_cases.json";

    // Read existing JSON file
    QFile file(TEST_CASES_FILE_PATH);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Failed to open test_cases.json file for reading";
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qDebug() << "JSON parse error:" << parseError.errorString();
        return false;
    }

    if (!doc.isArray()) {
        qDebug() << "Invalid JSON format – expected array";
        return false;
    }

    // Get the array and add new cases
    QJsonArray casesArray = doc.array();

    // Convert each QVariantMap to QJsonObject and add to array
    for (const QVariant &caseVariant : casesData) {
        if (caseVariant.canConvert<QVariantMap>()) {
            QVariantMap caseMap = caseVariant.toMap();
            QJsonObject newCase;

            for (auto it = caseMap.begin(); it != caseMap.end(); ++it) {
                if (it.value().isNull()) {
                    newCase[it.key()] = QJsonValue();
                } else {
                    newCase[it.key()] = QJsonValue::fromVariant(it.value());
                }
            }
            casesArray.append(newCase);
        }
    }

    // Create new document with updated array
    QJsonDocument newDoc(casesArray);

    // Write back to file
    if (!file.open(QIODevice::WriteOnly)) {
        qDebug() << "Failed to open test_cases.json file for writing";
        return false;
    }

    QByteArray jsonData = newDoc.toJson(QJsonDocument::Indented);
    qint64 bytesWritten = file.write(jsonData);
    file.close();

    if (bytesWritten == -1) {
        qDebug() << "Failed to write to test_cases.json file";
        return false;
    }

    qDebug() << "Successfully saved" << casesData.size() << "cases to test_cases.json";
    return true;
}

int Game::assetNumber() const
{
    return m_assetNumber;
}

void Game::setAssetNumber(int newAssetNumber)
{
    if (m_assetNumber == newAssetNumber)
        return;
    m_assetNumber = newAssetNumber;
    emit assetNumberChanged();
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
