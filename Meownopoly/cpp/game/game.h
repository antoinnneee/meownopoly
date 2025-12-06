#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include <QVector>
#include <QList>
#include <QVariant>
#include <QDir>
#include "game/case/Case.h"
#include "game/case/CaseRestArea.h"

#include "card.h"
#include "game/player.h"
#include "game/item_snapable/ItemSnapable.h"
#include "map/mapinfo.h"
#include "map/map.h"
#include "map/maptypes.h"
#include "map/undoredomanager.h"


class Game : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int boardSize READ boardSize CONSTANT)
    Q_PROPERTY(int currentPlayerIndex READ currentPlayerIndex NOTIFY currentPlayerIndexChanged)

    Q_PROPERTY(QList<Player*> players READ players NOTIFY playersChanged)
    Q_PROPERTY(QList<Player *> listPlayers READ listPlayers CONSTANT FINAL)
    Q_PROPERTY(QList<Card *> listCards READ listCards CONSTANT FINAL)

    Q_PROPERTY(QVariantList assetPath READ assetPath WRITE setAssetPath NOTIFY assetPathChanged FINAL)

public:

    enum GAME_CONDITION {
        ABANDON,
        BANKRUPT,
        CTN_TURN
    };

    static void registerQml();
    static Game *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void init();    // create a new game, load caseFile
    Q_INVOKABLE void startGame();

    Q_INVOKABLE Player *createPlayer(const QString name, QColor color, int indexLogo, int kibbles);
    Q_INVOKABLE void setupPlayers(const QVariantList &playerData);

    Q_INVOKABLE void nextPlayer();
    Q_INVOKABLE Player *getPlayer();
    
    // Case library functions for UI
    Q_INVOKABLE QList<Case*> getPurchasableCases() const;


    QList<Player*> players() const { return m_listPlayers; }
    int boardSize() const { return 40; }  // Standard Monopoly board size
    int currentPlayerIndex() const;

    Q_INVOKABLE Case* getNewCaseType(Case::CaseType type);
    Q_INVOKABLE Player* getNewPlayer();


    QList<Player *> listPlayers() const;

    Case **listCases() const;

    QList<Card *> listCards() const;

    // Map saving/loading

    DisplayParameter *getDisplayerParameter(const QVariantMap &displayInfoMap);
    QJsonArray formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray);
    Q_INVOKABLE bool saveMap(MapInfo* mapInfo, QVariantList itemSnapableList, MapTypes::MapType mapType);
    Q_INVOKABLE bool deleteMap(QString mapName, MapTypes::MapType mapType);
    Q_INVOKABLE Map *loadMap(QString mapName, MapTypes::MapType mapType);
    Q_INVOKABLE QList<ItemSnapable*> generateItems(QJsonObject jsonObject);

    Q_INVOKABLE void askPreview();
    Q_INVOKABLE void askNext();



    ~Game();

    QVariantList assetPath() const;
    Q_INVOKABLE QVariant getAssetPath(int index) const;

    void setAssetPath(const QVariantList &newAssetPath);

public slots:
    void onReturnEdit(QJsonObject newEdit);

signals:
    void gameStarted();

    void clearCurrentMap();

    void playersChanged();
    void currentPlayerIndexChanged();
    void propertyPurchased(int position, Player* newOwner);

    void assetNumberChanged();
    void assetPathChanged();
    
    void mapLoaded(Map *map);
    void foundItemSnapableTile(ItemSnapable *itemSnapable);
    void updateListEdits(QJsonObject newEdit);
    void askEdit(UndoRedoManager::EditAction editAction);

private slots:

private:
    explicit Game(QObject *parent = nullptr);
    static Game *m_pThis;
    QList<Case*> m_board;
    QList<Player*> m_listPlayers;
    Player* m_players;
    // QList<Case*> m_listCases;
    QList<Card*>  m_listCards;
    QList<CaseRestArea*>    m_family[CaseRestArea::FT_COUNT];

    int userSelectNext = 0;
    int userSelectPrev = 0;

    int m_currentPlayerIndex = 0;


    QVariantList m_assetPath;
};

#endif // GAME_H
